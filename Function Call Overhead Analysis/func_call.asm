##############################################################
# Function Call Overhead Demo (Ripes RV32I)
#
# Goal:
#   - Measure overhead of jal/jalr + stack frame in a 5-stage pipeline
#   - main() calls func() many times
#
# main:
#   for i in [0 .. ITER-1]:
#       x10 = func(x10)
#
# func:
#   Prologue: save ra and s0 on stack
#   Body:     x10 = x10 + 1
#   Epilogue: restore s0, ra; return with jalr
##############################################################

    .data
ITER:      .word 100        # Number of function calls
RESULT:    .word 0          # Store final x10 here

    .text
    .globl _start
_start:
    ##########################################################
    # 1. Setup stack pointer and loop variables
    ##########################################################
    # Ripes usually initializes x2 (sp) to 0x10000000 (or similar),
    # but we set it manually to be explicit and safe.
    #
    # NOTE: Adjust the stack base address if your Ripes config differs.
    ##########################################################
    lui   x2, 0x10010       # x2 = 0x10010_000 (example stack base)
                            # (upper bits only; low 12 bits = 0)

    la    x5, ITER          # x5 = &ITER
    lw    x6, 0(x5)         # x6 = ITER (loop count)
    addi  x10, x0, 0        # x10 = 0 (argument / accumulator)
    addi  x7, x0, 0         # x7 = loop counter i = 0

##############################################################
# main loop: call func() ITER times
##############################################################
loop:
    # Call func with x10 as input/output
    jal   ra, func          # ra = return address, jump to func

    addi  x7, x7, 1         # i++
    blt   x7, x6, loop      # if (i < ITER) continue loop

    # After loop: x10 should be ITER (each func adds 1)

    # Store result to memory
    la    x8, RESULT
    sw    x10, 0(x8)

    # Done
end:
    nop                     # Put breakpoint here in Ripes

##############################################################
# func(x10):
#   Prologue:
#       sp -= 8
#       sw ra, 4(sp)
#       sw s0, 0(sp)
#
#   Body:
#       s0 = x10
#       x10 = s0 + 1
#
#   Epilogue:
#       lw s0, 0(sp)
#       lw ra, 4(sp)
#       sp += 8
#       ret  (jalr x0, 0(ra))
##############################################################
func:
    # Prologue: create stack frame, save ra and s0
    addi  x2, x2, -8        # sp -= 8
    sw    ra, 4(x2)         # store return address at [sp+4]
    sw    s0, 0(x2)         # store s0 at [sp]

    # Body: s0 = x10; x10 = x10 + 1
    add   s0, x10, x0       # s0 = x10
    addi  x10, s0, 1        # x10 = s0 + 1

    # Epilogue: restore s0 and ra, destroy frame, return
    lw    s0, 0(x2)         # restore s0
    lw    ra, 4(x2)         # restore ra
    addi  x2, x2, 8         # sp += 8

    ret                     # return (pseudo for jalr x0, 0(ra))
