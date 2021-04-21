org 0x7c00
%include "zfyFS.inc"

LOADERFILENAME: db "LOADER  BIN"

OFFSETOFFILESIZE    equ  0x1c
OFFSETOFFIRSTCLUS   equ  0x1a
LENGTHOFFILENAME    equ  0xb

StartOfFileSector   equ     32

OFFSETOFLOADER  equ 0x7e00

StartOfDirSector   equ  20

CurrentSector   dw  0
FileIndex   dw  0

Label_Start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0x0
    mov ss, ax
    mov sp, 0x7c00
    jmp Label_SearchLoader

;====== 
; void readSector(int* startOfSector, int* numberToRead, int* whereToPlace)
;======
Func_ReadSector:
    push bp
    mov bp, sp
    mov word[ss:bp - 2], di
    mov word[ss:bp - 4], si
    mov word[ss:bp - 6], dx
    mov ax, word[ss:bp - 2]
    mov bl, 36
    div bl
    mov ch, al
    mov al, ah
    mov ah, 0
    mov bl, 18
    div bl
    mov dh, al
    mov cl, ah
    mov ax, word[ss:bp - 4]
    mov bx, 0
    mov es, bx
    mov ah, 02h
    mov dl, 00h
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
    add ax, OFFSETOFLOADER
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


Label_SearchLoader:
    mov word[CurrentSector], 20
Label_ForSectorInRange:
    mov di, word[CurrentSector]
    mov si, 1
    mov dx, OFFSETOFLOADER
    call Func_ReadSector
    mov word[FileIndex], 0
Label_ForIndexInRange:
    mov di, word[FileIndex]
    call Func_IndexToDirPointer
    mov di, ax
    mov si, LOADERFILENAME
    call Func_CmpFileName
    cmp ax, 1
    je Label_LoaderFound
    inc word[FileIndex]
    cmp word[FileIndex], 17
    je Label_ForSectorInRangeEnd
    jmp Label_ForIndexInRange
Label_ForSectorInRangeEnd:
    inc word[CurrentSector]
    cmp word[CurrentSector], 35
    je Label_LoaderNoFound
    jmp Label_ForSectorInRange
Label_LoaderNoFound:
    jmp $

Label_LoaderFound:
    call Func_DirPointerToSectorOfFile
    mov si, ax
    call Func_DirPointerToStartSectorOfFilePointer
    mov di, ax
    mov dx, OFFSETOFLOADER
    call Func_ReadSector
    jmp 0x7e00

times 510 - ($ - $$) db 0
dw 0xaa55
