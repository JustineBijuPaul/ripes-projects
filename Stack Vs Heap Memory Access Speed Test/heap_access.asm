.data
# Simulate heap nodes scattered across memory
node1_value: .word 10
node1_next:  .word node2_value

.space 256              # separation (fragmentation)

node2_value: .word 20
node2_next:  .word node3_value

.space 256

node3_value: .word 30
node3_next:  .word 0      # End of list

.text
.globl main
main:
    la s0, node1_value    # s0 = pointer to heap node 1 (value + next pointer)

heap_loop:
    lw s1, 4(s0)          # Load 'next' pointer (must wait for s1)
    beq s1, x0, end       # If next == NULL, stop

    lw t2, 0(s1)          # Load value of next node (dependent load!)
    mv s0, s1             # Move to next node
    j heap_loop

end:
    li a7, 10
    ecall
