//
//             MMXXV July 18 PUBLIC DOMAIN by JML
//
//      The authors and contributors disclaim copyright, 
//      patents and all related rights to this software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT OF ANY PATENT, COPYRIGHT, TRADE SECRET OR OTHER
// PROPRIETARY RIGHT.  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR
// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//

module riscv (
    input          I_clk,        // Clock
    input          I_rst,        // Reset (synchronous, active high)
    input	   I_stall,
    output [31:0] O_imem_addr,  // Instruction memory address
    input  [31:0] I_imem_data,  // Instruction memory data
    output reg [31:0] O_dmem_addr,  // Data memory address
    input  [31:0] I_dmem_rdata, // Data memory read data
    output reg [31:0] O_dmem_wdata, // Data memory write data
    output reg [3:0]  O_dmem_wmask, // Data memory write mask (byte-enable)
    output reg O_dmem_rd,     // Data memory read enable
    output reg O_dmem_we     // Data memory write enable
);

// stage 1: IF instruction fetch
reg [31:0] instr;
reg [31:0] pc;
reg [31:0] next_pc;
wire stall;
assign stall = I_stall;

assign O_imem_addr = pc;

always @(posedge I_clk) begin
        if (I_rst) begin
            	pc = 32'h0;
		instr = 32'h0;
        end else begin
		if (!stall) begin
			pc = next_pc;
		end else begin	
			pc = pc;
		end
		instr <= I_imem_data;
        end
	$display("PC:%h OP:%h", O_imem_addr, I_imem_data);
end

// stage 2 : ID instruction decode and register fetch
// ==== Instruction Decode Wires ====
reg [6:0]  opcode;
reg [4:0]  rd;
reg [2:0]  funct3;
reg [4:0]  rs1;
reg [4:0]  rs2;
reg [6:0]  funct7;
// Immediate decode
reg [31:0] imm_i;
reg [31:0] imm_s;
reg [31:0] imm_b;
reg [31:0] imm_u;
reg [31:0] imm_j;
// ==== Registers ====
reg [31:0] regfile [0:31];
reg [31:0] rv1;
reg [31:0] rv2;
reg [4:0] shift_amount;

reg [31:0] pc_id;
integer i;

