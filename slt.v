// /*
//     Module for the Set Less than Unisigned instruction
//     intakes input A and B, along with the result from the comparator function iSet
//     Outputs oData, either 1 or 0
//         1 if A < B, 0 otherwise
// */

module slt (
    input [31:0] iDataA,
    input [31:0] iDataB,
    output [31:0] oData
  );

  // Find twos complement of B -----
  wire [31:0] invertB;
  wire [31:0] diff;
  /* verilator lint_off UNUSED */
  wire oCout; // unused
  wire oZero; // unsused
  assign invertB = ~iDataB;
  /* verilator lint_on UNUSED */

  // Check A - B
  LCA sub (
        .iDataA(iDataA),
        .iDataB(invertB),
        .iCin(1'b1),
        .oData(diff),
        .oCout(oCout),
        .oZero(oZero)
    );

    /* verilator lint_off UNUSED */
    wire [31:0] diff_unused = diff; 
    /* verilator lint_on UNUSED */

    // Check if there was overflow in the sub
    wire overflow;
    // if overflow with +A -B (should be pos) and -A +B (should be neg)
    assign overflow = (iDataA[31] & !iDataB[31] & !diff[31]) | (!iDataA[31] & iDataB[31] & diff[31]);

  assign oData = {31'b0, diff[31] ^ overflow}; // if last bit is 1, then overflow -> negative, so A is less than
endmodule
