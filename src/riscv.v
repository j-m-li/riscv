// -----------------------------------------------------------------------------
// Kleine-RISCV-PD: A Minimal Public Domain RISC-V RV32I Implementation in Verilog
// Inspired by https://github.com/rolandbernard/kleine-riscv
// Author: ChatGPT, 2025. Released to the public domain. No warranty.
// -----------------------------------------------------------------------------

// Notes:
//
//    This is a minimal, single-cycle, public domain Verilog RISC-V RV32I core, inspired by the linked "kleine-riscv" project.
//    It does not include CSR, exceptions, interrupts, or advanced features.
//    All register 0 writes are ignored (hardwired to zero).
//    LUI/AUIPC are supported.
//    Load/store mask logic is simplified; adjust O_dmem_wmask as needed for your RAM interface.
//    For educational use—suitable as a starting point for more complete designs!


module riscv (
    input          I_clk,        // Clock
    input          I_rst,        // Reset (synchronous, active high)
    input	   I_stall,
    output [31:0] O_imem_addr,  // Instruction memory address
    input  [31:0] I_imem_data,  // Instruction memory data
    output [31:0] O_dmem_addr,  // Data memory address
    input  [31:0] I_dmem_rdata, // Data memory read data
    output [31:0] O_dmem_wdata, // Data memory write data
    output reg [3:0]  O_dmem_wmask, // Data memory write mask (byte-enable)
    output        O_dmem_we     // Data memory write enable
);

    // ==== Registers ====
reg [31:0] pc;
reg [31:0] regfile [0:31];

 // Shifter
wire [31:0] shift1L;
wire [31:0] shift2L;
wire [31:0] shift4L;
wire [31:0] shift8L;
wire [31:0] shift16L;
wire [31:0] shift1R;
wire [31:0] shift2R;
wire [31:0] shift4R;
wire [31:0] shift8R;
wire [31:0] shift16R;
wire [15:0] fills;


    // ==== Instruction Decode Wires ====
wire [6:0]  opcode;
wire [4:0]  rd;
wire [2:0]  funct3;
wire [4:0]  rs1;
wire [4:0]  rs2;
wire [6:0]  funct7;
assign opcode = I_imem_data[6:0];
assign rd     = I_imem_data[11:7];
assign funct3 = I_imem_data[14:12];
assign rs1    = I_imem_data[19:15];
assign rs2    = I_imem_data[24:20];
assign funct7 = I_imem_data[31:25];


    // Immediate decode
