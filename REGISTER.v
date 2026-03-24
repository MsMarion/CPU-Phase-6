// Register module definition
/*
- has input ports and output ports 
- flipflops, rise or fall depending on clock
- combinational circuits depend on current inputs, no connection to past inputs
- sequential circuits use memory, and outputs depend on current and prior inputs
- we write to output when read/write signal is high 
- we read value from memory when read/write signal is low
- flipflops are triggered at edges (sync) and latches are triggered with levels (over period of time; async)
*/

// verilog learning resources:
/*
https://www.asic-world.com/verilog/verilog_one_day3.html
https://hwlabnitc.github.io/Verilog/registers.html
https://www.chipverify.com/tutorials/systemverilog
*/

module REGISTER (
    input iClk,              // Clock input
    input iRstN,             // Active low reset input
    input iWriteEn,          // Write enable input
    input [4:0] iRdAddr,     // 5 bit register address input
    input [4:0] iRs1Addr,    // 5 bit source register 1 address input
    input [4:0] iRs2Addr,    // 5 bit source register 2 address input
    input [31:0] iWriteData, // 32 bit data input to store in register
    output [31:0] oRs1Data,  // 32 bit source register 1 data output
    output [31:0] oRs2Data   // 32 bit source register 2 data output
  );
  // vector with registers, 32 bits
  reg [31:0] registers [31:0];

  integer j;
  initial
  begin
    for (j = 0; j < 32; j = j + 1)
      registers[j] = 32'b0;
  end

  integer i;

  // writing is sequential
  // says to always execute when it's positive edge for the clock, or when we need to reset
  always @(posedge iClk or negedge iRstN)
  begin
    // N stands for negative; iRstN is active when low
    // go ahead and reset all registers
    if (!iRstN)
    begin
      for(i=0; i<32; i=i+1)
      begin
        registers[i]<=32'b0; // sets to 0 in binary

      end

      // read write logic
    end
    else
    begin
      // write
      // write only when iWriteEn is high and on postedge and additionally only when the address input is not x0
      if((iWriteEn) && (iRdAddr!=5'b0))
      begin
        registers[iRdAddr]<=iWriteData; // <= is non-blocking for sequential logic; = is combinational

      end


    end
  end

  // combinational logic
  // assign is for combinational logic, uses state buffers a lot

  // Write-forwarding: if WB is writing to the same register being read this cycle,
  // return the new write data directly instead of the (not-yet-updated) array value.
  // This fixes the write-read same-cycle race where a load result committed to WB
  // at the same posedge that the dependent instruction is in ID.
  assign oRs1Data = (iRs1Addr == 5'b00000) ? 32'h00000000 :
                    (iWriteEn && (iRdAddr != 5'b00000) && (iRdAddr == iRs1Addr)) ? iWriteData :
                    registers[iRs1Addr];

  assign oRs2Data = (iRs2Addr == 5'b00000) ? 32'h00000000 :
                    (iWriteEn && (iRdAddr != 5'b00000) && (iRdAddr == iRs2Addr)) ? iWriteData :
                    registers[iRs2Addr];


endmodule