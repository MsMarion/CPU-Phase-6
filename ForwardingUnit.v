module ForwardingUnit (
    // ex->ex, mem->ex
    input [4:0] ID_EX_rs1, // cur in ex
    input [4:0] ID_EX_rs2, // cur in ex
    input [4:0] EX_MEM_rd, // dest reg for problem inst (one ahead) in mem (ex->ex problem)
    input [4:0] MEM_WB_rd, // dest reg for problem inst (two ahead) in wb (mem->ex problem)
    input EX_MEM_RegWrite, // indicates if reg can write
    input MEM_WB_RegWrite, // indicates if reg can write

    // mem->mem
    input  [4:0] EX_MEM_rs2, // source, holds reg whose value being written
    input MEM_WB_MemRead, // says if inst in wb was load (prevents false triggers)

    // outputs
    output reg [1:0] ForwardA, // rs1 input
    output reg [1:0] ForwardB, // rs2 input
    // create a mux saying if hazards
    // 00, no hazard
    // 10, ex->ex use ex mem alu res
    // 01 mem->ex use mem wb res

    output reg ForwardMem // when 1, gives new wb
);

// combinational, no past memory
always @(*) begin
    
    ForwardA = 2'b00;
    ForwardB = 2'b00;
    ForwardMem = 1'b0;

    // forward a, rs1 input
    if(EX_MEM_RegWrite && EX_MEM_rd!=5'd0 && ID_EX_rs1==EX_MEM_rd) begin
       ForwardA = 2'b10; 
        
    end
    else if (MEM_WB_RegWrite && MEM_WB_rd!=5'd0 && ID_EX_rs1==MEM_WB_rd) begin
        ForwardA = 2'b01;

    end

    // forward b, rs2 input
    if(EX_MEM_RegWrite && EX_MEM_rd!=5'd0 && ID_EX_rs2==EX_MEM_rd) begin
       ForwardB = 2'b10; 
        
    end
    else if (MEM_WB_RegWrite && MEM_WB_rd!=5'd0 && ID_EX_rs2==MEM_WB_rd) begin
        ForwardB = 2'b01;

    end
    
    // forward mem, for reading newly loaded reg
    if(MEM_WB_MemRead && MEM_WB_rd!=5'd0 && EX_MEM_rs2==MEM_WB_rd) begin
        ForwardMem = 1'b1;
    end

end

endmodule