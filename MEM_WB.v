module MEM_WB(
    input  wire        clk,
    input  wire        rst,

    // Control signals from MEM
    input  wire        iMemToReg,
    input  wire        iRegWrite,
    input  wire        iJump,
    input  wire        iLui,
    input  wire        iMemRead,

    // Data signals
    input  wire [31:0] i_mem_data,
    input  wire [31:0] i_ALU_result,
    input  wire [4:0]  i_rd_num,
    input  wire [31:0] i_imm,
    input  wire [31:0] i_pc_plus_4,
    input  wire        iFinish,

    // Output to WB stage
    output reg         oMemToReg,
    output reg         oRegWrite,
    output reg         oJump,
    output reg         oLui,
    output reg         oMemRead,

    output reg [31:0]  o_mem_data,
    output reg [31:0]  o_ALU_result,
    output reg [4:0]   o_rd_num,
    output reg [31:0]  o_imm,
    output reg [31:0]  o_pc_plus_4,
    output reg         oFinish
);

always @(posedge clk) begin
    if (rst) begin
        oMemToReg    <= 1'b0;
        oRegWrite    <= 1'b0;
        oJump        <= 1'b0;
        oLui         <= 1'b0;

        o_mem_data   <= 32'b0;
        o_ALU_result <= 32'b0;
        o_rd_num     <= 5'b00000;
        o_imm        <= 32'b0;
        o_pc_plus_4  <= 32'b0;
        oFinish      <= 1'b0;
        oMemRead     <= 1'b0;
    end
    else begin
        oMemToReg    <= iMemToReg;
        oRegWrite    <= iRegWrite;
        oJump        <= iJump;
        oLui         <= iLui;
        oMemRead     <= iMemRead;

        o_mem_data   <= i_mem_data;
        o_ALU_result <= i_ALU_result;
        o_rd_num     <= i_rd_num;
        o_imm        <= i_imm;
        o_pc_plus_4  <= i_pc_plus_4;
        oFinish      <= iFinish;
    end
end

endmodule
