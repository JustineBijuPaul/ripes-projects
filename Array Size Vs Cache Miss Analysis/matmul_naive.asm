.data
N:      .word 4                # Change this to 4, 8, 16 for the experiments
A:      .zero 1024             # Enough space for largest matrix (16x16 words = 256 words = 1024 bytes)
B:      .zero 1024
C:      .zero 1024

.text
.globl main
main:
    la s0, A                  # Base of A
    la s1, B                  # Base of B
    la s2, C                  # Base of C

    lw t0, N                  # t0 = N

    li t1, 0                  # i = 0
loop_i:
    beq t1, t0, end_program

    li t2, 0                  # j = 0
loop_j:
    beq t2, t0, inc_i

    li t3, 0                  # sum = 0
    li t4, 0                  # k = 0

loop_k:
    beq t4, t0, store_c

    # Load A[i][k]
    # Address = BaseA + (i * N + k) * 4
    mul t5, t1, t0
    add t5, t5, t4
    slli t5, t5, 2
    add t6, s0, t5
    lw a3, 0(t6)

    # Load B[k][j]
    # Address = BaseB + (k * N + j) * 4
    mul a4, t4, t0
    add a4, a4, t2
    slli a4, a4, 2
    add a5, s1, a4
    lw a5, 0(a5)

    # sum += A[i][k] * B[k][j]
    mul a3, a3, a5
    add t3, t3, a3

    addi t4, t4, 1
    j loop_k

store_c:
    # Store sum into C[i][j]
    # Address = BaseC + (i * N + j) * 4
    mul t5, t1, t0
    add t5, t5, t2
    slli t5, t5, 2
    add t6, s2, t5
    sw t3, 0(t6)

    addi t2, t2, 1
    j loop_j

inc_i:
    addi t1, t1, 1
    j loop_i

end_program:
    li a7, 10
    ecall
