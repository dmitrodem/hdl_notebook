`default_nettype none
module axis_width_conv_narrow_wide
#(
  parameter N = 8,
  parameter M = 24
) (
  input wire          rst,
  input wire          clk,

  output wire         s_axis_tnext,
  input wire [N-1:0]  s_axis_tdata,
  input wire          s_axis_tfirst,
  input wire          s_axis_tvalid,

  input wire          m_axis_tnext,
  output wire [M-1:0] m_axis_tdata,
  output wire         m_axis_tfirst,
  output wire         m_axis_tvalid,

  output wire [15:0]  bit_count
);

  localparam KN      = M/N;
  localparam W_SHREG = 2 * M;
  localparam W_KN    = $clog2(KN);
  localparam W_S     = $clog2(W_SHREG);


  initial begin : x_checks
    if (KN*N != M) begin
      $error("M is not divisible by N");
      $finish;
    end
  end

  logic [2**(W_KN+1)-1:0] [W_S-1:0] lut;

  int                               index;
  int                               value;

  initial begin : x_init_lut
    for (int i = 0; i <= {W_KN{1'b1}}; i = i + 1) begin
      index = {1'b0, i[W_KN-1:0]};
      if (i >= KN) begin
        value = 1*M - 1;
      end else begin
        value = 0*M + (i+1) * N - 1;
      end
      lut[index] = value;
    end
    for (int i = 0; i <= {W_KN{1'b1}}; i = i + 1) begin
      index = {1'b1, i[W_KN-1:0]};
      if (i >= KN) begin
        value = 2*M - 1;
      end else begin
        value = 1*M + (i+1) * N - 1;
      end
      lut[index] = value;
    end
  end : x_init_lut


  typedef struct packed {
    logic wr_ext;
    logic rd_ext;
    logic wr_page;
    logic rd_page;
    logic [W_KN-1:0] wr_ptr;
    logic [2*M-1:0]  rshift;
    logic [1:0]      rfirst;
    logic            frame_error;
    logic            tfirst;
    logic [N-1:0]    tdata;
    logic            tnext;
  } register_t;

  localparam register_t RES_register = '{
    wr_ext : 1'b1,
    rd_ext : 1'b1,
    wr_page : 1'b1,
    rd_page : 1'b1,
    wr_ptr  : KN-1,
    rshift : {(2*M){1'b0}},
    rfirst : 2'b00,
    frame_error : 1'b0,
    tfirst : 1'b0,
    tdata : {N{1'b0}},
    tnext : 1'b0
  };

  register_t r;
  register_t rin;

  logic [W_S-1:0] s_wr_ptr;
  assign s_wr_ptr = lut[{r.wr_page, r.wr_ptr}];

  logic           s_full;
  assign s_full   = (r.wr_ext != r.rd_ext) && (r.wr_page == r.rd_page);

  logic           s_empty;
  assign s_empty  = (r.wr_ext == r.rd_ext) && (r.wr_page == r.rd_page);

  logic s_frame_error;

  always_comb begin : x_comb
    automatic register_t v;
    v  = r;

    v.tnext  = (s_axis_tvalid && !s_full);
    v.tdata  = s_axis_tdata;
    v.tfirst = s_axis_tfirst;

    if (v.tnext) begin
      v.rshift[s_wr_ptr-:N] = v.tdata;
      if (r.wr_ptr == KN-1) begin
        v.frame_error = 1'b0;
        v.rfirst[r.wr_page] = v.tfirst;
      end else if (v.tfirst) begin
        v.frame_error = 1'b1;
      end

      if (r.wr_ptr == 0) begin
        v.wr_ptr = KN-1;
        v.wr_page = ~r.wr_page;
        if (r.wr_page == 1'b0) begin
          v.wr_ext = ~r.wr_ext;
        end
      end else begin
        v.wr_ptr = r.wr_ptr - 1;
      end
    end // if (s_axis_tvalid && !s_full)

    if (m_axis_tnext && !s_empty) begin
      v.rd_page = ~r.rd_page;
      if (r.rd_page == 0) begin
        v.rd_ext = ~r.rd_ext;
      end
    end

    if (~rst) begin
      v = RES_register;
    end
    rin = v;
    s_frame_error = v.frame_error;
  end : x_comb

  always_ff @(posedge clk) begin : x_seq
    r <= rin;
  end

  assign s_axis_tnext = s_axis_tvalid &&
                        !s_full &&
                        !s_frame_error;

  assign m_axis_tdata  = r.rd_page ? r.rshift[2*M-1:M] : r.rshift[M-1:0];
  assign m_axis_tfirst = r.rd_page ? r.rfirst[1]       : r.rfirst[0];
  assign m_axis_tvalid = ~s_empty;

endmodule : axis_width_conv_narrow_wide

`default_nettype wire
