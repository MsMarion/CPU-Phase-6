// interacts with memory SEPARATE from instruction memory
// read and writes to store and load values
module DATA_MEMORY (
    input iClk,
    input iRstN,
    input [31:0] iAddress,
    input [31:0] iWriteData,
    input [2:0] iFunct3, // selects width of the data; determines which read or store inst to do
    input iMemWrite,
    input iMemRead,
    output [31:0] oReadData
  );
  localparam B = 8;
  localparam K = 1024;
  localparam BASE  = 32'h1001_0000;
  localparam BYTES = K * 4; // 4096

  reg [B-1:0] rDataMem [0:BYTES-1]; // 4KB data memory, byte-addressable

  initial
  begin
    $readmemh("data.txt", rDataMem);
  end

  wire [11:0] bytesAddress = iAddress[11:0];
  wire check = 1'b1;

  // internal reg for combinational read logic
  reg [31:0] rReadData;
  assign oReadData = rReadData;

  // read logic
  // combinational logic, determined by current input without past inputs
  always @(*)
  begin
    rReadData = 32'b0;
    if (iMemRead == 1 && check)
    begin
      case (iFunct3) // changes oreaddata depending on funct3
        // load byte, signextend
        3'b000:
        begin
          rReadData = {{24{rDataMem[bytesAddress][7]}}, rDataMem[bytesAddress]};
        end

        // load halfword, signextend
        3'b001:
        begin
          rReadData = {{16{rDataMem[bytesAddress+1][7]}}, rDataMem[bytesAddress+1], rDataMem[bytesAddress]};
        end

        // load word
        3'b010:
        begin
          rReadData = {rDataMem[bytesAddress+3], rDataMem[bytesAddress+2], rDataMem[bytesAddress+1], rDataMem[bytesAddress]};
        end

        // load byte unsigned, zeroextend
        3'b100:
        begin
          rReadData = {24'b0, rDataMem[bytesAddress]};
        end

        // load halfword unsigned, zeroextend
        3'b101:
        begin
          rReadData = {16'b0, rDataMem[bytesAddress+1], rDataMem[bytesAddress]};
        end

        default:
          rReadData = 32'b0;

      endcase
    end
  end

  // write logic
  // clock here now lol
  always @(posedge iClk or negedge iRstN)
  begin
    if(!iRstN)
    begin

    end
    else if (iMemWrite == 1 && check)
    begin
      case (iFunct3)
        // store byte
        3'b000:
        begin
          rDataMem[bytesAddress+0] <= iWriteData[7:0];
        end

        // store half-word
        3'b001:
        begin
          rDataMem[bytesAddress+0] <= iWriteData[7:0];
          rDataMem[bytesAddress+1] <= iWriteData[15:8];
        end

        // store word
        3'b010:
        begin
          rDataMem[bytesAddress+0] <= iWriteData[7:0];
          rDataMem[bytesAddress+1] <= iWriteData[15:8];
          rDataMem[bytesAddress+2] <= iWriteData[23:16];
          rDataMem[bytesAddress+3] <= iWriteData[31:24];
        end

        default:
          ;

      endcase

    end

  end

endmodule
