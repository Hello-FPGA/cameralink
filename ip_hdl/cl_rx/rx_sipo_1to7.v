//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2017 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.3
//  \   \        Filename: rx_sipo_1to7.v
//  /   /        Date Last Modified:  06/06/2022
// /___/   /\    Date Created: 02/27/2017
// \   \  /  \
//  \___\/\___\
//
// Device    :  Ultrascale
//
// Purpose   :  Receiver Serial In Parallel Out with 1 to 7 conversion
//
// Parameters:  DIFF_TERM - String - Default = "FALSE"
//                 - Enable internal LVDS termination
//                 - Range = "FALSE" or "TRUE"
//              RX_SWAP_MASK - Binary - Default = 1'b0
//                 - Binary value indicating if an input line is inverted
//
// Reference:	XAPPxxx
//
// Revision History:
//    Rev 1.3 - Add SIM_DEVICE to allow code to work with ULTRASCALE_PLUS  (jimt)
//    Rev 1.0 - Initial Release (knagara)
//    Rev 0.9 - Early Access Release (mcgett)
//////////////////////////////////////////////////////////////////////////////
//
//  Disclaimer:
//
// This disclaimer is not a license and does not grant any rights to the
// materials distributed herewith. Except as otherwise provided in a valid
// license issued to you by Xilinx, and to the maximum extent permitted by
// applicable law:
//
// (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND
// XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR
// STATUTORY, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx
// shall not be liable (whether in contract or tort, including negligence, or
// under any other theory of liability) for any loss or damage of any kind or
// nature related to, arising under or in connection with these materials,
// including for any direct, or any indirect, special, incidental, or
// consequential loss or damage (including loss of data, profits, goodwill, or
// any type of loss or damage suffered as a result of any action brought by a
// third party) even if such damage or loss was reasonably foreseeable or
// Xilinx had been advised of the possibility of the same.
//
// Critical Applications:
//
// Xilinx products are not designed or intended to be fail-safe, or for use in
// any application requiring fail-safe performance, such as life-support or
// safety devices or systems, class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any other applications
// that could lead to death, personal injury, or severe property or
// environmental damage (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and liability of any use of
// Xilinx products in Critical Applications, subject only to applicable laws
// and regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE
// AT ALL TIMES.
//
//////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module rx_sipo_1to7 # (
      parameter  DIFF_TERM    = "FALSE",      // Enable internal LVDS termination
      parameter  RX_SWAP_MASK = 1'b0,         // Invert input line
      parameter  SIM_DEVICE   = "ULTRASCALE"  // Set for the family <ULTRASCALE | ULTRASCALE_PLUS>
   )
   (
      input        datain_p,      // Data input LVDS P-side
      input        datain_n,      // Data input LVDS N-side
      //
      input        rx_clkdiv2,    // RX clock running at 1/2 data rate
      input        rx_clkdiv8,    // RX clock running at 1/8 data rate
      input        rx_reset,      // RX reset
      input  [4:0] rx_wr_addr,    // RX write addr
      input  [8:0] rx_cntval,     // RX input delay count value
      input        rx_dlyload,    // RX input delay load
      input        rx_ready,      // RX input delay ready
      //
      input        px_clk,        // Pixel clock running at 1/7 transmit rate
      input  [4:0] px_rd_addr,    // Pixel read address
      input  [2:0] px_rd_seq,     // Pixel read sequence
      output reg [6:0] px_data    // Pixel 7-bit pixel data output
   );

wire        datain_i;
wire        datain_d;

wire [7:0]  rx_wr_curr;
reg  [7:0]  rx_wr_data;


wire [7:0]  px_rd_curr;
reg  [7:1]  px_rd_last;

//
// Data Input LVDS Buffer
//

IBUFDS # (
      .DIFF_TERM     (DIFF_TERM)
   )
   iob_clk_in (
      .I                (datain_p),
      .IB               (datain_n),
      .O                (datain_i)
   );

