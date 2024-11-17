`timescale 1ns / 1ps


module cl_rx#
(
   parameter CAMERA_LINK_MODE = 3// Set the number of channels. N=3 -> Full; N=2 -> Medium; N=1 -> Base
)(  
  
  //clock
  input wire ref_clk_300,//reference input clock, shoulde be 300MHz by default
  input wire user_reset_n,//active low reset
  //camera link data and clk
  input wire [3:0]  CL_X_N,
  input wire [3:0]  CL_X_P,
  input wire        CL_XCLK_N,
  input wire        CL_XCLK_P,

  input wire [3:0]  CL_Y_N,
  input wire [3:0]  CL_Y_P,
  input wire        CL_YCLK_N,
  input wire        CL_YCLK_P,

  input wire [3:0]  CL_Z_N,
  input wire [3:0]  CL_Z_P,
  input wire        CL_ZCLK_N,
  input wire        CL_ZCLK_P,
  
  output wire x_clk,
  output wire x_ready,//active high
  output wire xLVAL,
  output wire xFVAL,
  output wire xDVAL,
  output wire [7:0] PortA,//port a data
  output wire [7:0] PortB,//port b data
  output wire [7:0] PortC,//port c data
  
  output wire y_clk,
  output wire y_ready,//active high
  output wire yLVAL,
  output wire yFVAL,
  output wire yDVAL,
  output wire [7:0] PortD,//port D data
  output wire [7:0] PortE,//port E data
  output wire [7:0] PortF,//port F data
   
  output wire z_clk,
  output wire z_ready,//active high
  output wire zLVAL,
  output wire zFVAL,
  output wire zDVAL,
  output wire [7:0] PortG,//port G data
  output wire [7:0] PortH//port H data
 ); 

wire [28 * CAMERA_LINK_MODE  - 1:0] data_out;
wire [4 * CAMERA_LINK_MODE - 1:0] datain_p;
wire [4 * CAMERA_LINK_MODE - 1:0] datain_n;
wire rx_idelay_rdy;
wire rx_cmt_locked;
wire idly_reset_int;

wire ui_clk_sync_rst;
assign ui_clk_sync_rst = user_reset_n;//active low

assign idly_reset_int = ui_clk_sync_rst | !rx_cmt_locked;

if(CAMERA_LINK_MODE == 1)begin//base
  assign datain_p = CL_X_P;
  assign datain_n = CL_X_N;
end 
else if (CAMERA_LINK_MODE == 2)begin//medium
  assign datain_p = {CL_Y_P,CL_X_P};
  assign datain_n = {CL_Y_N,CL_X_N};
end
else if (CAMERA_LINK_MODE == 3)begin//full
  assign datain_p = {CL_Z_P,CL_Y_P,CL_X_P};
  assign datain_n = {CL_Z_N,CL_Y_N,CL_X_N};
end

//
//  Idelay control block
//
IDELAYCTRL #( // Instantiate input delay control block
      .SIM_DEVICE ("ULTRASCALE"))
   icontrol (
      .REFCLK (ref_clk_300),
      .RST    (idly_reset_int),
      .RDY    (rx_idelay_rdy)
   );

rx_channel_1to7 # (
            .LINES        ( 4 * CAMERA_LINK_MODE),          // Number of data lines 
            .CLKIN_PERIOD ( 12.5     ),      // Clock period (ns) of input clock on clkin_p
            .REF_FREQ     ( 300.0       ),      // Reference clock frequency for idelay control
            .DIFF_TERM    ( "TRUE"     ),    // Enable internal differential termination
            .USE_PLL      ( "FALSE"     ),    // Enable PLL use rather than MMCM use
            .DATA_FORMAT  ( "PER_LINE" ),// Mapping input lines to output bus
            .CLK_PATTERN  ( 7'b1100011  ), // Clock pattern for alignment
            .RX_SWAP_MASK ( 16'b0       ),       // Allows P/N inputs to be invered to ease PCB routing
            .SIM_DEVICE   ( "ULTRASCALE")   // Set for the family <ULTRASCALE | ULTRASCALE_PLUS>
      )rx2_channel_1to7_inst
         (
            .clkin_p    (CL_XCLK_P),              // Clock input LVDS P-side
            .clkin_n    (CL_XCLK_N),              // Clock input LVDS N-side
            .datain_p   (datain_p),             // Data input LVDS P-side
            .datain_n   (datain_n),             // Data input LVDS N-side
            .reset      (ui_clk_sync_rst),                // Asynchronous interface reset
            .idelay_rdy (rx_idelay_rdy),           // Asynchronous IDELAYCTRL ready 
            .cmt_locked (rx_cmt_locked),           // PLL/MMCM locked output
            .px_clk     (x_clk),               // Pixel clock output
            .px_data    (data_out),              // Pixel data bus output
            .px_ready   (x_ready)              // Pixel data ready
         );  

cameralink_bit_allocation_rx #(
    // Parameters
    .N(CAMERA_LINK_MODE)		// Set the number of channels. N=3 -> Full; N=2 -> Medium; N=1 -> Base
)bit_reallocate_inst(
    .data_in(data_out),		// Parallel data input
    .xLVAL  (xLVAL  ),		// Line Valid, active high
    .xFVAL  (xFVAL  ),		// Frame Valid, active high
    .xDVAL  (xDVAL  ),		// Data Valid, active high. Maybe always zero.
    .PortA  (PortA  ),		// Camera Link interface Port A , total 8 ports
    .PortB  (PortB  ),	// Camera Link interface Port B , total 8 ports
    .PortC  (PortC  ),
    .yLVAL  (yLVAL  ),
    .yFVAL  (yFVAL  ),
    .yDVAL  (yDVAL  ),
    .PortD  (PortD  ),
    .PortE  (PortE  ),
    .PortF  (PortF  ),
    .zLVAL  (zLVAL  ),
    .zFVAL  (zFVAL  ),
    .zDVAL  (zDVAL  ),
    .PortG  (PortG  ),
    .PortH  (PortH  )
  );

  ila_cl_full ila_cl_full_inst (
	.clk(ref_clk_300), // input wire clk

	.probe0( data_out), // input wire [83:0]  probe0  
	.probe1(xLVAL), // input wire [0:0]  probe1 
	.probe2(xFVAL), // input wire [0:0]  probe2 
	.probe3(xDVAL), // input wire [0:0]  probe3 
	.probe4(yLVAL), // input wire [0:0]  probe4 
	.probe5(yFVAL), // input wire [0:0]  probe5 
	.probe6(yDVAL), // input wire [0:0]  probe6 
	.probe7(zLVAL), // input wire [0:0]  probe7 
	.probe8(zFVAL), // input wire [0:0]  probe8 
	.probe9(zDVAL), // input wire [0:0]  probe9 
	.probe10(PortA), // input wire [7:0]  probe10 
	.probe11(PortB), // input wire [7:0]  probe11 
	.probe12(PortC), // input wire [7:0]  probe12 
	.probe13(PortD), // input wire [7:0]  probe13 
	.probe14(PortE), // input wire [7:0]  probe14 
	.probe15(PortF), // input wire [7:0]  probe15 
	.probe16(PortG), // input wire [7:0]  probe16 
	.probe17(PortH), // input wire [7:0]  probe17 
	.probe18(CAMERA_LINK_MODE), // input wire [0:0]  probe18
  .probe19(ui_clk_sync_rst), // input wire [84:0]  probe19
  .probe20(x_clk),        // input wire [0:0]  probe20
	.probe21(y_clk), // input wire [0:0]  probe21
  .probe22(z_clk) // input wire [0:0]  probe22
);

endmodule
