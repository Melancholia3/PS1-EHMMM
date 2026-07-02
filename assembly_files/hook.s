/*
Hook.s

PS1 EHMMM - PS1 Exception Handler by melanchlia3_

Baremetal hook implementation of a crashhandler for ps1, using INT_RP to hook the exception handler and verifier, 
this is a lowlevel implementation that does not require any kind of sdk 


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

.global INTRP
.global hook


.data
.align 2


    INTRP:
        .word   0 # Next,       00h
        .word   0 # Handler     04h
        .word   0 # Verifier    08h


.text
    hook:
        addiu   $sp, $sp, -16
        sw      $ra, 12($sp)

        la      $t0, INTRP
        la      $t1, handler
        la      $t2, verifier   

        sw      $zero, 0($t0) #Cleanse Next field
        sw      $t1, 4($t0) 
        sw      $t2, 8($t0) 

        # With the previous code, INT_RP structure is now ready,
        # Now, we backup the previous handler pointer (from 0x100) onto the 'next' field


        li      $a0, 0
        move    $a1, $t0
        li      $t1, 0x2        #SysEnqIntRP on c0 table
        jal     0x800000c0      # Jump to the master table of Syscalls c0
        nop
        la      $a0, hookedonafeeling
        jal     send_string
        nop


        lw      $ra, 12($sp)
        nop
        addiu   $sp, $sp, 16
        jr      $ra
        nop

        .section .rodata
        hookedonafeeling:
            .asciiz "Hooked on a feeling, EHMMM ready\r\n"
        #message to be printed when the hook is installed, can be changed to whatever you want
