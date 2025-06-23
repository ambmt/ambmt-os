org 0x7E00
bits 16

%define ENDL 0x0D, 0x0A

start:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov si, msg_kernel_start
    call puts

shell_loop:
    mov si, prompt
    call puts

    mov di, input_buffer
    mov cx, 31
    call read_line

    mov si, input_buffer
    mov di, cmd_hello
    call strcmp
    cmp al, 0
    je print_hello

    mov si, input_buffer
    mov di, cmd_help
    call strcmp
    cmp al, 0
    je print_help

    mov si, msg_unknown
    call puts
    jmp shell_loop

print_hello:
    mov si, msg_hello
    call puts
    jmp shell_loop

print_help:
    mov si, msg_help
    call puts
    jmp shell_loop

puts:
    push si
    push ax
    push bx
.puts_loop:
    lodsb
    or al, al
    jz .puts_done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .puts_loop
.puts_done:
    pop bx
    pop ax
    pop si
    ret

read_line:
    push ax
    push bx
    push cx
    push dx
    mov word [read_line_max_len], cx
    xor bx, bx
.read_char:
    cmp bx, word [read_line_max_len]
    jge .done_input_limit
    mov ah, 0
    int 16h
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .backspace
    cmp al, 0x20
    jb .read_char
    cmp al, 0x7E
    ja .read_char
    stosb
    mov ah, 0x0E
    mov bh, 0
    int 10h
    inc bx
    jmp .read_char
.backspace:
    cmp bx, 0
    je .read_char
    dec di
    dec bx
    mov ah, 0x0E
    mov al, 0x08
    int 10h
    mov al, ' '
    int 10h
    mov al, 0x08
    int 10h
    jmp .read_char
.done_read:
    mov si, ENDL_chars
    call puts
.done_input_limit:
    mov al, 0
    stosb
    mov si, di
    sub si, 2
    cmp byte [si], 0x0D
    jne .skip_strip_cr
    mov byte [si], 0
.skip_strip_cr:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

strcmp:
    push ax
.strcmp_loop:
    lodsb
    scasb
    jne .notequal
    test al, al
    jne .strcmp_loop
    xor al, al
    pop ax
    ret
.notequal:
    mov al, 1
    pop ax
    ret

msg_kernel_start: db 'Kernel: started!', ENDL, 0
prompt:           db 'os> ',0
cmd_hello:        db 'hello',0
cmd_help:         db 'help',0
msg_hello:        db 'Hello world!', ENDL, 0
msg_help:         db 'Type hello or help', ENDL, 0
msg_unknown:      db 'Unknown command', ENDL, 0
input_buffer:     times 32 db 0
ENDL_chars:       db ENDL, 0
read_line_max_len: dw