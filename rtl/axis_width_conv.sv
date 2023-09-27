`default_nettype none
module axis_width_conv
#(
  parameter N = 8,
  parameter M = 3
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
  function automatic int gcd (input int a, input int b);
    if (b == 0) return a; else return gcd(b, a % b);
  endfunction : gcd

  function automatic int lcm (input int a, input int b);
    return (a / gcd(a, b)) * b;
  endfunction : lcm

  localparam LCM = lcm(N, M);
  localparam bit KN = (LCM == N);
  localparam bit KM = (LCM == M);

  case ({KN, KM})
    2'b11: begin : x_direct
      assign s_axis_tnext = m_axis_tnext;
      assign m_axis_tdata = s_axis_tdata;
      assign m_axis_tfirst = s_axis_tfirst;
      assign m_axis_tvalid = s_axis_tvalid;
      assign bit_count = 'h0;
    end
    2'b01: begin : x_narrow_wide
      axis_width_conv_narrow_wide #(
        .N(N),
        .M(M))
      u0 (
        .rst           (rst),
        .clk           (clk),
        .s_axis_tnext  (s_axis_tnext),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tfirst (s_axis_tfirst),
        .s_axis_tvalid (s_axis_tvalid),

        .m_axis_tnext  (m_axis_tnext),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tfirst (m_axis_tfirst),
        .m_axis_tvalid (m_axis_tvalid),

        .bit_count     (bit_count));
    end
    2'b10: begin : x_wide_narrow
      axis_width_conv_wide_narrow #(
        .N(N),
        .M(M))
      u0 (
        .rst           (rst),
        .clk           (clk),
        .s_axis_tnext  (s_axis_tnext),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tfirst (s_axis_tfirst),
        .s_axis_tvalid (s_axis_tvalid),

        .m_axis_tnext  (m_axis_tnext),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tfirst (m_axis_tfirst),
        .m_axis_tvalid (m_axis_tvalid),

        .bit_count     (bit_count));
    end
    2'b00: begin : x_generic
      axis_width_conv_generic #(
        .N(N),
        .M(M),
        .LCM(LCM))
      u0 (
        .rst           (rst),
        .clk           (clk),
        .s_axis_tnext  (s_axis_tnext),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tfirst (s_axis_tfirst),
        .s_axis_tvalid (s_axis_tvalid),

        .m_axis_tnext  (m_axis_tnext),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tfirst (m_axis_tfirst),
        .m_axis_tvalid (m_axis_tvalid),

        .bit_count     (bit_count));
    end
  endcase

endmodule : axis_width_conv
`default_nettype wire
