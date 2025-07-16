
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

reg [31:0] ram[0:16383];
wire [31:0] data;
wire [31:0] ram_data;
reg [31:0] rom[0:4095];
initial $readmemh("../src/rom.hex", rom);

assign ram_data = ram[{2'h0,I_addr[31:2]}];
assign data[7:0] = I_mask[0] ? I_data[7:0] : ram_data[7:0];
assign data[15:8] = I_mask[1] ? I_data[15:8] : ram_data[15:8];
assign data[23:16] = I_mask[2] ? I_data[23:16] : ram_data[23:16];
assign data[31:24] = I_mask[3] ? I_data[31:24] : ram_data[31:24];

always @(posedge I_clk)
begin
	if (I_rst) begin
		O_data <= 32'h00000000;
		O_gpio <= 32'h00000000;
		O_stall <= 1;
	end else begin
		O_stall <= 0;
		if (I_we) begin
			if (I_addr == 0) begin
				O_gpio <= data;
			end else begin
				ram[{2'h0,I_addr[31:2]}] <= data;
			end
		end else begin
			O_data <= ram_data;
		end
	end
	O_idata <= rom[{2'h0,I_iaddr[15:2]}];
end

endmodule

