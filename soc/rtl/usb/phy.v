
// Basic USB1.1 level 3 UTMI interface for ULX3S board. Supports low speed
// and full speed only. Supports LS signalling through a hub. Will work with
// a USB2.0 hub, but only for LS/FS devices (i.e. not HS devices).
//

`default_nettype none

module PHY (
      input           clk_i,
      input           rst_i,

      // UTMI TX interface
      input  [  7:0]  utmi_data_out_i,
      input           utmi_txvalid_i,
      output          utmi_txready_o,
      
      // UTMI RX interface
      output [  7:0]  utmi_data_in_o,
      output          utmi_rxvalid_o,
      output          utmi_rxactive_o,
      output          utmi_rxerror_o,
      output [  1:0]  utmi_linestate_o,

      // UTMI settings
      input  [  1:0]  utmi_op_mode_i,
      input  [  1:0]  utmi_xcvrselect_i,
      input           utmi_termselect_i,
      input           utmi_dppulldown_i,
      input           utmi_dmpulldown_i,
    
      // ULX3S USB interface
      input  wire usb_fpga_dif,    // D differential in
      inout  wire usb_fpga_dp,     // D+
      inout  wire usb_fpga_dn,     // D-
      inout  wire usb_fpga_pu_dp,  // 1 = 1.5K up, 0 = 15K down, z = float
      inout  wire usb_fpga_pu_dn   // 1 = 1.5K up, 0 = 15K down, z = float
  );

  //-----------------------------------------------------------------
  // UTMI signalling interface
  //-----------------------------------------------------------------

  // xcvrselect 0 = HS, 1 = FS, 2 = LS, 3 = LS over FS line
  wire is_LS  = (utmi_xcvrselect_i == 2'b10);
  wire is_PRE = (utmi_xcvrselect_i == 2'b11);

  // Special UTMI setting to assert reset on host bus
  wire   utmi_reset_assert = (utmi_xcvrselect_i == 2'b00 && 
                              utmi_termselect_i == 1'b0  && 
                              utmi_op_mode_i    == 2'b10 && 
                              utmi_dppulldown_i && 
                              utmi_dmpulldown_i);
  
  // note DP/DN are swapped in LS mode
  assign utmi_linestate_o = {usb_fpga_dn, usb_fpga_dp};
  assign utmi_rxvalid_o   = rx_ready;
  assign utmi_rxerror_o   = rx_error;
  assign utmi_txready_o   = tx_ready;
  assign utmi_rxactive_o  = (state == S_RX_ACTIVE);
  assign utmi_data_in_o   = shiftreg;

  //-----------------------------------------------------------------
  // ULX3S pin interface. See schematics for details
  //-----------------------------------------------------------------

  // Pull-up / pull-down logic. Host = 10K pulldown
  assign usb_fpga_pu_dp = 1'b0; // utmi_termselect_i;
  assign usb_fpga_pu_dn = 1'b0;

  // inout pseudo-differential transmit & single-ended input lines
  // note DP/DN are swapped in LS mode
  assign usb_fpga_dp = (!rx_mode) ? (is_LS ? tx_dn : tx_dp) : 1'bz;
  assign usb_fpga_dn = (!rx_mode) ? (is_LS ? tx_dp : tx_dn) : 1'bz;
  wire   in_dp_w = is_LS ? usb_fpga_dn : usb_fpga_dp;
  wire   in_dn_w = is_LS ? usb_fpga_dp : usb_fpga_dn;

  // differential input (use single-ended fall back if not available)
  //wire in_rx_w = (in_dp_w == 1'b1 && in_dn_w == 1'b0) ? 1'b1 : 1'b0;
  wire in_rx_w = is_LS ? !usb_fpga_dif : usb_fpga_dif;

  //-----------------------------------------------------------------
  // Resample async signals & surpress noise
  //-----------------------------------------------------------------

  reg [2:0] rx_pos,  rx_neg,  rx_dif;
  reg       rx_dp_q, rx_dn_q, rxd_q;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      rx_pos  <= 3'b0; rx_neg  <= 3'b0; rx_dif <= 3'b0;
      rx_dp_q <= 1'b0; rx_dn_q <= 1'b0; rxd_q  <= 1'b0;
    end else begin
      rx_pos <= {rx_pos[1:0], in_dp_w};
      rx_neg <= {rx_neg[1:0], in_dn_w};
      rx_dif <= {rx_dif[1:0], in_rx_w};
      
      rx_dp_q <= (rx_pos[2] == rx_pos[1]) ? rx_pos[2] : rx_dp_q;
      rx_dn_q <= (rx_neg[2] == rx_neg[1]) ? rx_neg[2] : rx_dn_q;
      rxd_q   <= (rx_dif[2] == rx_dif[1]) ? rx_dif[2] : rxd_q;
      
    end
  end

  wire rx_J       = rx_SE0 ? 1'b0 :  rxd_q;
  wire rx_K       = rx_SE0 ? 1'b0 : ~rxd_q;
  wire rx_SE0     = (!rx_dp_q & !rx_dn_q);
  wire rx_SE1     = (rx_dp_q & rx_dn_q); // invalid

  //-----------------------------------------------------------------
  // TX free-running clock and RX PLL clock
  //-----------------------------------------------------------------

  // When sending the counter is freerunning. When receiving, keep receive
  // edges close to counter==0. Sample in middle, every 4 clocks for FS and
  // every 32 clocks for LS

  reg [4:0] clk_ctr;
  reg       in_prev;

  wire slow_tick = is_LS | (is_PRE & (rx_mode | in_PRE));
  wire bit_tick  = (slow_tick ? (clk_ctr == 5'd14) : (clk_ctr[1:0] == 2'd1));
  wire ctr_is_0  =  slow_tick ? (clk_ctr == 5'd0)  : (clk_ctr[1:0] == 2'd0);

  wire bit_edge  = in_prev ^ rx_J;

  always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      in_prev <= 1'b0;
      clk_ctr <= 5'd0;
      end
    else begin
      in_prev <= rx_J;
      clk_ctr <= (bit_edge && (state < S_TX_SYNC)) ? 5'd0 : clk_ctr + 5'd1;
    end
  end

  //-----------------------------------------------------------------
  // State Machine
  //-----------------------------------------------------------------
      
  localparam
    S_IDLE      = 5'd0,   S_RX_DETECT = 5'd1,   S_RX_SYNC_J = 5'd2,   S_RX_SYNC_K = 5'd3,
    S_RX_ACTIVE = 5'd4,   S_RX_EOP0   = 5'd5,   S_RX_EOP1   = 5'd6,   S_RX_EOP2   = 5'd7,
    S_TX_SYNC   = 5'd8,   S_TX_ACTIVE = 5'd9,   S_EOP_STUFF = 5'd10,  S_TX_EOP0   = 5'd11,
    S_TX_EOP1   = 5'd12,  S_TX_EOP2   = 5'd13,  S_TX_EOP3   = 5'd14,  S_TX_RST    = 5'd15,
    S_PRE_SYNC  = 5'd16,  S_PRE_PID   = 5'd17,  S_PRE_WAIT  = 5'd18;
    
  localparam
    SYNC = 8'h2a, PID_SOF = 8'ha5, PID_PRE = 8'h3c;

  // state vars
  //
  reg [4:0] state;  
  reg [7:0] shiftreg;
  reg       tx_dp, tx_dn, tx_ready, rx_ready;
  reg       prev_bit, in_PRE, rx_mode, saw_sync_J;

  // helper booleans
  //
  wire tx_toggle = ~shiftreg[0] | stuff_bit;
  wire rx_toggle = (prev_bit ^ rxd_q) & bit_tick;
  wire send_SOF  = (utmi_data_out_i==PID_SOF);
  wire is_LS_sof = utmi_txvalid_i & is_LS & send_SOF;
  
  // bit counter, delineates bytes in the de-stuffed bitstream
  //
  reg  [2:0] bit_count;
  wire       byte_done = (&bit_count);

  always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
      bit_count <= 3'b0;
    else if ((state == S_IDLE) || (state == S_RX_SYNC_K))
      bit_count <= 3'b0;
    else if ((state == S_RX_ACTIVE || state == S_TX_ACTIVE || state == S_PRE_PID) && bit_tick && !stuff_bit)
      bit_count <= bit_count + 3'd1;
    else if (((state == S_TX_SYNC) || (state == S_RX_SYNC_J) || state == S_PRE_SYNC) && bit_tick)
      bit_count <= bit_count + 3'd1;
  end
  
  // count 1 bits, stuff after 6 consecutive ones
  //
  reg [2:0] ones_count;
  wire      stuff_bit = (ones_count == 3'd6);
  wire      stuff_nxt = (ones_count == 3'd5) && shiftreg[0];

  // main state machine
  //
  always @ (posedge rst_i or posedge clk_i) begin
    if (rst_i) begin
      // init state vars
      state      <= S_IDLE;     // current state
      shiftreg   <= 8'b0;       // RX+TX shift register
      prev_bit   <= 1'b0;       // previous bit, to detect changes
      in_PRE     <= 1'b0;       // sending LS packet on FS line
      tx_ready   <= 1'b0;       // byte sent
      rx_ready   <= 1'b0;       // byte received
      rx_mode    <= 1'b1;       // line drivers switched off
      saw_sync_J <= 1'b0;       // saw a J in a RX sync pattern
      ones_count <= 3'd1;       // sync pattern ends with a 1 (double K)
      tx_dp      <= 1'b1;       // TX DP
      tx_dn      <= 1'b0;       // TX DN
      end
    else begin
      tx_ready <= 1'b0;
      rx_ready <= 1'b0;
      
      // Handle states that are not sync'ed on the bit clock
      //
      if (state==S_IDLE) begin
        prev_bit   <= rxd_q;
        rx_mode    <= ~(utmi_txvalid_i | utmi_reset_assert);
        saw_sync_J <= 1'b0;
        ones_count <= 3'd1;
        shiftreg   <= SYNC;
        tx_dp <= 1'b1; tx_dn <= 1'b0;

        // switch out into RX or TX task
        if (utmi_reset_assert)
          state <= S_TX_RST;
        else if (rx_K)
          state <= S_RX_DETECT;
        else if (is_LS_sof) begin // if in LS-mode, PID SOF => send EOP
          state <= S_TX_EOP0;
          tx_ready <= 1'b1; // consume PID byte
          end
        else if (utmi_txvalid_i)
          state <= (is_PRE && !(utmi_data_out_i==PID_SOF ) ? S_PRE_SYNC : S_TX_SYNC);

        end

      else if (state==S_TX_RST) begin
        tx_dp <= 1'b0; tx_dn <= 1'b0;
        if (!utmi_reset_assert) state <= S_IDLE;
        end
      
      // Handle state that are synced to the bit clock
      //
      else if (bit_tick) begin
        prev_bit <= rxd_q;
        case (state)

        // detect sync pattern KJKJKJKK
        //
        S_RX_DETECT:  begin // saw full K bit?
                      state <= (rx_K) ? S_RX_SYNC_K : S_IDLE;
                      end

        S_RX_SYNC_K:  begin
                      if (rx_K) // double K after KJ?
                        state <= saw_sync_J ? S_RX_ACTIVE : S_IDLE;
                      else if (rx_J) // J after K?
                        state <= S_RX_SYNC_J;
                      end
                      
        S_RX_SYNC_J:  begin
                      saw_sync_J <= 1'b1;
                      if (rx_K) // K after KJ?
                        state <= S_RX_SYNC_K;
                      else if (bit_count == 3'd1) // double J after K?
                        state <= S_IDLE;
                      end

        // receive data + EOP
        //
        S_RX_ACTIVE:  begin
                      if (rx_SE0)
                        state <= S_RX_EOP0;
                      else if (rx_error)
                        state <= S_IDLE;

                      if (!stuff_bit) begin
                        shiftreg <= {~rx_toggle, shiftreg[7:1]};
                        if (byte_done) rx_ready <= 1'b1;
                        end

                      ones_count <= rx_toggle ? 3'b0 : ones_count + 3'd1;
                      end
                      
        S_RX_EOP0:    begin // 2nd SE0 of EOP?
                      state <= (rx_SE0) ? S_RX_EOP1 : S_IDLE;
                      end

        S_RX_EOP1:    begin // driven J received? 
                      state <= (rx_J) ? S_RX_EOP2 : S_RX_EOP0;
                      end

        S_RX_EOP2:    begin // return to IDLE
                      state <= S_IDLE;
                      end

        // transmit PRE header before sending LS packet on FS line
        //
        S_PRE_SYNC:   begin // send sync pattern
                      if (byte_done) state <= S_PRE_PID;
                      shiftreg <= (byte_done) ? PID_PRE : {~rx_toggle, shiftreg[7:1]};
                      tx_dp <= shiftreg[0]; tx_dn <= ~shiftreg[0];
                      end
                      
        S_PRE_PID:    begin // send PRE token
                      if (byte_done) state <= S_PRE_WAIT;
                      if (!stuff_bit) shiftreg <= {~rx_toggle, shiftreg[7:1]};
                      if (tx_toggle) begin tx_dp <= ~tx_dp; tx_dn <= ~tx_dn; end
                      end

        S_PRE_WAIT:   begin // wait 4 bit times
                      if (tx_sep) begin
                        state <= S_TX_SYNC;
                        in_PRE  <= 1'b1;
                        end
                      shiftreg <= SYNC;
                      tx_dp <= 1'b1; tx_dn <= 1'b0;
                      end

        // transmit SYNC + data + EOP
        //
        S_TX_SYNC:    begin // send sync pattern
                      if (byte_done) begin
                        state <= S_TX_ACTIVE;
                        tx_ready <= 1'b1;
                        end
                      shiftreg <= (byte_done) ? utmi_data_out_i : {~rx_toggle, shiftreg[7:1]};
                      tx_dp <= shiftreg[0]; tx_dn <= ~shiftreg[0];
                      end

        S_TX_ACTIVE:  begin // send data bytes
                      if (!stuff_bit) begin
                        shiftreg <= (byte_done) ? utmi_data_out_i : {~rx_toggle, shiftreg[7:1]};
                        if (byte_done) begin
                          if (!utmi_txvalid_i || eop_pending)
                            state <= stuff_nxt ? S_EOP_STUFF : S_TX_EOP0;
                          else
                            tx_ready <= 1'b1;
                          end
                      end
                      if (tx_toggle) begin tx_dp <= ~tx_dp; tx_dn <= ~tx_dn; end
                      ones_count <= (tx_toggle) ? 3'b0 : ones_count + 3'd1;
                      end

        S_EOP_STUFF:  begin // output final stuff bit if needed
                      state <= S_TX_EOP0;
                      if (tx_toggle) begin tx_dp <= ~tx_dp; tx_dn <= ~tx_dn; end
                      end

        S_TX_EOP0:    begin // drive SE0
                      state <= S_TX_EOP1; tx_dp <= 1'b0; tx_dn <= 1'b0;
                      end

        S_TX_EOP1:    begin // drive SE0
                      state <= S_TX_EOP2; tx_dp <= 1'b0; tx_dn <= 1'b0;
                      end

        S_TX_EOP2:    begin // drive J
                      state <= S_TX_EOP3; tx_dp <= 1'b1; tx_dn <= 1'b0;
                      end

        S_TX_EOP3:    begin // float bus, switch back to FS after PRE, go back to RX mode
                      state   <= S_IDLE;
                      in_PRE  <= 1'b0;
                      end
    
        default:      state <= S_IDLE;

        endcase
      end
    end
  end

  //-----------------------------------------------------------------
  // RX Error Detection
  //-----------------------------------------------------------------
  reg rx_error;

  always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        rx_error  <= 1'b0;
    else if (ones_count == 3'd7) // RX bit stuffing error
        rx_error  <= 1'b1;
    else if (rx_SE1 && bit_tick) // Invalid line state
        rx_error  <= 1'b1;
    else if ((state == S_RX_SYNC_K) && !saw_sync_J & rx_K & bit_tick) // Invalid SYNC sequence
        rx_error  <= 1'b1;
    else if (rx_timeout) // RX time-out
        rx_error  <= 1'b1;
    else
        rx_error  <= 1'b0;
  end

  //-----------------------------------------------------------------
  // Timeout management
  //-----------------------------------------------------------------

  reg [7:0] rx_timer;

  always @ (posedge clk_i or posedge rst_i)
  if (rst_i)
      rx_timer  <= 8'd255;
  else if (state == S_TX_EOP2 || state == S_PRE_PID)
      rx_timer  <= 8'd0;
  else if (state == S_RX_ACTIVE) // once a read has started, it may error but cannot time-out
      rx_timer  <= 8'd255;
  else if (bit_tick && !(&rx_timer))
      rx_timer  <= rx_timer + 8'd1;
  
  // Expected reads time out after 18 bit times
  // PRE header to LS packet separation is 4 bit times
  wire rx_timeout = (rx_timer == 8'd250);
  wire tx_sep     = (rx_timer == 8'd4);

  //-----------------------------------------------------------------
  // A txvalid gap may last only one clock; remember until EOP sent
  //-----------------------------------------------------------------
  reg eop_pending;

  always @ (posedge rst_i or posedge clk_i)
  if (rst_i)
      eop_pending  <= 1'b0;
  else if ((state == S_TX_ACTIVE) && !utmi_txvalid_i)
      eop_pending  <= 1'b1;
  else if (state == S_TX_EOP0)
      eop_pending  <= 1'b0;

endmodule
