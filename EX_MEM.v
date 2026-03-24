module EX_MEM(
    input  wire        clk,
    input  wire        rst,

    // Control signals from EX
    input  wire        iMemRead,
    input  wire        iMemWrite,
    input  wire        iMemToReg,
    input  wire        iRegWrite,
    input  wire        iBranch,
    input  wire        iJump,
    input  wire        iLui,
    input  wire [31:0] i_imm,

    // Data signals
    input  wire [31:0] i_ALU_result,   // ALU output
    input  wire        i_zero,         // branch condition
    input  wire [31:0] i_offset,       // immediate or offset for PC update
    input  wire [31:0] i_rs2_value,    // store data
    input  wire [4:0]  i_rs2_ptr,
    input  wire [2:0]  i_funct3,
    input  wire [4:0]  i_rd_num,
    input  wire [31:0] i_base_pc,      // PC or rs1, already selected in EX
    input  wire        iFinish,

    // Outputs to MEM stage
    output reg         oMemRead,
    output reg         oMemWrite,
    output reg         oMemToReg,
    output reg         oRegWrite,
    output reg         oBranch,
    output reg         oJump,
    output reg         oLui,
    output reg [31:0]  o_imm,

    output reg [31:0]  o_ALU_result,
    output reg         o_zero,
    output reg [31:0]  o_offset,
    output reg [31:0]  o_rs2_value,
    output reg [4:0]   o_rs2_ptr,
    output reg [2:0]   o_funct3,
    output reg [4:0]   o_rd_num,
    output reg [31:0]  o_base_pc,
    output reg         oFinish
);


always @(posedge clk) begin
    if (rst) begin
        oMemRead     <= 1'b0;
        oMemWrite    <= 1'b0;
        oMemToReg    <= 1'b0;
        oRegWrite    <= 1'b0;
        oJump        <= 1'b0;
        oLui         <= 1'b0;
        o_imm        <= 32'b0;

        o_ALU_result <= 32'b0;
        o_zero       <= 1'b0;
        o_offset     <= 32'b0;
        o_rs2_value  <= 32'b0;
        o_rs2_ptr    <= 5'b00000;
        o_funct3     <= 3'b000;
        o_rd_num     <= 5'b00000;
        o_base_pc    <= 32'b0;
        oBranch     <= 1'b0;
        oFinish      <= 1'b0;
    end
    else begin
        oMemRead     <= iMemRead;
        oMemWrite    <= iMemWrite;
        oMemToReg    <= iMemToReg;
        oRegWrite    <= iRegWrite;
        oBranch      <= iBranch;
        oJump        <= iJump;
        oLui         <= iLui;
        o_imm        <= i_imm;

        o_ALU_result <= i_ALU_result;
        o_zero       <= i_zero;
        o_offset     <= i_offset;
        o_rs2_value  <= i_rs2_value;
        o_rs2_ptr   <= i_rs2_ptr;
        o_funct3     <= i_funct3;
        o_rd_num     <= i_rd_num;
        o_base_pc    <= i_base_pc;
        oFinish      <= iFinish;
    end
end


endmodule