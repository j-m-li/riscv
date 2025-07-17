
module cache (
	input	I_clk,     
	input	I_rst,
	input	[31:0] I_gpio,
	output reg [31:0] O_gpio,
	input	[31:0] I_iaddr,
	output reg [31:0] O_idata,
	input	[31:0] I_addr,
	input  [31:0] I_data,
	input  [3:0] I_mask,
	input   I_we,
	output reg [31:0] O_data,
	output reg O_stall
);

reg [7:0] ram0[0:16383];
reg [7:0] ram1[0:16383];
reg [7:0] ram2[0:16383];
reg [7:0] ram3[0:16383];
reg [31:0] rom[0:4095];
initial $readmemh("../src/rom.hex", rom);

always @(posedge I_clk)
begin
	if (I_rst) begin
		O_data <= 32'h00000000;
		O_idata <= 32'h00000000;
		O_gpio <= 32'h00000000;
		O_stall <= 1;
	end else begin
		O_stall <= I_iaddr[31];
		if (I_we) begin
			if (I_addr == 0) begin
				O_gpio <= I_data;
			end else begin
				if (I_mask[0]) begin
				       	ram0[{2'h0,I_addr[31:2]}] <=
				       		I_data[7:0];
				end
				if (I_mask[1]) begin
				       	ram1[{2'h0,I_addr[31:2]}] <=
				       		I_data[15:8];
				end
				if (I_mask[2]) begin
				       	ram2[{2'h0,I_addr[31:2]}] <=
				       		I_data[23:16];
				end
			
				if (I_mask[3]) begin
				       	ram3[{2'h0,I_addr[31:2]}] <=
				       		I_data[31:24];
				end
			end
			O_data <= 32'h0;
		end else begin
			O_data <= {
				ram3[{2'h0,I_addr[31:2]}],
				ram2[{2'h0,I_addr[31:2]}],
				ram1[{2'h0,I_addr[31:2]}],
				ram0[{2'h0,I_addr[31:2]}]
				};
		end
		O_idata <= rom[{2'h0,I_iaddr[15:2]}];
	end
end

endmodule

