# AoC 2025 Day 11 — Synthesizable Verilog RTL + Testbench (Staged / Pipeline-Style)

This repository provides a **synthesizable Verilog RTL** solution and a **ModelSim testbench** for Advent of Code 2025 Day 11, prepared in a hardware-oriented manner for a reproducible FPGA-style submission. The implementation follows a **staged / pipeline-style** methodology: streaming ASCII input is parsed into a directed graph, transformed into hardware-friendly adjacency storage, then solved using topological ordering and dynamic programming (DP). A control FSM sequences bounded RAMs and counters, producing **Part 1** and **Part 2** outputs with explicit `busy/out_valid/overflow` status.

---

## Repository Layout

- `src/day11_top.v` — synthesizable top-level RTL
- `tb/tb_day11.v` — testbench (reads `input.txt`, prints results, writes `results.txt`)
- `sim/run.do` — ModelSim compile + run script

---

## Top-Level Interface (Streaming)

### Input Stream
- `in_valid` — input byte is valid
- `in_byte[7:0]` — ASCII input byte
- `in_last` — asserted on the final byte (end-of-stream)

### Output / Status
- `busy` — high while the design is processing
- `out_valid` — asserted when outputs are ready (often a single-cycle pulse at DONE)
- `part1[63:0]` — Part 1 answer
- `part2[63:0]` — Part 2 answer
- `overflow` — asserted when resource bounds are exceeded or consistency checks fail

---

## Methodology (Academic / Hardware-Oriented)

### Problem Abstraction
The input describes a directed graph whose vertices are **3-letter node names** and whose edges define valid transitions. The puzzle reduces to counting constrained path families:

- **Part 1:** number of directed paths from `you` to `out`.
- **Part 2:** number of directed paths from `svr` to `out` subject to a visitation constraint: the path must visit both `fft` and `dac` at least once.

The hardware challenge is mapping (1) **streaming ASCII parsing** and (2) **irregular graph traversal** into deterministic, bounded-memory operations suitable for synthesizable RTL.

---

## Staged / Pipeline-Style Hardware Mapping

Instead of implementing the algorithm as a single monolithic “software loop,” the design is decomposed into stages. Each stage performs a fixed transformation using bounded RAM arrays and counters, and the control FSM sequences these stages.

### Stage 0 — Streaming Ingestion
Consume ASCII bytes via `(in_valid, in_byte, in_last)`. A small parser FSM detects 3-letter tokens and separators without requiring the full input to be buffered as a string.

### Stage 1 — Tokenization & Node-ID Mapping
Each 3-letter node name is converted into a compact **integer node ID** using a node table (name ↔ ID). This converts text-domain identifiers into fixed-width indices for RAM addressing.

### Stage 2 — Edge Capture (Edge RAM)
As edges are parsed, store `(src_id, dst_id)` pairs into an edge RAM. In parallel, accumulate per-node **out-degree** counts needed for adjacency construction.

### Stage 3 — CSR (Compressed Sparse Row) Construction
To enable efficient neighbor iteration in hardware, transform the edge list into CSR:

- `offset[u]`: start index of node `u`’s adjacency list in `adj[]` (computed by prefix-summing out-degrees)
- `adj[]`: packed adjacency array; neighbors of `u` occupy `adj[offset[u] .. offset[u+1)-1]`
- `indegree[v]`: computed for Kahn’s topological sort

CSR converts an irregular list-of-lists into two dense arrays (`offset[]`, `adj[]`) that are hardware-friendly for sequential scanning.

### Stage 4 — Topological Sort (Kahn)
Perform Kahn’s algorithm using a FIFO queue:

- initialize queue with all `indegree==0` nodes
- pop into `topo[]`, decrement neighbors’ indegree, push newly-zero nodes
- consistency check: if `topo_len != node_count`, assert `overflow`

### Stage 5 — Dynamic Programming on the DAG
Compute DP in **reverse topological order** so each node can accumulate contributions from successors whose DP values are already available.

#### Part 1: Unconstrained Path Count
- state: `dp1[u]`
- base: `dp1[out] = 1`
- transition: `dp1[u] = Σ dp1[v]` over all edges `u -> v`

