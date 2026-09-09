default rel

extern GetStdHandle
extern WriteConsoleA
extern SetConsoleCursorPosition
extern SetConsoleTextAttribute
extern GetAsyncKeyState
extern Sleep
extern GetTickCount
extern ExitProcess

global main

STD_OUTPUT_HANDLE equ -11

VK_ESCAPE equ 1Bh
VK_SPACE  equ 20h
VK_LEFT   equ 25h
VK_UP     equ 26h
VK_RIGHT  equ 27h
VK_DOWN   equ 28h

BOARD_W equ 10
BOARD_H equ 20

PIECE_COUNT equ 7
ROT_COUNT equ 4
CELL_COUNT equ 4

COLOR_BLACK   equ 0
COLOR_BLUE    equ 1
COLOR_GREEN   equ 2
COLOR_CYAN    equ 3
COLOR_RED     equ 4
COLOR_MAGENTA equ 5
COLOR_YELLOW  equ 6
COLOR_WHITE   equ 7
BRIGHT        equ 8

section .data

title db '             T R E S',13,10,0

top_border db '       +--------------------+',13,10,0
bot_border db '       +--------------------+',13,10,0

score_text db ' SCORE: ',0
lines_text db ' LINES: ',0
level_text db ' LEVEL: ',0
next_text db ' NEXT:',13,10,0
hold_text db ' HOLD:',13,10,0

controls db \
' Controls:',13,10,\
'   <- -> / A D   Move',13,10,\
'   UP / W        Rotate',13,10,\
'   Z             Rotate CCW',13,10,\
'   DOWN / S      Soft Drop',13,10,\
'   SPACE         Hard Drop',13,10,\
'   C             Hold',13,10,\
'   P             Pause',13,10,\
'   R             Restart',13,10,\
'   Q / ESC       Quit',13,10,0

pause_text db 13,10,'                 P A U S E D',13,10,0

gameover_text db 13,10,\
'              G A M E   O V E R',13,10,\
'               Press R',13,10,0

newline db 13,10,0
empty_cell db '  ',0
block_cell db '[]',0
space_char db ' ',0

digits db '0123456789'

piece_data:

; I
db 0,1, 1,1, 2,1, 3,1
db 2,0, 2,1, 2,2, 2,3
db 0,2, 1,2, 2,2, 3,2
db 1,0, 1,1, 1,2, 1,3

; O
db 1,0, 2,0, 1,1, 2,1
db 1,0, 2,0, 1,1, 2,1
db 1,0, 2,0, 1,1, 2,1
db 1,0, 2,0, 1,1, 2,1

; T
db 1,0, 0,1, 1,1, 2,1
db 1,0, 1,1, 2,1, 1,2
db 0,1, 1,1, 2,1, 1,2
db 1,0, 0,1, 1,1, 1,2

; S
db 1,0, 2,0, 0,1, 1,1
db 1,0, 1,1, 2,1, 2,2
db 1,1, 2,1, 0,2, 1,2
db 0,0, 0,1, 1,1, 1,2

; Z
db 0,0, 1,0, 1,1, 2,1
db 2,0, 1,1, 2,1, 1,2
db 0,1, 1,1, 1,2, 2,2
db 1,0, 0,1, 1,1, 0,2

; J
db 0,0, 0,1, 1,1, 2,1
db 1,0, 2,0, 1,1, 1,2
db 0,1, 1,1, 2,1, 2,2
db 1,0, 1,1, 0,2, 1,2

; L
db 2,0, 0,1, 1,1, 2,1
db 1,0, 1,1, 1,2, 2,2
db 0,1, 1,1, 2,1, 0,2
db 0,0, 1,0, 1,1, 1,2

section .bss

h_out resq 1

board resb BOARD_W * BOARD_H

current_piece resd 1
next_piece resd 1
hold_piece resd 1

rotation resd 1
piece_x resd 1
piece_y resd 1

hold_used resd 1

score resd 1
lines resd 1
level resd 1

fall_timer resd 1
fall_delay resd 1

