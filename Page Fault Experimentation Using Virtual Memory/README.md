# Page Fault Experiment Using Virtual Memory for Ripes

An experiment in the Ripes RISC-V simulator that demonstrates **page faults**, **trap handling**, and the difference between a **normal load** and a **faulting load** in terms of control flow and performance.

This project sets up a **bare-metal trap handler** using RISC-V privileged CSRs, deliberately triggers a **faulting memory access**, and then safely **recovers** by skipping the offending instruction.

---

## 📁 Project Files

| File                  | Description                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------- |
| `page_fault_demo.asm` | RISC-V assembly that installs a trap handler, triggers a page/access fault, and recovers |

You’ll load and run this program in Ripes and observe:

* How control transfers to the **trap handler**
* How the handler **skips** the bad instruction
* How execution resumes **after** the fault

---

## 🎯 What This Demonstrates

* **Exceptions vs Normal Control Flow**
  How a faulting instruction causes an asynchronous jump to a **trap handler** instead of just the next PC.

* **Page Fault / Access Fault Handling (Conceptual)**
  Difference between a **TLB miss** (which might be handled by hardware) and a **page fault**, which always traps to privileged mode (OS / Machine mode).

* **Trap Handler Mechanics**
  Using `mtvec`, `mepc`, `mcause`, and `mret` to:

  * Catch a fault
  * Adjust the saved PC
  * Resume user code safely

* **Performance Penalty of Faults**
  Even without real disk I/O, we can see that a fault triggers:

  * Pipeline flush
  * CSR reads/writes
  * Extra instructions – much more expensive than a normal load

---

## 🔧 Ripes Setup Instructions (Privileged Mode)

> ⚠️ This experiment requires a RISC-V core model in Ripes that supports **Machine Mode** and **CSRs** like `mtvec`, `mepc`, `mcause`, and `mret`. Most 5-stage RV32I/M cores in Ripes do.

### Step 1: Select a Privileged-Capable Core

1. Open **Ripes**.
2. Click the **Processor Selection** (chip/chipset icon).
3. Choose a **RISC-V 32-bit 5-stage core** with privilege support (e.g. `RV32IM 5-stage`).
4. Ensure that:

   * CSRs such as `mtvec`, `mepc`, `mcause`, and `mstatus` exist in the **CSR view**.

### Step 2: Memory Assumptions

We conceptually assume:

* **0x10000000** is part of a valid, mapped data segment (Ripes usually maps .data / .bss there).
* **0x00000000** is **not** mapped for loads → accessing it should raise an **exception** (load access fault / page fault).

> If in your Ripes setup 0x00000000 doesn’t fault, you can choose another known-invalid address. The conceptual behavior is the same: *one valid access, one invalid access that traps*.

---

## 📝 The Assembly Code

### Trap-Handling Page Fault Demo

```asm
.text
.globl main

main:
    # 1. Register Trap Handler
    la   t0, trap_handler   # Load address of trap handler
    csrw mtvec, t0          # Set mtvec to point to trap_handler

    # 2. Good Access (should succeed)
    li   s0, 0x10000000     # Assume this is a valid mapped data segment
    lw   t1, 0(s0)          # Normal load; no exception expected

    # 3. Bad Access (Triggers Exception: Page/Access Fault)
    li   s1, 0x00000000     # Null pointer (assumed unmapped)
    lw   t2, 0(s1)          # *** EXCEPTION TRIGGERED HERE ***

    # 4. Continuation Point
    # If the trap handler works correctly, execution resumes here
    li   t3, 42             # We expect this to execute after mret
    li   a7, 10
    ecall                   # End program (semantics depend on Ripes)

# --- Trap Handler (Machine Mode) ---
.align 4
trap_handler:
    # In a real OS, we would inspect mcause to check the exception type
    csrr t5, mcause         # Read cause of trap (optional: for debugging)

    # We must SKIP the faulting instruction, or we'd fault forever.
    csrr t6, mepc           # t6 = address of faulting instruction (lw t2, 0(s1))
    addi t6, t6, 4          # Advance PC by 4 bytes (skip over that instruction)
    csrw mepc, t6           # Update MEPC so we resume AFTER bad load

    mret                    # Return from trap to main program
```

