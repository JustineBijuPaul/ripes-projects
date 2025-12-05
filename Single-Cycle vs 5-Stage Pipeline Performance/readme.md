# Single-Cycle vs 5-Stage Pipeline Performance Comparison

A complete "single program, two CPUs" experiment for comparing **RISC-V Single Cycle Processor** vs **RISC-V 5-Stage Pipeline** performance in the [Ripes](https://github.com/mortbopet/Ripes) simulator.

---

## 📁 Project Files

| File | Description |
|------|-------------|
| `sum_loop.asm` | Test program that computes sum of numbers 0..(N-1) |

---

## 🎯 What This Demonstrates

- **Performance comparison** between Single-Cycle and Pipelined architectures
- **Cycles, CPI, and Speedup** measurement methodology
- **Same program, different processors** - proving functional equivalence
- **Pipeline overhead** from branch penalties and startup/flush costs

---

## 📝 Assembly Code

This program computes the sum of numbers from 0 to N-1 using a simple loop. Run this **exact same code** on both processor models.

```asm
###########################################################
# Single-Cycle vs 5-Stage Pipeline Performance Demo
# Program: Sum of numbers 0..(N-1) using a simple loop
#
# - Works on:
#     * RISC-V Single Cycle Processor
#     * RISC-V 5-Stage Processor (with hazard detection + forwarding)
#
# - You will measure:
#     * Total cycles
#     * Instructions
#     * CPI
#     * Speedup = Cycles_single / Cycles_pipeline
###########################################################

    .data
N:      .word 10        # N = 10  → sum = 0+1+...+9 = 45
SUM:    .word 0         # where we store the result

    .text
    .globl _start
_start:
    #######################################################
    # 1. Setup pointers and load N
    #######################################################
    la      x10, N          # x10 = &N
    la      x11, SUM        # x11 = &SUM

    lw      x5, 0(x10)      # x5 = N
    addi    x6, x0, 0       # x6 = i = 0
    addi    x7, x0, 0       # x7 = sum = 0

    #######################################################
    # 2. Loop: sum = sum + i   for i = 0 .. N-1
    #######################################################
loop:
    add     x7, x7, x6      # sum += i
    addi    x6, x6, 1       # i++

    blt     x6, x5, loop    # if (i < N) goto loop

    #######################################################
    # 3. Store result and stop
    #######################################################
    sw      x7, 0(x11)      # SUM = sum  (should be 45 for N=10)

end:
    nop                     # Place breakpoint here in Ripes
```

---

## 🔧 Ripes Setup Instructions

### Common Settings (For Both Runs)

1. **Input Type**
   - In the **Editor** tab, set `Input type: Assembly (RISC-V)`

2. **Assemble**
   - Click **Assemble** (hammer icon) to load the code into the CPU

3. **Set Breakpoint**
   - In the **Program** view (right side), click the margin next to the `end:` label
   - The simulator will stop there so you can read stats & registers

4. **Open Statistics**
   - In the **Processor** tab, open:
     - **Registers** pane (register file)
     - **Statistics** pane (Cycles, Instructions, CPI)

---

## 🧪 Experiment Workflow

### Run 1: Single-Cycle CPU

1. Click the **Processor selection** icon (CPU/chip icon)
2. Choose: **`RISC-V Single Cycle Processor`**
3. Click **Reset** (circular arrow)
4. Click **Run**
5. Execution stops at the breakpoint (`end:`)

**Record from Statistics panel:**

| Metric | Value |
|--------|-------|
| Cycles_single | ___ |
| Instructions_single | ___ |
| CPI_single | ___ |

> **Note:** CPI should be exactly **1.0** for single-cycle (one instruction per cycle by definition)

---

### Run 2: 5-Stage Pipelined CPU

1. Click the **Processor selection** icon again
2. Choose: **`RISC-V 5-Stage Processor`** (with hazard detection + forwarding)
3. Click **Reset**
4. Click **Run**
5. When it stops at `end:`, record:

| Metric | Value |
|--------|-------|
| Cycles_pipe | ___ |
| Instructions_pipe | ___ |
| CPI_pipe | ___ |

> **Note:** CPI will be ≈1 but slightly >1 due to branch penalties and pipeline startup/flush

---

## ✅ Expected Output

At the `end:` breakpoint, **both CPUs** should produce identical results:

### Register Values

| Register | Value | Description |
|----------|-------|-------------|
| `x5` | 10 | N (loop bound) |
| `x6` | 10 | i ended at 10 (loop exits when i == N) |
| `x7` | 45 | sum = 0 + 1 + 2 + ... + 9 |
| `x10` | addr | Address of N (implementation-dependent) |
| `x11` | addr | Address of SUM |

### Memory Values

In the **Data/Memory** view, at label **`SUM`**:

```
SUM = 45   # (0 + 1 + 2 + ... + 9 = 45)
```

### Verification Formula

For N = 10:
$$\text{Sum} = \sum_{i=0}^{N-1} i = \frac{(N-1) \times N}{2} = \frac{9 \times 10}{2} = 45$$

> 💡 **Try changing N!** Edit `N: .word 100` to compute sum of 0..99 = 4950. Both CPUs must give the same result.

---

## 📊 Performance Analysis

### Speedup Calculation

From your two runs, compute:

$$\text{Speedup (by cycles)} = \frac{\text{Cycles}_{\text{single}}}{\text{Cycles}_{\text{pipe}}}$$

### Sample Results Table

| Metric | Single-Cycle | 5-Stage Pipeline | Notes |
|--------|--------------|------------------|-------|
| **Cycles** | ~X | ~Y | Pipeline may have more cycles due to startup |
| **Instructions** | Same | Same | Same program! |
| **CPI** | 1.0 | >1.0 | Pipeline overhead from branches |

### Why Pipeline CPI > 1.0?

The 5-stage pipeline experiences overhead from:

1. **Pipeline Fill**: First instruction takes 5 cycles to complete
2. **Pipeline Flush**: Branch mispredictions flush the pipeline
3. **Branch Penalty**: `blt` instruction may cause stalls

---

## 🔬 Theoretical Discussion

### Real-World Speedup

In actual hardware, speedup considers clock period:

$$\text{Real Speedup} = \frac{\text{Cycles}_{\text{single}} \times T_{\text{clk,single}}}{\text{Cycles}_{\text{pipe}} \times T_{\text{clk,pipe}}}$$

### Why Pipelining Wins

| Factor | Single-Cycle | 5-Stage Pipeline |
|--------|--------------|------------------|
| **Clock Period** | Long (limited by slowest instruction) | Short (limited by slowest stage) |
| **CPI** | Exactly 1.0 | Slightly >1.0 |
| **Throughput** | 1 inst/long_cycle | ~1 inst/short_cycle |

Even though pipeline CPI may be >1, the **shorter clock period** typically results in:

$$T_{\text{clk,pipe}} \approx \frac{T_{\text{clk,single}}}{5}$$

This means **real speedup ≈ 4-5x** even with pipeline overhead!

---

## 📈 Understanding the Results

### Single-Cycle Processor

```
Cycle 1: [Instruction 1 complete]
Cycle 2: [Instruction 2 complete]
Cycle 3: [Instruction 3 complete]
...
```
- One instruction completes every cycle
- CPI = 1.0 exactly
- But each cycle is LONG

### 5-Stage Pipeline

```
Cycle 1: IF1
Cycle 2: IF2  ID1
Cycle 3: IF3  ID2  EX1
Cycle 4: IF4  ID3  EX2  MEM1
Cycle 5: IF5  ID4  EX3  MEM2  WB1  ← First instruction complete!
Cycle 6: IF6  ID5  EX4  MEM3  WB2  ← Second instruction complete
...
```
- Takes 5 cycles for first instruction
- After that, ~1 instruction completes per cycle
- Each cycle is SHORT (1/5 of single-cycle)

---

## 📋 Lab Report Template

### Aim
To compare the performance of Single-Cycle and 5-Stage Pipelined RISC-V processors using cycle count, CPI, and speedup metrics.

### Apparatus
- Ripes RISC-V Simulator
- Test program: Sum of numbers 0..(N-1)

### Procedure
1. Load the assembly program in Ripes
2. Run on Single-Cycle processor, record metrics
3. Run on 5-Stage Pipeline processor, record metrics
4. Calculate speedup and analyze results

### Observations

| Processor | Cycles | Instructions | CPI |
|-----------|--------|--------------|-----|
| Single-Cycle | ___ | ___ | ___ |
| 5-Stage Pipeline | ___ | ___ | ___ |

### Result
$$\text{Speedup} = \frac{\text{Cycles}_{\text{single}}}{\text{Cycles}_{\text{pipe}}} = \_\_\_$$

### Discussion
- Both processors produce the same correct result (SUM = 45)
- Single-cycle CPI = 1.0 (by definition)
- Pipeline CPI > 1.0 due to branch penalties and startup overhead
- In real hardware, pipeline would be faster due to shorter clock period

---

## 🚀 Extensions

Try these variations to deepen your understanding:

1. **Increase N**: Change `N: .word 100` and observe how the ratio changes
2. **Remove branches**: Write a straight-line program and compare CPIs
3. **Compare all models**: Include `5-Stage w/o Forwarding` in your comparison
4. **Branch-heavy code**: Write a program with many branches to maximize pipeline penalties

---

## 📚 Key Concepts

| Concept | Definition |
|---------|------------|
| **CPI** | Cycles Per Instruction - average cycles needed per instruction |
| **Throughput** | Number of instructions completed per unit time |
| **Latency** | Time from instruction fetch to completion |
| **Pipeline Speedup** | Theoretical max = number of pipeline stages |
| **Branch Penalty** | Extra cycles wasted when branch prediction is wrong |

---

## 📚 References

- [Ripes GitHub Repository](https://github.com/mortbopet/Ripes)
- [RISC-V Specification](https://riscv.org/specifications/)
- Patterson & Hennessy, *Computer Organization and Design*

---

## 📄 License

This educational material is provided for learning purposes. Feel free to use and modify for your coursework and labs.