game_over resd 1
paused resd 1

bag resd PIECE_COUNT
bag_index resd 1
random_seed resd 1

key_left resd 1
key_right resd 1
key_down resd 1
key_up resd 1
key_space resd 1
key_z resd 1
key_c resd 1
key_p resd 1
key_r resd 1
key_q resd 1
key_esc resd 1

render_buf resb 16384
number_buf resb 32
bytes_written resd 1

section .text

main:

    ; main is called by the MinGW CRT, so use the normal Win64 ABI entry.
    ; Keep RSP 16-byte aligned before every API/function call.
    sub rsp, 28h

    mov ecx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov [h_out], rax

    call GetTickCount
    mov [random_seed], eax

    call game_reset

.loop:

    call input_update

    cmp dword [game_over], 1
    je .game_over

    cmp dword [paused], 1
    je .paused

    mov eax, [fall_timer]
    add eax, 16
    mov [fall_timer], eax

    mov eax, [fall_delay]
    cmp [fall_timer], eax
    jb .render

    mov dword [fall_timer], 0

    call move_down

.render:

    call render

    mov ecx, 16
    call Sleep

    jmp .loop

.paused:

    call render

    mov ecx, 50
    call Sleep

    call input_update

    cmp dword [paused], 1
    je .paused

    jmp .loop

.game_over:

    call render

    mov ecx, 50
    call Sleep

    call input_update

    cmp dword [game_over], 1
    je .game_over

    jmp .loop


game_reset:

    push rdi

    lea rdi, [board]
    xor eax, eax
    mov ecx, BOARD_W * BOARD_H
    rep stosb

    mov dword [score], 0
    mov dword [lines], 0
    mov dword [level], 1

    mov dword [fall_timer], 0
    mov dword [fall_delay], 600

    mov dword [game_over], 0
    mov dword [paused], 0

    mov dword [hold_piece], -1
    mov dword [hold_used], 0

    mov dword [bag_index], PIECE_COUNT

    call fill_bag
    call get_bag_piece
    mov [current_piece], eax

    call get_bag_piece
    mov [next_piece], eax

    mov dword [rotation], 0
    mov dword [piece_x], 3
    mov dword [piece_y], 0

    pop rdi
    ret


fill_bag:

    mov dword [bag + 0], 0
    mov dword [bag + 4], 1
    mov dword [bag + 8], 2
    mov dword [bag + 12], 3
    mov dword [bag + 16], 4
    mov dword [bag + 20], 5
    mov dword [bag + 24], 6

    mov dword [bag_index], 7

    mov ecx, 6

.shuffle:
    cmp ecx, 0
    jle .done

    call random_u32

    ; random index = random_u32() % (ecx + 1)
    mov r10d, eax
    mov eax, ecx
    inc eax
    mov r9d, eax
    mov eax, r10d
    xor edx, edx
    div r9d
    mov r8d, edx

    lea r9, [bag]

    ; Swap bag[ecx] and bag[random_index].
    mov eax, ecx
    mov eax, [r9 + rax*4]

    mov ebx, r8d
    mov edx, [r9 + rbx*4]

    mov ebx, ecx
    mov [r9 + rbx*4], edx

    mov ebx, r8d
    mov [r9 + rbx*4], eax

    dec ecx
    jmp .shuffle

.done:
    ret

get_bag_piece:

    mov eax, [bag_index]

    cmp eax, 7
    jl .get

    call fill_bag
    xor eax, eax

.get:

    mov ecx, eax
    inc eax
    mov [bag_index], eax

    lea r9, [bag]
    mov eax, [r9 + rcx*4]
    ret


random_u32:

    mov eax, [random_seed]
    imul eax, eax, 1664525
    add eax, 1013904223
    mov [random_seed], eax
    ret


input_update:

    call key_left_check
    call key_right_check
    call key_down_check
    call key_up_check
    call key_z_check
    call key_space_check
    call key_c_check
    call key_p_check
    call key_r_check
    call key_q_check
    call key_esc_check

    ret


