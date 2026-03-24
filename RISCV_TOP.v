module RISCV_TOP (
    input iClk,
    input iRstN,
    output oFinish // Added to signal end of simulation
  );

  // Autograder signals
  wire [31:0] wInstr, wPc;

  // ==========================================================================
  // 1. IF Stage (Instruction Fetch)
  // ==========================================================================
  wire [31:0] wActualNextPC, wIF_PC, wIF_Instr;
  reg  [31:0] rPC;
  wire wPCWrite, wIFIDWrite;

  always @(posedge iClk or negedge iRstN) begin
    if (~iRstN) rPC <= 32'h0;
    else if (wPCWrite) rPC <= wActualNextPC;
  end

  assign wIF_PC = rPC;

  INSTRUCTION_MEMORY instr_mem (
    .iRdAddr(wIF_PC),
    .oInstr(wIF_Instr)
  );

  // ==========================================================================
  // Pipeline Register: IF/ID
  // ==========================================================================
  wire [31:0] wID_PC, wID_Instr;
  wire wIDEXFlush, wBranchTaken; // wBranchTaken comes from EX stage logic

  IF_ID reg_if_id (
    .clk(iClk),
    .rst(~iRstN),
    .stall(~wIFIDWrite),
    .flush(wBranchTaken),
    .i_PC(wIF_PC),
    .i_instruction(wIF_Instr),
    .o_PC(wID_PC),
    .o_instruction(wID_Instr)
  );
  
  assign wPc    = wID_PC;    // Signal for autograder (IF/ID register PC output)
  assign wInstr = wID_Instr; // Signal for autograder (IF/ID register Instr output)


  // ==========================================================================
  // 2. ID Stage (Instruction Decode / Register Read)
  // ==========================================================================
  wire [6:0] wID_Opcode, wID_Funct7;
  wire [2:0] wID_Funct3;
  wire [4:0] wID_Rd, wID_Rs1, wID_Rs2;
  wire [31:0] wID_Imm, wID_Rs1Data, wID_Rs2Data;
  
  // Control Signals (ID Stage)
  wire wID_Lui, wID_PcSrc, wID_MemRd, wID_MemWr, wID_MemtoReg, wID_AluSrc1, wID_AluSrc2, wID_RegWrite, wID_Branch, wID_Jump;
  wire [2:0] wID_AluOp;

  DECODER decoder (
    .iInstr(wID_Instr),
    .oOpcode(wID_Opcode),
    .oRd(wID_Rd),
    .oFunct3(wID_Funct3),
    .oRs1(wID_Rs1),
    .oRs2(wID_Rs2),
    .oFunct7(wID_Funct7),
    .oImm(wID_Imm)
  );

  CONTROL control (
    .iOpcode(wID_Opcode),
    .oLui(wID_Lui),
    .oPcSrc(wID_PcSrc),
    .oMemRd(wID_MemRd),
    .oMemWr(wID_MemWr),
    .oAluOp(wID_AluOp),
    .oMemtoReg(wID_MemtoReg),
    .oAluSrc1(wID_AluSrc1),
    .oAluSrc2(wID_AluSrc2),
    .oRegWrite(wID_RegWrite),
    .oBranch(wID_Branch),
    .oJump(wID_Jump),
    .oFinish(wID_Finish)
  );
  wire wID_Finish;


  // Data for Register: RD address is from WB stage
  wire [4:0] wWB_Rd;
  wire wWB_RegWrite;
  wire [31:0] wWB_FinalWriteData;

  REGISTER register (
    .iClk(iClk),
    .iRstN(iRstN),
    .iWriteEn(wWB_RegWrite),
    .iRdAddr(wWB_Rd),
    .iRs1Addr(wID_Rs1),
    .iRs2Addr(wID_Rs2),
    .iWriteData(wWB_FinalWriteData),
    .oRs1Data(wID_Rs1Data),
    .oRs2Data(wID_Rs2Data)
  );

  // Hazard Detection Unit
  // Connect after Control since it needs MemRead from ID/EX (not yet defined)
  wire [4:0] wEX_Rd;
  wire wEX_MemRd;

  hazard_detect hazard_unit (
    .iIDExMemRead(wEX_MemRd),
    .iIDExRegisterRd(wEX_Rd),
    .iIFIdRegisterRs1(wID_Rs1),
    .iIFIdRegisterRs2(wID_Rs2),
    .iID_isStore(wID_MemWr), 
    .oPCWrite(wPCWrite),
    .oIFIDWrite(wIFIDWrite),
    .ID_EX_Flush(wIDEXFlush)
  );

  // ==========================================================================
  // Pipeline Register: ID/EX
  // ==========================================================================
  wire wEX_PcSrc, wEX_MemWr, wEX_MemtoReg, wEX_AluSrc1, wEX_AluSrc2, wEX_RegWrite, wEX_Branch, wEX_Jump, wEX_Lui;
  wire [2:0] wEX_AluOp, wEX_Funct3;
  wire [6:0] wEX_Funct7;
  wire [31:0] wEX_Rs1Data, wEX_Rs2Data, wEX_PC, wEX_Imm;
  wire [4:0] wEX_Rs1, wEX_Rs2;

  ID_EX reg_id_ex (
    .clk(iClk),
    .rst(~iRstN),
    .stall(1'b0),
    .flush(wIDEXFlush || wBranchTaken),
    .iPcSrc(wID_PcSrc),
    .iMemRead(wID_MemRd),
    .iMemWrite(wID_MemWr),
    .iAluOp(wID_AluOp),
    .iMemToReg(wID_MemtoReg),
    .iAluSrc1(wID_AluSrc1),
    .iAluSrc2(wID_AluSrc2),
    .iRegWrite(wID_RegWrite),
    .iBranch(wID_Branch),
    .iJump(wID_Jump),
    .iLui(wID_Lui),
    .i_rs1_value(wID_Rs1Data),
    .i_rs2_value(wID_Rs2Data),
    .i_PC(wID_PC),
    .i_imm(wID_Imm),
    .i_rs1_num(wID_Rs1),
    .i_rs2_num(wID_Rs2),
    .i_rd_num(wID_Rd),
    .i_funct3(wID_Funct3),
    .i_funct7(wID_Funct7),
    .iFinish(wID_Finish),
    // Outputs
    .oPcSrc(wEX_PcSrc),
    .oMemRead(wEX_MemRd),
    .oMemWrite(wEX_MemWr),
    .oAluOp(wEX_AluOp),
    .oMemToReg(wEX_MemtoReg),
    .oAluSrc1(wEX_AluSrc1),
    .oAluSrc2(wEX_AluSrc2),
    .oRegWrite(wEX_RegWrite),
    .oBranch(wEX_Branch),
    .oJump(wEX_Jump),
    .oLui(wEX_Lui),
    .o_rs1_value(wEX_Rs1Data),
    .o_rs2_value(wEX_Rs2Data),
    .o_PC(wEX_PC),
    .o_imm(wEX_Imm),
    .o_rs1_ptr(wEX_Rs1),
    .o_rs2_ptr(wEX_Rs2),
    .o_rd_ptr(wEX_Rd),
    .o_funct3(wEX_Funct3),
    .o_funct7(wEX_Funct7),
    .oFinish(wEX_Finish)
  );
  wire wEX_Finish;


  // ==========================================================================
  // 3. EX Stage (Execute)
  // ==========================================================================
  wire [1:0] wForwardA, wForwardB;
  wire [31:0] wAluDataA, wAluDataB, wAluResult;
  wire [3:0] wAluCtrl;
  wire wAluZero;
  
  // Forwarding Unit
  wire [4:0] wMEM_Rd, wWB_Rd;
  wire wMEM_RegWrite, wWB_RegWrite, wMEM_MemRd, wWB_MemRd;
  wire [31:0] wMEM_AluResult, wWB_FinalWriteData;

  ForwardingUnit forward_unit (
    .ID_EX_rs1(wEX_Rs1),
    .ID_EX_rs2(wEX_Rs2),
    .EX_MEM_rd(wMEM_Rd),
    .MEM_WB_rd(wWB_Rd),
    .EX_MEM_RegWrite(wMEM_RegWrite),
    .MEM_WB_RegWrite(wWB_RegWrite),
    .EX_MEM_rs2(wMEM_Rs2Ptr), // Passing current RS2 for store-after-load forwarding
    .MEM_WB_MemRead(wWB_MemRd),
    .ForwardA(wForwardA),
    .ForwardB(wForwardB),
    .ForwardMem(wForwardMem)
  );
  wire wForwardMem; // Note: This could be used for Store-after-Load forwarding

  // EX->EX forwarding must use the same value WB will eventually write,
  // not just the raw ALU result. For LUI the correct value is the immediate;
  // for JAL/JALR the correct value is PC+4 (the link address).
  wire [31:0] wMEM_ForwardData = wMEM_Lui  ? wMEM_Imm     :
                                  wMEM_Jump ? wMEM_PcPlus4 :
                                              wMEM_AluResult;

  // Select between RS1 data and forwarded values
  // Forwarding logic: 2'b10 = EX_MEM result, 2'b01 = WB result
  wire [31:0] wAluSrcA_raw, wAluSrcB_raw;
  assign wAluSrcA_raw = (wForwardA == 2'b10) ? wMEM_ForwardData :
                        (wForwardA == 2'b01) ? wWB_FinalWriteData :
                        wEX_Rs1Data;

  assign wAluSrcB_raw = (wForwardB == 2'b10) ? wMEM_ForwardData :
                        (wForwardB == 2'b01) ? wWB_FinalWriteData :
                        wEX_Rs2Data;

  MUX_2_1 #(32) alu_src1_mux (
    .iData0(wAluSrcA_raw),
    .iData1(wEX_PC),
    .iSel(wEX_AluSrc1),
    .oData(wAluDataA)
  );

  MUX_2_1 #(32) alu_src2_mux (
    .iData0(wAluSrcB_raw),
    .iData1(wEX_Imm),
    .iSel(wEX_AluSrc2),
    .oData(wAluDataB)
  );

  ALU_CONTROL alu_control (
    .iAluOp(wEX_AluOp),
    .iFunct3(wEX_Funct3),
    .iFunct7(wEX_Funct7),
    .oAluCtrl(wAluCtrl)
  );

  ALU alu (
    .iDataA(wAluDataA),
    .iDataB(wAluDataB),
    .iAluCtrl(wAluCtrl),
    .oData(wAluResult),
    .oZero(wAluZero)
  );

  BRANCH_JUMP branch_jump (
    .iBranch(wEX_Branch),
    .iJump(wEX_Jump),
    .iZero(wAluZero),
    .iOffset(wEX_Imm),
    .iPc(wEX_PC),
    .iRs1(wAluSrcA_raw),
    .iPcSrc(wEX_PcSrc),
    .oPc(wEX_BranchTarget)
  );
  wire [31:0] wEX_BranchTarget;
  
  assign wBranchTaken = (wEX_Branch && wAluZero) || wEX_Jump;
  
  // PC Update Logic: Normal = PC + 4, Branch/Jump = BranchTarget
  assign wActualNextPC = (wBranchTaken) ? wEX_BranchTarget : (~wPCWrite) ? wIF_PC : (wIF_PC + 32'd4); // Keep PC the same if stalling
                                         


  // ==========================================================================
  // Pipeline Register: EX/MEM
  // ==========================================================================
  wire wMEM_MemWr, wMEM_MemtoReg, wMEM_Jump, wMEM_Lui;
  wire [31:0] wMEM_Rs2Data, wMEM_PcPlus4, wMEM_Imm;
  wire [2:0] wMEM_Funct3;
  wire [4:0] wMEM_Rs2Ptr;

  EX_MEM reg_ex_mem (
    .clk(iClk),
    .rst(~iRstN),
    .i_rs2_ptr(wEX_Rs2),
    .iMemRead(wEX_MemRd),
    .iMemWrite(wEX_MemWr),
    .iMemToReg(wEX_MemtoReg),
    .iRegWrite(wEX_RegWrite),
    .iBranch(wEX_Branch),
    .iJump(wEX_Jump),
    .iLui(wEX_Lui),
    .i_imm(wEX_Imm),
    .i_ALU_result(wAluResult),
    .i_zero(wAluZero),
    .i_offset(wEX_Imm),
    .i_rs2_value(wAluSrcB_raw),
    .i_funct3(wEX_Funct3),
    .i_rd_num(wEX_Rd),
    .i_base_pc(wEX_PC + 4),
    .iFinish(wEX_Finish),
    .oMemRead(wMEM_MemRd),
    .oMemWrite(wMEM_MemWr),
    .oMemToReg(wMEM_MemtoReg),
    .oRegWrite(wMEM_RegWrite),
    .oLui(wMEM_Lui),
    .o_imm(wMEM_Imm),
    .o_ALU_result(wMEM_AluResult),
    .o_zero(wMEM_Zero),
    .o_offset(wMEM_Offset),
    .o_rs2_value(wMEM_Rs2Data),
    .o_rs2_ptr(wMEM_Rs2Ptr),
    .o_funct3(wMEM_Funct3),
    .o_rd_num(wMEM_Rd),
    .o_base_pc(wMEM_PcPlus4),
    .oJump(wMEM_Jump),
    .oBranch(wMEM_Branch),
    .oFinish(wMEM_Finish)
  );
  wire wMEM_Zero, wMEM_Branch, wMEM_Finish;

  wire [31:0] wMEM_Offset;

  // ==========================================================================
  // 4. MEM Stage (Memory Access)
  // ==========================================================================
  wire [31:0] wMEM_ReadData;
  wire [31:0] wActualMemWriteData;
  assign wActualMemWriteData = (wForwardMem) ? wWB_FinalWriteData : wMEM_Rs2Data;
  MEM_STAGE mem_stage (
    .iClk(iClk),
    .iRstN(iRstN),
    .iAddress(wMEM_AluResult),
    .iWriteData(wActualMemWriteData),
    .iFunct3(wMEM_Funct3),
    .iMemWrite(wMEM_MemWr),
    .iMemRead(wMEM_MemRd),
    .oReadData(wMEM_ReadData)
  );


  // ==========================================================================
  // Pipeline Register: MEM/WB
  // ==========================================================================
  wire wWB_MemtoReg, wWB_Jump, wWB_Lui;
  wire [31:0] wWB_MemData, wWB_AluResult, wWB_Imm, wWB_PcPlus4;

  MEM_WB reg_mem_wb (
    .clk(iClk),
    .rst(~iRstN),
    .iMemToReg(wMEM_MemtoReg),
    .iRegWrite(wMEM_RegWrite),
    .iJump(wMEM_Jump),
    .iLui(wMEM_Lui),
    .iMemRead(wMEM_MemRd),
    .i_mem_data(wMEM_ReadData),
    .i_ALU_result(wMEM_AluResult),
    .i_rd_num(wMEM_Rd),
    .i_imm(wMEM_Imm),
    .i_pc_plus_4(wMEM_PcPlus4),
    .iFinish(wMEM_Finish),
    .oMemToReg(wWB_MemtoReg),
    .oRegWrite(wWB_RegWrite),
    .oJump(wWB_Jump),
    .oLui(wWB_Lui),
    .oMemRead(wWB_MemRd),
    .o_mem_data(wWB_MemData),
    .o_ALU_result(wWB_AluResult),
    .o_rd_num(wWB_Rd),
    .o_imm(wWB_Imm),
    .o_pc_plus_4(wWB_PcPlus4),
    .oFinish(wWB_Finish)
  );
  wire wWB_Finish;
  assign oFinish = wWB_Finish;


  // ==========================================================================
  // 5. WB Stage (Write Back)
  // ==========================================================================
  wire [31:0] wWB_MemToRegData, wWB_WriteData;
  MUX_2_1 #(32) mem_to_reg_mux (
    .iData0(wWB_AluResult),
    .iData1(wWB_MemData),
    .iSel(wWB_MemtoReg),
    .oData(wWB_MemToRegData)
  );

  MUX_2_1 #(32) lui_mux (
    .iData0(wWB_MemToRegData),
    .iData1(wWB_Imm),
    .iSel(wWB_Lui),
    .oData(wWB_WriteData)
  );

  MUX_2_1 #(32) jump_wb_mux (
    .iData0(wWB_WriteData),
    .iData1(wWB_PcPlus4),
    .iSel(wWB_Jump),
    .oData(wWB_FinalWriteData)
  );

endmodule
