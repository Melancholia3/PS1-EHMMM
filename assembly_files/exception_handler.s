/* 

exception_handler.s 

PS1 EHMMM - PS1 Exception Handler by melanchlia3_

Captures PS1 exceptions and sends the register values over the SIO1 on serial, sending the registers on a console

It Should work on retail (SCPH7501.bin) and openBIOS, this should be captured by the serial port on the PS1 with a TTY console
or using the serial cable for ps1

if you want to use this on psn00bsdk you can use the exception handler as a library, just include the exception_handler.s and data.s 
on your project and call the handler function on your exception vector

  MIT License
  Copyright (c) 2026 Melanchlia3_
 
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

*/

    .text
    .global handler
    .global verifier

    .extern send_string
    .extern send_hex
    
    .extern Offset
    .extern Strings
    .extern CauseText
    .extern GenericCause
    .extern newline
    .extern excHead
    .extern separate
    .extern spaces
    .extern str_opcode

    .set noreorder

handler:
    la      $gp, _gp    
    addiu   $sp, $sp, -32
    sw      $ra, 28($sp)     
    sw      $s0, 24($sp)     
    sw      $s1, 20($sp)
    sw      $s2, 16($sp)
         

    # SIO INIT, will be configured to 115200 bauds, 
    lui     $t0, 0x1f80

    li      $t1, 0x004e          
    sh      $t1, 0x1058($t0)    #SIO_MODE: 8 data bits, no parity, 1 stop bit, 16x clock
    nop

    li      $t1, 0x0012          
    sh      $t1, 0x105e($t0)    #SIO_BAUD: should be ~ 115200 bauds
    nop

    li      $t1, 0x0025          
    sh      $t1, 0x105a($t0)    #SIO_CTRL: enable TX + RX, RTS asserted
    nop

    # Load the address of thhe TCB to memory, will be used to retrieve the registers
    lw      $s0, 0x108($zero)
    nop
    lw      $s0, 0($s0)
    nop

    la      $s1, Offset
    la      $s2, Strings
    li      $s3, 0
    li      $s4, 0

    la      $a0, excHead    # Inserts head
    jal     send_string
    nop    
    jal    retrieve_cause
    nop


    # re-read TCB: retrieve_cause may have trashed $t registers, it's optional to resave them
    lw      $s0, 0x108($zero)
    nop
    lw      $s0, 0($s0)
    nop

loop_handler:

    # first 3 entries, EPC, $ra, $sp
    jal     retrieve
    nop

    #Loop logic
    addiu   $s3, $s3, 1
    slti    $t0, $s3, 3
    bnez    $t0, loop_handler
    nop

    # When out of loop, print decoration
    la      $a0, newline    
    jal     send_string
    nop

    la      $a0, separate    # Inserts newline
    jal     send_string
    nop

loop_handler2:

    # here, remaining registers will be printed, 3 per row
    jal     retrieve
    nop
    addiu   $s4, $s4, 1     # Column Counter
    addiu   $s3, $s3, 1     # Total Counter

    slti    $t0, $s3, 30
    beq     $t0, $zero , handler_end_clean

    li      $t1, 3
    beq     $s4, $t1, skip_line 
    nop

    j       loop_handler2
    nop

handler_end_clean:
    # Does one last line jump
    la      $a0, newline    
    jal     send_string
    nop

handler_end:
    # Halts the exception handler, there should be nothing after a crash
    j       handler_end
    nop

skip_line:
    la      $a0, newline    
    jal     send_string
    nop

    li      $s4, 0
    j       loop_handler2
    nop


retrieve:

    addiu   $sp, $sp, -16      # open own frame
    sw      $ra, 12($sp)


    lw      $t0, 0($s1)
    nop
    addu    $t0, $t0, $s0
    nop
    lw      $a1, 0($t0) # Value to print

    lw      $a0, 0($s2) # poiner to fixed string
    nop

    jal     send_string
    nop
    jal     send_hex
    nop

    la      $a0, spaces    # Inserts spaces
    jal     send_string
    nop    
    

    addi    $s1, $s1, 4    
    addi    $s2, $s2, 4


    lw      $ra, 12($sp)
    nop

    addiu   $sp, $sp, 16       # close own frame
    jr      $ra
    nop

retrieve_cause:
    addiu   $sp, $sp, -16      # open own frame
    sw      $ra, 12($sp)
    sw      $s1, 8($sp)


    mfc0    $a1, $13             # Load Cause register directly from the cop0, as TCB could read wrong values
    nop 
    srl     $a1, $a1, 2
    andi    $a1, $a1, 0x1f
    nop

    move    $t0, $a1            # ExcCode -> index
    sll     $t0, $t0, 2         # * 4 for word offset

    la      $t1, CauseText
    add     $t1, $t1, $t0
    lw      $s1, 0($t1)         # $s1 survives the jal calls, so we need to move then here as $t registers will be trashed
    nop

    la      $a0, GenericCause   # "Cause = "
    jal     send_string
    nop

    move    $a0, $s1            # actual cause string
    jal     send_string
    nop

    la      $a0, spaces        # putspace
    jal     send_string
    nop

    la      $a0, str_opcode     #raw opcode string
    jal     send_string
    nop

    move    $a0, $s1
    jal     send_hex            #Raw opcode
    nop

 
    la      $a0, newline        #enter newline
    jal     send_string
    nop
    
    lw      $s1, 8($sp)
    lw      $ra, 12($sp)
    nop
    addiu   $sp, $sp, 16       # close own frame
    jr      $ra
    nop


verifier:
    # Claim the exception unless it's irq (0x00) or syscall (0x08), as such aren't part of a crash but a normal flow of program execution
    mfc0    $t0, $13
    nop
    srl     $t0, $t0, 2
    andi    $t0, $t0, 0x1F
    beq     $t0, $zero, not_exception
    nop
    li      $t1, 8
    beq     $t0, $t1, not_exception
    nop
    

    li      $v0, 1



    jr      $ra
    nop

not_exception:

    li      $v0,0
    jr      $ra
    nop