key_left_check:

    sub rsp, 28h

    mov ecx, VK_LEFT
    call GetAsyncKeyState
    test ax, 8000h
    jnz .pressed

    mov ecx, 'A'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

.pressed:

    cmp dword [key_left], 1
    je .done

    mov dword [key_left], 1

    cmp dword [paused], 1
    je .done
    cmp dword [game_over], 1
    je .done

    call move_left
    add rsp, 28h
    ret

.up:
    mov dword [key_left], 0

.done:
    add rsp, 28h
    ret


key_right_check:

    sub rsp, 28h

    mov ecx, VK_RIGHT
    call GetAsyncKeyState
    test ax, 8000h
    jnz .pressed

    mov ecx, 'D'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

.pressed:

    cmp dword [key_right], 1
    je .done

    mov dword [key_right], 1

    cmp dword [paused], 1
    je .done
    cmp dword [game_over], 1
    je .done

    call move_right
    add rsp, 28h
    ret

.up:
    mov dword [key_right], 0

.done:
    add rsp, 28h
    ret


key_down_check:

    sub rsp, 28h

    mov ecx, VK_DOWN
    call GetAsyncKeyState
    test ax, 8000h
    jnz .pressed

    mov ecx, 'S'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

.pressed:

    cmp dword [key_down], 1
    je .done

    mov dword [key_down], 1

    cmp dword [paused], 1
    je .done
    cmp dword [game_over], 1
    je .done

    call move_down
    cmp eax, 1
    jne .done

    add dword [score], 1

.up:
    mov dword [key_down], 0

.done:
    add rsp, 28h
    ret


key_up_check:

    sub rsp, 28h

    mov ecx, VK_UP
    call GetAsyncKeyState
    test ax, 8000h
    jnz .pressed

    mov ecx, 'W'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

.pressed:

    cmp dword [key_up], 1
    je .done

    mov dword [key_up], 1

    cmp dword [paused], 1
    je .done
    cmp dword [game_over], 1
    je .done

    call rotate_cw

.up:
    mov dword [key_up], 0

.done:
    add rsp, 28h
    ret


key_z_check:

    sub rsp, 28h

    mov ecx, 'Z'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

    cmp dword [key_z], 1
    jne .pressed
    add rsp, 28h
    ret

.pressed:

    mov dword [key_z], 1

    cmp dword [paused], 1
    je .done
    cmp dword [game_over], 1
    je .done

    call rotate_ccw
    add rsp, 28h
    ret

.up:
    mov dword [key_z], 0

.done:
    add rsp, 28h
    ret


key_space_check:

    sub rsp, 28h

    mov ecx, VK_SPACE
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

    cmp dword [key_space], 1
    jne .pressed
    add rsp, 28h
    ret

.pressed:

    mov dword [key_space], 1

    cmp dword [paused], 1
    je .done
    cmp dword [game_over], 1
    je .done

    call hard_drop

.up:
    mov dword [key_space], 0

.done:
    add rsp, 28h
    ret


key_c_check:

    sub rsp, 28h

    mov ecx, 'C'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

    cmp dword [key_c], 1
    jne .pressed
    add rsp, 28h
    ret

.pressed:

    mov dword [key_c], 1

    cmp dword [paused], 1
    je .done
    cmp dword [game_over], 1
    je .done

    call hold

.up:
    mov dword [key_c], 0

.done:
    add rsp, 28h
    ret


key_p_check:

    sub rsp, 28h

    mov ecx, 'P'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

    cmp dword [key_p], 1
    jne .pressed
    add rsp, 28h
    ret

.pressed:

    mov dword [key_p], 1

    cmp dword [game_over], 1
    je .done

    xor dword [paused], 1

.up:
    mov dword [key_p], 0

.done:
    add rsp, 28h
    ret


key_r_check:

    sub rsp, 28h

    mov ecx, 'R'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

    cmp dword [key_r], 1
    jne .pressed
    add rsp, 28h
    ret