always @(posedge I_clk) begin
        if (I_rst) begin
		rv1 = 32'h0;
		rv2 = 32'h0;
            	for (i = 0; i < 32; i = i+1) regfile[i] <= 0;
        end else begin
    		// ==== Main Register Read ====
		rv1 = (instr[19:15] == 0) ? 32'b0 : regfile[instr[19:15]];
		rv2 = (instr[24:20] == 0) ? 32'b0 : regfile[instr[24:20]];
        end
	pc_id <= pc;
	shift_amount = instr[24:20]; 
	opcode = instr[6:0];
	rd     = instr[11:7];
	funct3 = instr[14:12];
	rs1    = instr[19:15];
	rs2    = instr[24:20];
	funct7 = instr[31:25];
	imm_i = {{20{instr[31]}}, instr[31:20]};
	imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
	imm_b = {{19{instr[31]}}, instr[31], instr[7],
                         instr[30:25], instr[11:8], 1'b0};
	imm_u = {instr[31:12], 12'b0};
	imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                         instr[20], instr[30:21], 1'b0};
end



// stage 3 : EX execute and effective address calculation
// ==== ALU ====
// Shifter
wire [31:0] shift1l;
wire [31:0] shift2l;
wire [31:0] shift4l;
wire [31:0] shift8l;
wire [31:0] shift16l;
wire [31:0] shift1r;
wire [31:0] shift2r;
wire [31:0] shift4r;
wire [31:0] shift8r;
wire [31:0] shift16r;
wire [15:0] fills;

assign shift1l = (shift_amount[0] == 1) ? {rv1[30:0],1'b0} : rv1;
assign shift2l = (shift_amount[1] == 1) ? {shift1l[29:0],2'b00} : shift1l;
assign shift4l = (shift_amount[2] == 1) ? {shift2l[27:0],4'b0000} : shift2l;
assign shift8l = (shift_amount[3] == 1) ? {shift4l[23:0],8'h00} : shift4l;
assign shift16l = (shift_amount[4] == 1) ? {shift8l[15:0],16'h0000} : shift8l;
assign fills = (funct3 == 3'b001 && funct7 != 7'h0 /*SHIFT_RIGHT_SIGNED*/
	&& rv1[31] == 1'b1) ? 16'b1111_1111_1111_1111 : 16'b0000_0000_0000_0000;
assign shift1r = (shift_amount[0] == 1) ? {fills[0],rv1[31:1]} : rv1;
assign shift2r = (shift_amount[1] == 1) ? {fills[1:0],shift1r[31:2]} : shift1r;
assign shift4r = (shift_amount[2] == 1) ? {fills[3:0],shift2r[31:4]} : shift2r;
assign shift8r = (shift_amount[3] == 1) ? {fills[7:0],shift4r[31:8]} : shift4r;
assign shift16r = (shift_amount[4] == 1)?{fills[15:0],shift8r[31:16]} : shift8r;

reg [31:0] alu_out;

reg [6:0]  opcode_ex;
reg [4:0]  rd_ex;
reg [31:0] imm_u_ex;
reg [31:0] pc_ex;

wire [31:0] dmem_addr;
reg [31:0] dmem_wdata;
reg [31:0] dmem_wmask;

assign dmem_addr = rv1 + imm_s;

reg take_branch;

always @(posedge I_clk) begin
        if (I_rst) begin
        	alu_out = 32'b0;
        	next_pc = 32'b0;
		O_dmem_rd = 0;
		O_dmem_we = 0;
		O_dmem_wmask = 4'b0000;
		O_dmem_wdata = 32'h0;
	end else begin
        	case (opcode)
		7'b1101111: begin
				next_pc = pc + imm_j; //JAL
				alu_out = 32'b0;
			end
		7'b1100111: begin
			       	next_pc =  (rv1 + imm_i ) & ~1; //JALR
				alu_out = 32'b0;
			end
            	7'b0110011: begin // R-type
                	case ({funct7, funct3})
                    	{7'b0000000,3'b000}: alu_out = rv1 + rv2; // ADD
                    	{7'b0100000,3'b000}: alu_out = rv1 - rv2; // SUB
                    	{7'b0000000,3'b001}: alu_out = rv1 << rv2[4:0]; // SLL
                    	{7'b0000000,3'b010}: alu_out = 
			    ($signed(rv1) < $signed(rv2)) ? 32'b1 : 32'b0; //SLT
                    	{7'b0000000,3'b011}: alu_out =
			    (rv1 < rv2) ? 32'b1 : 32'b0; // SLTU
                    	{7'b0000000,3'b100}: alu_out = rv1 ^ rv2; // XOR
                    	{7'b0000000,3'b101}: alu_out = rv1 >> rv2[4:0]; // SRL
                    	{7'b0100000,3'b101}: alu_out = 
			    $signed(rv1) >>> rv2[4:0]; // SRA
                    	{7'b0000000,3'b110}: alu_out = rv1 | rv2; // OR
                    	{7'b0000000,3'b111}: alu_out = rv1 & rv2; // AND
			default: begin 
				alu_out = 32'b0;
			end
           		endcase
			next_pc = (pc + 4);
            	end
            	7'b0010011: begin // I-type ALU
                		case (funct3)
                    		3'b000: alu_out = rv1 + imm_i; // ADDI
                    		3'b010: alu_out = 
					($signed(rv1) < $signed(imm_i)) 
		    			? 32'b1 : 32'b0; // SLTI
                    		3'b011: alu_out = (rv1 < imm_i) 
					? 32'b1 : 32'b0; // SLTIU
                    		3'b100: alu_out = rv1 ^ imm_i; // XORI
                    		3'b110: alu_out = rv1 | imm_i; // ORI
                    		3'b111: alu_out = rv1 & imm_i; // ANDI
                    		3'b001: alu_out = shift16l; // SLLI
                    		3'b101: alu_out = shift16r; // SRLI/SRAI
				default: begin 
					alu_out = 32'b0;
				end
                		endcase
				next_pc = (pc + 4);
            		end
		7'b1100011: begin 
				case (funct3)
            			3'b000: take_branch = rv1 == rv2; // BEQa
            			3'b001: take_branch =  rv1 != rv2; // BNE
            			3'b100: take_branch =  
					$signed(rv1) < $signed(rv2); // BLT
            			3'b101: take_branch =  
					$signed(rv1) >= $signed(rv2); // BGE
            			3'b110: take_branch =  rv1 < rv2; // BLTU
            			3'b111: take_branch =  rv1 >= rv2;    // BGEU
				default: take_branch = 0;
				endcase
				next_pc = take_branch ? (pc + imm_b): (pc + 4);
			end
		default: begin 
				alu_out = 32'b0;
				next_pc = (pc + 4);
			end
        	endcase
		O_dmem_addr = dmem_addr;
		if (opcode == 7'b0100011) begin
			dmem_wdata = rv2;
			if (funct3  == 4'b000) begin
				O_dmem_wmask = 4'b0001 << dmem_addr[1:0]; // SB
			end else if (funct3  == 4'b001) begin
				O_dmem_wmask = 4'b0011 << dmem_addr[1:0]; // SH
			end else begin
				O_dmem_wmask = 4'b1111; // SW
			end
			O_dmem_wdata = rv2;
			O_dmem_we = 1;
			O_dmem_rd = 0;
		end else if (opcode == 7'b0000011) begin
			O_dmem_wdata = 32'h0;
			O_dmem_wmask = 4'b0000;
			O_dmem_rd = 1;
			O_dmem_we = 0;
		end else begin
			O_dmem_wdata = 32'h0;
			O_dmem_wmask = 4'b0000;
			O_dmem_rd = 0;
			O_dmem_we = 0;
		end
	end
	opcode_ex = opcode;
	rd_ex = rd;
	imm_u_ex = imm_u;
	pc_ex = pc_id;
end

// stage 4: MEM memory access
reg [31:0] dmem_rdata;
reg [6:0]  opcode_mem;
reg [4:0]  rd_mem;
reg [31:0] imm_u_mem;
reg [31:0] pc_mem;
reg [31:0] alu_out_mem;

always @(posedge I_clk) begin
        if (I_rst) begin
	end else begin
		if (opcode_ex == 7'b0000011) begin
			dmem_rdata = I_dmem_rdata; // Load
		end else begin
		end
	end
	opcode_mem = opcode_ex;
	rd_mem = rd_ex;
	imm_u_mem = imm_u_ex;
	pc_mem = pc_ex;
	alu_out_mem = alu_out;
end

// stage 5: WB write back
always @(posedge I_clk) begin
        if (I_rst) begin
	end else begin 
		case (opcode_mem)
        	7'b0110011: regfile[rd_mem] = alu_out_mem; // R-type
        	7'b0010011: regfile[rd_mem] = alu_out_mem; // I-type ALU
        	7'b0000011: regfile[rd_mem] = dmem_rdata; // Loads
		7'b1101111: regfile[rd_mem] = pc_mem + 4; //JAL
		7'b1100111: regfile[rd_mem] = pc_mem + 4; //JALR
        	7'b0110111: regfile[rd_mem] = imm_u_mem; // LUI
        	7'b0010111: regfile[rd_mem] = pc_mem + imm_u_mem;// AUIPC
		endcase
	end
end

endmodule

