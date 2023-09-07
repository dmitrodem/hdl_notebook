`include "vunit_defines.svh"

`timescale 1ns/100ps
`default_nettype none
module tb_axis_width_conv_narrow_wide;

  localparam N               = 8;
  localparam M               = 24;

  int        testcase        = -1;
  int        testcase_done   = 0;
  int        testcase_result = 0;

  logic      rst             = 1'b0;
  logic      clk             = 1'b0;
  logic         s_axis_tnext;
  logic [N-1:0] s_axis_tdata;
  logic         s_axis_tfirst;
  logic         s_axis_tvalid;
  logic         m_axis_tnext;
  logic [M-1:0] m_axis_tdata;
  logic         m_axis_tfirst;
  logic         m_axis_tvalid;

  axis_width_conv_narrow_wide #(
    .N(N),
    .M(M))
  dut0 (
    .rst           (rst),
    .clk           (clk),
    .s_axis_tnext  (s_axis_tnext),
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tfirst (s_axis_tfirst),
    .s_axis_tvalid (s_axis_tvalid),

    .m_axis_tnext  (m_axis_tnext),
    .m_axis_tdata  (m_axis_tdata),
    .m_axis_tfirst (m_axis_tfirst),
    .m_axis_tvalid (m_axis_tvalid));

  wire fifo_full;
  wire fifo_empty;
  wire fifo_wr_rst_busy;
  wire fifo_rd_rst_busy;
  wire [N:0] fifo_data_out;

  reg        fifo_write = 1'b0;
  reg [N:0]  fifo_data_in = {(N+1){1'b0}};
  wire       fifo_read;


  xpm_fifo_async #(
    // Parameters
    .FIFO_MEMORY_TYPE                 ("block"),
    .ECC_MODE                         ("no_ecc"),
    .RELATED_CLOCKS                   (0),
    .SIM_ASSERT_CHK                   (0),
    .CASCADE_HEIGHT                   (0),
    .FIFO_WRITE_DEPTH                 (2048),
    .WRITE_DATA_WIDTH                 (N+1),
    .WR_DATA_COUNT_WIDTH              (1),
    .PROG_FULL_THRESH                 (10),
    .FULL_RESET_VALUE                 (0),
    .USE_ADV_FEATURES                 ("0404"),
    .READ_MODE                        ("fwft"),
    .FIFO_READ_LATENCY                (0),
    .READ_DATA_WIDTH                  (N+1),
    .RD_DATA_COUNT_WIDTH              (1),
    .PROG_EMPTY_THRESH                (10),
    .DOUT_RESET_VALUE                 ("0"),
    .CDC_SYNC_STAGES                  (2),
    .WAKEUP_TIME                      (0)
  ) fifo0 (
    // Outputs
    .full                        (fifo_full),
    .prog_full                   (),
    .wr_data_count               (),
    .overflow                    (),
    .wr_rst_busy                 (fifo_wr_rst_busy),
    .almost_full                 (),
    .wr_ack                      (),
    .dout                        (fifo_data_out[N:0]),
    .empty                       (fifo_empty),
    .prog_empty                  (),
    .rd_data_count               (),
    .underflow                   (),
    .rd_rst_busy                 (fifo_rd_rst_busy),
    .almost_empty                (),
    .data_valid                  (),
    .sbiterr                     (),
    .dbiterr                     (),
    // Inputs
    .sleep                       (1'b0),
    .rst                         (~rst),
    .wr_clk                      (clk),
    .wr_en                       (fifo_write),
    .din                         (fifo_data_in[N:0]),
    .rd_clk                      (clk),
    .rd_en                       (fifo_read),
    .injectsbiterr               (1'b0),
    .injectdbiterr               (1'b0));

  always #(5ns) clk = ~clk;

  int reset_state = 0;
  always_ff @(posedge clk) begin : x_reset
    if (reset_state < 10) begin
      reset_state = reset_state + 1;
    end else begin
      rst = 1'b1;
    end
  end : x_reset


  int fifo_state         = 0;
  logic [N:0] fifo_data [0:2047];
  logic [31:0] fifo_tmp;

  typedef struct  {
    logic         first;
    logic [M-1:0] data;
  } result_t;
  result_t results[];

  initial begin : x_init_fifo_data
    automatic int state           = 0;
    automatic bit tfirst          = 1'b0;
    automatic logic [M-1:0] shreg = {M{1'b0}};
    automatic bit frame_error     = 1'b0;
    automatic bit first           = 1'b1;

    results = new [1];

    for (int i = 0; i < $size(fifo_data); i = i + 1) begin
      fifo_tmp     = $urandom();
      fifo_data[i] = {{1{
                      (i == 0) ||
                      (i == 4) ||
                      (i == 5)
                      }}, fifo_tmp[N-1:0]};
      $display("%3d :: %s %h", i, (fifo_data[i][N] === 1'b1) ? "t" : " ", fifo_data[i][N-1:0]);
    end

    for (int i = 0; i < $size(fifo_data);) begin
      if (state == 0) begin
        frame_error = 1'b0;
        tfirst = fifo_data[i][N];
      end else if (fifo_data[i][N] == 1'b1) begin
        frame_error = 1'b1;
      end

      shreg = {shreg[(M-N-1):0], fifo_data[i][N-1:0]};

      if (!frame_error) begin
        i = i + 1;
      end
      state = (state + 1) % (M/N);

      if (state == 0) begin
        if (first) begin
          first = 1'b0;
        end else begin
          results = new [results.size() + 1] (results);
        end
        results[results.size()-1] = '{
                                    first : tfirst,
                                    data : shreg
                                    };
      end
    end // for (int i = 0; i < $size(fifo_data);)
    foreach (results[i]) begin
      $display("SHR = %s %h", results[i].first ? "t" : " ", results[i].data);
    end
  end


  int fifo_init_state = 0;
  always_ff @(posedge clk) begin : x_init_fifo
    if (!((rst === 1'b0) || (fifo_wr_rst_busy === 1'b1))) begin
      if (fifo_init_state < $size(fifo_data)) begin
        fifo_data_in    <= fifo_data[fifo_init_state];
        fifo_write      <= 1'b1;
        fifo_init_state <= fifo_init_state + 1;
      end else begin
        fifo_write <= 1'b0;
      end
    end
  end  : x_init_fifo

  assign s_axis_tdata = fifo_data_out[N-1:0];
  assign s_axis_tfirst = fifo_data_out[N];
  assign s_axis_tvalid = ~fifo_empty;
  assign fifo_read = s_axis_tnext;

  int read_out_state = 0;
  always_ff @(posedge clk) begin : x_read_out
    if (m_axis_tvalid) begin
      automatic int i  = read_out_state;
      automatic bit ok = (results[i].first == m_axis_tfirst) && (results[i].data == m_axis_tdata);
      `CHECK_EQUAL(results[i].first, m_axis_tfirst);
      `CHECK_EQUAL(results[i].data,  m_axis_tdata);
      $display("Read : %d %h -> %s", m_axis_tfirst, m_axis_tdata, ok ? "[PASS]" : "[FAIL]");
      read_out_state   = read_out_state + 1;
      if (read_out_state == $size(results)) begin
        results.delete();
        testcase_done = 1;
      end
    end
  end  : x_read_out

  assign m_axis_tnext = m_axis_tvalid;

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin

    end // UNMATCHED !!

    `TEST_CASE("Test") begin
      testcase = 0;
      wait (testcase_done == 1);
    end // UNMATCHED !!

  end // UNMATCHED !!


endmodule : tb_axis_width_conv_narrow_wide
`default_nettype wire
