.data
array:
    .zero 4096       # Large data: 4KB array (1024 words)

.text
.globl main
main:
    la s0, array      # pointer to start of array
    li t0, 1024       # 1024 iterations

loop:
    lw t1, 0(s0)      # Data access -> D-cache pressure
    addi s0, s0, 4
    addi t0, t0, -1
    bnez t0, loop

    li a7, 10
    ecall