.pressed:

    mov dword [key_r], 1

    cmp dword [game_over], 1
    jne .done

    call game_reset

.up:
    mov dword [key_r], 0

.done:
    add rsp, 28h
    ret


key_q_check:

    sub rsp, 28h

    mov ecx, 'Q'
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

    cmp dword [key_q], 1
    jne .pressed
    add rsp, 28h
    ret

.pressed:

    mov dword [key_q], 1
    xor ecx, ecx
    call ExitProcess

.up:
    mov dword [key_q], 0

.done:
    add rsp, 28h
    ret


key_esc_check:

    sub rsp, 28h

    mov ecx, VK_ESCAPE
    call GetAsyncKeyState
    test ax, 8000h
    jz .up

    cmp dword [key_esc], 1
    jne .pressed
    add rsp, 28h
    ret

.pressed:

    mov dword [key_esc], 1
    xor ecx, ecx
    call ExitProcess

.up:
    mov dword [key_esc], 0

.done:
    add rsp, 28h
    ret


move_left:

    mov eax, [piece_x]
    dec eax

    mov ebx, [piece_y]
    call test_position

    cmp eax, 0
    jne .done

    dec dword [piece_x]

.done:
    ret


move_right:

    mov eax, [piece_x]
    inc eax

    mov ebx, [piece_y]
    call test_position

    cmp eax, 0
    jne .done

    inc dword [piece_x]

.done:
    ret


move_down:

    mov eax, [piece_x]
    mov ebx, [piece_y]
    inc ebx

    call test_position

    cmp eax, 1
    je .blocked

    inc dword [piece_y]
    xor eax, eax
    ret

.blocked:

    call lock_current
    call clear_lines
    call spawn_next

    mov eax, 1
    ret


hard_drop:

    xor ecx, ecx

.loop:

    mov eax, [piece_x]
    mov ebx, [piece_y]
    inc ebx

    call test_position

    cmp eax, 1
    je .landed

    inc dword [piece_y]
    inc ecx
    jmp .loop

.landed:

    imul ecx, 2
    add [score], ecx

    call lock_current
    call clear_lines
    call spawn_next

    ret


rotate_cw:

    mov eax, [rotation]
    inc eax
    and eax, 3

    mov r8d, eax

    call try_rotation

    ret


rotate_ccw:

    mov eax, [rotation]
    dec eax
    and eax, 3

    mov r8d, eax

    call try_rotation

    ret


try_rotation:

    sub rsp, 40
    mov [rsp+32], edx

    mov eax, [piece_x]
    mov ebx, [piece_y]
    mov edx, [rotation]
    mov [rsp+32], edx
    mov [rotation], r8d

    call test_position
    cmp eax, 0
    je .success

    mov eax, [piece_x]
    dec eax
    mov ebx, [piece_y]
    call test_position
    cmp eax, 0
    je .kick_left

    mov eax, [piece_x]
    inc eax
    mov ebx, [piece_y]
    call test_position
    cmp eax, 0
    je .kick_right

    mov edx, [rsp+32]
    mov [rotation], edx
    add rsp, 40
    ret

.kick_left:
    dec dword [piece_x]
    add rsp, 40
    ret

.kick_right:
    inc dword [piece_x]
    add rsp, 40
    ret

.success:
    add rsp, 40
    ret

test_position:

    push r12
    push r13
    push r14
    push r15

    mov r12d, eax
    mov r13d, ebx

    mov eax, [current_piece]
    imul eax, 32

    mov ebx, [rotation]
    imul ebx, 8

    add eax, ebx
    lea r10, [piece_data]
    lea r14, [r10 + rax]

    xor r15d, r15d

.loop:

    cmp r15d, 4
    jge .clear

    mov eax, r15d
    imul eax, 2

    movzx ecx, byte [r14 + rax]
    movzx edx, byte [r14 + rax + 1]

    add ecx, r12d
    add edx, r13d

    cmp ecx, 0
    jl .collision

    cmp ecx, BOARD_W
    jge .collision

    cmp edx, BOARD_H
    jge .collision

    cmp edx, 0
    jl .next

    mov eax, edx
    imul eax, BOARD_W
    add eax, ecx

    lea r10, [board]
    cmp byte [r10 + rax], 0
    jne .collision

