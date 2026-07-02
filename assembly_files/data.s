/*
    data.s
    PS1 EHMMM - PS1 Exception Handler by melanchlia3_

    read only Data Tables for the PS1 Exception Handler

    Contains the opcodes and strings for the exception handler



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



.section .rodata

.global Offset
.global Strings
.global CauseText
.global GenericCause
.global newline
.global excHead
.global separate
.global spaces
.global str_opcode

# ====================================================================
# OFFSET TABLE (Numeric values of registers to retrieve)
# ====================================================================
.align 2
Offset:
    # Exceptions and Initial Registers
    .word 0x88    # Index 0  -> EPC
    .word 0x84    # Index 1  -> $ra
    .word 0x7C    # Index 2  -> $sp
    
    # Ascending Sequence (0x0C to 0x80)
    .word 0x0C    # Index 3  -> $at
    .word 0x10    # Index 4  -> $v0
    .word 0x14    # Index 5  -> $v1
    .word 0x18    # Index 6  -> $a0
    .word 0x1C    # Index 7  -> $a1
    .word 0x20    # Index 8  -> $a2
    .word 0x24    # Index 9  -> $a3
    .word 0x28    # Index 10 -> $t0
    .word 0x2C    # Index 11 -> $t1
    .word 0x30    # Index 12 -> $t2
    .word 0x34    # Index 13 -> $t3
    .word 0x38    # Index 14 -> $t4
    .word 0x3C    # Index 15 -> $t5
    .word 0x40    # Index 16 -> $t6
    .word 0x44    # Index 17 -> $t7
    .word 0x48    # Index 18 -> $s0
    .word 0x4C    # Index 19 -> $s1
    .word 0x50    # Index 20 -> $s2
    .word 0x54    # Index 21 -> $s3
    .word 0x58    # Index 22 -> $s4
    .word 0x5C    # Index 23 -> $s5
    .word 0x60    # Index 24 -> $s6
    .word 0x64    # Index 25 -> $s7
    .word 0x68    # Index 26 -> $t8
    .word 0x6C    # Index 27 -> $t9
    .word 0x78    # Index 28 -> $gp
    .word 0x80    # Index 29 -> $fp

# ====================================================================
# REGISTER STRINGS TABLE (Synchronized 1:1 with 'Offset')
# ====================================================================
.align 2
Strings:
    # Exceptions and Initial Registers
    .word str_EPC  # Index 0  -> Corresponds to 0x88
    .word str_ra   # Index 1  -> Corresponds to 0x84
    .word str_sp   # Index 2  -> Corresponds to 0x7C
    
    # Ascending Sequence
    .word str_at   # Index 3  -> Corresponds to 0x0C
    .word str_v0   # Index 4  -> Corresponds to 0x10
    .word str_v1   # Index 5  -> Corresponds to 0x14
    .word str_a0   # Index 6  -> Corresponds to 0x18
    .word str_a1   # Index 7  -> Corresponds to 0x1C
    .word str_a2   # Index 8  -> Corresponds to 0x20
    .word str_a3   # Index 9  -> Corresponds to 0x24
    .word str_t0   # Index 10 -> Corresponds to 0x28
    .word str_t1   # Index 11 -> Corresponds to 0x2C
    .word str_t2   # Index 12 -> Corresponds to 0x30
    .word str_t3   # Index 13 -> Corresponds to 0x34
    .word str_t4   # Index 14 -> Corresponds to 0x38
    .word str_t5   # Index 15 -> Corresponds to 0x3C
    .word str_t6   # Index 16 -> Corresponds to 0x40
    .word str_t7   # Index 17 -> Corresponds to 0x44
    .word str_s0   # Index 18 -> Corresponds to 0x48
    .word str_s1   # Index 19 -> Corresponds to 0x4C
    .word str_s2   # Index 20 -> Corresponds to 0x50
    .word str_s3   # Index 21 -> Corresponds to 0x54
    .word str_s4   # Index 22 -> Corresponds to 0x58
    .word str_s5   # Index 23 -> Corresponds to 0x5C
    .word str_s6   # Index 24 -> Corresponds to 0x60
    .word str_s7   # Index 25 -> Corresponds to 0x64
    .word str_t8   # Index 26 -> Corresponds to 0x68
    .word str_t9   # Index 27 -> Corresponds to 0x6C
    .word str_gp   # Index 28 -> Corresponds to 0x78
    .word str_fp   # Index 29 -> Corresponds to 0x80

# ====================================================================
# EXCEPTION STRINGS VECTOR (ExcCode from Cause Register)
# ====================================================================
CauseText:
    .word   interrupt        # 0x00 - Int
    .word   uns              # 0x01 - Mod
    .word   uns              # 0x02 - TLBL
    .word   uns              # 0x03 - TLBS
    .word   addrload         # 0x04 - AdEL
    .word   addrstore        # 0x05 - AdES
    .word   businstr         # 0x06 - IBE
    .word   busdata          # 0x07 - DBE
    .word   scall            # 0x08 - Sys
    .word   breakpoint       # 0x09 - Bp
    .word   reservinstr      # 0x0a - RI
    .word   cop_unusable     # 0x0b - CpU
    .word   overflow         # 0x0c - Ov
    # Padding for unassigned/unused codes up to 32 entries total (0 to 31)
    .word   uns, uns, uns, uns, uns, uns, uns, uns, uns, uns
    .word   uns, uns, uns, uns, uns, uns, uns, uns, uns

# ====================================================================
# LITERAL STRING DEFINITIONS (ASCIIZ)
# ====================================================================

# Register Names
str_opcode:    .asciiz "Opcode = "
str_EPC:       .asciiz "epc = "    
str_ra:        .asciiz "Return Address = "
str_sp:        .asciiz "Stack Pointer = "
str_at:        .asciiz "at = "
str_v0:        .asciiz "v0 = "
str_v1:        .asciiz "v1 = "
str_a0:        .asciiz "a0 = "
str_a1:        .asciiz "a1 = "
str_a2:        .asciiz "a2 = "
str_a3:        .asciiz "a3 = "
str_t0:        .asciiz "t0 = "
str_t1:        .asciiz "t1 = "
str_t2:        .asciiz "t2 = "
str_t3:        .asciiz "t3 = "
str_t4:        .asciiz "t4 = "
str_t5:        .asciiz "t5 = "
str_t6:        .asciiz "t6 = "
str_t7:        .asciiz "t7 = "
str_s0:        .asciiz "s0 = "
str_s1:        .asciiz "s1 = "
str_s2:        .asciiz "s2 = "
str_s3:        .asciiz "s3 = "
str_s4:        .asciiz "s4 = "
str_s5:        .asciiz "s5 = "
str_s6:        .asciiz "s6 = "
str_s7:        .asciiz "s7 = "
str_t8:        .asciiz "t8 = "
str_t9:        .asciiz "t9 = "
str_gp:        .asciiz "gp = "
str_fp:        .asciiz "fp = "

# Exception Handler Messages
GenericCause:  .asciiz "Cause = "
interrupt:     .asciiz "Interrupt"
addrload:      .asciiz "Address Error Load"
addrstore:     .asciiz "Address Error Store"
businstr:      .asciiz "Bus Error Instruction"
busdata:       .asciiz "Bus Error Data"
scall:         .asciiz "SystemCall"
breakpoint:    .asciiz "Breakpoint"
reservinstr:   .asciiz "Reserved Instruction"
cop_unusable:  .asciiz "Coprocessor Unusable"
overflow:      .asciiz "Overflow"
uns:           .asciiz "Undefined ExcCode\n"

# Console Formatting Strings
newline:       .asciiz "\r\n"
excHead:       .asciiz "========EXCEPTION OCCURRED!!!========\r\n"
separate:      .asciiz "=====================================\r\n"
spaces:        .asciiz "    "