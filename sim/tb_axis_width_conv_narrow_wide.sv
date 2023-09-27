`timescale 1ns/100ps
`default_nettype none
`include "vunit_defines.svh"
module tb_axis_width_conv_narrow_wide;

  parameter N = 4;
  parameter M = 8;
  parameter LCM = M;
  parameter NREQUESTS = 1024;

  logic      rst;
  logic      clk;
  logic         s_axis_tnext;
  logic [N-1:0] s_axis_tdata;
  logic         s_axis_tfirst;
  logic         s_axis_tvalid;
  logic         m_axis_tnext;
  logic [M-1:0] m_axis_tdata;
  logic         m_axis_tfirst;
  logic         m_axis_tvalid;
  logic [15:0]  bit_count;

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
    .m_axis_tvalid (m_axis_tvalid),

    .bit_count     (bit_count));

  wire fifo_full;
  wire fifo_empty;
  wire fifo_wr_rst_busy;
  wire fifo_rd_rst_busy;
  wire [N:0] fifo_data_out;

  reg        fifo_write = 1'b0;
  reg [N:0]  fifo_data_in = {(N+1){1'b0}};
  wire       fifo_read;

  localparam W_CNT = $clog2(2*NREQUESTS) + 1;

  logic [W_CNT-1:0] fifo_rd_data_count;
  logic [W_CNT-1:0] fifo_wr_data_count;

  xpm_fifo_async #(
    // Parameters
    .FIFO_MEMORY_TYPE                 ("block"),
    .ECC_MODE                         ("no_ecc"),
    .RELATED_CLOCKS                   (0),
    .SIM_ASSERT_CHK                   (0),
    .CASCADE_HEIGHT                   (0),
    .FIFO_WRITE_DEPTH                 (2*NREQUESTS),
    .WRITE_DATA_WIDTH                 (N+1),
    .WR_DATA_COUNT_WIDTH              (W_CNT),
    .PROG_FULL_THRESH                 (10),
    .FULL_RESET_VALUE                 (0),
    .USE_ADV_FEATURES                 ("0404"),
    .READ_MODE                        ("fwft"),
    .FIFO_READ_LATENCY                (0),
    .READ_DATA_WIDTH                  (N+1),
    .RD_DATA_COUNT_WIDTH              (W_CNT),
    .PROG_EMPTY_THRESH                (10),
    .DOUT_RESET_VALUE                 ("0"),
    .CDC_SYNC_STAGES                  (2),
    .WAKEUP_TIME                      (0)
  ) fifo0 (
    // Outputs
    .full                        (fifo_full),
    .prog_full                   (),
    .wr_data_count               (fifo_wr_data_count),
    .overflow                    (),
    .wr_rst_busy                 (fifo_wr_rst_busy),
    .almost_full                 (),
    .wr_ack                      (),
    .dout                        (fifo_data_out[N:0]),
    .empty                       (fifo_empty),
    .prog_empty                  (),
    .rd_data_count               (fifo_rd_data_count),
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

  task generate_clock;
    begin
      clk = 1'b0;
      forever #(5ns) clk = ~clk;
    end
  endtask : generate_clock

  task generate_reset;
    begin
      automatic int reset_state = 0;
      rst = 1'b0;
      for (;;) begin
        @(posedge clk);
        if (reset_state < 10) begin
          reset_state = reset_state + 1;
        end else begin
          rst = 1'b1;
          break;
        end
      end
    end
  endtask : generate_reset

  typedef struct {
    bit first;
    bit [N-1:0] data;
  } request_t;

  request_t requests[$];

  task make_requests (
    input bit verbose = 0,
    input int max_disp = 10,
    input bit dont_randomize_tfirst = 0);
    begin
      automatic int ndisp = 0;
      for (int i = 0; i < NREQUESTS; i = i + 1) begin
        automatic request_t r;
        r.data      = $urandom();
        randcase
          1: r.first = 1'b1;
          10: r.first = 1'b0;
        endcase // randcase
        if (i == 0) r.first = 1'b1;
        if (dont_randomize_tfirst)
          r.first = 1'b0;
        requests = {requests, r};
        if (verbose) begin
          if (ndisp < max_disp) begin
            $display("%3d :: %s %h", i, (r.first === 1'b1) ? "t" : " ", r.data);
            ndisp = ndisp + 1;
          end
        end
      end // for (int i = 0; i < NREQUESTS; i = i + 1)
    end
  endtask : make_requests

  typedef struct {
    bit first;
    bit [M-1:0] data;
  } reply_t;

  reply_t replies[$];

  task make_replies (
    input bit verbose = 0,
    input int max_disp = 10);
    begin
      automatic bit [LCM-1:0] rhold;
      automatic bit tfirst = 0;
      automatic int idx    = 0;
      static int ndisp = 0;
      for (int i = 0; i < $size(requests);) begin
        if (idx == 0) begin
          tfirst = requests[i].first;
        end
        rhold[((LCM-1)-idx*N)-:N] = requests[i].data;
        if ((idx == 0) || (requests[i].first == 1'b0)) begin
          i = i + 1;
        end
        idx = idx + 1;
        if (idx == LCM/N) begin
          for (int j = 0; j < LCM; j = j + M) begin
            if (verbose) begin
              if (ndisp < max_disp) begin
                $display("%3d :: %s %1h [%3b]",
                         ndisp,
                         ((j == 0) ? tfirst : 0) ? "t" : " ",
                         rhold[(LCM-1-j)-:M],
                         rhold[(LCM-1-j)-:M]);
                ndisp = ndisp + 1;
              end
            end
            replies = {replies,
                       reply_t'({
                       first : ((j == 0) ? tfirst : 0),
                       data : rhold[(LCM-1-j)-:M]})};
          end
          idx = 0;
        end
      end
    end
  endtask : make_replies

  task init_fifo;
    begin
      automatic int fifo_init_state = 0;
      for(int i = 0; i < $size(requests);) begin
        @(posedge clk);
        if (!((rst === 1'b0) || (fifo_wr_rst_busy === 1'b1))) begin
          fifo_data_in = {
                          requests[i].first,
                          requests[i].data
                          };
          fifo_write = 1'b1;
          i = i + 1;
        end
      end // for (int i = 0; i < NREQUESTS;)
      @(posedge clk);
      requests = {};
      fifo_write = 1'b0;
    end
  endtask : init_fifo

  task check_data (input bit verbose = 0);
    begin
      automatic int check_running = 0;
      automatic int stuck_timer = 0;
      for (int i = 0; i < $size(replies);) begin
        @(posedge clk);
        if (m_axis_tvalid) begin
          automatic bit ok = (replies[i].first == m_axis_tfirst) && (replies[i].data == m_axis_tdata);
          `CHECK_EQUAL(replies[i].first, m_axis_tfirst);
          `CHECK_EQUAL(replies[i].data,  m_axis_tdata);
          check_running = 1;
          stuck_timer = 0;
          if (verbose) begin
            $display("%5d :: %s %h -> %s", i, m_axis_tfirst ? "t" : " ", m_axis_tdata, ok ? "[PASS]" : "[FAIL]");
          end
          i = i + 1;
        end else begin // if (m_axis_tvalid)
          if (check_running)
            stuck_timer = stuck_timer + 1;
        end // else: !if(m_axis_tvalid)
        if (check_running && (stuck_timer > 1000)) begin
          $display("Got stuck...");
          break;
        end
      end // for (int i = 0; i < $size(replies);)
      replies       = {};
    end
  endtask : check_data

  assign s_axis_tdata = fifo_data_out[N-1:0];
  assign s_axis_tfirst = fifo_data_out[N];
  assign s_axis_tvalid = ~fifo_empty;
  assign fifo_read = s_axis_tnext;
  assign m_axis_tnext = m_axis_tvalid;

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
    end
    `TEST_CASE("Test") begin
      fork : x_run_test
        generate_clock();
        generate_reset();
        begin
          make_requests();
          make_replies();
          $display("Number of replies = %d", $size(replies));
          init_fifo();
        end
        begin
          check_data();
          disable x_run_test;
        end
      join
    end
    `TEST_CASE("SizeCheck") begin
      force m_axis_tnext = 1'b0;
      fork : x_size_check_test
        generate_clock();
        generate_reset();
        begin
          make_requests(.dont_randomize_tfirst(1));
          make_replies();
          init_fifo();
          repeat(10) @(posedge clk);
          `CHECK_EQUAL(NREQUESTS*N, fifo_rd_data_count*N + bit_count);
          disable x_size_check_test;
        end
      join
    end
  end

endmodule : tb_axis_width_conv_narrow_wide
`default_nettype wire
