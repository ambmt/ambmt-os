org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

jmp short start
nop

bdb_oem:                    db "MSWIN4.1"
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

ebr_drive_number:           db 0
                            db 0

ebr_signature:              db 29h
ebr_volume_id:              db 24h, 38h, 59h, 78h
ebr_volume_label:           db "AMBMT OS   "
ebr_system_id:              db "FAT12   "

start:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [ebr_drive_number], dl

    mov si, msg_boot_start
    call puts

    mov ax, 1          ; LBA = 1 (second sector)
    mov cx, 4          ; load 4 sectors (adjust if kernel is bigger)
    mov bx, 0x7E00     ; load address
    mov dl, [ebr_drive_number]
    call disk_read

    mov si, msg_boot_jump
    call puts

    jmp 0x0000:0x7E00  ; jump to kernel

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0

puts:
    push si
    push ax
    push bx
.puts_loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .puts_loop
.done:
    pop bx
    pop ax
    pop si
    ret

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
    mov di, 3
.retry:
    pusha
    stc
    int 13h
    jnc .done
    popa
    call disk_reset
    dec di
    test di, di
    jnz .retry
.fail:
    jmp floppy_error
.done:
    popa
    pop ax
    pop bx
    pop cx
    pop dx
    pop di
    ret

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_boot_start:    db 'Boot: loading kernel...', ENDL, 0
msg_boot_jump:     db 'Boot: jumping to kernel', ENDL, 0
msg_read_failed:   db 'Failed to read disk', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h