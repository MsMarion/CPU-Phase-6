/* verilator lint_off DECLFILENAME */
// /*
//     Comparator module compares input and output
//     If A > B -> oData[0] = 1
//     If A = B -> oData[1] = 1
//     If A < B -> oData[2] = 1
// */
module Comparator (
    input [31:0] iDataA,
    input [31:0] iDataB,
    output [2:0] oData
  );
  assign oData[0] = (iDataA > iDataB) ? 1'b1 : 1'b0;
  assign oData[1] = (iDataA == iDataB) ? 1'b1 : 1'b0;
  assign oData[2] = (iDataA < iDataB) ? 1'b1 : 1'b0;
endmodule
/* verilator lint_on DECLFILENAME */