//
// Data Input IDELAY
//
IDELAYE3 # (
      .DELAY_SRC        ("IDATAIN"),
      .CASCADE          ("NONE"),
      .DELAY_TYPE       ("VAR_LOAD"),
      .DELAY_VALUE      (0),
      .REFCLK_FREQUENCY (300.0),
      .DELAY_FORMAT     ("COUNT"),
      .UPDATE_MODE      ("ASYNC"),
      .SIM_DEVICE   	(SIM_DEVICE)  
   )
   idelay_cm (
      .IDATAIN          (datain_i),
      .DATAOUT          (datain_d),
      .CLK              (rx_clkdiv8),
      .CE               (1'b0),
      .RST              (1'b0),
      .INC              (1'b0),
      .DATAIN           (1'b0),
      .LOAD             (rx_dlyload),
      .CNTVALUEIN       (rx_cntval),
      .EN_VTC           (rx_ready),
      .CASC_IN          (1'b0),
      .CASC_RETURN      (1'b0),
      .CASC_OUT         (),
      .CNTVALUEOUT      ());

//
// Date ISERDES
//
ISERDESE3 #(
       .DATA_WIDTH      (8),
       .SIM_DEVICE   	(SIM_DEVICE),
       .FIFO_ENABLE     ("FALSE"),
       .FIFO_SYNC_MODE  ("FALSE") )
   iserdes_m (
       .D               (datain_d),
       .RST             (rx_reset),
       .CLK             ( rx_clkdiv2),
       .CLK_B           (~rx_clkdiv2),
       .CLKDIV          ( rx_clkdiv8),
       .Q               (rx_wr_curr), 
       .FIFO_RD_CLK     (1'b0),
       .FIFO_RD_EN      (1'b0),
       .FIFO_EMPTY      (),
       .INTERNAL_DIVCLK ()
   );

//
// Register data from ISERDES
//
always @ (posedge rx_clkdiv8)
begin 
   if (RX_SWAP_MASK) begin
       rx_wr_data <= ~rx_wr_curr;
   end
   else begin
       rx_wr_data <=  rx_wr_curr;
   end
end
//
// Generate 8 Dual Port Distributed RAMS for FIFO
//
genvar i;
generate
for (i = 0 ; i < 8 ; i = i+1) begin : bit
  RAM32X1D mem (
     .D     (rx_wr_data[i]),
     .WCLK  (rx_clkdiv8),
     .WE    (1'b1),
     .A4    (rx_wr_addr[4]),
     .A3    (rx_wr_addr[3]),
     .A2    (rx_wr_addr[2]),
     .A1    (rx_wr_addr[1]),
     .A0    (rx_wr_addr[0]),
     .SPO   (),
     .DPRA4 (px_rd_addr[4]),
     .DPRA3 (px_rd_addr[3]),
     .DPRA2 (px_rd_addr[2]),
     .DPRA1 (px_rd_addr[1]),
     .DPRA0 (px_rd_addr[0]),
     .DPO   (px_rd_curr[i]));
end

endgenerate

//
// Store last read data for one cycle
//
always @ (posedge px_clk)
begin
    px_rd_last[7:1] <= px_rd_curr[7:1];
end

//
// Read 8 to 7 gearbox
//
always @ (posedge px_clk)
begin
    case (px_rd_seq ) 
      3'h0 : begin 
         px_data <= px_rd_curr[6:0];
         end
      3'h1 : begin 
         px_data <= {px_rd_curr[5:0], px_rd_last[7]};
         end
      3'h2 : begin 
         px_data <= {px_rd_curr[4:0], px_rd_last[7:6]};
         end
      3'h3 : begin 
         px_data <= {px_rd_curr[3:0], px_rd_last[7:5]};
         end
      3'h4 : begin 
         px_data <= {px_rd_curr[2:0], px_rd_last[7:4]};
         end
      3'h5 : begin 
         px_data <= {px_rd_curr[1:0], px_rd_last[7:3]};
         end
      3'h6 : begin 
         px_data <= {px_rd_curr[0],   px_rd_last[7:2]};
         end
      3'h7 : begin 
         px_data <= {px_rd_last[7:1]};
         end
    endcase
end


// ila_cameralink_data ila_cameralink_data_inst (
// 	.clk(rx_clkdiv2), // input wire clk


// 	.probe0(rx_reset), // input wire [0:0]  probe0  
// 	.probe1(px_rd_curr), // input wire [7:0]  probe1 
// 	.probe2(rx_wr_data), // input wire [7:0]  probe2 
//   .probe3(rx_wr_addr),// input wire [4:0]  probe2 
//   .probe4(px_rd_addr)// input wire [4:0]  probe2 
// );
endmodule
  
