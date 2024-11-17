
`timescale 1ps/1ps

module cameralink_bit_allocation_rx #(
	// Parameters
	parameter	integer		N = 3,		// Set the number of channels. N=3 -> Full; N=2 -> Medium; N=1 -> Base
	parameter	integer		X = 4		// Set the number of data lines per channel
)(
	input	[N*X*7-1:0]	data_in,		// Parallel data input

	// cameralink parallel data bus: bit allocation format
	// Chip X signals
	output			xLVAL,		// Line Valid, active high
	output			xFVAL,		// Frame Valid, active high
	output			xDVAL,		// Data Valid, active high. Maybe always zero.
	output	[7:0]	PortA,		// Camera Link interface Port A , total 8 ports
	output	[7:0]	PortB,		// Camera Link interface Port B , total 8 ports
  output	[7:0]	PortC,		// Camera Link interface Port B , total 8 ports
	// Chip Y signals
	output			yLVAL,		// Line Valid, active high
	output			yFVAL,		// Frame Valid, active high
	output			yDVAL,		// Data Valid, active high. Maybe always zero.
	output	[7:0]	PortD,		// Camera Link interface Port D , total 8 ports
	output	[7:0]	PortE,		// Camera Link interface Port E , total 8 ports
	output	[7:0]	PortF,		// Camera Link interface Port F , total 8 ports

	// Chip Z signals
	output			zLVAL,		// Line Valid, active high
	output			zFVAL,		// Frame Valid, active high
	output			zDVAL,		// Data Valid, active high. Maybe always zero.
	output	 [7:0]	PortG,		// Camera Link interface Port G , total 8 ports
	output	 [7:0]	PortH		// Camera Link interface Port H , total 8 ports
);

// Bit map
generate
	// Base cameralink
	if(N >= 1)
		begin: label_1
			// Input data Mapped to Cameralink Bit Allocation
      		assign	xLVAL = data_in[16];
			assign	xFVAL = data_in[15];
			assign	xDVAL = data_in[14] ;
			assign	PortA[7:0] = {data_in[26], data_in[27], data_in[1], data_in[2], data_in[3], data_in[4], data_in[5], data_in[6]};
			assign	PortB[7:0] = {data_in[24], data_in[25], data_in[9], data_in[10], data_in[11], data_in[12], data_in[13], data_in[0]};
			assign	PortC[7:0] = {data_in[22], data_in[23], data_in[17], data_in[18], data_in[19], data_in[20], data_in[7], data_in[8]};
		end

	// Medium cameralink
	if(N >= 2)
		begin: label_2
			assign	yLVAL = data_in[16 + X*7];
			assign	yFVAL = data_in[15 + X*7];
			assign	yDVAL = data_in[14] + X*7;
			assign	PortD[7:0] = {data_in[26 + X*7], data_in[27 + X*7], data_in[1 + X*7], data_in[2 + X*7], data_in[3 + X*7], data_in[4 + X*7], data_in[5 + X*7], data_in[6 + X*7]};
			assign	PortE[7:0] = {data_in[24 + X*7], data_in[25 + X*7], data_in[9 + X*7], data_in[10 + X*7], data_in[11 + X*7], data_in[12 + X*7], data_in[13 + X*7], data_in[0 + X*7]};
			assign	PortF[7:0] = {data_in[22 + X*7], data_in[23 + X*7], data_in[17 + X*7], data_in[18 + X*7], data_in[19 + X*7], data_in[20 + X*7], data_in[7 + X*7], data_in[8 + X*7]};
		end

	// Full cameralink
	if(N == 3)
		begin: label_3
			assign	zLVAL = data_in[16 + X*2*7];
			assign	zFVAL = data_in[15 + X*2*7];
			assign	zDVAL = data_in[14 + X*2*7];
			assign	PortG[7:0] = {data_in[26 + X*2*7], data_in[27 + X*2*7], data_in[1 + X*2*7], data_in[2 + X*2*7], data_in[3 + X*2*7], data_in[4 + X*2*7], data_in[5 + X*2*7], data_in[6 + X*2*7]};
			assign	PortH[7:0] = {data_in[24 + X*2*7], data_in[25 + X*2*7], data_in[9 + X*2*7], data_in[10 + X*2*7], data_in[11 + X*2*7], data_in[12 + X*2*7], data_in[13 + X*2*7], data_in[0 + X*2*7]};
		end
endgenerate

endmodule
