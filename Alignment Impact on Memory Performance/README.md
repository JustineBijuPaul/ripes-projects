# Alignment Impact on Memory Performance — Ripes Demonstration

A complete, step-by-step experiment showing how **aligned vs. misaligned memory accesses** affect performance, the pipeline, and exception behavior in RISC-V.

**Update for Ripes v2.3+:** Newer versions of Ripes strictly enforce alignment for word loads (`lw`). Misaligned accesses will **always trap**. This experiment demonstrates both the trap behavior and the "manual fix-up" cost that hardware or software must pay to handle misalignment.

---

## 📁 Project Files

| File                        | Description                                                        |
| --------------------------- | ------------------------------------------------------------------ |
| `aligned_vs_misaligned.asm` | Demonstrates aligned loads, trapping misaligned loads, and manual fix-ups |

---

## 🎯 What This Demonstrates

* **Aligned access (fast path)**
  * Address = multiple of 4.
  * L1 cache can fetch entire word in **one bus transaction**.

* **Misaligned access (Exception)**
  * In standard RISC-V (and Ripes v2.3+), a misaligned `lw` raises a **Load Address Misaligned** exception.
  * This forces a trap to the OS, which is extremely expensive.

* **Simulated Hardware Support (Slow Path)**
  * If hardware supported misalignment, it would effectively do what we simulate manually:
    * Fetch multiple parts.
    * Shift and merge bytes.
    * **Result:** 2-4x latency penalty compared to aligned loads.

---

## 🔧 Ripes Setup Instructions

### Step 1 — Select Processor
1. Open **Ripes**.
2. Click CPU icon → Choose:
   * `RV32I 5-stage` or `RV32IM 5-stage`

### Step 2 — Note on Misalignment
* **Old Ripes (v2.2 and older):** Had a "Support Misaligned Access" toggle.
* **New Ripes (v2.3+):** This toggle is removed. Misaligned word loads **always trap**.
* We will simulate the "hardware support" cost using assembly instructions.

---

## 📝 The Assembly Code Overview

### 1. Aligned Load (Fast)
```asm
lw t0, 0(s0)   # Address ends in 00 -> 1 cycle memory access
```

### 2. Misaligned Load (Trap)
```asm
lw t1, 0(s1)   # Address ends in 01 -> TRAP (Load Address Misaligned)
```
In the provided code, this line is commented out so you can run the manual simulation. Uncomment it to observe the exception.

### 3. Manual Fix-up (Simulated Slow Path)
To emulate what happens when hardware (or a trap handler) fixes the misalignment:
```asm
lbu t2, 0(s1)
lbu t3, 1(s1)
lbu t4, 2(s1)
lb  t5, 3(s1)
sll ...
or  ...
```
This reconstructs the word but requires **4 memory accesses** and ALU operations, proving why misalignment hurts performance.

---

## 🧪 Experiment Workflow

### Experiment 1: Aligned vs. Manual Fix-up
1. Load `aligned_vs_misaligned.asm`.
2. Run the program.
3. Compare the **Aligned Load** section vs. the **Simulated Misaligned Load** section.
   * **Aligned:** 1 instruction, 1 memory access.
   * **Misaligned (Simulated):** ~10 instructions, 4 memory accesses.
4. **Conclusion:** Misalignment increases instruction count and memory traffic significantly.

### Experiment 2: Trigger the Trap
1. Uncomment the line `# lw t1, 0(s1)`.
2. Run the program.
3. Observe that execution **stops** (or jumps to a trap handler if configured).
4. Check the **Processor Status**:
   * `mcause` register will show exception code `4` (Load Address Misaligned).
   * This confirms that the hardware refuses to handle the request directly.

---

## 📈 Summary: Why Alignment Matters

### 🧩 Aligned
* One bus request.
* Zero overhead.

### 🔥 Misaligned
* **If Trapped:** Thousands of cycles for OS handler.
* **If Hardware Supported:** Multiple bus requests + stall cycles for merging.
* **Result:** Always slower.

### 🛠 Compiler Strategy
Compilers add **padding** to structs to ensure every 4-byte integer starts at an address divisible by 4, avoiding these penalties entirely.

---

## 📄 License
This material is designed for RISC-V architecture education. Free to use and modify.
