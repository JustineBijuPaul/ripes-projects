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
    beq  t1, t0, end
    
    lw   t2, 0(a0)      # 1. Load Start
    
    # --- THE FIX ---
    # We move the pointer increment UP. 
    # This instruction does not depend on t2.
    # It executes while t2 is being fetched from memory.
    addi a0, a0, 4      
    # ---------------
    
    addi t3, t2, 100    # Now t2 is ready! Zero stalls.
    
    sw   t3, 0(a1)
    
    addi a1, a1, 4      # (Moved a0 increment up, kept a1 here)
    addi t1, t1, 1
    
    j    loop

end:
    nop