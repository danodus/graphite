
`default_nettype none

module SIE (
  input  wire         clk_i,
  input  wire         rst_i,
  output wire [7:0]   led_o,
  
  // SIE control
  input  wire         start_i,
  input  wire         in_transfer_i,
  input  wire         sof_transfer_i,
  input  wire         resp_expected_i,

  // SIE status
  output wire         idle_o,
  output reg          crc_err_o,
  output reg          timeout_o,
  output reg          ack_o,
  output reg          tx_done_o,
  output reg          rx_done_o,
  output wire [15:0]  rx_count_o,
  output reg  [ 7:0]  response_o,
  
  // Token packet
  input  wire [ 7:0]  token_pid_i,
  input  wire [ 6:0]  token_dev_i,
  input  wire [ 3:0]  token_ep_i,

  // Data packet
  input  wire [15:0]  data_len_i,
  input  wire         data_idx_i,  // send DATA0 or DATA1

  // FIFO interface
  input  wire [ 7:0]  tx_data_i,
  output wire         tx_pop_o,
  output wire [ 7:0]  rx_data_o,
  output wire         rx_push_o,

  // UTMI interface to PHY and host
  output wire [ 7:0]  utmi_data_o,
  output wire         utmi_txvalid_o,
  input  wire         utmi_txready_i,
  input  wire [ 7:0]  utmi_data_i,
  input  wire         utmi_rxvalid_i,
  input  wire         utmi_rxactive_i,
  input  wire         utmi_rxerror_i,
  input  wire [ 1:0]  utmi_xcvrselect_i
  );


  assign led_o = {4'b0, state};

  localparam  PID_DATA0 = 8'hc3, PID_DATA1 = 8'h4b, PID_ACK   = 8'hd2;

  localparam  S_IDLE       = 4'd0, S_TX_TOKEN1  = 4'd1,  S_TX_TOKEN2  = 4'd2,
              S_TX_TOKEN3  = 4'd3, S_TX_SEP     = 4'd4,  S_TX_PID     = 4'd5,
              S_TX_DATA    = 4'd6, S_TX_CRC1    = 4'd7,  S_TX_CRC2    = 4'd8,
              S_RX_WAIT    = 4'd9, S_RX_DATA    = 4'd10, S_TX_ACK     = 4'd11;

  //-----------------------------------------------------------------
  // CRC calculation
  //-----------------------------------------------------------------
  
  // CRC5 for token packets
  //
  function [ 4:0] crc5;
    input [10:0] data;
    reg   [ 3:0] i;
    reg   [ 4:0] x;
    begin
      crc5 = 5'b11111;
      for (i = 0; i <= 10; i = i + 1) begin
        crc5 = {1'b0, crc5[4:1]} ^ ((data[i] ^ crc5[0]) ? 5'b10100 : 5'b0);
      end
    end
  endfunction

  wire  [15:0] token_dat = {~crc5({token_ep_i, token_dev_i}), token_ep_i, token_dev_i};
  
  // CRC16 for data packets, accumulated per data byte in crc_sum
  //
  function [15:0] crc16;
    input [ 7:0] data;
    input [15:0] crc;
    reg   [ 3:0] i;
    reg   [15:0] x;
    begin
      crc16 = crc;
      for (i = 0; i <= 7; i = i + 1) begin
        crc16 = {1'b0, crc16[15:1]} ^ ((data[i] ^ crc16[0]) ? 16'ha001 : 16'h0);
      end
    end
  endfunction
  
  reg  [15:0] crc_sum;
  wire [ 7:0] crc_in  = (state==S_RX_DATA) ? utmi_data_i : tx_data_i;
  wire [15:0] crc_out = crc16(crc_in, crc_sum);
  
  wire crc_error = (state == S_RX_DATA) && !rx_active && in_transfer    &&
                   (response_o == PID_DATA0 || response_o == PID_DATA1) &&
                   (crc_sum != 16'hb001); // = residual, reverse of 16'h800d

  //-----------------------------------------------------------------
  // Timeout
  //-----------------------------------------------------------------

  reg [11:0] timeout_q;

  always @ (posedge clk_i or posedge rst_i)
  if (rst_i)
      timeout_q       <= 12'h000;
  else if (utmi_txready_i)
      timeout_q       <= 12'h000;
  else if (!rx_resp_timeout_w)
      timeout_q       <= timeout_q + 12'h1;

  wire   is_LS      = (utmi_xcvrselect_i == 2'b10);
  
  // timeout occurs 18 bit times after EOP (which is 12 bit times after txready ends, so 30 in total)
  wire rx_resp_timeout_w = is_LS ? (timeout_q == 12'd4095) : (timeout_q == 12'd4095) ;

  //-----------------------------------------------------------------
  // UTMI interface
  //-----------------------------------------------------------------
  
  // Output (SIE -> PHY) multiplexer
  //
  assign utmi_data_o    = (state==S_TX_TOKEN1) ?  token_pid_i     :
                          (state==S_TX_TOKEN2) ?  token_dat[ 7:0] :
                          (state==S_TX_TOKEN3) ?  token_dat[15:8] :
                          (state==S_TX_PID)    ? (send_data1 ? PID_DATA1 : PID_DATA0) :
                          (state==S_TX_DATA)   ?  tx_data_i       :
                          (state==S_TX_CRC1)   ? ~crc_sum[ 7:0]   :
                          (state==S_TX_CRC2)   ? ~crc_sum[15:8]   :
                          (state==S_TX_ACK)    ?  PID_ACK         : 8'h00;

  assign utmi_txvalid_o = !(state==S_IDLE || state==S_RX_DATA || state==S_RX_WAIT || state==S_TX_SEP);
  
  // Input (PHY -> SIE): 2 byte data delay to strip CRC bytes from inbound DATAx packets
  //
  wire rx_valid   = utmi_rxvalid_i & utmi_rxactive_i;
  wire rx_active  = utmi_rxactive_i;

  reg [15:0] databuf;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i)
      databuf <= 16'b0;
    else if (utmi_rxvalid_i & utmi_rxactive_i)
      databuf <= {utmi_data_i, databuf[15:8]};
  end

  // FIFO interface; note that bytecount starts at -2 for inbound DATAx packets.
  //
  assign rx_data_o  = databuf[7:0];
  assign rx_push_o  = (state == S_RX_DATA) & rx_valid & ~byte_cnt[15];
  assign tx_pop_o   = (state == S_TX_DATA || state == S_TX_PID) & utmi_txready_i;
  
  // Misc. status lines
  assign rx_count_o = byte_cnt;
  assign idle_o     = (state == S_IDLE);

  //-----------------------------------------------------------------
  // State engine
  //-----------------------------------------------------------------
  
  reg [ 3:0] state;
  reg [15:0] byte_cnt;
  reg        in_transfer, send_data1, send_sof, send_ack;
  reg        wait_resp;

  always @(posedge clk_i or posedge rst_i)
  begin
     if (rst_i) begin
      state       <= S_IDLE;
      response_o  <=  8'h0;   // device response packet PID (handshake or DATAx)
      timeout_o   <=  1'b0;   // RX timed out
      crc_err_o   <=  1'b0;   // RX crc error
      ack_o       <=  1'b0;   // command has started
      rx_done_o   <=  1'b0;   // RX phase complete
      tx_done_o   <=  1'b0;   // TX phase complete
      in_transfer <=  1'b0;   // IN transfer in progress
      send_ack    <=  1'b0;   // send ACK after successful IN
      send_data1  <=  1'b0;   // send DATA1 instead of DATA0 packet
      send_sof    <=  1'b0;   // send SOF packet
      wait_resp   <=  1'b0;   // wait for device handshake
      crc_sum     <= 16'h0;   // running crc sum
      byte_cnt    <= 16'h0;   // running byte count
      end
    else begin
      case (state)

      S_IDLE:       begin
                    rx_done_o     <= 1'b0;
                    tx_done_o     <= 1'b0;
                    ack_o         <= 1'b0;
                    
                    if (start_i && !sof_transfer_i) begin // clear status
                      response_o  <= 8'h0;
                      timeout_o   <= 1'b0;
                      crc_err_o   <= 1'b0;
                      byte_cnt    <= data_len_i;
                      end

                    if (start_i) begin // latch command and go...
                      in_transfer <= in_transfer_i;
                      send_ack    <= in_transfer_i && resp_expected_i;
                      send_data1  <= data_idx_i;
                      send_sof    <= sof_transfer_i;
                      wait_resp   <= resp_expected_i;
                      state       <= S_TX_TOKEN1;
                      end
                    end

      S_TX_TOKEN1:  begin
                    if (utmi_txready_i) begin
                      state <= (is_LS & send_sof) ? S_TX_SEP : S_TX_TOKEN2;
                      ack_o <= 1'b1;
                      end
                    end
                    
      S_TX_TOKEN2:  begin
                    if (utmi_txready_i) state <= S_TX_TOKEN3;
                    end

      S_TX_TOKEN3:  begin
                    if (utmi_txready_i) begin
                      state <= (send_sof)    ? S_TX_SEP  : // SOF - no data packet
                               (in_transfer) ? S_RX_WAIT   // IN - wait for data
                                             : S_TX_SEP;   // OUT/SETUP - Send data or ZLP
                      end
                    end

      S_TX_SEP:     begin
                    state <= (send_sof) ? S_IDLE : S_TX_PID;
                    end

      S_TX_PID:     begin
                    if (utmi_txready_i) begin
                      state <= (byte_cnt == 16'b0) ? S_TX_CRC1 : S_TX_DATA;
                      byte_cnt  <= byte_cnt - 16'd1;
                      end
                    crc_sum <= 16'hffff;
                    end

      S_TX_DATA:    begin
                    if (utmi_txready_i) begin
                      crc_sum <= crc_out;
                      byte_cnt  <= byte_cnt - 16'd1;
                      if (byte_cnt == 16'h0) state <= S_TX_CRC1;
                      end
                    end
                    
      S_TX_CRC1:    begin
                    if (utmi_txready_i) state <= S_TX_CRC2;
                    end

      S_TX_CRC2:    begin
                    if (utmi_txready_i) begin
                      if (wait_resp) tx_done_o <= 1'b1;
                      state <= wait_resp ? S_RX_WAIT : state <= S_IDLE;
                      end
                    end

      S_RX_WAIT:    begin
                    tx_done_o <= 1'b0;
                    crc_sum <= 16'hffff;
                    // for DATAx packets start at -2 because the crc bytes don't count
                    byte_cnt  <= (utmi_data_i==PID_DATA0 || utmi_data_i==PID_DATA1) ? 16'hfffe : 16'h0;
                    
                    if (rx_valid) begin
                      response_o <= utmi_data_i;
                      wait_resp  <= 1'b0;
                      state      <= S_RX_DATA;
                      end
                    else if (rx_resp_timeout_w) begin
                      timeout_o <= 1'b1;
                      state     <= S_IDLE;
                      end
                    end

      S_RX_DATA:    begin
                    rx_done_o   <= !utmi_rxactive_i;

                    if (~rx_active) begin
                      if (send_ack && crc_error) // do not ACK on crc error
                        state <= S_IDLE;
                      else if (send_ack && ((response_o == PID_DATA1) || response_o == PID_DATA0))
                        state <= S_TX_ACK;
                      else
                        state <= S_IDLE;
                      end

                    if (rx_valid) begin
                      crc_sum <= crc_out;
                      byte_cnt <= byte_cnt + 16'd1;
                      end
                    else if (~rx_active)
                      crc_err_o <= crc_error;
                    end
                    
      S_TX_ACK:     begin
                    if (utmi_txready_i) state <= S_IDLE;
                    end
                    
      default:      state <= S_IDLE;

      endcase
    end
  end

endmodule
