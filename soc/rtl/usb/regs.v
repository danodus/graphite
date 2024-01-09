
// CPU register interface with PHY+SIE. Modelled after the registers of the
// ultra-embedded usb host example: https://github.com/ultraembedded/core_usb_host

`default_nettype none

module REGS (
  input          clk_i,
  input          rst_i,
  output [7:0]   led_o,

  // CPU memory interface
  input           m_sel,
  input   [3:0]   m_addr,
  input  [31:0]   m_data_i,
  output [31:0]   m_data_o,
  input           m_rd,
  input           m_wr,
  output          m_intr_o,
  
  // UTMI+ level 3 PHY interface
  input  [7:0]   utmi_data_in_i,
  input          utmi_rxvalid_i,
  input          utmi_rxactive_i,
  input          utmi_rxerror_i,

  output [7:0]   utmi_data_out_o,
  output         utmi_txvalid_o,
  input          utmi_txready_i,

  output [1:0]   utmi_op_mode_o,
  output [1:0]   utmi_xcvrselect_o,
  output         utmi_termselect_o,
  output         utmi_dppulldown_o,
  output         utmi_dmpulldown_o,
  input  [1:0]   utmi_linestate_i
  );

  wire reg_wr = m_wr & m_sel;
  wire reg_rd = m_rd & m_sel;

  wire irq_done, irq_sof, irq_err, irq_det;  

  //-----------------------------------------------------------------
  // CPU visible control registers
  //-----------------------------------------------------------------

  reg  [ 8:0] reg_ctrl;
  reg  [ 3:0] reg_irq;
  reg  [ 3:0] reg_irq_mask;
  reg  [15:0] reg_tx_len;
  reg  [31:0] reg_tx_token;
  wire [31:0] reg_sts;
  wire [31:0] reg_rx_stat;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      reg_ctrl     <=  9'h0;
      reg_irq      <=  4'h0;
      reg_irq_mask <=  4'h0;
      reg_tx_len   <= 16'h0;
      reg_tx_token <= 31'h0;
    end
    else begin
      if (reg_wr) begin
        case (m_addr)
        4'd0: reg_ctrl     <= m_data_i[8:0];
        4'd2: reg_irq      <= reg_irq & ~m_data_i[3:0];
        4'd4: reg_irq_mask <= m_data_i[3:0];
        4'd5: reg_tx_len   <= m_data_i[15:0];
        4'd6: reg_tx_token <= m_data_i;
        endcase
      end
      if (start_ack & ~send_sof) reg_tx_token[31] <= 1'b0;
      if (irq_sof)  reg_irq[0] <= 1'b1;
      if (irq_done) reg_irq[1] <= 1'b1;
      if (irq_err)  reg_irq[2] <= 1'b1;
      if (irq_det)  reg_irq[3] <= 1'b1;
    end
  end

  wire tx_flush = reg_wr & (m_addr==4'd0) & m_data_i[8];
  
  // adjust SIE status when new request is pending
  wire tx_sts30 = crc_err  & ~reg_tx_token[31];
  wire tx_sts29 = timeout  & ~reg_tx_token[31];
  wire tx_sts28 = sie_idle & ~reg_tx_token[31];
  
  assign reg_sts            = { sof_timer, 12'b0, detect, phy_err, utmi_linestate_i };  
  assign reg_rx_stat[31:24] = { start_req, tx_sts30, tx_sts29, tx_sts28, 4'b0 };
  
  // output multiplexer
  assign m_data_o = (m_addr==4'd0) ? { 23'h0, reg_ctrl }     :
                    (m_addr==4'd1) ? reg_sts                 :
                    (m_addr==4'd3) ? { 28'h0, reg_irq }      :
                    (m_addr==4'd4) ? { 28'h0, reg_irq_mask } :
                    (m_addr==4'd5) ? { 16'h0, reg_tx_len }   :
                    (m_addr==4'd6) ? reg_tx_token            :
                    (m_addr==4'd7) ? reg_rx_stat             :
                    (m_addr==4'd8) ? { 24'h0, rx_data_o }    : 31'h0;

  //-----------------------------------------------------------------
  // UTMI configuration & status lines
  //-----------------------------------------------------------------

  assign utmi_op_mode_o    = reg_ctrl[2:1];
  assign utmi_xcvrselect_o = reg_ctrl[4:3];
  assign utmi_termselect_o = reg_ctrl[5];
  assign utmi_dppulldown_o = reg_ctrl[6];
  assign utmi_dmpulldown_o = reg_ctrl[7];
  
  //-----------------------------------------------------------------
  // SIE + FIFO's
  //-----------------------------------------------------------------

  wire [3:0] dump;
  assign led_o[7:4] = reg_rx_stat[31:28];
  
  wire [7:0] sie_tx_data, sie_rx_data, rx_data;
  wire       sie_tx_pop,  sie_rx_push;
  wire       tx_done, rx_done, sie_idle, crc_err, timeout;
  
  localparam PID_SOF = 8'hA5;
  
  wire [7:0] token_pid = send_sof ? PID_SOF         : reg_tx_token[23:16];
  wire [6:0] token_dev = send_sof ? sof_frame[6:0]  : reg_tx_token[15: 9];
  wire [3:0] token_ep  = send_sof ? sof_frame[10:7] : reg_tx_token[ 8: 5];
  
  SIE u_sie (
    // Clock & reset
    .clk_i(clk_i),
    .rst_i(rst_i),
    .led_o({dump, led_o[3:0]}),

    // Control
    .start_i         (start_req),
    .in_transfer_i   (in_transfer),
    .sof_transfer_i  (send_sof),
    .resp_expected_i (resp_expected),    
    .ack_o           (start_ack),

    // Token + data packet    
    .token_pid_i (token_pid),
    .token_dev_i (token_dev),
    .token_ep_i  (token_ep),
    .data_len_i  (reg_tx_len),
    .data_idx_i  (reg_tx_token[28]),

    // Tx+Rx Data FIFO's
    .tx_data_i   (sie_tx_data),
    .tx_pop_o    (sie_tx_pop),
    .rx_data_o   (sie_rx_data),
    .rx_push_o   (sie_rx_push),

    // Status
    .rx_done_o   (rx_done),
    .tx_done_o   (tx_done),
    .crc_err_o   (crc_err),
    .timeout_o   (timeout),
    .response_o  (reg_rx_stat[23:16]),
    .rx_count_o  (reg_rx_stat[15: 0]),
    .idle_o      (sie_idle),

    // UTMI Interface
    .utmi_xcvrselect_i (utmi_xcvrselect_o),
    .utmi_data_o       (utmi_data_out_o),
    .utmi_txvalid_o    (utmi_txvalid_o),
    .utmi_txready_i    (utmi_txready_i),
    .utmi_data_i       (utmi_data_in_i),
    .utmi_rxvalid_i    (utmi_rxvalid_i),
    .utmi_rxactive_i   (utmi_rxactive_i),
    .utmi_rxerror_i    (utmi_rxerror_i)
  );

  FIFO fifo_tx(
    .clk_i   (clk_i),
    .rst_i   (rst_i),
    .flush_i (tx_flush),

    .data_i  (m_data_i[7:0]),
    .push_i  ((m_addr==4'h8) && reg_wr),

    .data_o  (sie_tx_data),
    .pop_i   (sie_tx_pop)
  );

  FIFO fifo_rx (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .flush_i(rx_flush),

    .data_i (sie_rx_data),
    .push_i (sie_rx_push),

    .data_o (rx_data),
    .pop_i  ((m_addr==4'h8) && reg_rd)
  );

  wire [7:0] rx_data_o = rx_data;
  
  //-----------------------------------------------------------------
  // SOF timer, frame counter
  //-----------------------------------------------------------------

  localparam SOF_GUARD_LOW   =    16'd160; // wait past SOF complete
  localparam SOF_GUARD_HIGH  = 16'd41_000; // 1 ms - one max size transaction - some slack
  localparam SOF_THRESHOLD   = 16'd47_999; // 1 ms - 1 clock

  wire sof_enable   = reg_ctrl[0];
  wire tx_sof       = (sof_timer == SOF_THRESHOLD) & sof_enable & sie_idle;
  wire in_guardband = (sof_timer <= SOF_GUARD_LOW || sof_timer >= SOF_GUARD_HIGH);
  
  reg [15:0] sof_timer; // counts out milliseconds
  reg [10:0] sof_frame; // counts frames
  reg        sof_irq;
  
  always @(posedge clk_i or posedge rst_i) begin
    sof_irq <= 1'b0;
    if (rst_i) begin
      sof_frame <= 11'd0;
      sof_timer <= 16'd0;
      end
    // start new SOF packet every millisecond
    else if (tx_sof) begin
      sof_timer <= 15'd0;
      sof_frame <= sof_frame + 11'd1;
      sof_irq   <= 1'b1;
      end
    else
      if (sof_timer != SOF_THRESHOLD) sof_timer <= sof_timer + 16'd1;
    
  end

  //-----------------------------------------------------------------
  // SIE transaction controller
  //-----------------------------------------------------------------

  reg  rx_flush, start_req, send_sof, in_transfer, resp_expected;
  wire can_send = ~(in_guardband & sof_enable) & sie_idle;
  wire start_ack;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      rx_flush      <= 1'b0;
      in_transfer   <= 1'b0;
      resp_expected <= 1'b0;
      send_sof      <= 1'b0;
      start_req     <= 1'b0;
      end
    else begin

      // Wait for pending request to start...
      if (start_req) begin
        if (start_ack) start_req <= 1'b0;
        rx_flush <= 1'b0;
        end

      // Time to send another SOF token?
      else if (tx_sof) begin
        in_transfer   <= 1'b0;
        resp_expected <= 1'b0;
        send_sof      <= 1'b1;
        start_req     <= 1'b1;
        end

      // Start new host transaction ?
      else if (can_send & reg_tx_token[31]) begin              
        rx_flush      <= 1'b1; // flush unread data
        in_transfer   <= reg_tx_token[30];
        resp_expected <= reg_tx_token[29];
        send_sof      <= 1'b0;
        start_req     <= 1'b1;
        end

    end
  end

  //-----------------------------------------------------------------
  // Interrupts & errors
  //-----------------------------------------------------------------

`ifdef __ICARUS__
`define SPEED   8
`else
`define SPEED   22
`endif

  reg [`SPEED:0] dt_ctr;
  wire           dt_up   = (dt_ctr[`SPEED:`SPEED-1] == 2'b11);
  wire           dt_down = (dt_ctr[`SPEED:`SPEED-1] == 2'b00);

  reg phy_err, sie_err, detect;
  
  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        phy_err <= 1'b0;
        sie_err <= 1'b0;
        detect  <= 1'b0;
        dt_ctr  <= 'd0;
        end
    else begin
      // latch PHY error until reset (any write to ctrl reg)
      if (reg_wr && m_addr==4'h0)
        phy_err <= 1'b0;
      else if (utmi_rxerror_i)
        phy_err <= 1'b1;
      
      // latch SIE error until int acknowledged
      if (crc_err | timeout)
        sie_err <= 1'b1;
      else if (reg_wr && m_addr==4'h2 && m_data_i[2])
        sie_err <= 1'b0;
        
      // detect connect / detach
      if (utmi_linestate_i != 2'b0 && !(&dt_ctr))
        dt_ctr <= dt_ctr + 1;
      else if (utmi_linestate_i == 2'b0 && |dt_ctr)
        dt_ctr <= dt_ctr - 1;
      if (dt_up)
        detect <= 1'b1;
      else if (dt_down)
        detect <= 1'b0;
    end
  end

  assign irq_done = (rx_done | tx_done);
  assign irq_sof  = sof_irq;
  assign irq_err  = (crc_err | timeout) && (!sie_err);
  assign irq_det  = (dt_up & ~detect) | (dt_down & detect);

  assign m_intr_o = |(reg_irq & reg_irq_mask);

endmodule

module FIFO (
  input  wire       clk_i,
  input  wire       rst_i,
  input  wire       flush_i,
  
  input  wire [7:0] data_i,
  input  wire       push_i,
  output reg  [7:0] data_o,
  input  wire       pop_i
  );

  reg [7:0] ram [0:63];
  reg [5:0] rd_ptr,wr_ptr;
  reg [6:0] count;
  
  wire full_o  = (count == 7'd64);
  wire empty_o = (count == 7'd0);
  wire inc = ((push_i & ~full_o) & ~(pop_i & ~empty_o));
  wire dec = (~(push_i & ~full_o) & (pop_i & ~empty_o));

  always @(posedge clk_i) begin
    if (rst_i|flush_i) begin
      count   <= 7'd0;
      rd_ptr  <= 6'd0;
      wr_ptr  <= 6'd0;
      end
    else begin

      if (push_i & ~full_o) begin
        ram[wr_ptr] <= data_i;
        wr_ptr      <= wr_ptr + 1;
        end

      if (pop_i & ~empty_o) begin
        data_o <= ram[rd_ptr];
        rd_ptr <= rd_ptr + 1;
        end

      count <= inc ? count + 7'd1 :
               dec ? count - 7'd1 :
                     count;
    end
  end

endmodule
