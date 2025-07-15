
module code_cache (
	input	I_clk,     
	input	I_rst,
	input	[31:0] I_addr,
	output reg [31:0] O_data,
	output reg O_stall
);


(* ram_style = "block" *)reg [31:0] rom0[0:1683];
reg [15:0] cnt;
reg [7:0] rom[0:65535];
initial $readmemh("rom.hex", rom);

always @(posedge I_clk)
begin
	if (I_rst) begin
		O_data <= 32'h00000000;
		O_stall <= 1;
		cnt <= 0;
	end else if (cnt < 10000) begin
		O_stall <= 1;
		O_data <= 32'h00000000;
		rom0[cnt[15:0]][7:0] <= rom[{cnt,2'h0}];
		rom0[cnt[15:0]][15:8] <= rom[{cnt,2'h1}];
		rom0[cnt[15:0]][23:16] <= rom[{cnt,2'h2}];
		rom0[cnt[15:0]][31:24] <= rom[{cnt,2'h3}];
/*		case (cnt[1:0])
		1:rom0[cnt[15:2]] <= rom[{cnt}];
		2:rom1[cnt[15:2]] <= rom[{cnt}];
	//	3:rom2[cnt[15:2]] <= rom[{cnt}];
	//	4:rom3[cnt[15:2]] <= rom[{cnt}];
		endcase*/
		cnt <= cnt +1; 
	end else begin
		O_stall <= 0;
		O_data <= rom[{2'h0, I_addr[31:2]}];
		/*
		O_data[7:0] <= rom0[{2'h0, I_addr[31:2]}];
		O_data[15:8] <= rom1[{2'h0, I_addr[31:2]}];
		O_data[23:16] <= rom2[{2'h0, I_addr[31:2]}];
		O_data[31:24] <= rom3[{2'h0, I_addr[31:2]}];
		*/
	end
end

endmodule

