//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2017 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.3
//  \   \        Filename: rx_channel_1to7.v
//  /   /        Date Last Modified:  06/06/2022
// /___/   /\    Date Created: 02/27/2017
// \   \  /  \
//  \___\/\___\
//
// Device    :  Ultrascale
//
// Purpose   :  Receiver interface with 1-to-7 deserialization 
//
// Parameters:  LINES - Integer - Default = 5
//                 - # of input data lines
//                 - Range 1 to 24
//              CLKIN_PERIOD - Real - Default = 6.600
//                 - Period in nanoseconds of the input clock clkin_p
//                 - Range = 6.364 to 17.500
//              REF_FREQ - Real - Default = 300.00
//                 - Frequency of the reference clock provided to IDELAYCTRL
//                 - Range = 200.0 to 800.0
//              DIFF_TERM - String - Default = "FALSE"
//                 - Enable internal LVDS termination
//                 - Range = "FALSE" or "TRUE"
//              USE_PLL - String - Default = "FALSE"
//                 - Selects either PLL or MMCM for clocking
//                 - Range = "FALSE" or "TRUE"
//              DATA_FORMAT - String - Default = "PER_CLOCK"
//                 - Selects format of data bus to map sequential bits 
//                   either on a clock or line basis.  When PER_CLOCK is 
//                   used bits 0 to LINES-1 are the first bits received
//                   from each lane.  When PER_LINE is used bits 0 to 6
//                   are the 7 sequential bits received on line 0
//                 - Range = "PER_CLOCK" or "PER_LINE"
//              CLK_PATTERN - Binary - Default = 7'b1100011
//                 - Sets the clock pattern that is expected to be received
//                   and is used for aligning the data lines
//                 - Range = 0 to 2^7-1 typically 7'b1100011 or 7'b1100001
//              RX_SWAP_MASK - Binary - Default = 16'b0
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

module rx_channel_1to7 # (
      parameter integer LINES        = 5,          // Number of data lines 
      parameter real    CLKIN_PERIOD = 6.600,      // Clock period (ns) of input clock on clkin_p
      parameter real    REF_FREQ     = 300.0,      // Reference clock frequency for idelay control
      parameter         DIFF_TERM    = "FALSE",    // Enable internal differential termination
      parameter         USE_PLL      = "FALSE",    // Enable PLL use rather than MMCM use
      parameter         DATA_FORMAT  = "PER_CLOCK",// Mapping input lines to output bus
      parameter         CLK_PATTERN  = 7'b1100011, // Clock pattern for alignment
      parameter         RX_SWAP_MASK = 16'b0,       // Allows P/N inputs to be invered to ease PCB routing
      parameter         SIM_DEVICE = "ULTRASCALE"   // Set for the family <ULTRASCALE | ULTRASCALE_PLUS>
   )
   (
      input                clkin_p,              // Clock input LVDS P-side
      input                clkin_n,              // Clock input LVDS N-side
      input  [LINES-1:0]   datain_p,             // Data input LVDS P-side
      input  [LINES-1:0]   datain_n,             // Data input LVDS N-side
      input                reset,                // Asynchronous interface reset
      input                idelay_rdy,           // Asynchronous IDELAYCTRL ready 
      output               cmt_locked,           // PLL/MMCM locked output
      //
      output               px_clk,               // Pixel clock output
      output [LINES*7-1:0] px_data,              // Pixel data bus output
      output               px_ready              // Pixel data ready
   );


wire               rx_clkdiv2;
wire               rx_clkdiv8;
wire               rx_reset;
wire         [8:0] rx_cntval;
wire               rx_dlyload;
wire               rx_ready;
wire         [4:0] px_rd_addr;
wire         [2:0] px_rd_seq;
wire         [4:0] rx_wr_addr;
wire [LINES*7-1:0] px_raw;

genvar             i;
genvar             j;