---

## 🧠 How the Code Works

### 1. Installing the Trap Handler

```asm
la   t0, trap_handler
csrw mtvec, t0
```

* `mtvec` (Machine Trap-Vector Base Address Register) tells the CPU where to jump when:

  * An exception occurs (e.g., access fault, page fault, illegal instruction).
  * An interrupt occurs (if enabled).
* We set it to `trap_handler`, so **every trap** will jump there.

---

### 2. A Valid Memory Access

```asm
li   s0, 0x10000000
lw   t1, 0(s0)
```

* This is a **normal load** from a valid address.
* No exception is raised; the pipeline proceeds as usual.
* You can optionally place a breakpoint here to see the state *before* the faulty access.

---

### 3. A Faulting Memory Access

```asm
li   s1, 0x00000000
lw   t2, 0(s1)    # Faulting load
```

* Accessing **0x00000000** is treated as invalid in our setup:

  * Either because it’s unmapped (Page Fault).
  * Or because it’s not allowed (Load Access Fault).
* When this instruction reaches the **MEM** stage:

  * The hardware detects the fault.
  * The pipeline is **flushed**.
  * The PC is saved in `mepc`.
  * The cause code is written to `mcause`.
  * Control transfers to `mtvec` → our `trap_handler`.

---

### 4. The Trap Handler

```asm
trap_handler:
    csrr t5, mcause        # Read cause (optional)
    csrr t6, mepc          # Faulting instruction address
    addi t6, t6, 4         # Move to next instruction
    csrw mepc, t6          # Save updated PC
    mret                   # Return from Machine Mode
```

* `mcause` tells *why* we trapped (load access fault, etc.).

* `mepc` holds the address of the instruction that caused the exception.

* If we returned without changing `mepc`, we would re-execute the same faulting `lw` → infinite trap loop.

* Instead, we:

  * Increment `mepc` by 4 (size of one 32-bit instruction).
  * So, after `mret`, execution resumes at the **next** instruction:

    ```asm
    li t3, 42
    ```

* This demonstrates how an OS **skips or emulates** faulting instructions after handling or logging the fault.

---

### 5. Resuming Normal Execution

```asm
li t3, 42
li a7, 10
ecall
```

* If the trap handler did its job:

  * `t3` will be set to 42.
  * The program reaches `ecall` and terminates cleanly.
* You can inspect register `t3` after the program finishes:

  * If `t3 == 42`, you know **execution resumed after the faulting load**.

---

## ✅ Expected Behavior in Ripes

Even though Ripes doesn’t simulate real disk I/O (so there’s no true multi-millisecond page-in), you should observe:

1. The faulting `lw t2, 0(s1)` is **never retired** successfully.
2. Control transfers to `trap_handler`.
3. After `mret`, the **next retired instruction** is `li t3, 42`.
4. `t3` ends with value 42, proving the handler skipped the bad instruction.

Internally, the CPU:

* Flushes the pipeline.
* Writes `mepc`, `mcause`, and possibly updates `mstatus`.
* Executes the handler and returns.

This is much more expensive than a **normal 1–5 cycle load**.

---

## 📊 Measuring the Penalty (Conceptual / Relative)

You can’t simulate real **disk latency** in Ripes, but you can reason about and/or measure:

### Normal Load (No Fault)

* Pipeline stays full.
* A cached `lw` might take ~1–5 cycles visible at the commit/retire level.

### Faulting Load (Page Fault / Access Fault)

* Pipeline flush on exception.
* Jump to `mtvec`.
* Execute handler:

  * CSRs: `csrr`/`csrw` (multiple instructions).
  * `mret` to return.
* Refill pipeline after return.

Even a “soft” page fault that **does not** hit disk (just an in-memory handler) costs on the order of **tens to hundreds of cycles**, depending on pipeline depth and handler complexity.

