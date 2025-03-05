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

    mov eax, 5          ;Intel 32-bit call for open - File pointer will be stores in rax
    mov ebx, mesg       ;Parameter 1 - ebx - filename
    mov ecx, 0          ;Parameter 2 - ecx - flags (0 = O_RDONLY)
    int 0x80            ;System interrupt

    mov [fd], eax       ;Save the file descriptor
    xor r13, r13        ;Clear r13

doCRC:

    lea r13d, line      ;Load address of the line into r13d
readline:
    mov edx, 1          ;Move contents at memory address [bufsize] into edx, Parameter 3 - read count
    mov ecx, buf        ;Move buffer address into ecx - Parameter 2 - buffer
    mov ebx, [fd]       ;Move file pointer into ebx from r8d
    mov eax, 3          ;Intel 32-bit call for read
    int 0x80            ;System interrupt
    mov al, [buf]       ;Save buffer in al
    cmp al, 0x0D        ;Make sure al isn't carriage return
    jz continue         ;If it is, stop looping
    movzx eax, al       ;Otherwise, 0 extend al into eax
    mov [r13d], eax     ;Move eax into the next byte of the line
    inc r13d            ;Increment the address pointed to of the line
    jmp readline        ;Jump to beginning of loop

continue:


    mov eax, 19         ;Syscall for lseek(). Moving file pointer forward 4 to skip return carriage / line feed for next iteration
    mov ebx, [fd]
    mov ecx, 4
    mov edx, 1
    int 0x80

    sub r13d, line      ;Find length of string - This is how many times the CRC must loop through to hit all bytes
                        ;Since the first 2 characters are read in by default, this number accounts for the 16 0's that must be padded

    mov ecx, 2          ;Do once for CRC, second time for redundancy check
crcagain:
    
    mov r14d, ecx       ;Save counter register so it can be used for other loops
   
    mov ecx, r13d       ;Save above "length of string" value for number of times to loop through it


    xor rax, rax        ;Clear rax and rbx
    xor rbx, rbx 

    lea r12d, [line]    ;Save line in r12d, r12d will act as pointer to line
    mov al, byte [r12d] ;Save 1st byte of line in al
    xor ah, al          ;Move it to ah
    inc r12d            ;Increment pointer
    mov al, byte[r12d]  ;Save 2nd byte of line in al
    inc r12d            ;Increment pointer
    mov bl, byte[r12d]  ;Save 3rd byte in bl
    xor bh, bl          ;Move it to bh
    inc r12d            ;Increment pointer
    mov bl, byte[r12d]  ;Save 4th byte in bl


CRCLoop:

    mov edx, 8          ;8 bits / byte to loop through
shiftloop:
    shl bx, 1           ;Shift bx (Incoming data) 1 bit and store it in CF
    rcl ax, 1           ;Shift ax (Current frame) 1 bit, moving CF (from bx) into LSB and moving MSB into CF 
    jc ifcarry          ;If 1 is MSB, we must XOR!
    jmp aftercarry      ;Otherwise, loop again

ifcarry:
    xor ax, 0x1021      ;XOR ax with our given polynomial 

aftercarry:
    dec edx             ;Decrement loop counter
    cmp edx, 0          ;If it's 0, done for this iteration
    jnz shiftloop

    add r12d, 1         ;Otherwise, move pointer to line forward
    mov bl, byte [r12d] ;Grab next byte. bx has been shifted 8 bits left, so bl is empty for next byte

    loop CRCLoop        ;Loop back and perform CRC on next byte

    sub r12d, 2         ;Once CRC is calculated, move pointer 2 back so we can store CRC at end of data
    movzx r15d, ax      ;Save the CRC in r15d for use after printf call

    mov esi, line       ;Inputted line from file
    mov edx,  r15d      ;CRC value (in hex)
    mov edi, print      ;Print formatter
    call printf

    mov ax, r15w        ;Restore CRC value to ax
    mov [r12d], al      ;x86 is little endian, so we store the CRC "Backwards"
    sub r12d, 1         ;Move pointer 1 back
    xchg ah, al         ;Move first half of CRC into higher 8-bits
    mov [r12d], al      ;Move other half of CRC

    mov ecx, r14d       ;Restore counter for overall CRC Loop (1 time for CRC, 2nd for error checking)
    dec ecx             ;Decrement it
    jnz crcagain        ;If we've done 2 loops, we're done. Otherwise, so 2nd loop

    mov ecx, 128        ;If we are done with CRC and error check, clear memory of line (128 bytes)
    lea r13d, [line]    ;Load effective address of line into r13d
clearline:
    mov r13d, 0x00      ;Clear byte
    inc r13d            ;Increment pointer
    loop clearline

afterclear:

                        ;We must now check to see if we have reached the end of the file
                        ;Using read, we will check if al results in a read error

    mov edx, 1          ;Move contents at memory address [bufsize] into edx, Parameter 3 - read count
    mov ecx, buf        ;Move buffer address into ecx - Parameter 2 - buffer
    mov ebx, [fd]       ;Move file pointer into ebx from r8d
    mov eax, 3          ;Intel 32-bit call for read
    int 0x80            ;System interrupt 
    cmp al, 0x00        ;See if al read, if it didn't we are done
    je done
    mov eax, 19         ;Otherwise, move the file pointer back to where it should be
    mov ebx, [fd]
    mov ecx, -4
    mov edx, 1
    int 0x80

    jmp doCRC           ;Do CRC again for next line of file

done:

    mov eax, 6          ;System call for close file
    mov ebx, [fd]       ;File descriptor
    int 0x80

    mov rax, 0
    leave
    ret