//
// Clock Input and Generation
//
rx_clkgen_1to7 # (
      .CLKIN_PERIOD (CLKIN_PERIOD),      // Clock period (ns) of input clock on clkin_p
      .REF_FREQ     (REF_FREQ),          // Reference clock frequency for idelay control
      .DIFF_TERM    (DIFF_TERM),         // Enable internal differential termination
      .CLK_PATTERN  (CLK_PATTERN),       // Expected clock pattern
      .USE_PLL      (USE_PLL),           // Enable PLL use rather than MMCM
      .SIM_DEVICE   (SIM_DEVICE)  // Set for the family <ULTRASCALE | ULTRASCALE_PLUS>
   )
   rxc_gen
   (
      .clkin_p   (clkin_p),      // Input from LVDS clock receiver pin
      .clkin_n   (clkin_n),      // Input from LVDS clock receiver pin
      .reset     (reset),        // Reset 
      .idelay_rdy(idelay_rdy),   // Idelay control ready
      .cmt_locked(cmt_locked),   // PLL/MMCM locked
      //
      .rx_clkdiv2(rx_clkdiv2),   // RX clock div2 output
      .rx_clkdiv8(rx_clkdiv8),   // RX clock div8 output
      .rx_reset  (rx_reset),     // RX reset
      .rx_wr_addr(rx_wr_addr),   // RX write address
      .rx_cntval (rx_cntval),    // RX input delay count value
      .rx_dlyload(rx_dlyload),   // RX input delay load
      .rx_ready  (rx_ready),     // RX ready
      //
      .px_clk    (px_clk),       // Pixel clock output
      .px_rd_addr(px_rd_addr),   // Pixel read address
      .px_rd_seq (px_rd_seq),    // Pixel read sequence
      .px_ready  (px_ready)      // Pixel data ready data
   );


//
// Data Input 1:7 Deserialization
//
generate
   for (i = 0 ; i < LINES ; i = i+1) begin : rxd
      rx_sipo_1to7 # (
            .DIFF_TERM    (DIFF_TERM),         // Enable internal differential termination
            .RX_SWAP_MASK (RX_SWAP_MASK[i]),    // Invert data line
            .SIM_DEVICE   (SIM_DEVICE)  // Set for the family <ULTRASCALE | ULTRASCALE_PLUS>
         )
         sipo
         (
            .datain_p     (datain_p[i]),       // Input from LVDS data pins
            .datain_n     (datain_n[i]),       // Input from LVDS data pins
            //
            .rx_clkdiv2   (rx_clkdiv2),        // RX clock DDR rate
            .rx_clkdiv8   (rx_clkdiv8),        // RX clock QDDR rate
            .rx_reset     (rx_reset),          // RX reset
            .rx_ready     (rx_ready),          // RX ready
            .rx_wr_addr   (rx_wr_addr),        // RX write address
            .rx_cntval    (rx_cntval),         // RX input delay count value
            .rx_dlyload   (rx_dlyload),        // RX input delay load
            //
            .px_clk       (px_clk),            // Pixel clock
            .px_rd_addr   (px_rd_addr),        // Pixel read address
            .px_rd_seq    (px_rd_seq),         // Pixel read sequence
            .px_data      (px_raw[(i+1)*7-1 -:7]) // Pixel data output
         );
   end
endgenerate

//
// Data formatting based on the following
//
// PER_CLOCK - 5 Lines Example
//    - [ 4:0 ] - Received on 1st clock edge
//    - [ 9:5 ] - Received on 2nd clock edge
//    - [14:10] - Received on 3rd clock edge
//    - [19:15] - Received on 4th clock edge
//    - [24:20] - Received on 5th clock edge
//    - [29:25] - Received on 6th clock edge
//    - [34:30] - Received on 7th clock edge
//
// PER_LINE - 5 Lines Example
//    - [ 6:0 ] - Received on 1st line ( 0,  1,  2,  3,  4,  5,  6)
//    - [13:7 ] - Received on 2nd line ( 7,  8,  9, 10, 11, 12, 13)
//    - [20:14] - Received on 3rd line (14, 15, 16, 17, 18, 18, 20)
//    - [27:21] - Received on 4th line (21, 22, 23, 24, 25, 26, 27)
//    - [34:28] - Received on 5th line (28, 29, 30, 31, 32, 33, 34)
generate
   for (i=0; i<LINES; i=i+1) begin :loop1
      for (j=0; j<7   ; j=j+1) begin : loop2
         if (DATA_FORMAT == "PER_CLOCK")
             assign px_data[LINES*j+i] = px_raw[7*i+j];
         else
             assign px_data[7*i+j]     = px_raw[7*i+j];
      end
   end
endgenerate


endmodule