.next:

    inc r15d
    jmp .loop

.collision:

    mov eax, 1
    jmp .done

.clear:

    xor eax, eax

.done:

    pop r15
    pop r14
    pop r13
    pop r12
    ret


lock_current:

    push r12
    push r13
    push r14

    mov eax, [current_piece]
    imul eax, 32

    mov ebx, [rotation]
    imul ebx, 8

    add eax, ebx
    lea r10, [piece_data]
    lea r14, [r10 + rax]

    xor r12d, r12d

.loop:

    cmp r12d, 4
    jge .done

    mov eax, r12d
    imul eax, 2

    movzx ecx, byte [r14 + rax]
    movzx edx, byte [r14 + rax + 1]

    add ecx, [piece_x]
    add edx, [piece_y]

    cmp ecx, 0
    jl .next

    cmp ecx, BOARD_W
    jge .next

    cmp edx, 0
    jl .next

    cmp edx, BOARD_H
    jge .next

    mov eax, edx
    imul eax, BOARD_W
    add eax, ecx

    mov ecx, [current_piece]
    inc ecx
    lea r10, [board]
    mov [r10 + rax], cl

.next:

    inc r12d
    jmp .loop

.done:

    pop r14
    pop r13
    pop r12
    ret


clear_lines:

    push r12
    push r13
    push r14
    push r15

    xor r12d, r12d

.row:

    cmp r12d, BOARD_H
    jge .done

    xor r13d, r13d

.check:

    cmp r13d, BOARD_W
    jge .full

    mov eax, r12d
    imul eax, BOARD_W
    add eax, r13d

    lea r10, [board]
    cmp byte [r10 + rax], 0
    je .next_row

    inc r13d
    jmp .check

.next_row:

    inc r12d
    jmp .row

.full:

    mov r15d, r12d

.shift:

    cmp r15d, 0
    jle .clear_top

    mov eax, r15d
    dec eax
    imul eax, BOARD_W
    lea r10, [board]
    lea rsi, [r10 + rax]

    mov eax, r15d
    imul eax, BOARD_W
    lea r10, [board]
    lea rdi, [r10 + rax]

    mov ecx, BOARD_W

.copy:

    mov al, [rsi]
    mov [rdi], al

    inc rsi
    inc rdi

    dec ecx
    jnz .copy

    dec r15d
    jmp .shift

.clear_top:

    lea rdi, [board]
    xor eax, eax
    mov ecx, BOARD_W
    rep stosb

    inc dword [lines]

    mov eax, [lines]
    xor edx, edx
    mov ecx, 10
    div ecx

    inc eax
    cmp eax, 20
    jle .level

    mov eax, 20

.level:

    mov [level], eax

    mov ecx, 600
    mov eax, [level]
    imul eax, 25
    sub ecx, eax

    cmp ecx, 80
    jge .delay

    mov ecx, 80

.delay:

    mov [fall_delay], ecx

    mov eax, [level]
    imul eax, 100
    add [score], eax

    jmp .row

.done:

    pop r15
    pop r14
    pop r13
    pop r12
    ret


spawn_next:

    mov eax, [next_piece]
    mov [current_piece], eax

    call get_bag_piece
    mov [next_piece], eax

    mov dword [rotation], 0
    mov dword [piece_x], 3
    mov dword [piece_y], 0
    mov dword [fall_timer], 0
    mov dword [hold_used], 0

    mov eax, [piece_x]
    mov ebx, [piece_y]

    call test_position

    cmp eax, 0
    je .done

    mov dword [game_over], 1

.done:
    ret


hold:

    cmp dword [hold_used], 1
    je .done

    mov dword [hold_used], 1

    mov eax, [hold_piece]

    cmp eax, -1
    jne .swap

    mov eax, [current_piece]
    mov [hold_piece], eax

    mov eax, [next_piece]
    mov [current_piece], eax

    call get_bag_piece
    mov [next_piece], eax

    jmp .reset

