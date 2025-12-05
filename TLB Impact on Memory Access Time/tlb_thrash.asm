.data
    .align 12           # Align to 4KB page boundary (2^12 = 4096)

page1:
    .word 1
    .space 4092         # Fill remainder of page 1 (total 4096 bytes)

page2:
    .word 2
    .space 4092         # Page 2

page3:
    .word 3
    .space 4092         # Page 3

page4:
    .word 4
    .space 4092         # Page 4

page5:
    .word 5             # Page 5 (5th distinct page)

.text
.globl main
main:
    la   s0, page1      # Start from Page 1
    li   t0, 4096       # Stride = 4KB (page size)

loop_tlb:
    # Access Page 1
    lw   zero, 0(s0)    # TLB Entry 1 (on first touch)
    add  s0, s0, t0     # Move to Page 2 (s0 += 4096)

    # Access Page 2
    lw   zero, 0(s0)    # TLB Entry 2
    add  s0, s0, t0     # Move to Page 3

    # Access Page 3
    lw   zero, 0(s0)    # TLB Entry 3
    add  s0, s0, t0     # Move to Page 4

    # Access Page 4
    lw   zero, 0(s0)    # TLB Entry 4 (TLB now full)
    add  s0, s0, t0     # Move to Page 5

    # Access Page 5
    lw   zero, 0(s0)    # Access Page 5 -> requires 5th TLB entry
                        # In a 4-entry TLB with LRU, this evicts Page 1

    # Loop back to Page 1
    la   s0, page1      # Reset pointer to Page 1
    j    loop_tlb       # Repeat forever (continuous thrashing)
