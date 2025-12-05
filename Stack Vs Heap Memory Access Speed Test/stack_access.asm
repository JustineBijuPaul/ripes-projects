.text
.globl main
main:
    # Create a 16-byte stack frame
    addi sp, sp, -16

    # Save frame pointer and return address
    sw ra, 12(sp)
    sw s0, 8(sp)

    # Local variable
    li t0, 42
    sw t0, 4(sp)        # Store to stack (L1 write)

    lw t1, 4(sp)        # Fast load from same stack line (L1 hit)

    # Exit
    li a7, 10
    ecall