.swap:

    mov ebx, [current_piece]
    mov [current_piece], eax
    mov [hold_piece], ebx

.reset:

    mov dword [rotation], 0
    mov dword [piece_x], 3
    mov dword [piece_y], 0
    mov dword [fall_timer], 0

.done:
    ret


render:

    call cursor_home

    lea rcx, [title]
    call write_string

    lea rcx, [top_border]
    call write_string

    xor r12d, r12d

.row:

    cmp r12d, BOARD_H
    jge .bottom

    mov ecx, COLOR_WHITE
    call set_color

    lea rcx, [space_char]
    call write_string

    mov byte [render_buf], '|'
    mov byte [render_buf + 1], 0

    lea rcx, [render_buf]
    call write_string

    xor r13d, r13d

.col:

    cmp r13d, BOARD_W
    jge .row_end

    mov eax, r12d
    imul eax, BOARD_W
    add eax, r13d

    lea r10, [board]
    movzx ebx, byte [r10 + rax]

    cmp ebx, 0
    jne .board_block

    mov eax, r13d
    sub eax, [piece_x]

    mov ebx, r12d
    sub ebx, [piece_y]

    call active_cell

    cmp eax, 0
    je .empty

    dec eax
    call color_for_piece

    mov ecx, eax
    call set_color

    lea rcx, [block_cell]
    call write_string

    jmp .next

.board_block:

    dec ebx
    mov eax, ebx
    call color_for_piece

    mov ecx, eax
    call set_color

    lea rcx, [block_cell]
    call write_string

    jmp .next

.empty:

    mov ecx, COLOR_BLACK
    call set_color

    lea rcx, [empty_cell]
    call write_string

.next:

    inc r13d
    jmp .col

.row_end:

    mov ecx, COLOR_WHITE
    call set_color

    mov byte [render_buf], '|'
    mov byte [render_buf + 1], 13
    mov byte [render_buf + 2], 10
    mov byte [render_buf + 3], 0

    lea rcx, [render_buf]
    call write_string

    inc r12d
    jmp .row

.bottom:

    lea rcx, [bot_border]
    call write_string

    call render_info

    cmp dword [paused], 1
    jne .check_over

    lea rcx, [pause_text]
    call write_string

.check_over:

    cmp dword [game_over], 1
    jne .done

    lea rcx, [gameover_text]
    call write_string

.done:

    mov ecx, COLOR_WHITE
    call set_color

    ret


active_cell:

    push r12
    push r13
    push r14

    mov r12d, eax
    mov r13d, ebx

    cmp r12d, 0
    jl .none
    cmp r12d, 4
    jge .none
    cmp r13d, 0
    jl .none
    cmp r13d, 4
    jge .none

    mov eax, [current_piece]
    imul eax, 32

    mov ebx, [rotation]
    imul ebx, 8

    add eax, ebx
    lea r10, [piece_data]
    lea r14, [r10 + rax]

    xor ecx, ecx

.find:

    cmp ecx, 4
    jge .none

    mov eax, ecx
    imul eax, 2

    movzx edx, byte [r14 + rax]
    cmp edx, r12d
    jne .next

    movzx edx, byte [r14 + rax + 1]
    cmp edx, r13d
    jne .next

    mov eax, [current_piece]
    inc eax
    jmp .done

.next:

    inc ecx
    jmp .find

.none:

    xor eax, eax

.done:

    pop r14
    pop r13
    pop r12
    ret


color_for_piece:

    cmp eax, 0
    je .cyan

    cmp eax, 1
    je .yellow

    cmp eax, 2
    je .magenta

    cmp eax, 3
    je .green

    cmp eax, 4
    je .red

    cmp eax, 5
    je .blue

    mov eax, COLOR_YELLOW + BRIGHT
    ret

.cyan:
    mov eax, COLOR_CYAN + BRIGHT
    ret

