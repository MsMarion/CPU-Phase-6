// selects between two data inputs
module MUX_2_1 #(
    parameter WIDTH = 32
) (
    input [WIDTH-1:0] iData0,
    input [WIDTH-1:0] iData1,
    input iSel, // iSel=0, iData0 and iSel=1, iData1
    output [WIDTH-1:0] oData
);
    // set output to iData1 if iSel is 1 and iData0 if iSel is 0
    assign oData = iSel ? iData1 : iData0;
    
endmodule