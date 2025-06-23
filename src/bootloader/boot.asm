org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


; FAT12 heaeder

jmp short start 
nop

; Boot sector code starts here
bdb_oem:                    db "MSWIN4.1" ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1  
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880
bdb_media_descriptor:       db 0F0h
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record

ebr_drive_number:           db 0
                            db 0 ;reserved

ebr_signature:              db 29h
ebr_volume_id:              db 24h, 38h, 59h, 78h ; 4 b
ebr_volume_label:           db "AMBMT OS   "
ebr_system_id:              db "FAT12   "



start:
    jmp main


;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; save registers we will modify
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; verify if next character is null?
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret
    

main:
    ; setup data segments
    mov ax, 0           ; can't set ds/es directly
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00      ; stack grows downwards from where we are loaded in memory


    mov [ebr_drive_number], dl

    mov ax , 1
    mov cl, 1
    mov bx, 0x7E00 ; load address for boot sector
    call disk_read
    ; print hello world message
    mov si, msg_hello
    call puts

    cli
    hlt


floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot


wait_key_and_reboot:
    ; wait for a key press
    mov ah, 0
    int 16h
    jmp 0FFFFh:0

.halt:
    cli ; disable interrupts, so cpu cannot stop halting
    jmp .halt

; Converts LBA to CHS
; Params:
;   - ax: LBA value
; Returns:
;   - cx[bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh : head
lba_to_chs: 

    push ax
    push dx


    xor dx, dx
    div word [bdb_sectors_per_track]

    inc dx 
    mov cx, dx

    xor dx, dx
    div word [bdb_heads]

    mov dh, dl 
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax 
    mov dl, al
    pop ax
    ret


; Reads sectors from disk
; Params:
;   - ax: LBA value
;   - cx: number of sectors to read (up to 128)
;   - dl :drive number
;   - es:bx: memory address where to store read data

disk_read:

    push ax
    push bx
    push cx
    push dx
    push di 

    push cx
    call lba_to_chs
    pop ax
    mov ah, 02h
    mov di, 3  ; retry count, as recommended by the docs


.retry:
    pusha
    stc ; set carry flag to indicate success or not
    int 13h
    jnc .done
    
    ; failed
    popa
    call disk_reset

    dec di 
    test di, di
    jnz .retry

.fail:
    jmp floppy_error ; if all attempts fail, we stop 


.done:
    popa

    pop ax
    pop bx
    pop cx
    pop dx
    pop di 
    ret


; Reset disk controller
; Params:
;   - dl : drive number
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_hello: db 'Hello world!', ENDL, 0
msg_read_failed: db 'Failed to read disk', ENDL, 0
msg_osname: db 'AMBMT OS', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h