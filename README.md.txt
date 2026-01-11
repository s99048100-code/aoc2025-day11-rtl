# Advent of FPGA 2025 — AoC 2025 Day 11 (Synthesizable RTL)

Synthesizable RTL + testbench solution for Advent of Code 2025 Day 11, prepared for Jane Street’s Advent of FPGA submission.

## Repo layout

- `src/day11_top.v` — top module (synthesizable)
- `tb/tb_day11.v` — testbench (reads `input.txt`, writes `results.txt`)
- `sim/run.do` — ModelSim GUI script

## Top-level I/O

Input stream:
- `in_valid`: `in_byte` is valid
- `in_byte[7:0]`: ASCII input byte
- `in_last`: asserted on the final byte

Output:
- `out_valid`: pulses when outputs are ready
- `part1[63:0]`: Part 1 answer
- `part2[63:0]`: Part 2 answer
- `overflow`: asserted if internal limits are exceeded
- `busy`: high while running

## How to run (ModelSim)

1. Put your AoC input in repo root as `input.txt`.
   - This repository does not include personal inputs.
   - Use `input.example.txt` as a template and rename it to `input.txt`.

2. In ModelSim Transcript:

```tcl
cd <path-to-repo>
do sim/run.do
