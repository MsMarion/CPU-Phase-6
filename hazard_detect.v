// Two types of hazards: EX hazard and MEM hazard


// EX hazard pseudo code:
  // can do the same thing for each forward A and forward B, but for simplicity, i just did for forward A
/*
    if(EX/MEM.RegWrite && EX/MEM.RegisterRd != 0 && EX/MEM.RegisterRd == ID/EX.RegisterRs1) 
        ForwardA = 10; // Forward from EX/MEM
    else if(MEM/WB.RegWrite && MEM/WB.RegisterRd != 0 && MEM/WB.RegisterRd == ID/EX.RegisterRs) 
        ForwardA = 01; // Forward from MEM/WB
    else 
        ForwardA = 00; // No hazard
*/

//  MEM hazard pseudo code:
/*
    if(MEM/WB.RegWrite && MEM/WB.RegisterRd != 0 && MEM/WB.RegisterRd == ID/EX.RegisterRt) 
        ForwardA = 10; // Forward from MEM/WB
    else 
        ForwardA = 00; // No hazard
*/

// MUX Control Values:
/*
        ForwardA = 00 -> Source: ID/EX -> First ALU operand comes from register file
        ForwardA = 01 -> Source: MEM/WB -> First ALU operand forwarded from data mem OR earlier ALU result
        ForwardA = 10 -> Source: EX/MEM -> First ALU operand forwarded from prior ALU result
        
        ForwardB = 00 -> Source: ID/EX -> Second ALU operand comes from register file (no hazard)
        ForwardB = 01 -> Source: MEM/WB -> Second ALU operand forwarded from data mem OR earlier ALU result
        ForwardB = 10 -> Source: EX/MEM -> Second ALU operand forwarded from prior ALU result

*/

module hazard_detect(
    input wire iIDExMemRead, // true iff instruction in EX is load type
    input wire [4:0] iIDExRegisterRd, 
    input wire [4:0] iIFIdRegisterRs1, 
    input wire [4:0] iIFIdRegisterRs2, 
    input wire iID_isStore,
    output reg oPCWrite,
    output reg oIFIDWrite,
    output reg ID_EX_Flush // 1 -> stall (for bubble), 0 -> continue
);

    always @(*) begin
        // Check for Load-Use Hazard
        if (iIDExMemRead && (iIDExRegisterRd != 0) && ((iIDExRegisterRd == iIFIdRegisterRs1) || ((iIDExRegisterRd == iIFIdRegisterRs2) && !iID_isStore))) begin
            // stall!! insert bubbles!!!
            oPCWrite = 1'b0;
            oIFIDWrite = 1'b0;
            ID_EX_Flush = 1'b1; // trigger the flush signal
        end else begin
            // normal otherwise :3
            oPCWrite = 1'b1;
            oIFIDWrite = 1'b1;
            ID_EX_Flush = 1'b0; 
        end
    end
endmodule
