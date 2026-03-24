/*
    The branch and jump unit are used to adjust the PC
    to go to different instruction address rather than just
    incrementing.
 
    Default PC + 4 (go to next instruction even if no branch/jump)
    
    The branch and jump unit then can select to use an offset,
    which will be used in place of incrementing.
 
        Branch & Jump: PC = base address + Offset
    
    Finally, the branch and jump unit can start with a different source address,
    selecting between the PC and an address from a register. The output of the
    branch and jump unit is always the next instruction address to be processed
*/


module BRANCH_JUMP (
    input iBranch,          // if using branching
    input iJump,            // if using jumping
    input iZero,            // keeps track if branch condition met
    input [31:0] iOffset,   // offset
    input [31:0] iPc,       // current PC if not using register
    input [31:0] iRs1,      // reg source
    input iPcSrc,           // flag to determine if using reg or pc
    output [31:0] oPc       // pc output
  );

  wire branch;
  wire [31:0] base;
  wire [31:0] offset;

  /* verilator lint_off UNUSED */
  wire oCout; // unused
  wire oZero; // unsused
  /* verilator lint_on UNUSED */

  // obtain branch flag
  assign branch = ((iBranch && iZero) || iJump) ? 1'b1 : 1'b0;

  // if branch taken, find the offset
  assign offset = (branch) ? iOffset : 32'd4;

  assign base = (iPcSrc && iJump) ? iRs1 : iPc;

  // calculate the final output program counter
  // oPC = base address + offset
  wire [31:0] wRawPc;

  LCA programCounter (
        .iDataA(base),
        .iDataB(offset),
        .iCin(1'b0),
        .oData(wRawPc),
        .oCout(oCout),
        .oZero(oZero)
      );

  // JALR requires LSB forced to 0 (RISC-V spec)
  assign oPc = (iJump && iPcSrc) ? (wRawPc & ~32'd1) : wRawPc;

endmodule
