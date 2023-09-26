`default_nettype none
module axis_width_conv_wide_narrow
#(
  parameter N   = 8,
  parameter M   = 4
) (
  input wire          rst,
  input wire          clk,

  output wire         s_axis_tnext,
  input  wire [N-1:0] s_axis_tdata,
  input  wire         s_axis_tfirst,
  input  wire         s_axis_tvalid,

  input  wire         m_axis_tnext,
  output wire [M-1:0] m_axis_tdata,
  output wire         m_axis_tfirst,
  output wire         m_axis_tvalid,

  output wire [15:0]  bit_count
);

  localparam LCM     = N;
  localparam KM      = LCM/M;
  localparam W_SHREG = 2 * LCM;
  localparam W_KM    = $clog2(KM);
  localparam W_S     = $clog2(W_SHREG);
  localparam KM2     = 2**W_KM;

  initial begin : x_checks
    if (KM*M != LCM) begin
      $error("LCM is not divisible by N");
      $finish;
    end
    if (KM == 1) begin
      $error("Degenerate case, LCM = M");
      $finish;
    end
  end

  logic [W_S-1:0] rlut [0:(2*KM2-1)];
  initial begin : x_init_rlut
    for (int i = 0; i < 2*KM2; i = i + 1) begin
      automatic logic page = i[W_KM];
      if (i[W_KM-1:0] >= KM) begin
        rlut[i] = (1+page)*LCM - 1;
      end else begin
        rlut[i] = (0+page)*LCM + (i[W_KM-1:0]+1) * M - 1;
      end
    end
  end

  typedef struct packed {
    logic              wr_ext;
    logic              rd_ext;
    logic              wr_page;
    logic              rd_page;
    logic [W_KM-1:0]   rd_ptr;
    logic [2*LCM-1:0]  rshift;
    logic [1:0]        rfirst;
    logic              tfirst;
    logic [N-1:0]      tdata;
    logic              tnext;
  } register_t;

  localparam register_t RES_register = '{
    wr_ext : 1'b1,
    rd_ext : 1'b1,
    wr_page : 1'b1,
    rd_page : 1'b1,
    rd_ptr  : KM-1,
    rshift : {(2*LCM){1'b0}},
    rfirst : 2'b00,
    tfirst : 1'b0,
    tdata : {N{1'b0}},
    tnext : 1'b0
  };

  register_t r;
  register_t rin;

  logic [W_S-1:0] s_rd_ptr;
  assign s_rd_ptr = rlut[{r.rd_page, r.rd_ptr}];

  logic           s_full;
  assign s_full   = (r.wr_ext != r.rd_ext) && (r.wr_page == r.rd_page);

  logic           s_empty;
  assign s_empty  = (r.wr_ext == r.rd_ext) && (r.wr_page == r.rd_page);

  always_comb begin : x_comb
    automatic register_t v;
    v = r;

    v.tnext  = (s_axis_tvalid && !s_full);
    v.tdata  = s_axis_tdata;
    v.tfirst = s_axis_tfirst;

    if (v.tnext) begin
      if (r.wr_page == 1'b1) begin
        v.rshift[(2*LCM-1)-:N] = v.tdata;
      end else begin
        v.rshift[(LCM-1)-:N] = v.tdata;
      end
      v.rfirst[r.wr_page] = v.tfirst;

      v.wr_page = ~r.wr_page;
      if (r.wr_page == 1'b0) begin
        v.wr_ext = ~r.wr_ext;
      end
    end

    if (m_axis_tnext && !s_empty) begin
      if (r.rd_ptr == 0) begin
        v.rd_ptr = KM-1;
        v.rd_page = ~r.rd_page;
        if (r.rd_page == 1'b0) begin
          v.rd_ext = ~r.rd_ext;
        end
      end else begin
        v.rd_ptr = r.rd_ptr - 1;
      end
    end

    if (~rst) begin
      v = RES_register;
    end
    rin = v;
  end : x_comb

  always_ff @(posedge clk) begin : x_seq
    r <= rin;
  end

  assign s_axis_tnext = s_axis_tvalid &&
                        !s_full;

  assign m_axis_tdata  = r.rshift[s_rd_ptr-:M];
  assign m_axis_tfirst = (r.rd_ptr == KM-1) ? r.rfirst[r.rd_page] : 1'b0;
  assign m_axis_tvalid = ~s_empty;

endmodule : axis_width_conv_wide_narrow
`default_nettype wire