#### Part 2: Visitation Constraint via Mask DP
Use a 2-bit mask to track whether `fft` and/or `dac` have been visited:

- state: `dp2[u][m]`, where `m ∈ {0..3}`
  - bit0: visited `fft`
  - bit1: visited `dac`
- mask update occurs when stepping into a special node
- base at `out`: only masks satisfying the requirement contribute; others are 0
- transition: `dp2[u][m] = Σ dp2[v][m’]` where `m’` is the updated mask after moving to `v`

Finally:
- `part1 = dp1[you]`
- `part2 = dp2[svr][3]` (mask `11`, meaning both `fft` and `dac` visited)

### Stage 6 — Emit
Latch outputs and assert `out_valid` when `part1/part2` are stable. `busy` deasserts in the terminal state.

---

## Control Strategy (FSM Scheduling)

A single FSM sequences the full flow (conceptually):

`IDLE → PARSE → BUILD_CSR → TOPO_SORT → DP → DONE`

- `busy=1` from PARSE through DP
- `out_valid` asserted when DONE is reached (often a pulse)
- `overflow` asserted when bounds are exceeded or consistency checks fail

This scheduling style is intentionally hardware-first: the algorithm is expressed as deterministic memory transformations and bounded scans rather than software loops.

---

## Resource Bounds (Synthesizable Limits)

The design uses fixed-size RAM arrays and explicit limits. If any limit is exceeded, `overflow` asserts.

- MAXV: maximum number of nodes
- MAXE: maximum number of edges
- MAXB: maximum number of input bytes

(Refer to `src/day11_top.v` for the actual parameter/localparam values.)

---

## Verification / Testbench Strategy

`tb/tb_day11.v`:
1. reads `input.txt` from the repository root
2. streams the file byte-by-byte into the DUT
3. waits for `out_valid`
4. prints `Part 1 / Part 2 / overflow` in the Transcript
5. writes `results.txt` to the repository root

---

## Complexity, Throughput Notes, and Completion Semantics

### Stage complexity (hardware view)

Let:
- **B** = number of input bytes streamed (`in_valid` cycles),
- **V** = number of unique nodes,
- **E** = number of directed edges.

The staged datapath is designed as bounded scans over on-chip memories:

- **Parse + node mapping:**  Θ(B)  
  Streaming ASCII parsing; node table lookup/insert is bounded and performed incrementally.
- **CSR build (degree → prefix-sum → adjacency fill):**  Θ(V + E)  
  One pass to compute degrees, one prefix-sum over V, and one pass over E to fill `adj[]`.
- **Topological sort (Kahn):**  Θ(V + E)  
  Each node is enqueued/dequeued once; each edge decrements indegree once.
- **DP (reverse-topological):**
  - **Part 1:** Θ(V + E)
  - **Part 2:** Θ(4·(V + E)) due to the 2-bit visitation mask (4 states per node)

This is intentionally “hardware-first”: every phase is a predictable scan with explicit counters and fixed RAM arrays, rather than an unbounded software loop.

### Handshake / completion semantics

- The DUT consumes the input stream using:
  - `in_valid` (byte valid), `in_byte[7:0]` (ASCII), and `in_last` (end-of-stream).
- While processing, `busy=1`.
- When the results are ready, `out_valid` is asserted (often as a pulse at completion). At this point:
  - `part1` and `part2` are stable and can be sampled,
  - `busy` transitions low shortly after (or at the same time, depending on the internal sequencing).
- `overflow=1` indicates the design hit a bounded-resource limit or a consistency check failure
  (e.g., exceeded MAXV/MAXE/MAXB, or `topo_len != V` implying a cycle/inconsistency under the design’s checks).

### Reproducibility and common pitfalls

The reference flow is:
1. Place your puzzle input in repo root as `input.txt`.
2. Run `do sim/run.do` in ModelSim.
3. Read results in:
   - ModelSim Transcript (printed Part 1 / Part 2 / overflow),
   - and `results.txt` generated in the repo root.

If results do not appear, the most common issue is running the script from the wrong directory.
In the Transcript, verify you are in the repository root:
```tcl
pwd
dir
