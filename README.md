# AoC 2025 Day 11 — Synthesizable Verilog RTL + Testbench

Synthesizable RTL implementation (streaming ASCII input) with a self-checking ModelSim testbench, prepared for Jane Street’s Advent of FPGA submission.

![language](https://img.shields.io/badge/language-Verilog-informational)
![license](https://img.shields.io/badge/license-MIT-success)
![sim](https://img.shields.io/badge/sim-ModelSim%2010.1d-blue)

## What’s inside

- `src/day11_top.v` — synthesizable top module
- `tb/tb_day11.v` — testbench (reads `input.txt`, writes `results.txt`)
- `sim/run.do` — ModelSim script (GUI)

## Design overview (hardware-oriented)

The solver is structured as a bounded-memory control FSM:

1. **Parse & node mapping**
   - Stream-parse ASCII into 3-letter node names.
   - Map each node name to a compact integer ID.
   - Store edges as `(src_id, dst_id)`.

2. **CSR adjacency build**
   - Compute out-degree, prefix-sum offsets, then pack adjacency array.
   - Compute indegree for topo.

3. **Topological sort (Kahn)**
   - Queue all indegree=0 nodes.
   - Pop -> `topo[]`, decrement neighbors, push new zeros.
   - If `topo_len != node_count`, assert `overflow`.

4. **DAG DP**
   - **Part 1:** count paths `you -> out`.
   - **Part 2:** count paths `svr -> out` that visit both `fft` and `dac` using a 2-bit visitation mask:
     `dp[node][mask]`, computed in reverse-topological order.

5. **Emit**
   - `out_valid` pulses when `part1/part2` are ready.

## I/O interface

Input stream:
- `in_valid`: `in_byte` valid
- `in_byte[7:0]`: ASCII byte
- `in_last`: asserted on final byte

Outputs:
- `out_valid`: results ready pulse
- `part1[63:0]`, `part2[63:0]`
- `busy`: high while running
- `overflow`: asserted on bounds/consistency failure

## Limits

Fully bounded for synthesizability:
- MAXV (nodes): 1024
- MAXE (edges): 4096
- MAXB (input bytes): 20000

## How to run (ModelSim)

1. Put your AoC input in repo root as `input.txt` (do not commit personal inputs).
2. In ModelSim Transcript:

```tcl
cd <path-to-repo>
do sim/run.do
