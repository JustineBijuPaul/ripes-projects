.data
    result: .word 0

.text
.globl main

main:
    li t0, 10           # Initial value
    li t1, 5            # Loop counter
    li t2, 2            # Constant operand
    li t3, 3            # Constant operand

loop:
    beq t1, zero, end   # Exit if counter is 0
    
    # --- THE DEPENDENCY CHAIN ---
    # Every instruction needs the result of the previous one immediately.
    
    add a0, t0, t2      # 1. a0 = t0 + 2
                        # (Without forwarding: Stall needed here for a0)
                        
    sub a1, a0, t3      # 2. a1 = a0 - 3
                        # (Without forwarding: Stall needed here for a1)
                        
    or  a2, a1, t2      # 3. a2 = a1 OR 2
                        # (Without forwarding: Stall needed here for a2)
                        
    xor t0, a2, t3      # 4. t0 = a2 XOR 3 (Update t0 for next loop)
    # ----------------------------

    addi t1, t1, -1     # Decrement loop counter
    j loop

end:
    la s0, result
    sw t0, 0(s0)        # Store final result
    nop