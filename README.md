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

## Design overview (hardware-oriented)

flowchart TD
  A[Start / Reset] --> B[Stream input bytes]
  B --> C[Parse tokens: SRC, DST]
  C --> D[Node mapping: 3-letter name -> node_id]
  D --> E[Store edge list (src_id, dst_id)]
  E --> F[Build CSR adjacency<br/>outdeg -> prefix-sum offsets -> adj array]
  F --> G[Kahn topo sort<br/>queue indeg==0 -> topo[]]
  G --> H{topo_len == node_count?}
  H -- no --> X[Set overflow=1<br/>Output 0/0]
  H -- yes --> I[Reverse-topo DP]
  I --> J[Part1: dp1 paths you->out]
  I --> K[Part2: dp2 with mask visits fft&dac]
  J --> L[Emit part1/part2 + out_valid]
  K --> L


The solver is implemented as a small control FSM with bounded on-chip memories. It consumes the puzzle input as an ASCII byte stream and produces Part 1 / Part 2 answers when computation completes.

### Pipeline / stages

1. **Input parse & node mapping**
   - Stream-parse the input into 3-letter node names.
   - Each node name is encoded into a compact integer ID and stored in a small mapping table.
   - Edges are stored as `(src_id, dst_id)` pairs as they are parsed.

2. **Graph build (CSR adjacency)**
   - Compute out-degree for each node.
   - Prefix-sum to build CSR offsets.
   - Populate a packed adjacency array so neighbors of a node are in a contiguous region.
   - Compute indegree in parallel for Kahn topological sort.

3. **Topological sort (Kahn)**
   - Initialize a queue with all nodes having indegree 0.
   - Pop queue, append to `topo[]`, decrement indegree of neighbors, push new zeros.
   - If `topo_len != node_count`, assert `overflow` (cycle / inconsistent parse / bounds).

4. **DAG dynamic programming**
   - **Part 1:** number of paths from `you` to `out` using a single DP value per node.
   - **Part 2:** number of paths from `svr` to `out` that visit both `fft` and `dac`.
     This is done with a 2-bit visitation mask, i.e. DP state `dp[node][mask]` where
     `mask` tracks whether `fft` and `dac` have been visited so far.
   - DP is computed in reverse-topological order so each node accumulates contributions
     from its outgoing edges.

5. **Emit result**
   - When DP completes, `out_valid` pulses and `part1/part2` are stable.
   - `overflow` indicates bounds were exceeded or graph consistency checks failed.

### Resource bounds

The implementation is fully bounded (synthesizable). If input exceeds these limits, `overflow` asserts.

- MAXV (nodes): 1024
- MAXE (edges): 4096
- MAXB (input bytes): 20000

## How to run (ModelSim)

1. Put your AoC input in repo root as `input.txt`.
   - This repository does not include personal inputs.
   - Use `input.example.txt` as a template and rename it to `input.txt`.

2. In ModelSim Transcript:

```tcl
cd <path-to-repo>
do sim/run.do
