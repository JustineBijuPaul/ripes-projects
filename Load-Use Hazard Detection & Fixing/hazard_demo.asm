.data
    # Input: 5 integers
    source: .word 10, 20, 30, 40, 50
    # Output: Destination for results
    dest:   .word 0, 0, 0, 0, 0

.text
.globl main

main:
    la   a0, source     # Address of Source
    la   a1, dest       # Address of Destination
    li   t0, 5          # Loop count (N=5)
    li   t1, 0          # Iterator i=0

loop:
    beq  t1, t0, end    # Exit if i == 5
    
    # --- THE HAZARD ZONE ---
    lw   t2, 0(a0)      # 1. Load data from Memory (Takes time)
    
    # HAZARD: We need t2 IMMEDIATELY.
    # In 'No Forwarding' mode: CPU pauses for ~2-3 cycles.
    # In 'Forwarding' mode: CPU pauses for 1 cycle (Load delay).
    
    addi t3, t2, 100    # 2. Use t2 immediately (Add 100)
    # -----------------------

    sw   t3, 0(a1)      # Store result
    
    addi a0, a0, 4      # Next source address
    addi a1, a1, 4      # Next dest address
    addi t1, t1, 1      # i++
    
    j    loop

end:
    nop