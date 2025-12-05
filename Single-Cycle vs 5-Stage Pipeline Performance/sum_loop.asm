###########################################################
# Single-Cycle vs 5-Stage Pipeline Performance Demo
# Program: Sum of numbers 0..(N-1) using a simple loop
#
# - Works on:
#     * RISC-V Single Cycle Processor
#     * RISC-V 5-Stage Processor (with hazard detection + forwarding)
#
# - You will measure:
#     * Total cycles
#     * Instructions
#     * CPI
#     * Speedup = Cycles_single / Cycles_pipeline
###########################################################

    .data
N:      .word 10        # N = 10  → sum = 0+1+...+9 = 45
SUM:    .word 0         # where we store the result

    .text
    .globl _start
_start:
    #######################################################
    # 1. Setup pointers and load N
    #######################################################
    la      x10, N          # x10 = &N
    la      x11, SUM        # x11 = &SUM

    lw      x5, 0(x10)      # x5 = N
    addi    x6, x0, 0       # x6 = i = 0
    addi    x7, x0, 0       # x7 = sum = 0

    #######################################################
    # 2. Loop: sum = sum + i   for i = 0 .. N-1
    #######################################################
loop:
    add     x7, x7, x6      # sum += i
    addi    x6, x6, 1       # i++

    blt     x6, x5, loop    # if (i < N) goto loop

    #######################################################
    # 3. Store result and stop
    #######################################################
    sw      x7, 0(x11)      # SUM = sum  (should be 45 for N=10)

end:
    nop                     # Place breakpoint here in Ripes
