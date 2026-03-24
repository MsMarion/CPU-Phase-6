module ID_EX(
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,   // from hazard unit
    input  wire        flush,   // from branch/jump logic

    // Control signals from ID
    input  wire        iPcSrc,
    input  wire        iMemRead,
    input  wire        iMemWrite,
    input  wire [2:0]  iAluOp,
    input  wire        iMemToReg,
    input  wire        iAluSrc1,
    input  wire        iAluSrc2,
    input  wire        iRegWrite,
    input  wire        iBranch,
    input  wire        iJump,
    input  wire        iLui,

    // Extra inputs
    input  wire [31:0] i_rs1_value,
    input  wire [31:0] i_rs2_value,
    input  wire [31:0] i_PC,
    input  wire [31:0] i_imm,
    input  wire [4:0]  i_rs1_num,   // for forwarding
    input  wire [4:0]  i_rs2_num,
    input  wire [4:0]  i_rd_num,
    input  wire [2:0]  i_funct3,    // for ALU and MEM control
    input  wire [6:0]  i_funct7,    // for ALU control
    input  wire        iFinish,

    // Outputs to EX stage
    output reg         oPcSrc,
    output reg         oMemRead,
    output reg         oMemWrite,
    output reg  [2:0]  oAluOp,
    output reg         oMemToReg,
    output reg         oAluSrc1,
    output reg         oAluSrc2,
    output reg         oRegWrite,
    output reg         oBranch,
    output reg         oJump,
    output reg         oLui,

    output reg [31:0]  o_rs1_value,
    output reg [31:0]  o_rs2_value,
    output reg [31:0]  o_PC,
    output reg [31:0]  o_imm,
    output reg [4:0]   o_rs1_ptr,
    output reg [4:0]   o_rs2_ptr,
    output reg [4:0]   o_rd_ptr,
    output reg [2:0]   o_funct3,
    output reg [6:0]   o_funct7,
    output reg         oFinish
);

always @(posedge clk) begin
    if (rst || flush) begin
        // Bubble or reset
        oPcSrc      <= 1'b0;
        oMemRead    <= 1'b0;
        oMemWrite   <= 1'b0;
        oAluOp      <= 3'b000;
        oMemToReg   <= 1'b0;
        oAluSrc1    <= 1'b0;
        oAluSrc2    <= 1'b0;
        oRegWrite   <= 1'b0;
        oBranch     <= 1'b0;
        oJump       <= 1'b0;
        oLui        <= 1'b0;

        o_rs1_value <= 32'b0;
        o_rs2_value <= 32'b0;
        o_PC        <= 32'b0;
        o_imm       <= 32'b0;
        o_rs1_ptr   <= 5'b00000;
        o_rs2_ptr   <= 5'b00000;
        o_rd_ptr    <= 5'b00000;
        o_funct3    <= 3'b000;
        o_funct7    <= 7'b0000000;
        oFinish     <= 1'b0;
    end
    else if (!stall) begin
        oPcSrc      <= iPcSrc;
        oMemRead    <= iMemRead;
        oMemWrite   <= iMemWrite;
        oAluOp      <= iAluOp;
        oMemToReg   <= iMemToReg;
        oAluSrc1    <= iAluSrc1;
        oAluSrc2    <= iAluSrc2;
        oRegWrite   <= iRegWrite;
        oBranch     <= iBranch;
        oJump       <= iJump;
        oLui        <= iLui;

        o_rs1_value <= i_rs1_value;
        o_rs2_value <= i_rs2_value;
        o_PC        <= i_PC;
        o_imm       <= i_imm;
        o_rs1_ptr   <= i_rs1_num;
        o_rs2_ptr   <= i_rs2_num;
        o_rd_ptr    <= i_rd_num;
        o_funct3    <= i_funct3;
        o_funct7    <= i_funct7;
        oFinish     <= iFinish;
    end
end

endmodule