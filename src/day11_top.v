module day11_top(clk,rst_n,in_valid,in_byte,in_last,out_valid,part1,part2,overflow,busy);
parameter MAXV = 1024;
parameter MAXE = 4096;
parameter MAXB = 20000;
input clk;
input rst_n;
input in_valid;
input [7:0] in_byte;
input in_last;
output reg out_valid;
output reg [63:0] part1;
output reg [63:0] part2;
output reg overflow;
output reg busy;

localparam IDXW = 10;
localparam CODEMAX = 17576;
localparam [IDXW-1:0] UNMAP = {IDXW{1'b1}};

localparam [14:0] C_YOU = 15'd16608;
localparam [14:0] C_OUT = 15'd10003;
localparam [14:0] C_SVR = 15'd12731;
localparam [14:0] C_DAC = 15'd2030;
localparam [14:0] C_FFT = 15'd3529;

reg [7:0] inbuf [0:MAXB-1];
reg [17:0] wr_ptr;
reg [17:0] in_len;

reg [IDXW-1:0] code2idx [0:CODEMAX-1];

reg [IDXW-1:0] edge_src [0:MAXE-1];
reg [IDXW-1:0] edge_dst [0:MAXE-1];

reg [11:0] out_cnt [0:MAXV-1];
reg [11:0] indeg  [0:MAXV-1];

reg [15:0] off [0:MAXV-1];
reg [11:0] wptr [0:MAXV-1];
reg [IDXW-1:0] adj [0:MAXE-1];

reg [IDXW-1:0] q [0:MAXV-1];
reg [IDXW-1:0] topo [0:MAXV-1];

reg [63:0] w1 [0:MAXV-1];
reg [63:0] w2_0 [0:MAXV-1];
reg [63:0] w2_1 [0:MAXV-1];
reg [63:0] w2_2 [0:MAXV-1];
reg [63:0] w2_3 [0:MAXV-1];

reg [IDXW-1:0] node_n;
reg [15:0] edge_n;

reg have_you, have_out, have_svr, have_dac, have_fft;
reg [IDXW-1:0] idx_you, idx_out, idx_svr, idx_dac, idx_fft;

function [14:0] enc3;
input [7:0] a;
input [7:0] b;
input [7:0] c;
reg [7:0] x0,x1,x2;
begin
  x0 = a - 8'd97;
  x1 = b - 8'd97;
  x2 = c - 8'd97;
  enc3 = (x0 * 15'd676) + (x1 * 15'd26) + x2;
end
endfunction

reg [4:0] st;
localparam ST_RECV     = 5'd0;
localparam ST_CLR_MAP  = 5'd1;
localparam ST_CLR_NODE = 5'd2;
localparam ST_PARSE    = 5'd3;
localparam ST_OFF      = 5'd4;
localparam ST_ADJ      = 5'd5;
localparam ST_QINIT    = 5'd6;
localparam ST_TOPOP    = 5'd7;
localparam ST_TOPE     = 5'd8;
localparam ST_DP1I     = 5'd9;
localparam ST_DP1      = 5'd10;
localparam ST_DP2I     = 5'd11;
localparam ST_DP2      = 5'd12;
localparam ST_DONE     = 5'd13;

reg [15:0] clr_map_i;
reg [IDXW-1:0] clr_node_i;

reg [17:0] rd_ptr;
reg have_b;
reg [7:0] b;

reg [2:0] ps;
localparam PS_WAIT_SRC0 = 3'd0;
localparam PS_SRC1      = 3'd1;
localparam PS_SRC2      = 3'd2;
localparam PS_WAIT_COL  = 3'd3;
localparam PS_WAIT_DST0 = 3'd4;
localparam PS_DST1      = 3'd5;
localparam PS_DST2      = 3'd6;

reg [7:0] t0,t1,t2;
reg [IDXW-1:0] src_idx;

reg [14:0] code;
reg [IDXW-1:0] idx_val;

reg [IDXW-1:0] n_i;
reg [15:0] sum_e;
reg [15:0] e_i;

reg [IDXW-1:0] qh, qt;
reg [IDXW-1:0] topo_len;

reg [IDXW-1:0] cur_v;
reg [11:0] cur_k;

reg [IDXW-1:0] dp_i;
reg [1:0] dp_m;
reg dp_phase;
reg [IDXW-1:0] pu;
reg [1:0] pnm;
reg [63:0] padd;
reg [63:0] pbase;

reg [1:0] nm_val;
reg [63:0] add_val;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    out_valid <= 1'b0;
    part1 <= 64'd0;
    part2 <= 64'd0;
    overflow <= 1'b0;
    busy <= 1'b1;

    wr_ptr <= 18'd0;
    in_len <= 18'd0;

    node_n <= {IDXW{1'b0}};
    edge_n <= 16'd0;

    have_you <= 1'b0; have_out <= 1'b0; have_svr <= 1'b0; have_dac <= 1'b0; have_fft <= 1'b0;
    idx_you <= {IDXW{1'b0}}; idx_out <= {IDXW{1'b0}}; idx_svr <= {IDXW{1'b0}}; idx_dac <= {IDXW{1'b0}}; idx_fft <= {IDXW{1'b0}};

    clr_map_i <= 16'd0;
    clr_node_i <= {IDXW{1'b0}};

    rd_ptr <= 18'd0;
    have_b <= 1'b0;
    b <= 8'd0;
    ps <= PS_WAIT_SRC0;

    t0 <= 8'd0; t1 <= 8'd0; t2 <= 8'd0;
    src_idx <= {IDXW{1'b0}};
    code <= 15'd0;
    idx_val <= {IDXW{1'b0}};

    n_i <= {IDXW{1'b0}};
    sum_e <= 16'd0;
    e_i <= 16'd0;

    qh <= {IDXW{1'b0}}; qt <= {IDXW{1'b0}}; topo_len <= {IDXW{1'b0}};
    cur_v <= {IDXW{1'b0}}; cur_k <= 12'd0;

    dp_i <= {IDXW{1'b0}}; dp_m <= 2'd0; dp_phase <= 1'b0;
    pu <= {IDXW{1'b0}}; pnm <= 2'd0; padd <= 64'd0; pbase <= 64'd0;

    st <= ST_RECV;
  end else begin
    out_valid <= 1'b0;

    case (st)
      ST_RECV: begin
        busy <= 1'b1;
        if (in_valid) begin
          if (wr_ptr < MAXB) begin
            inbuf[wr_ptr] <= in_byte;
            wr_ptr <= wr_ptr + 18'd1;
            if (in_last) begin
              in_len <= wr_ptr + 18'd1;
              st <= ST_CLR_MAP;
              clr_map_i <= 16'd0;
              overflow <= 1'b0;
              node_n <= {IDXW{1'b0}};
              edge_n <= 16'd0;
              have_you <= 1'b0; have_out <= 1'b0; have_svr <= 1'b0; have_dac <= 1'b0; have_fft <= 1'b0;
            end
          end else begin
            overflow <= 1'b1;
          end
        end
      end

      ST_CLR_MAP: begin
        busy <= 1'b1;
        code2idx[clr_map_i] <= UNMAP;
        clr_map_i <= clr_map_i + 16'd1;
        if (clr_map_i == CODEMAX-1) begin
          st <= ST_CLR_NODE;
          clr_node_i <= {IDXW{1'b0}};
        end
      end

      ST_CLR_NODE: begin
        busy <= 1'b1;
        out_cnt[clr_node_i] <= 12'd0;
        indeg[clr_node_i] <= 12'd0;
        clr_node_i <= clr_node_i + {{(IDXW-1){1'b0}},1'b1};
        if (clr_node_i == MAXV-1) begin
          st <= ST_PARSE;
          rd_ptr <= 18'd0;
          have_b <= 1'b0;
          ps <= PS_WAIT_SRC0;
        end
      end

      ST_PARSE: begin
        busy <= 1'b1;

        if (!have_b && rd_ptr < in_len) begin
          b <= inbuf[rd_ptr];
          rd_ptr <= rd_ptr + 18'd1;
          have_b <= 1'b1;
        end else if (have_b) begin
          have_b <= 1'b0;

          if (ps == PS_WAIT_SRC0) begin
            if (b >= 8'd97 && b <= 8'd122) begin
              t0 <= b;
              ps <= PS_SRC1;
            end
          end else if (ps == PS_SRC1) begin
            t1 <= b;
            ps <= PS_SRC2;
          end else if (ps == PS_SRC2) begin
            t2 <= b;
            ps <= PS_WAIT_COL;
          end else if (ps == PS_WAIT_COL) begin
            if (b == 8'd58) begin
              code = enc3(t0,t1,t2);
              idx_val = code2idx[code];
              if (idx_val == UNMAP) begin
                if (node_n < MAXV) begin
                  idx_val = node_n;
                  code2idx[code] <= node_n;
                  out_cnt[node_n] <= 12'd0;
                  indeg[node_n] <= 12'd0;
                  if (code == C_YOU) begin idx_you <= node_n; have_you <= 1'b1; end
                  if (code == C_OUT) begin idx_out <= node_n; have_out <= 1'b1; end
                  if (code == C_SVR) begin idx_svr <= node_n; have_svr <= 1'b1; end
                  if (code == C_DAC) begin idx_dac <= node_n; have_dac <= 1'b1; end
                  if (code == C_FFT) begin idx_fft <= node_n; have_fft <= 1'b1; end
                  node_n <= node_n + {{(IDXW-1){1'b0}},1'b1};
                end else begin
                  overflow <= 1'b1;
                  idx_val = {IDXW{1'b0}};
                end
              end else begin
                if (code == C_YOU) begin idx_you <= idx_val; have_you <= 1'b1; end
                if (code == C_OUT) begin idx_out <= idx_val; have_out <= 1'b1; end
                if (code == C_SVR) begin idx_svr <= idx_val; have_svr <= 1'b1; end
                if (code == C_DAC) begin idx_dac <= idx_val; have_dac <= 1'b1; end
                if (code == C_FFT) begin idx_fft <= idx_val; have_fft <= 1'b1; end
              end
              src_idx <= idx_val;
              ps <= PS_WAIT_DST0;
            end else begin
              ps <= PS_WAIT_SRC0;
            end
          end else if (ps == PS_WAIT_DST0) begin
            if (b == 8'd10 || b == 8'd13) begin
              ps <= PS_WAIT_SRC0;
            end else if (b == 8'd32) begin
              ps <= PS_WAIT_DST0;
            end else if (b >= 8'd97 && b <= 8'd122) begin
              t0 <= b;
              ps <= PS_DST1;
            end
          end else if (ps == PS_DST1) begin
            t1 <= b;
            ps <= PS_DST2;
          end else if (ps == PS_DST2) begin
            t2 <= b;
            code = enc3(t0,t1,b);
            idx_val = code2idx[code];
            if (idx_val == UNMAP) begin
              if (node_n < MAXV) begin
                idx_val = node_n;
                code2idx[code] <= node_n;
                out_cnt[node_n] <= 12'd0;
                indeg[node_n] <= 12'd0;
                if (code == C_YOU) begin idx_you <= node_n; have_you <= 1'b1; end
                if (code == C_OUT) begin idx_out <= node_n; have_out <= 1'b1; end
                if (code == C_SVR) begin idx_svr <= node_n; have_svr <= 1'b1; end
                if (code == C_DAC) begin idx_dac <= node_n; have_dac <= 1'b1; end
                if (code == C_FFT) begin idx_fft <= node_n; have_fft <= 1'b1; end
                node_n <= node_n + {{(IDXW-1){1'b0}},1'b1};
              end else begin
                overflow <= 1'b1;
                idx_val = {IDXW{1'b0}};
              end
            end else begin
              if (code == C_YOU) begin idx_you <= idx_val; have_you <= 1'b1; end
              if (code == C_OUT) begin idx_out <= idx_val; have_out <= 1'b1; end
              if (code == C_SVR) begin idx_svr <= idx_val; have_svr <= 1'b1; end
              if (code == C_DAC) begin idx_dac <= idx_val; have_dac <= 1'b1; end
              if (code == C_FFT) begin idx_fft <= idx_val; have_fft <= 1'b1; end
            end

            if (edge_n < MAXE) begin
              edge_src[edge_n] <= src_idx;
              edge_dst[edge_n] <= idx_val;
              edge_n <= edge_n + 16'd1;
              out_cnt[src_idx] <= out_cnt[src_idx] + 12'd1;
              indeg[idx_val] <= indeg[idx_val] + 12'd1;
            end else begin
              overflow <= 1'b1;
            end

            ps <= PS_WAIT_DST0;
          end

          if (rd_ptr == in_len && !have_b) begin
            if (ps == PS_WAIT_SRC0 || ps == PS_WAIT_DST0) begin
              st <= ST_OFF;
              n_i <= {IDXW{1'b0}};
              sum_e <= 16'd0;
            end
          end
        end else if (rd_ptr == in_len && !have_b) begin
          if (ps == PS_WAIT_SRC0 || ps == PS_WAIT_DST0) begin
            st <= ST_OFF;
            n_i <= {IDXW{1'b0}};
            sum_e <= 16'd0;
          end
        end
      end

      ST_OFF: begin
        busy <= 1'b1;
        if (n_i < node_n) begin
          off[n_i] <= sum_e;
          sum_e <= sum_e + out_cnt[n_i];
          wptr[n_i] <= 12'd0;
          n_i <= n_i + {{(IDXW-1){1'b0}},1'b1};
        end else begin
          st <= ST_ADJ;
          e_i <= 16'd0;
        end
      end

      ST_ADJ: begin
        busy <= 1'b1;
        if (e_i < edge_n) begin
          adj[off[edge_src[e_i]] + wptr[edge_src[e_i]]] <= edge_dst[e_i];
          wptr[edge_src[e_i]] <= wptr[edge_src[e_i]] + 12'd1;
          e_i <= e_i + 16'd1;
        end else begin
          st <= ST_QINIT;
          n_i <= {IDXW{1'b0}};
          qh <= {IDXW{1'b0}};
          qt <= {IDXW{1'b0}};
          topo_len <= {IDXW{1'b0}};
        end
      end

      ST_QINIT: begin
        busy <= 1'b1;
        if (n_i < node_n) begin
          if (indeg[n_i] == 12'd0) begin
            q[qt] <= n_i;
            qt <= qt + {{(IDXW-1){1'b0}},1'b1};
          end
          n_i <= n_i + {{(IDXW-1){1'b0}},1'b1};
        end else begin
          st <= ST_TOPOP;
        end
      end

      ST_TOPOP: begin
        busy <= 1'b1;
        if (qh != qt) begin
          cur_v <= q[qh];
          topo[topo_len] <= q[qh];
          topo_len <= topo_len + {{(IDXW-1){1'b0}},1'b1};
          qh <= qh + {{(IDXW-1){1'b0}},1'b1};
          cur_k <= 12'd0;
          st <= ST_TOPE;
        end else begin
          if (topo_len != node_n) overflow <= 1'b1;
          st <= ST_DP1I;
          n_i <= {IDXW{1'b0}};
        end
      end

      ST_TOPE: begin
        busy <= 1'b1;
        if (cur_k < out_cnt[cur_v]) begin
          pu <= adj[off[cur_v] + cur_k];
          if (indeg[adj[off[cur_v] + cur_k]] == 12'd1) begin
            indeg[adj[off[cur_v] + cur_k]] <= 12'd0;
            q[qt] <= adj[off[cur_v] + cur_k];
            qt <= qt + {{(IDXW-1){1'b0}},1'b1};
          end else begin
            indeg[adj[off[cur_v] + cur_k]] <= indeg[adj[off[cur_v] + cur_k]] - 12'd1;
          end
          cur_k <= cur_k + 12'd1;
        end else begin
          st <= ST_TOPOP;
        end
      end

      ST_DP1I: begin
        busy <= 1'b1;
        if (n_i < node_n) begin
          w1[n_i] <= 64'd0;
          n_i <= n_i + {{(IDXW-1){1'b0}},1'b1};
        end else begin
          if (have_you) w1[idx_you] <= 64'd1;
          st <= ST_DP1;
          dp_i <= {IDXW{1'b0}};
          cur_k <= 12'd0;
          dp_phase <= 1'b0;
        end
      end

      ST_DP1: begin
        busy <= 1'b1;
        if (dp_i < topo_len) begin
          if (!dp_phase) begin
            if (cur_k < out_cnt[topo[dp_i]]) begin
              pu <= adj[off[topo[dp_i]] + cur_k];
              padd <= w1[topo[dp_i]];
              pbase <= w1[adj[off[topo[dp_i]] + cur_k]];
              dp_phase <= 1'b1;
              cur_k <= cur_k + 12'd1;
            end else begin
              dp_i <= dp_i + {{(IDXW-1){1'b0}},1'b1};
              cur_k <= 12'd0;
            end
          end else begin
            w1[pu] <= pbase + padd;
            dp_phase <= 1'b0;
          end
        end else begin
          st <= ST_DP2I;
          n_i <= {IDXW{1'b0}};
        end
      end

      ST_DP2I: begin
        busy <= 1'b1;
        if (n_i < node_n) begin
          w2_0[n_i] <= 64'd0;
          w2_1[n_i] <= 64'd0;
          w2_2[n_i] <= 64'd0;
          w2_3[n_i] <= 64'd0;
          n_i <= n_i + {{(IDXW-1){1'b0}},1'b1};
        end else begin
          if (have_svr) begin
            if (have_fft && (idx_svr == idx_fft) && have_dac && (idx_svr == idx_dac)) w2_3[idx_svr] <= 64'd1;
            else if (have_fft && (idx_svr == idx_fft)) w2_1[idx_svr] <= 64'd1;
            else if (have_dac && (idx_svr == idx_dac)) w2_2[idx_svr] <= 64'd1;
            else w2_0[idx_svr] <= 64'd1;
          end
          st <= ST_DP2;
          dp_i <= {IDXW{1'b0}};
          dp_m <= 2'd0;
          cur_k <= 12'd0;
          dp_phase <= 1'b0;
        end
      end

      ST_DP2: begin
        busy <= 1'b1;
        if (dp_i < topo_len) begin
          if (!dp_phase) begin
            if (cur_k < out_cnt[topo[dp_i]]) begin
              pu <= adj[off[topo[dp_i]] + cur_k];

              nm_val = dp_m;
              if (have_fft && (adj[off[topo[dp_i]] + cur_k] == idx_fft)) nm_val = nm_val | 2'd1;
              if (have_dac && (adj[off[topo[dp_i]] + cur_k] == idx_dac)) nm_val = nm_val | 2'd2;
              pnm <= nm_val;

              add_val = 64'd0;
              if (dp_m == 2'd0) add_val = w2_0[topo[dp_i]];
              else if (dp_m == 2'd1) add_val = w2_1[topo[dp_i]];
              else if (dp_m == 2'd2) add_val = w2_2[topo[dp_i]];
              else add_val = w2_3[topo[dp_i]];
              padd <= add_val;

              if (nm_val == 2'd0) pbase <= w2_0[adj[off[topo[dp_i]] + cur_k]];
              else if (nm_val == 2'd1) pbase <= w2_1[adj[off[topo[dp_i]] + cur_k]];
              else if (nm_val == 2'd2) pbase <= w2_2[adj[off[topo[dp_i]] + cur_k]];
              else pbase <= w2_3[adj[off[topo[dp_i]] + cur_k]];

              dp_phase <= 1'b1;
              cur_k <= cur_k + 12'd1;
            end else begin
              if (dp_m == 2'd3) begin
                dp_m <= 2'd0;
                dp_i <= dp_i + {{(IDXW-1){1'b0}},1'b1};
              end else begin
                dp_m <= dp_m + 2'd1;
              end
              cur_k <= 12'd0;
            end
          end else begin
            if (pnm == 2'd0) w2_0[pu] <= pbase + padd;
            else if (pnm == 2'd1) w2_1[pu] <= pbase + padd;
            else if (pnm == 2'd2) w2_2[pu] <= pbase + padd;
            else w2_3[pu] <= pbase + padd;
            dp_phase <= 1'b0;
          end
        end else begin
          st <= ST_DONE;
        end
      end

      ST_DONE: begin
        busy <= 1'b0;
        if (have_out) begin
          part1 <= w1[idx_out];
          part2 <= w2_3[idx_out];
        end else begin
          part1 <= 64'd0;
          part2 <= 64'd0;
        end
        out_valid <= 1'b1;
        st <= ST_DONE;
      end

      default: st <= ST_DONE;
    endcase
  end
end

endmodule
