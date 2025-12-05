# Arithmetic Program Optimization (ALU-to-ALU Forwarding) for Ripes

A demonstration of **ALU-to-ALU Hazards** (Read-After-Write) and how **data forwarding** can **completely eliminate** stalls in the [Ripes](https://github.com/mortbopet/Ripes) RISC-V simulator.

Unlike Load-Use hazards (which require at least 1 stall even with forwarding), ALU hazards can be fully resolved by forwarding, resulting in a **massive performance difference**.

---

## 📁 Project Files

| File | Description |
|------|-------------|
| `dependency_chain.asm` | Code with back-to-back ALU dependencies (worst case for no forwarding) |

---

## 🎯 What This Demonstrates

- **ALU-to-ALU RAW Hazards**: When consecutive ALU instructions depend on each other
- **Data Forwarding**: Hardware technique to bypass the register file
- **Performance Impact**: 2.4x speedup with forwarding enabled
- **Pipeline Visualization**: See bubbles inserted vs. smooth flow

---

## 🔬 Understanding ALU-to-ALU Hazards

### The Problem

When one ALU instruction produces a result and the next instruction immediately needs it:

```asm
add a0, t0, t2      # a0 = result (available at end of EX stage)
sub a1, a0, t3      # Needs a0 immediately!
```

### Without Forwarding

The data must travel the "long way":
```
ALU Output → MEM Stage → WB Stage → Register File → ID Stage → ALU Input
                                                    ↑
                                            2 cycles wasted!
```

### With Forwarding

A direct wire connects ALU output to ALU input:
```
ALU Output ──────────────────────────────────────→ ALU Input
                        ↑
                  0 cycles wasted!
```

---

## 🔧 Ripes Setup Instructions

### The A/B Comparison

Run the **same code** on two processor configurations to see the dramatic difference.

### Configuration A: No Forwarding (Baseline)

1. Open **Ripes**
2. Click the **Processor Selection** icon
3. Select **RISC-V 32-bit**
4. Choose: **`5-Stage Processor w/o Forwarding`**

**Effect:** Processor must wait for instruction to finish writing to register file (Stage 5) before the next instruction can read it.

### Configuration B: With Forwarding (Optimized)

1. Click the **Processor Selection** icon
2. Choose: **`5-Stage Processor (w/ Forwarding)`**

**Effect:** Processor takes the result from the ALU (Stage 3) and immediately wires it to the input of the next instruction.

---

## 📝 Assembly Code: The Dependency Chain

This code is a **worst-case scenario** for pipelines without forwarding. Every instruction depends on the result of the exact previous one:

```asm
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
```

### Dependency Graph

```
t0 ──→ add ──→ a0 ──→ sub ──→ a1 ──→ or ──→ a2 ──→ xor ──→ t0 (next iteration)
        ↑              ↑              ↑              ↑
       t2             t3             t2             t3
```

Every arrow represents a RAW (Read-After-Write) dependency!

---

## 🧪 Experiments

### Configuration A: No Forwarding

**What to Observe:**

1. Look at the **Pipeline** view
2. When `add` is in the **EX** stage, `sub` is stuck in **ID**
3. You'll see **2 Bubbles (NOPs)** inserted between every arithmetic instruction

**Pipeline Diagram (No Forwarding):**

```
Cycle:  1    2    3    4    5    6    7    8    9   10
add:    IF   ID   EX   MEM  WB
                            ↓ a0 written to register file
sub:         IF   ID   --   --   EX   MEM  WB
                  ↑ STUCK! Waiting for a0
             2 bubbles inserted
```

**Performance:**
- **Cycles:** ~120 cycles
- **CPI:** ~2.4 (Very High - Bad!)
- **Bubbles per dependency:** 2

**Why so slow?** The pipeline spends more time stalling than working. It waits for data to travel all the way to Writeback before Decode can read it.

---

### Configuration B: With Forwarding

**What to Observe:**

1. **No bubbles!** The pipeline flows smoothly
2. Look for the **Forwarding Unit** (multiplexer before ALU)
3. You'll see it selecting data from **EX/MEM** pipeline register instead of Register File

**Pipeline Diagram (With Forwarding):**

```
Cycle:  1    2    3    4    5    6    7
add:    IF   ID   EX   MEM  WB
                  ↓ Forward a0 directly!
sub:         IF   ID   EX   MEM  WB
                       ↓ Forward a1 directly!
or:               IF   ID   EX   MEM  WB
                            ↓ Forward a2 directly!
xor:                   IF   ID   EX   MEM  WB
```

**Performance:**
- **Cycles:** ~50 cycles
- **CPI:** ~1.05 (Near ideal!)
- **Bubbles per dependency:** 0

**Why so fast?** Hardware detects that `sub` needs `a0`, sees that `add` is currently calculating `a0`, and "forwards" the electrical signal directly.

---

## ✅ Expected Output

### Functional Verification

The program performs 5 iterations of the dependency chain. Check the `result` variable in memory after execution.

**Initial value:** `t0 = 10`

**Per iteration:**
1. `a0 = t0 + 2`
2. `a1 = a0 - 3`
3. `a2 = a1 | 2`
4. `t0 = a2 ^ 3`

> ⚠️ **Both configurations must produce the same final result!** Forwarding only affects performance, not correctness.

### Register Values at End

| Register | Description |
|----------|-------------|
| `t0` | Final computed value (stored to memory) |
| `t1` | 0 (loop counter exhausted) |
| `t2` | 2 (constant) |
| `t3` | 3 (constant) |

---

## 📊 Performance Comparison

### Summary Table

| Metric | No Forwarding | With Forwarding | Improvement |
|--------|---------------|-----------------|-------------|
| **Total Cycles** | ~120 | ~50 | **2.4x Speedup** |
| **CPI** | ~2.4 | ~1.05 | **56% Reduction** |
| **Bubbles per Instruction** | 2 | 0 | **100% Elimination** |
| **Throughput** | Poor | Excellent | |

### Speedup Calculation

$$\text{Speedup} = \frac{\text{Cycles}_{\text{no-forwarding}}}{\text{Cycles}_{\text{forwarding}}} = \frac{120}{50} = 2.4\times$$

### CPI Analysis

$$\text{CPI}_{\text{no-forwarding}} = 1 + 2 \times \frac{\text{dependencies}}{\text{instructions}} \approx 2.4$$

$$\text{CPI}_{\text{forwarding}} \approx 1.0$$

---

## 🔍 Understanding EX-to-EX Forwarding

### The Data Path

Focus on the **EX (Execute)** stage to understand forwarding:

1. **Instruction 1 (`add`)** calculates `10 + 2 = 12`
   - This value sits at the *output* of the ALU

2. **Instruction 2 (`sub`)** needs `a0` at the *input* of the ALU

**Without Forwarding (The Long Trip):**
```
ALU Output → EX/MEM Register → MEM Stage → MEM/WB Register → 
WB Stage → Register File → ID Stage (Read) → ID/EX Register → ALU Input
                                                    ↑
                                            Takes 2 extra cycles!
```

**With Forwarding (The Shortcut):**
```
ALU Output ─────────────────────────────────────────→ ALU Input
                            ↑
                    Direct wire connection!
```

### Forwarding Unit Logic

The forwarding unit detects hazards and selects the correct data source:

```
if (EX/MEM.RegWrite AND EX/MEM.Rd == ID/EX.Rs1)
    Forward from EX/MEM to ALU input A
    
if (MEM/WB.RegWrite AND MEM/WB.Rd == ID/EX.Rs1)
    Forward from MEM/WB to ALU input A
    
(Similar logic for Rs2 / ALU input B)
```

---

## 🎨 Visualizing in Ripes

### How to See Forwarding

1. Select **5-Stage Processor w/ Forwarding**
2. Look at the processor diagram
3. Find the **multiplexers** before ALU inputs
4. During execution, watch which input is selected:
   - **0**: From Register File (normal)
   - **1**: From EX/MEM (EX-to-EX forwarding)
   - **2**: From MEM/WB (MEM-to-EX forwarding)

### How to See Stalls (No Forwarding)

1. Select **5-Stage Processor w/o Forwarding**
2. Set clock to **Manual** mode
3. Step through and watch:
   - Instructions stuck in ID stage
   - Bubbles (NOPs) appearing in EX stage
   - Pipeline "stretching out"

---

## 🧠 Why ALU Forwarding is Different from Load Forwarding

### ALU-to-ALU (This Project)

```
add:   IF   ID   EX   MEM   WB
                 ↓ Result available here!
sub:        IF   ID   EX    MEM   WB
                     ↑ Needed here - SAME cycle possible!
```

**Result:** Forwarding eliminates ALL stalls (0 cycle penalty)

### Load-Use (Different Project)

```
lw:    IF   ID   EX   MEM   WB
                      ↓ Data available here (end of MEM)
add:        IF   ID   EX    MEM   WB
                 ↑ Needed here (start of EX)
```

**Result:** Forwarding still requires 1 stall (timing conflict)

---

## 📋 Lab Report Template

### Aim
To demonstrate ALU-to-ALU RAW hazards and how data forwarding completely eliminates stalls.

### Theory
In a pipelined processor, ALU instructions produce results at the end of the EX stage. Without forwarding, dependent instructions must wait for the result to be written to the register file (WB stage). Forwarding creates a direct path from ALU output to ALU input, eliminating this delay.

### Apparatus
- Ripes RISC-V Simulator
- Test program with chained ALU dependencies

### Procedure
1. Run code on 5-Stage Processor w/o Forwarding
2. Count bubbles and record cycles
3. Run same code on 5-Stage Processor w/ Forwarding
4. Verify no bubbles and record cycles
5. Calculate speedup

### Observations

| Configuration | Cycles | CPI | Bubbles/Dependency |
|---------------|--------|-----|-------------------|
| No Forwarding | ___ | ___ | ___ |
| With Forwarding | ___ | ___ | ___ |

### Result

$$\text{Speedup} = \frac{\text{Cycles}_{\text{no-fwd}}}{\text{Cycles}_{\text{fwd}}} = \_\_\_\times$$

### Discussion
1. ALU hazards cause 2 stalls per dependency without forwarding
2. Forwarding completely eliminates ALU-to-ALU stalls
3. This is more effective than Load-Use forwarding (which still has 1 stall)
4. Modern processors always implement forwarding due to massive performance benefit

---

## 🚀 Extensions

### 1. Longer Dependency Chains

Add more operations to the chain:
```asm
add a0, t0, t2
sub a1, a0, t3
and a2, a1, t2
or  a3, a2, t3
xor t0, a3, t2
```

### 2. Mixed Dependencies

Combine ALU and Load-Use hazards:
```asm
lw  t4, 0(a0)       # Load
add t5, t4, t2      # Load-Use hazard (1 stall with forwarding)
sub t6, t5, t3      # ALU hazard (0 stalls with forwarding)
```

### 3. No Dependencies (Baseline)

Compare with code that has zero dependencies:
```asm
add a0, t0, t2      # Independent
sub a1, t1, t3      # Independent
or  a2, t0, t2      # Independent
```

---

## 📚 Key Concepts

| Concept | Definition |
|---------|------------|
| **RAW Hazard** | Read-After-Write - instruction reads register before previous instruction writes it |
| **Data Forwarding** | Hardware technique to bypass register file by connecting pipeline stages directly |
| **EX-to-EX Forwarding** | Forwarding from one ALU instruction to the immediately following one |
| **MEM-to-EX Forwarding** | Forwarding from MEM stage to EX stage (2 instructions apart) |
| **Forwarding Unit** | Hardware that detects hazards and selects correct data source |
| **Bubble/NOP** | Empty cycle inserted when stalling |

---

## 📚 References

- [Ripes GitHub Repository](https://github.com/mortbopet/Ripes)
- [RISC-V Specification](https://riscv.org/specifications/)
- Patterson & Hennessy, *Computer Organization and Design*

---

## 📄 License

This educational material is provided for learning purposes. Feel free to use and modify for your coursework and labs.