.yellow:
    mov eax, COLOR_YELLOW + BRIGHT
    ret

.magenta:
    mov eax, COLOR_MAGENTA + BRIGHT
    ret

.green:
    mov eax, COLOR_GREEN + BRIGHT
    ret

.red:
    mov eax, COLOR_RED + BRIGHT
    ret

.blue:
    mov eax, COLOR_BLUE + BRIGHT
    ret


render_info:

    lea rcx, [newline]
    call write_string

    lea rcx, [score_text]
    call write_string

    mov eax, [score]
    call print_number

    lea rcx, [newline]
    call write_string

    lea rcx, [lines_text]
    call write_string

    mov eax, [lines]
    call print_number

    lea rcx, [newline]
    call write_string

    lea rcx, [level_text]
    call write_string

    mov eax, [level]
    call print_number

    lea rcx, [newline]
    call write_string

    call render_hold
    call render_next

    lea rcx, [controls]
    call write_string

    ret


render_hold:

    lea rcx, [hold_text]
    call write_string

    cmp dword [hold_piece], -1
    je .empty

    mov eax, [hold_piece]
    call render_piece_preview
    ret

.empty:

    lea rcx, [newline]
    call write_string

    lea rcx, [newline]
    call write_string

    ret


render_next:

    lea rcx, [next_text]
    call write_string

    mov eax, [next_piece]
    call render_piece_preview

    ret


render_piece_preview:

    push r12
    push r13
    push r14

    mov r12d, eax

    xor r13d, r13d

.row:

    cmp r13d, 2
    jge .done

    xor r14d, r14d

.col:

    cmp r14d, 4
    jge .line

    mov eax, r12d
    imul eax, 32
    lea r10, [piece_data]
    lea r8, [r10 + rax]

    xor ecx, ecx

.find:

    cmp ecx, 4
    jge .empty

    mov eax, ecx
    imul eax, 2

    movzx edx, byte [r8 + rax]
    cmp edx, r14d
    jne .next

    movzx edx, byte [r8 + rax + 1]
    cmp edx, r13d
    jne .next

    mov eax, r12d
    call color_for_piece

    mov ecx, eax
    call set_color

    lea rcx, [block_cell]
    call write_string

    jmp .after

.next:

    inc ecx
    jmp .find

.empty:

    mov ecx, COLOR_BLACK
    call set_color

    lea rcx, [empty_cell]
    call write_string

.after:

    inc r14d
    jmp .col

.line:

    mov ecx, COLOR_WHITE
    call set_color

    lea rcx, [newline]
    call write_string

    inc r13d
    jmp .row

.done:

    pop r14
    pop r13
    pop r12

    ret


print_number:

    push rbx
    push rdi

    lea rdi, [number_buf + 31]
    mov byte [rdi], 0

    mov ebx, 10

    cmp eax, 0
    jne .convert

    dec rdi
    mov byte [rdi], '0'

    mov rcx, rdi
    call write_string

    jmp .done

.convert:

    xor edx, edx
    div ebx

    add dl, '0'

    dec rdi
    mov [rdi], dl

    test eax, eax
    jnz .convert

    mov rcx, rdi
    call write_string

.done:

    pop rdi
    pop rbx

    ret


cursor_home:

    sub rsp, 28h

    xor edx, edx

    mov rcx, [h_out]
    call SetConsoleCursorPosition

    add rsp, 28h
    ret


set_color:

    sub rsp, 28h

    mov edx, ecx
    mov rcx, [h_out]

    call SetConsoleTextAttribute

    add rsp, 28h
    ret


write_string:

    sub rsp, 28h

    push rbx
    push rsi

    mov rsi, rcx
    xor ebx, ebx

.count:

    cmp byte [rsi + rbx], 0
    je .count_done

    inc ebx
    jmp .count

.count_done:

    mov rcx, [h_out]
    mov rdx, rsi
    mov r8d, ebx
    lea r9, [bytes_written]

    call WriteConsoleA

    pop rsi
    pop rbx

    add rsp, 28h
    ret