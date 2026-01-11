## Methodology (Academic / Hardware-Oriented)

This solution treats the puzzle input as a labeled directed graph and implements the complete flow as a bounded, synthesizable RTL datapath controlled by an FSM. The key goal is to map a software-like graph algorithm into a hardware-friendly staged pipeline with explicit memory structures and termination conditions.

### Problem abstraction

The input describes a directed graph whose vertices are 3-letter node names and whose edges define valid transitions. The task reduces to counting constrained path families on this graph:

- **Part 1** computes the number of directed paths from `you` to `out`.
- **Part 2** computes the number of directed paths from `svr` to `out` subject to a visitation constraint: the path must visit both `fft` and `dac` at least once.

This formulation is naturally solved on a DAG using topological order. In hardware, the main challenge is converting (1) streaming text parsing and (2) irregular graph traversal into deterministic memory accesses with bounded resources.

### Hardware pipeline decomposition

Instead of implementing the algorithm as one monolithic “do-everything” loop, the design is decomposed into stages that can be scheduled and verified independently. Each stage has clear input/output contracts and uses only bounded RAM arrays, making it synthesizable.

**Stage 0 — Streaming ingestion**
- The design consumes ASCII bytes via `(in_valid, in_byte, in_last)`.
- A small parser FSM detects 3-letter tokens and separators.

**Stage 1 — Tokenization and node-ID mapping**
- Each 3-letter node name is encoded and mapped to a compact integer ID.
- A node table is maintained so repeated names map to the same ID.
- This converts text-domain identifiers into fixed-width IDs suitable for RAM indexing.

**Stage 2 — Edge capture**
- Parsed edges are stored as `(src_id, dst_id)` pairs in an edge RAM.
- In parallel, per-node out-degree counters are accumulated to prepare adjacency construction.

**Stage 3 — CSR (Compressed Sparse Row) adjacency construction**
To enable efficient neighbor iteration in later stages, the edge list is transformed into a CSR representation:
- Compute prefix sums of out-degree to form `offset[u]` (start index of adjacency list of node `u`).
- Populate `adj[offset[u] + k] = v` for each outgoing edge `u -> v`.
- Compute `indegree[v]` for topological sorting.
CSR converts irregular “list-of-lists” structure into two dense arrays (`offset[]`, `adj[]`) that are hardware-friendly.

**Stage 4 — Topological sorting (Kahn)**
- Initialize a FIFO with all nodes of indegree 0.
- Pop nodes into `topo[]`, decrement neighbors’ indegree, and push newly-zero nodes.
- A consistency check enforces `topo_len == node_count`. If violated (cycle / corruption / bounds exceeded), `overflow` asserts.

**Stage 5 — Dynamic programming on the DAG**
DP is performed in reverse-topological order, which ensures that when processing node `u`, all successors’ DP values are already available.

- **Part 1 (unconstrained paths):**
  - Maintain a scalar `dp1[u]` per node.
  - Base case at sink: `dp1[out] = 1`.
  - Transition: `dp1[u] = sum_{(u->v)} dp1[v]`.

- **Part 2 (visitation constraint via mask DP):**
  - Maintain `dp2[u][m]` where `m` is a 2-bit mask indicating whether `fft` and/or `dac` has been visited so far.
  - The visitation mask is updated when traversing an edge to a special node.
  - Base case: `dp2[out][m] = 1` only for masks satisfying the required condition; otherwise 0.
  - Transition: `dp2[u][m] = sum_{(u->v)} dp2[v][m']`, where `m'` is the updated mask after moving to `v`.

Finally, the outputs are latched and `out_valid` is asserted once when results are stable.

### Control strategy and synthesizability

A single control FSM sequences the stages:
`IDLE → PARSE → BUILD_CSR → TOPO_SORT → DP → DONE`.

Each stage uses bounded counters and explicit RAMs; no dynamic allocation or unbounded loops are used. Resource limits (MAXV/MAXE/MAXB) are enforced. If exceeded, `overflow` is asserted, and the design transitions to a safe terminal behavior.

### Code-level mapping (where to look)

- `src/day11_top.v` contains:
  - the parser/token extraction logic (streaming ASCII to tokens),
  - node-ID mapping table updates,
  - edge RAM writes and degree accumulation,
  - CSR build logic (offset prefix sums and adjacency fill),
  - Kahn topological sort and `topo[]` storage,
  - reverse-topological DP engines for Part 1 and Part 2,
  - output register/handshake generation (`busy`, `out_valid`, `overflow`).

- `tb/tb_day11.v` drives the input stream from `input.txt` and checks that the DUT produces stable `part1` and `part2` once `out_valid` is asserted. The testbench prints the answers and writes `results.txt` for reproducibility.

This staged design is intentionally “hardware-first”: the algorithm is expressed as deterministic memory transformations and DP scans, matching the constraints of synthesizable RTL.
