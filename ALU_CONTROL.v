module ALU_CONTROL (
    input [2:0] iAluOp,
    input [2:0] iFunct3,
    input [6:0] iFunct7,
    output [3:0] oAluCtrl
  );

  /* iAluOp Descriptions:
      000
          ADD (default)
          loads, stores, JAL, JALR, AUIPC
      001
          Branch compare
          BEQ/BNE/BLT/BGE/etc.
      010
          R-type
          ADD/SUB/AND/OR/XOR/etc.
      011
          I-type ALU
          ADDI/ANDI/ORI/etc.
  */


  // ALU Control Values
  localparam ADD = 4'b0000;
  localparam SUB = 4'b1000;
  localparam SLL = 4'b0001;
  localparam SRL = 4'b1001;
  localparam SRA = 4'b1101;
  localparam SLT = 4'b0010;
  localparam SLTU = 4'b0011;
  localparam XOR = 4'b0100;
  localparam OR = 4'b0110;
  localparam AND = 4'b0111;
  localparam BEQ = 4'b1000;
  localparam BNE = 4'b1100;
  localparam BLT = 4'b1010;
  localparam BGE = 4'b1110;
  localparam BLTU = 4'b1011;
  localparam BGEU = 4'b1111;


  // Internal reg for combinational logic
  reg [3:0] rAluCtrl;
  assign oAluCtrl = rAluCtrl;

  always @(*)
  begin
    rAluCtrl = 4'b0000;
    case (iAluOp)

      3'b000: // Adding values for later use in ALU
        // why add? Because the remaning instrctions (not listed above)
        // are fundamentally adding numbers and saving them in specific places
      begin
        rAluCtrl = ADD;
      end

      3'b001: // BRANCH INSTRUCTIONS
      begin
        if(iFunct3 == 3'd0)
          rAluCtrl = BEQ;

        if(iFunct3 == 3'b001)
          rAluCtrl = BNE;

        if(iFunct3 == 3'b100)
          rAluCtrl = BLT;

        if(iFunct3 == 3'b101)
          rAluCtrl = BGE;

        if(iFunct3 == 3'b110)
          rAluCtrl = BLTU;

        if(iFunct3 == 3'b111)
          rAluCtrl = BGEU;
      end

      3'b010: // R-TYPE INSTRUCTIONS
      begin
        if(iFunct3 == 3'd0 && iFunct7 == 7'd0)
          rAluCtrl = ADD;

        if(iFunct3 == 3'd0 && iFunct7 == 7'b0100000)
          rAluCtrl = SUB;

        if(iFunct3 == 3'b001 && iFunct7 == 7'd0)
          rAluCtrl = SLL;

        if(iFunct3 == 3'b010 && iFunct7 == 7'd0)
          rAluCtrl = SLT;

        if(iFunct3 == 3'b011 && iFunct7 == 7'd0)
          rAluCtrl = SLTU;

        if(iFunct3 == 3'b100 && iFunct7 == 7'd0)
          rAluCtrl = XOR;

        if(iFunct3 == 3'b101 && iFunct7 == 7'd0)
          rAluCtrl = SRL;

        if(iFunct3 == 3'b101 && iFunct7 == 7'b0100000)
          rAluCtrl = SRA;

        if(iFunct3 == 3'b110 && iFunct7 == 7'd0)
          rAluCtrl = OR;

        if(iFunct3 == 3'b111 && iFunct7 == 7'd0)
          rAluCtrl = AND;

      end

      3'b011: // I-TYPE INSTRUCTIONS
      begin
        if(iFunct3 == 3'd0)
          rAluCtrl = ADD;

        if(iFunct3 == 3'b001 && iFunct7 == 7'd0)
          rAluCtrl = SLL;

        if(iFunct3 == 3'b010)
          rAluCtrl = SLT;

        if(iFunct3 == 3'b011)
          rAluCtrl = SLTU;

        if(iFunct3 == 3'b100)
          rAluCtrl = XOR;

        if(iFunct3 == 3'b101 && iFunct7 == 7'd0)
          rAluCtrl = SRL;

        if(iFunct3 == 3'b101 && iFunct7 == 7'b0100000)
          rAluCtrl = SRA;

        if(iFunct3 == 3'b110)
          rAluCtrl = OR;

        if(iFunct3 == 3'b111)
          rAluCtrl = AND;
      end


      default:
      begin
      end
    endcase
  end

endmodule