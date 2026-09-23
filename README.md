# Matrix-Vector Multiplication Engine

A fully-pipelined, latency-insensitive hardware accelerator for matrix-vector multiplication, implemented in SystemVerilog and deployed on the AMD/Xilinx Kria KV260 FPGA. The design meets timing at **350 MHz**, with an architecture modeled on the class of systolic/lane-parallel accelerators used in real-world deep learning inference hardware (e.g. Microsoft's BrainWave).

## Overview

The engine computes `y = A · x` for matrices and vectors of arbitrary size by splitting work across a configurable number of parallel **output lanes**, each responsible for producing one element of the output vector. Each lane runs an 8-wide pipelined dot product unit and an accumulator, fed by on-chip SRAM memories and orchestrated by a shared FSM-based controller.

## Architecture

```
                 ┌──────────────┐
  i_vec_* ──────▶│ Vector Memory│
                 └──────┬───────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
  ┌───────────┐   ┌───────────┐   ┌───────────┐
  │ Matrix Mem│   │ Matrix Mem│   │ Matrix Mem│   ... (NUM_OLANES lanes)
  │  (Lane 0) │   │  (Lane 1) │   │  (Lane N) │
  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
        ▼               ▼               ▼
  ┌───────────┐   ┌───────────┐   ┌───────────┐
  │ Dot Product│  │ Dot Product│  │ Dot Product│
  │   Unit     │  │   Unit     │  │   Unit     │
  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
        ▼               ▼               ▼
  ┌───────────┐   ┌───────────┐   ┌───────────┐
  │ Accumulator│  │ Accumulator│  │ Accumulator│
  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
        └───────────────┴───────────────┘
                        ▼
                   o_result / o_valid

              ▲
      FSM Controller sequences vec/mat read
      addresses + accumulator first/last bits
```

### Components

| Module | Role |
|---|---|
| `mem.sv` | Parameterizable single-read/single-write SRAM block (1-cycle latency) used for both vector and matrix storage |
| `dot8.sv` | 8-lane pipelined dot product unit — 8 parallel multipliers feeding a `log2(8)`-level binary adder reduction tree, fully pipelined for throughput |
| `accum.sv` | Streaming accumulator with `first`/`last` control bits to mark accumulation boundaries between matrix rows |
| `ctrl.sv` | Two-state (`IDLE` / `COMPUTE`) finite-state machine that sequences memory read addresses and accumulator control signals across the whole matrix-vector product |
| `mvm.sv` | Top-level module integrating the vector memory, per-lane matrix memories, dot product units, accumulators, and controller into the complete engine |

### Data layout

Matrix rows are split into 8-element words and distributed round-robin across the per-lane matrix memories, so each lane independently streams the row data it needs without contention. The vector operand is broadcast to all lanes from a single shared vector memory using the same word layout.

## Performance

- **Clock frequency:** 350 MHz (post-implementation, out-of-context synthesis)
- **Pipeline:** Fully pipelined datapath — dot product unit and accumulator both operate at II=1, sustaining one input pair per cycle per lane
- **Scalability:** Throughput scales linearly with `NUM_OLANES`, trading FPGA resource utilization (DSP blocks, BRAM) for output bandwidth

## Verification

- Component-level simulation of `dot8.sv` and `accum.sv` against known-good reference values
- Full-system verification via a randomized testbench that writes random vector/matrix operands to memory, triggers computation, and checks `o_result` against pre-computed golden outputs
- Post-implementation (post-synthesis) functional simulation to confirm the netlist matches RTL-level behavior after Vivado implementation
- Resource utilization (DSP/BRAM) and static timing analysis checked against expected values post-implementation

## Tools

- **Language:** SystemVerilog
- **Synthesis / Implementation:** AMD Vivado
- **Target device:** Kria KV260 FPGA
- **Debug:** SignalTap-style waveform inspection during simulation

## Background

Built as part of an advanced digital hardware systems course, extending this into a fully working, timing-closed accelerator on real FPGA hardware.