In a **real OS** with swap/disk:

* Page Fault Cost ≈ **microseconds to milliseconds** (thousands to millions of cycles).
* That’s why **page fault rate** is so crucial for performance.

---

## 🧪 Experiment Workflow

### Experiment 1: Confirm Control Flow

1. Load `page_fault_demo.asm` in Ripes.
2. Assemble and **Reset**.
3. Set a breakpoint:

   * Before `lw t2, 0(s1)` (the faulting instruction).
   * At `trap_handler`.
   * At `li t3, 42`.
4. Run:

   * Confirm execution hits:

     1. Good load
     2. Faulting load
     3. Trap handler
     4. Return to `li t3, 42`.
5. Verify that:

   * `t3` ends as 42.
   * The faulting `lw t2, 0(s1)` does **not** complete successfully.

---

### Experiment 2: Measure Relative Cost (Optional, Approximate)

1. **Case A:** Comment out the bad access:

   ```asm
   # li s1, 0x00000000
   # lw t2, 0(s1)
   ```

   * Run the program.
   * Record **Cycles** from the **Statistics** panel.

2. **Case B:** Enable the bad access (original code).

   * Run again.
   * Record **Cycles**.

3. Compare:

   $$
   \Delta \text{Cycles} = \text{Cycles}_{\text{with fault}} - \text{Cycles}_{\text{without fault}}
   $$

This gives you a **rough estimate** of the overhead of triggering the trap and running the handler (even without modeling disk).

---

## 📈 Why Page Faults Are So Expensive

* A **TLB miss** can sometimes be handled by hardware:

  * Hardware page walker reads PTEs from memory and fills the TLB.
  * Still expensive, but **stays in hardware**.

* A **Page Fault**:

  * Indicates that the PTE is invalid (page not in memory, or illegal access).
  * CPU must trap to **OS / Machine Mode**:

    * Save state.
    * Run OS code: allocate frame, read from disk, update PTE.
    * Restore state and restart instruction.

Even without disk access, this involves:

* Mode switch (user → machine → user).
* Pipeline flush and refill.
* CSR reads/writes and handler instructions.

In real systems, a full page fault might cost **millions of cycles**, hence:

* OSes aggressively:

  * Use **LRU-like replacement** to keep hot pages in memory.
  * Perform **prefetching** (read-ahead).
  * Use **large pages** to reduce fault frequency.

---

## 📚 Key Concepts

| Concept                 | Definition                                                                                |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| Exception / Trap        | An event that causes a change in control flow to a privileged handler                     |
| Page Fault              | Exception raised when a virtual page is not present or access permissions are violated    |
| `mtvec`                 | Machine trap-vector base register; holds address of trap handler                          |
| `mepc`                  | Machine exception program counter; holds address of faulting instruction                  |
| `mcause`                | CSR that encodes the cause of the exception/interrupt                                     |
| `mret`                  | Instruction that returns from machine mode to lower privilege and resumes at `mepc`       |
| Context Switch Overhead | Extra cycles spent for saving/restoring state and running handlers instead of normal code |

---

## 🚀 Extensions

Want to expand this experiment?

* **Different Fault Types**

  * Trigger **illegal instruction** by encoding an invalid opcode and see how `mcause` changes.
  * Trigger **environment call** from user mode (`ecall`) and handle it in `trap_handler`.

* **“Real” Page Emulator**

  * In the handler, simulate “allocating” memory by:

    * Checking `mcause`.
    * Writing some marker to a “PTE table” in memory.
    * Skipping or retrying the instruction.

* **Count Exceptions**

  * Maintain a global counter in `.data` and increment it in the trap handler to count exceptions.

* **Add Timing Loops**

  * Use a software cycle counter (or Ripes statistics) to compare code paths with and without faults.

---

## 📄 License

This page-fault/trap-handling demo is intended for **educational use** in architecture and OS courses.
Feel free to copy, adapt, and integrate it into your labs, reports, or teaching material.