wire [31:0] imm_i;
wire [31:0] imm_s;
wire [31:0] imm_b;
wire [31:0] imm_u;
wire [31:0] imm_j;
assign imm_i = {{20{I_imem_data[31]}}, I_imem_data[31:20]};
assign imm_s = {{20{I_imem_data[31]}}, I_imem_data[31:25], I_imem_data[11:7]};
assign imm_b = {{19{I_imem_data[31]}}, I_imem_data[31], I_imem_data[7],
                         I_imem_data[30:25], I_imem_data[11:8], 1'b0};
assign imm_u = {I_imem_data[31:12], 12'b0};
assign imm_j = {{11{I_imem_data[31]}}, I_imem_data[31], 
	    		I_imem_data[19:12],
                         I_imem_data[20], I_imem_data[30:21], 1'b0};


    // ==== Main Register Read ====
wire [31:0] rv1;
wire [31:0] rv2;

assign rv1 = (rs1 == 0) ? 32'b0 : regfile[rs1];
assign rv2 = (rs2 == 0) ? 32'b0 : regfile[rs2];
    // ==== ALU ====
reg [31:0] alu_out;

wire [4:0] shift_amount;
assign shift_amount = I_imem_data[24:20]; 
assign shift1L = (shift_amount[0] == 1) ? {rv1[30:0],1'b0} : rv1;
assign shift2L = (shift_amount[1] == 1) ? {shift1L[29:0],2'b00} : shift1L;
assign shift4L = (shift_amount[2] == 1) ? {shift2L[27:0],4'b0000} : shift2L;
assign shift8L = (shift_amount[3] == 1) ? {shift4L[23:0],8'h00} : shift4L;
assign shift16L = (shift_amount[4] == 1) ? {shift8L[15:0],16'h0000} : shift8L;

assign fills = (funct3 == 3'b001 && funct7 != 7'h0 /*SHIFT_RIGHT_SIGNED*/
	&& rv1[31] == 1'b1)
	? 16'b1111_1111_1111_1111 : 16'b0000_0000_0000_0000;

assign shift1R = (shift_amount[0] == 1) ? 
	{fills[0],rv1[31:1]} : rv1;
assign shift2R = (shift_amount[1] == 1) ? 
	{fills[1:0],shift1R[31:2]} : shift1R;
assign shift4R = (shift_amount[2] == 1) ? 
	{fills[3:0],shift2R[31:4]} : shift2R;
assign shift8R = (shift_amount[3] == 1) ? 
	{fills[7:0],shift4R[31:8]} : shift4R;
assign shift16R = (shift_amount[4] == 1) ? 
	{fills[15:0],shift8R[31:16]} : shift8R;

always @* begin
        case (opcode)
            7'b0110011: begin // R-type
                case ({funct7, funct3})
                    {7'b0000000,3'b000}: alu_out = rv1 + rv2; // ADD
                    {7'b0100000,3'b000}: alu_out = rv1 - rv2; // SUB
                    {7'b0000000,3'b001}: alu_out = rv1 << rv2[4:0]; // SLL
                    {7'b0000000,3'b010}: alu_out = ($signed(rv1) < $signed(rv2)) ? 32'b1 : 32'b0; // SLT
                    {7'b0000000,3'b011}: alu_out = (rv1 < rv2) ? 32'b1 : 32'b0; // SLTU
                    {7'b0000000,3'b100}: alu_out = rv1 ^ rv2; // XOR
                    {7'b0000000,3'b101}: alu_out = rv1 >> rv2[4:0]; // SRL
                    {7'b0100000,3'b101}: alu_out = $signed(rv1) >>> rv2[4:0]; // SRA
                    {7'b0000000,3'b110}: alu_out = rv1 | rv2; // OR
                    {7'b0000000,3'b111}: alu_out = rv1 & rv2; // AND
                    default: alu_out = 32'b0;
                endcase
            end
	    
            7'b0010011: begin // I-type ALU
                case (funct3)
                    3'b000: alu_out = rv1 + imm_i; // ADDI
                    3'b010: alu_out = ($signed(rv1) < $signed(imm_i)) ? 32'b1 : 32'b0; // SLTI
                    3'b011: alu_out = (rv1 < imm_i) ? 32'b1 : 32'b0; // SLTIU
                    3'b100: alu_out = rv1 ^ imm_i; // XORI
                    3'b110: alu_out = rv1 | imm_i; // ORI
                    3'b111: alu_out = rv1 & imm_i; // ANDI
                    3'b001: alu_out = shift16L; // SLLI
                    3'b101: alu_out = shift16R; // SRLI/SRAI
                    default: alu_out = 32'b0;
                endcase
            end
            default: alu_out = 32'b0;
        endcase
end

    // ==== Next-PC Calculation ====
reg take_branch;
always @* begin
	if (opcode == 7'b1100011) begin 
		case (funct3)
            	3'b000: take_branch = rv1 == rv2; // BEQa
            	3'b001: take_branch =  rv1 != rv2; // BNE
            	3'b100: take_branch =  $signed(rv1) < $signed(rv2); // BLT
            	3'b101: take_branch =  $signed(rv1) >= $signed(rv2); // BGE
            	3'b110: take_branch =  rv1 < rv2; // BLTU
            	3'b111: take_branch =  rv1 >= rv2;    // BGEU
		default: take_branch = 0;
    		endcase
	end else begin
		take_branch = 0;
	end
end

wire is_jal;
wire is_jalr;
assign is_jal  = (opcode == 7'b1101111);
assign is_jalr = (opcode == 7'b1100111);

reg [31:0] next_pc;
always @* begin
	case (opcode)
	7'b1101111: next_pc <= pc +imm_j - 4; //JAL
	7'b1100111: next_pc <=  (rv1 + imm_i - 4 ) & ~1; //JALR
        default: next_pc <= take_branch ? (pc + imm_b - 4): (pc + 4);
	endcase
end

    // ==== Write-back Data ====
reg wb_enable;
always @* begin
	case (opcode)
        7'b0110011,//: wb_enable <= 1; // R-type
        7'b0010011,//: wb_enable <= 1; // I-type ALU
        7'b0000011,//: wb_enable <= 1; // Loads
	7'b1101111,//: wb_enable <= 1; //JAL
	7'b1100111,//: wb_enable <= 1; //JALR
        7'b0110111,//: wb_enable <= 1; // LUI
        7'b0010111: wb_enable <= 1;// AUIPC
	default: wb_enable <= 0;
	endcase
end
    // ==== Data Memory Access ====
assign O_dmem_addr  = rv1 + imm_s;
assign O_dmem_wdata = rv2;
always @* begin
	if (opcode == 7'b0100011) begin
		if (funct3  == 4'b000) begin
			O_dmem_wmask = 4'b0001 << O_dmem_addr[1:0]; // SB
		end else if (funct3  == 4'b001) begin
			O_dmem_wmask = 4'b0011 << O_dmem_addr[1:0]; // SH
		end else begin
			O_dmem_wmask = 4'b1111; // SW
		end
	end else begin
		O_dmem_wmask = 4'b0000;
	end
end

assign O_dmem_we    = (opcode == 7'b0100011);

    // ==== Instruction Memory ====
assign O_imem_addr = pc;

    // ==== Main Sequential Logic ====
integer i;
reg skip;

always @(posedge I_clk) begin
        if (I_rst) begin
		skip <= 0;
            	pc <= 32'h0;
            	for (i = 0; i < 32; i = i+1) regfile[i] <= 0;
        end else begin
            	// Write-back
            	if (wb_enable /*&& rd != 0*/ && !skip) begin
			case (opcode)
			7'b0110111: regfile[rd] <= imm_u; // LUI
                        7'b0010111: regfile[rd] <= pc + imm_u; // AUIPC
        		7'b0000011: regfile[rd] <= I_dmem_rdata; // Load
			7'b1101111: regfile[rd] <= pc + 4; // JAL
			7'b1100111: regfile[rd] <= pc + 4; // JALR
                        default: regfile[rd] <= alu_out;
			endcase
		end
		if (!I_stall) begin
            		// PC Update
            		pc <= next_pc;
			if (!skip && (take_branch || is_jal || is_jalr)) begin
				skip <= 1;
			end else begin
				skip <= 0;
			end
		end
        end
end

endmodule

