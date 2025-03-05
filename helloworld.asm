segment .bss
buf resb 1
fd resd 1
index resb 1
line resb 128


segment .data
mesg: db "crctest.txt",0
out: db "%s",10,0
print: db "The CRC for the string '%s' is - %04x",10,0


segment .text
global asm_main
extern printf

asm_main:
    enter 0,0

    mov byte [index], 0

    mov eax, 5    ;Intel 32-bit call for open - File pointer will be stores in rax
    mov ebx, mesg ;Parameter 1 - ebx - filename
    mov ecx, 0    ;Parameter 2 - ecx - flags (0 = O_RDONLY)
    int 0x80      ;System interrupt

    mov [fd], eax   ;Save the file descriptor
    xor r13, r13    ;Clear r13
    lea r13d, line  ;Load address of the line into r13d

readline:
    mov edx, 1         ;Move contents at memory address [bufsize] into edx, Parameter 3 - read count
    mov ecx, buf       ;Move buffer address into ecx - Parameter 2 - buffer
    mov ebx, [fd]      ;Move file pointer into ebx from r8d
    mov eax, 3         ;Intel 32-bit call for read
    int 0x80           ;System interrupt
    mov al, [buf]      ;Save buffer in al
    cmp al, 0x0D       ;Make sure al isn't carriage return
    jz continue        ;If it is, stop looping
    movzx eax, al      ;Otherwise, 0 extend al into eax
    mov [r13d], eax    ;Move eax into the next byte of the line
    inc r13d           ;Increment the address pointed to of the line
    jmp readline       ;Jump to beginning of loop


continue:


    mov eax, 19
    mov ebx, [fd]
    mov ecx, 1
    mov edx, 1
    int 0x80

    mov edx, 1
    mov ecx, buf
    mov ebx, [fd]
    mov eax, 3
    int 0x80
    mov al, [buf]
    
    sub r13d, line ;Find length of string
    sub r13d, 1    ;Padding for 16 0s, and must shift 16 times to begin 
    imul r13d, 8
    mov edx, r13d  

    xor rax, rax
    xor r13, r13
    

    lea r12d, [line]
    mov r13d, [r12d]
    add r12d, 3

    mov ecx, 16
initializeloop:
    shr r13, 1
    rcr ax, 1
    loop initializeloop

    mov ecx, 16
initializeincomingloop:
    shr r13, 1
    rcr bx, 1
    loop initializeincomingloop
    

    xchg ah, al
    xchg bh, bl

    mov ecx, 17

CRCLoop:

    mov edx, 8
shiftloop:
    shl bx, 1
    rcl ax, 1
    jc ifcarry
    jmp aftercarry

ifcarry:
    xor ax, 0x1021

aftercarry:
    dec edx
    cmp edx, 0
    jnz shiftloop

    add r12d, 1
    mov bl, byte [r12d]

    loop CRCLoop


after:

    mov esi, line
    movzx rdx, ax
    mov edi, print
    call printf

    mov rax, 0
    leave
    ret
