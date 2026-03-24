// DECODER module definition
module DECODER (
    input [31:0] iInstr, // 32 bit instruction input

    output [6:0] oOpcode, // 7 bit opcode output (all types)
    output [4:0] oRd,     // 5 bit destination register output (R, I, U, J)
    output [2:0] oFunct3, // 3 bit function output (R, I, S, B)
    output [4:0] oRs1,    // 5 bit source register (R, I, S, B)
    output [4:0] oRs2,    // 5 bit source register (R, S, B)
    output [6:0] oFunct7, // 7 bit function output (R)
    output [31:0] oImm    // 32 bit immediate output (I, S, B, U, J)
);
    // oImm:
    //  sign extend
    //  use opcode to determine the immediate bitfields

    // Set fields
    assign oOpcode = iInstr[6:0];
    assign oRd     = iInstr[11:7];
    assign oFunct3 = iInstr[14:12];
    assign oRs1    = iInstr[19:15];
    assign oRs2    = iInstr[24:20];
    assign oFunct7 = iInstr[31:25];

    // Internal reg for combinational immediate logic
    reg [31:0] rImm;
    assign oImm = rImm;

    // Make the immediates
    always @(*) begin
        case (iInstr[6:0])

            // I-type
            7'b0010011, 7'b0000011, 7'b1100111: begin
                rImm = {{20{iInstr[31]}}, iInstr[31:20]};
            end

            // S-type
            7'b0100011: begin
                rImm = {{20{iInstr[31]}}, iInstr[31:25], iInstr[11:7]};
            end

            // B-type
            7'b1100011: begin
                rImm = {{19{iInstr[31]}}, iInstr[31], iInstr[7], iInstr[30:25], iInstr[11:8], 1'b0};
            end

            // U-type
            7'b0110111, 7'b0010111: begin
                rImm = {iInstr[31:12], 12'b0};
            end

            // J-type
            7'b1101111: begin
                rImm = {{11{iInstr[31]}}, iInstr[31], iInstr[19:12], iInstr[20], iInstr[30:21], 1'b0};
            end

            // SYSTEM (ebreak, ecall)
            7'b1110011: begin
                rImm = {{20{iInstr[31]}}, iInstr[31:20]}; // Same as I-type
            end

            // R-type or unknown
            default: begin
                rImm = 32'b0;
            end

        endcase
    end

endmodule