/*
    sio_low.s 

    PS1 EHMMM - PS1 Exception Handler by Melanchlia3_


    This assembly file is a component to  Exception_handler.s as this lets the exception handler send registers and messages over the serial port of the PS1
    by any means, this should work without any kind of sdk, as this writes directly onto the ps1 registers, making it lightweight for any kind of lowlevel application

    this routines are safe to call from inside an exception where printf could lead to corruption of the stack 

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
.global send_string
.global send_hex
.set noreorder

/*
    Send String
        Input:  $a0 = pointer to a null-terminated string
        Clobbers:   $t0, $t1, $a0
        #Doesn't use stack, no $ra saved nor needed except for return

*/

send_string:
    lbu      $t1, 0($a0)                # load current byte 
    nop
    beqz    $t1, ss_done                # 0x00 -> end of string
    nop

ss_wait:
    lw      $t0, 0x1f801054($zero)      # poll SIO_STAT
    nop
    andi    $t0, $t0, 1                 # TXRDY bit
    beqz    $t0, ss_wait    
    nop

    sb      $t1, 0x1f801050($zero)      # Store byte on SIO_DATA
    #sb      $t1, 0x1f802041($zero)     # TTY  -> PCSX-Redux log, Optional, as it sends BIOS traces

    addiu   $a0, $a0, 1                 # prepare for next char
    j       send_string
    nop

ss_done:

    jr      $ra
    nop


send_hex:
    li      $t2, 8                      # 8 Nibbles per 32bit value

sh_loop:
    srl     $t1, $a1, 28    # top Nibble
    andi    $t1, $t1,  0xF
    nop

    slti    $t3, $t1, 10
    beqz    $t3, sh_letter
    nop

    addiu   $t1, $t1, 0x30  # from 0 to 9
    nop
    j       sh_send
    nop

sh_letter:
    addiu   $t1, $t1, 0x37  #From A to F
    nop

sh_send:
sh_wait:
    lw      $t0, 0x1f801054($zero)  # SIO_STAT
    nop
    andi    $t0, $t0, 4
    beqz    $t0, sh_wait
    nop

    sb      $t1, 0x1f801050($zero)  # SIO_DATA <- Ascii char
    # sb      $t1, 0x1f802041($zero)  # TTY  -> PCSX-Redux log, this is optional, as it sends BIOS traces

    sll     $a1, $a1, 4             # Shift to next nibble
    addiu   $t2, $t2, -1
    bnez    $t2, sh_loop
    nop

    jr      $ra
    nop

