module XOR (
    input [31:0] iDataA,
    input [31:0] iDataB,
    output [31:0] oData
    );
    assign oData = iDataA ^ iDataB;
endmodule