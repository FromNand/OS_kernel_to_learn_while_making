##### マクロ #####
.equ	Null_Selector, 0x00			# GDTの中でのNULLセグメントのオフセット。
.equ	SysCode_Selector, 0x08			# GDTの中でのシステムコードセグメントのオフセット。
.equ	SysData_Selector, 0x10			# GDTの中でのシステムデータセグメントのオフセット。
.equ	Video_Selector, 0x18			# GDTの中でのカラーテキストVRAMを指すセグメントのオフセット。

##### 16bitモードの機械語を生成 #####
.code16

##### .textにプログラムを配置する #####
.text

##### レジスタの初期化 #####
init_regs:
	movw	%cs, %ax			# csには0x1000が入っている。
	movw	%ax, %ds			# dsもcsと同じセグメントを指すようにしておく。
	xorw	%ax, %ax			# axを0クリアする。
	movw	%ax, %ss			# ssは0に初期化する。
	movw	$0xfff0, %sp			# カーネルは0x10000から読み込まれるので、0xfff0から下をスタックにする。

##### 32bitモードに入る前に、GDTRの設定を行う #####
	cli					# gdtrの設定をする前に、割り込みを禁止する。
	lgdtl	(gdtr)				# 暫定GDTを設定。

##### 32bitモードに移行する #####
.arch i486					# 80486に向けての機械語を生成するようにgasに命令。(https://sourceware.org/binutils/docs-2.31/as/i386_002dArch.html)
	movl	%cr0, %eax			# cr0は直接値を変更することができないので、とりあえずeaxに保存する。
	andl	$0x7fffffff, %eax		# bit31を0に(ページング禁止)
	orl	$0x00000001, %eax		# bit0を1に(プロテクトモード移行)
	movl	%eax, %cr0			# cr0を更新することで設定を有効にする。
	ljmpw	$SysCode_Selector, $flash	# リアルモード(16bit)からプロテクテッドモード(32bit)に変化して、機械語の解釈が変わったのでパイプラインをフラッシュする。同時にcsに0x08を代入。
flash:						# フラッシュ用のラベルを作成。

##### csが32bitのコードセグメントを指すようになったので、生成する機械語も32bit用にしてもらう。(ここがないとエラー) #####
.code32

##### プロテクテッドでの設定を行う(esの設定は少し下で行う) #####
	movw	$SysData_Selector, %ax		# 32bitのデータセグメントをds, fs, gs, ssに設定したい。
	movw	%ax, %ds			# dsにaxを代入。
	movw	%ax, %fs			# fsにaxを代入。
	movw	%ax, %gs			# gsにaxを代入。
	movw	%ax, %ss			# ssにaxを代入。
	movl	$0x10000, %esp			# 物理メモリの0x20000の直下の部分を取り合えず、カーネルのスタック領域に指定。

##### カラーテキストVRAMを指すセグメントをesに設定する #####
	movw	$Video_Selector, %ax		# カラーテキストVRAMを指す、32bitのデータセグメントへのセレクタ値。
	movw	%ax, %es			# esに設定。
	movl	$(80*2*20)+(2*10), %edi		# 0xb8000から始まるVRAMは、一行80文字で一文字2byteなので、80*2*20+2*10=20行目の10文字目から書き込みの意味になる。
	leal	(msg), %esi			# 表示する文字列のアドレスをesiに設定。
	call	print				# 文字列表示関数(といっても、メモリにmovするだけだけれど)の呼び出し。

##### カーネルの終末 #####
fin:
	hlt					# みんな大好きHLT命令！
	jmp	fin				# なんだか、cli指定ない状態だと、この行がなければ貫通してしまうみたい。

##### 文字列表示関数(ds:esiに表示したい文字列、es:ediに文字列を表示したいVRAMのアドレスを指定する) #####
##### ただし、この関数は32bitモードで呼ばれることを前提としている #####
print:
	pushal					# めんどくさいから、全部のレジスタをまとめて退避。
print_loop:
	lodsb					# ds:esiの1byteをalにコピーして、esiに1加算する。
	andb	%al, %al			# alが0であるかどうかをチェック。
	jz	print_end			# もし、alが0ならば終了。
	stosb					# 取得した文字コードをes:ediに書き込む。
	movb	$0x60, %al			# 文字コードの属性をalに格納。
	stosb					# es:ediにalをコピー。
	jmp	print_loop			# 次の文字を読みに行く。
print_end:
	popal					# レジスタの復帰。
	ret					# 呼び出し元に帰る。

##### GDTや文字列などのデータは.dataセクションに並べる #####
.data

##### 文字列関連 #####
msg:
	.string	"We are in Protected Mode!!!"

##### GDTRに設定するデータ #####
	.align	8				# アライメントを8byte境界に揃える。
gdtr:						# ここのデータはlgdtlでgdtrに設定する値。
	.word	gdt_end-gdt-1			# gdtのlimit。
	.int	gdt+0x10000			# gdtのbase。dsが0x1000なので、デフォルトではデータへのアクセスの際、VMAが0x10000だけ引かれた値になっている。+0x10000でこれを修正する。

##### GDT #####
	.align	8				# アライメントを8byte境界に揃える。
gdt:

#.equ	Null_Selector, 0x00			# GDTの中でのNULLセグメントのオフセット。
	.skip	8, 0x00				# NULLセグメント。

#.equ	SysCode_Selector, 0x08			# GDTの中でのシステムコードセグメントのオフセット。
	.word	0xffff				# Segment Limit Low(16bit:0xffff)。
	.word	0x0000				# Segment Base Low(16bit:0x0000)。
	.byte	0x01				# Segment Base Mid(8bit:0x01)。
	.byte	0x9a				# 読み取り実行可能コードセグメント。
	.byte	0xcf				# Segment Limit High(4bit:0xf)。G:1, 32ビットセグメント。
	.byte	0x00				# Segment Base High(8bit:0x00)。

#.equ	SysData_Selector, 0x10			# GDTの中でのシステムデータセグメントのオフセット。
	.word	0xffff				# Segment Limit Low(16bit:0xffff)。
	.word	0x0000				# Segment Base Low(16bit:0x0000)。
	.byte	0x01				# Segment Base Mid(8bit:0x01)。
	.byte	0x92				# 読み取り書き込み可能データセグメント。
	.byte	0xcf				# Segment Limit High(4bit:0xf)。G:1, 32ビットセグメント。
	.byte	0x00				# Segment Base High(8bit:0x00)。

#.equ	Video_Selector, 0x18			# GDTの中でのカラーテキストVRAMを指すセグメントのオフセット。
	.word	0xffff				# Segment Limit Low(16bit:0xffff)。
	.word	0x8000				# Segment Base Low(16bit:0x8000)。
	.byte	0x0b				# Segment Base Mid(8bit:0x0b)。
	.byte	0x92				# 読み取り書き込み可能データセグメント。
	.byte	0x40				# Segment Limit High(4bit:0x0)。G:0, 32ビットセグメント。
	.byte	0x00				# Segment Base High(8bit:0x00)。

gdt_end:
