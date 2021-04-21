org 0x7e00

mov ax, cs
mov ds, ax
mov es, ax
mov ax, 0x0
mov ss, ax
mov sp, 0x7c00

jmp Label_Start

CurrentSector       dw  0
FileIndex           dw  0
SectorOfKernel      dw  0
StartSectorOfKernel dw  0
ByteIndexOfKernel   dd  0
OFFSETOFCACHE 	    equ  0x9000
OFFSETOFFILESIZE    equ  0x1c
OFFSETOFFIRSTCLUS   equ  0x1a
LENGTHOFFILENAME    equ  0xb
StartOfFileSector   equ  31
StartOfDirSector    equ  2
OffsetOfKernel      equ  0x100000

KERNELFILENAME: db "KERNEL  BIN"
[BITS 16]

Label_InReadMode:
    mov ax, 0
    jmp $

Label_Start:
Label_SearchKernel:
    mov word[CurrentSector], 19
Label_ForSectorInRange:
    mov di, word[CurrentSector]
    mov si, 1
    mov dx, OFFSETOFCACHE
	call Func_ReadSector
	mov word[FileIndex], 0
Label_ForIndexInRange:
    mov di, word[FileIndex]
    call Func_IndexToDirPointer
    mov di, ax
    mov si, KERNELFILENAME
    call Func_CmpFileName
    cmp ax, 1
    je Label_KernelFound
    inc word[FileIndex]
    cmp word[FileIndex], 17
    je Label_ForSectorInRangeEnd
    jmp Label_ForIndexInRange
Label_ForSectorInRangeEnd:
    inc word[CurrentSector]
    cmp word[CurrentSector], 32
    je Label_KernelNoFound
    jmp Label_ForSectorInRange
Label_KernelNoFound:
    jmp $

Label_KernelFound:
    call Func_DirPointerToSectorOfFile
    mov word[SectorOfKernel], ax
    call Func_DirPointerToStartSectorOfFilePointer
    mov word[StartSectorOfKernel], ax

    lgdt [gdt_size]

    in al, 0x92
	or al, 00000010B
	out 0x92, al

	mov eax, cr0
	or eax, 1
	mov cr0, eax

    mov ax, 0x0010
    mov fs, ax 

    mov eax, cr0
    and al, 11111110b
    mov cr0, eax

Label_LoadKernel:
    mov word[FileIndex], 0  
Label_ForIndexInSectorOfKernel:
    mov si, 1   
    mov di, word[StartSectorOfKernel]
    mov dx, 0x9000
    call Func_ReadSector
    call Func_CopyKernel
    inc word[FileIndex]
    inc word[StartSectorOfKernel]
    mov ax, word[FileIndex]
    cmp ax, word[SectorOfKernel]
    je Label_ForIndexInSectorOfKernelEnd
    jmp Label_ForIndexInSectorOfKernel
Label_ForIndexInSectorOfKernelEnd:
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    mov ax, 0x0010
    mov ds, ax

    jmp 0x0008:Label_ToLongMode

Func_CopyKernel:
    mov cx, 512
    mov si, OFFSETOFCACHE
    mov edi, OffsetOfKernel
Label_CopySingleByteOfKernel:
    lodsb
    mov edx, dword[ByteIndexOfKernel]
    mov byte[fs:edi + edx], al
    inc dword[ByteIndexOfKernel]
    loop Label_CopySingleByteOfKernel
    ret

Func_ReadSector:
    push bp
    mov bp, sp
    mov word[ss:bp - 2], di
    mov word[ss:bp - 4], si
    mov word[ss:bp - 6], dx
    mov ax, word[ss:bp - 2]
    mov bl, 18
    div bl
    inc ah 
    mov dh, al
    shr al, 1
    and dh, 1 

    mov cl, ah
    mov ch, al

    mov ax, word[ss:bp - 4]
    mov ah, 02h
    mov dl, 0 

    mov bx, 0  
    mov es, bx  
    mov bx, word[ss:bp - 6]

    int 13h    
    pop bp
    ret 

Func_DirPointerToStartSectorOfFilePointer:
    mov bx, di
    add bx, OFFSETOFFIRSTCLUS
    mov ax, word[bx]
    add ax, StartOfFileSector
    ret

; int(sectorOfFile) DirPointerToSizeOfFile(int* dirPointer)
Func_DirPointerToSectorOfFile:
    mov ax, word[di + OFFSETOFFILESIZE]
    mov dx, word[di + OFFSETOFFILESIZE + 2]
    mov bx, 512
    div bx
    cmp dx, 0
    je  Label_FileSizeComplete
    inc ax
Label_FileSizeComplete:
    ret

; int* indexToDirPointer(int index)
Func_IndexToDirPointer:
    mov ax, di
    mov bl, 32
    mul bl
    add ax, OFFSETOFCACHE
    ret


; bool CmpFileName(int* dirPointer, int* fileNamePointer)
Func_CmpFileName:
    mov bx, 0
Label_GoOnCmpFileName:
    lodsb
    cmp byte[di + bx], al
    je Label_GoOn
    cmp bx, LENGTHOFFILENAME
    je Label_FileFound
    jmp Label_FileNameIncorrect
Label_FileFound:
    mov ax, 1
    ret
Label_FileNameIncorrect:
    mov ax, 0
    ret
Label_GoOn:
    inc bx
    jmp Label_GoOnCmpFileName

[BITS 32]
Label_ToLongMode:

    ;====== init template page table at 0x90000
    mov dword[0x90000], 0x91007

    mov dword[0x91000], 0x92007

    mov dword[0x92000], 0x000087

    lgdt [gdt64_size]
    mov ax, 0x10 
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov sp, 0x7e00

    mov eax, cr4
    bts eax, 5 
    mov cr4, eax

    mov eax, 0x90000 
    mov cr3, eax

    mov ecx, 0x0c0000080
    rdmsr

    bts eax, 8 
    wrmsr

    mov eax, cr0
    bts eax, 0
    bts eax, 31
    mov cr0, eax

    jmp 0x0008:0x100000
 
Func_SetSVGAMode:
	mov ax, 4f02h
	mov bx, 4180h
	int 10h
	ret 

;====== protect mode gdt
gdt_start_desc  dq  0x0000000000000000
gdt_code_desc   dq  0x00cf9a000000ffff
gdt_data_desc   dq  0x00cf92000000ffff

gdt_size    dw  $ - gdt_start_desc
gdt_base    dd  gdt_start_desc
	
;====== long mode gdt
gdt64_start_desc dq 0x0000000000000000
gdt64_code_desc  dq 0x0020980000000000
gdt64_data_desc  dq 0x0000920000000000

gdt64_size  dw  $ - gdt64_start_desc
gdt64_base  dd  gdt64_start_desc
;;====== set SVGA mode 
;mov ax, 4f02h
;mov bx, 4180h
;int 10h
;
;jmp Label_Start
;;====== 
;; void readSector(int* startOfSector, int* numberToRead, int* whereToPlace)
;;======
;Func_ReadSector:
;    push bp
;    mov bp, sp
;    mov word[ss:bp - 2], di
;    mov word[ss:bp - 4], si
;    mov word[ss:bp - 6], dx
;    mov ax, word[ss:bp - 2]
;    mov bl, 36
;    div bl
;    mov ch, al
;    mov al, ah
;    mov ah, 0
;    mov bl, 18
;    div bl
;    mov dh, al
;    mov cl, ah
;    mov ax, word[ss:bp - 4]
;    mov bx, 0
;    mov es, bx
;    mov ah, 02h
;    mov dl, 00h
;    mov bx, word[ss:bp - 6]
;    int 13h
;    pop bp
;    ret
;
;Func_DirPointerToStartSectorOfFilePointer:
;    mov bx, di
;    add bx, OFFSETOFFIRSTCLUS
;    mov ax, word[bx]
;    add ax, StartOfFileSector
;    ret
;
;; int(sectorOfFile) DirPointerToSizeOfFile(int* dirPointer)
;Func_DirPointerToSectorOfFile:
;    mov ax, word[di + OFFSETOFFILESIZE]
;    mov dx, word[di + OFFSETOFFILESIZE + 2]
;    mov bx, 512
;    div bx
;    cmp dx, 0
;    je  Label_FileSizeComplete
;    inc ax
;Label_FileSizeComplete:
;    ret
;
;; int* indexToDirPointer(int index)
;Func_IndexToDirPointer:
;    mov ax, di
;    mov bl, 32
;    mul bl
;    add ax, OffsetOfKernel
;    ret
;
;
;; bool CmpFileName(int* dirPointer, int* fileNamePointer)
;Func_CmpFileName:
;    mov bx, 0
;Label_GoOnCmpFileName:
;    lodsb
;    cmp byte[di + bx], al
;    je Label_GoOn
;    cmp bx, LENGTHOFFILENAME
;    je Label_FileFound
;    jmp Label_FileNameIncorrect
;Label_FileFound:
;    mov ax, 1
;    ret
;Label_FileNameIncorrect:
;    mov ax, 0
;    ret
;Label_GoOn:
;    inc bx
;    jmp Label_GoOnCmpFileName
;
;
;Label_SearchKernel:
;    mov word[CurrentSector], 20
;Label_ForSectorInRange:
;    mov di, word[CurrentSector]
;    mov si, 1
;    mov dx, OffsetOfKernel
;    call Func_ReadSector
;    mov word[FileIndex], 0
;Label_ForIndexInRange:
;    mov di, word[FileIndex]
;    call Func_IndexToDirPointer
;    mov di, ax
;    mov si, KernelFileName
;    call Func_CmpFileName
;    cmp ax, 1
;    je Label_KernelFound
;    inc word[FileIndex]
;    cmp word[FileIndex], 17
;    je Label_ForSectorInRangeEnd
;    jmp Label_ForIndexInRange
;Label_ForSectorInRangeEnd:
;    inc word[CurrentSector]
;    cmp word[CurrentSector], 35
;    je Label_KernelNoFound
;    jmp Label_ForSectorInRange
;Label_KernelNoFound:
;    jmp $
;Label_KernelFound:
;    call Func_DirPointerToSectorOfFile
;    mov si, ax
;    call Func_DirPointerToStartSectorOfFilePointer
;    mov di, ax
;    mov dx, OffsetOfKernel
;    call Func_ReadSector
;
;
;Label_Start:
;    jmp Label_ToProtectMode
;
;Label_ToProtectMode:
;    lgdt [gdt_size]
;    ;====== open A20 address
;	in al, 0x92
;	or al, 00000010B
;	out 0x92, al
;	;====== open protect mode
;	mov eax, cr0
;	or eax, 1
;	mov cr0, eax
;
;    jmp 0x0008:Lbael_InProtectMode
;
;[bits 32]
;Lbael_InProtectMode:
;	call Func_SearchKernel
;    mov ax, 0x10
;    mov ds, ax
;    jmp Label_ToLongMode
;
;Label_ToLongMode:
;    ;====== base of page
;	mov	dword	[0x5000],	0x6007	
;	mov	dword	[0x6000],	0x7007
;    mov dword   [0x6018],   0x7007
;	mov	dword	[0x7000],	0x8007
;    mov dword   [0x7800],   0x8007
;	mov	dword	[0x8000],	0xe0000007
;	mov dword	[0x8038],	0x7007
;
;	lgdt [gdt64_size]
;
;	mov eax, cr4
;	bts eax, 5
;	mov cr4, eax
;	
;	mov eax, 0x5000
;	mov cr3, eax
;
;	mov ecx, 0c0000080h
;	rdmsr
;	bts eax, 8
;	wrmsr
;
;	mov eax, cr0
;	bts eax, 31
;	bts eax, 0
;	mov cr0, eax
;
;    mov ecx, 0
;Label_ShowColor:
;    inc ecx
;    mov eax, ecx
;    mov bl, 4
;    mul bl
;    mov byte [0xe0000000+eax], 0x00
;    mov byte [0xe0000001+eax], 0xff
;    mov byte [0xe0000002+eax], 0x00
;    mov byte [0xe0000003+eax], 0x00
;    cmp ecx, 500
;    jne Label_ShowColor
;	jmp $
;
;
;;====== protect mode gdt
;gdt_start_desc  dq  0x0000000000000000
;gdt_code_desc   dq  0x00cf9a000000ffff
;gdt_data_desc   dq  0x00cf92000000ffff
;
;gdt_size    dw  $ - gdt_start_desc
;gdt_base    dd  gdt_start_desc
;
;;====== long mode gdt
;gdt64_start_desc dq 0x0000000000000000
;gdt64_code_desc  dq 0x0000980000000000
;gdt64_data_desc  dq 0x0000920000000000
;
;gdt64_size  dw  $ - gdt64_start_desc
;gdt64_base  dd  gdt64_start_desc
;
;;======
;KernelFileName	db	"KERNEL   BIN"
;