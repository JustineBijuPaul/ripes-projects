.data
    .align 4                 # Force alignment for the base address
data_word:
    .word 0xDEADBEEF         # Stored at an address ending in ...00

.text
.globl main
main:
    la s0, data_word

    # -------------------------
    # 1. Aligned Load (Fast)
    # -------------------------
    # This takes 1 memory access
    lw t0, 0(s0)            # Correctly aligned (address ends in .00)

    # -------------------------
    # 2. Misaligned Load (Traps in Ripes v2.3+)
    # -------------------------
    addi s1, s0, 1          # Now address ends in .01 (misaligned)
    
    # UNCOMMENT the line below to see the "Load Address Misaligned" exception!
    # lw t1, 0(s1)          # *** TRAPS HERE ***

    # -------------------------
    # 3. Simulated Misaligned Load (Slow Manual Fix-up)
    # -------------------------
    # Since Ripes traps on misaligned loads, we simulate what a CPU 
    # with hardware support would do (or what a trap handler does):
    # 4 separate byte accesses + shifting + merging.
    
    # Load 4 bytes individually
    lbu  t2, 0(s1)          # Load byte 0 (unsigned)
    lbu  t3, 1(s1)          # Load byte 1
    lbu  t4, 2(s1)          # Load byte 2
    lb   t5, 3(s1)          # Load byte 3 (signed, preserves sign of word)

    # Reconstruct 32-bit word manually (Little Endian)
    sll  t3, t3, 8
    sll  t4, t4, 16
    sll  t5, t5, 24

    or   t2, t2, t3
    or   t2, t2, t4
    or   t2, t2, t5
    
    # t2 now holds the reassembled word, but it took ~4x more instructions/cycles!

    li a7, 10
    ecall
