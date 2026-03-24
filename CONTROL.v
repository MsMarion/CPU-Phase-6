module CONTROL (
    input [6:0] iOpcode,
    output oLui,
    output oPcSrc,
    output oMemRd,
    output oMemWr,
    output [2:0] oAluOp,
    output oMemtoReg,
    output oAluSrc1,
    output oAluSrc2,
    output oRegWrite,
    output oBranch,
    output oJump,
    output oFinish
);

// Use assign and registers so we can use the 'always' loop.
reg rLui, rPcSrc, rMemRd, rMemWr, rMemtoReg, rAluSrc1, rAluSrc2, rRegWrite, rBranch, rJump, rFinish;
reg [2:0] rAluOp;

assign oLui      = rLui;
assign oPcSrc    = rPcSrc;
assign oMemRd    = rMemRd;
assign oMemWr    = rMemWr;
assign oAluOp    = rAluOp;
assign oMemtoReg = rMemtoReg;
assign oAluSrc1  = rAluSrc1;
assign oAluSrc2  = rAluSrc2;
assign oRegWrite = rRegWrite;
assign oBranch   = rBranch;
assign oJump     = rJump;
assign oFinish   = rFinish;


// Very similar logic to decoder. Map opcode -> flags.
always @(*) begin
    
    rLui      = 0;
    rPcSrc    = 0;
    rMemRd    = 0;
    rMemWr    = 0;
    rAluOp    = 3'b000;
    rMemtoReg = 0;
    rAluSrc1  = 0;
    rAluSrc2  = 0;
    rRegWrite = 0;
    rBranch   = 0;
    rJump     = 0;
    rFinish   = 0;

    case (iOpcode)

        // R-type
        7'b0110011: begin 
            rRegWrite = 1;
            rAluOp    = 3'b010;
        end

        // I-type ALU
        7'b0010011: begin 
            rRegWrite = 1;
            rAluSrc2  = 1;
            rAluOp    = 3'b011;
        end

        // Load
        7'b0000011: begin 
            rRegWrite = 1;
            rMemRd    = 1;
            rMemtoReg = 1;
            rAluSrc2  = 1;
            rAluOp = 3'b000;
        end

        // Store
        7'b0100011: begin 
            rMemWr    = 1;
            rAluSrc2  = 1;
            rAluOp = 3'b000;
        end

        // Branch
        7'b1100011: begin 
            rBranch   = 1;
            rPcSrc    = 0;
            rAluOp    = 3'b001;
        end

        // LUI
        7'b0110111: begin 
            rRegWrite = 1;
            rLui      = 1;
        end

        // AUIPC
        7'b0010111: begin 
            rRegWrite = 1;
            rAluSrc1  = 1;
            rAluSrc2  = 1;
            rAluOp = 3'b000;
        end

        // JAL
        7'b1101111: begin 
            rRegWrite = 1;
            rJump     = 1;
            rPcSrc = 0;
            rBranch = 0;
        end

        // JALR
        7'b1100111: begin 
            rRegWrite = 1;
            rJump     = 1;
            rPcSrc    = 1;
            rAluSrc2  = 1;
            rAluOp = 3'b000;
        end

        // SYSTEM (ebreak, ecall)
        7'b1110011: begin
            rFinish = 1;
        end


        default: begin end

    endcase
end

endmodule