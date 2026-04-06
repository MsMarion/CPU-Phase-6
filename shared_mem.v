module SHARED_MEM #(
    parameter BLOCK_SIZE  = 16,
    parameter MEM_LATENCY = 100,
    parameter MEM_DEPTH   = (1_048_576 / BLOCK_SIZE)   // 1 mb
) (
    input  wire                     iClk,
    input  wire                     iRstN,

    input  wire                     iRead,
    input  wire                     iWrite,
    input  wire [31:0]              iAddr,
    input  wire [BLOCK_SIZE*8-1:0]  iWriteData,

    output reg  [BLOCK_SIZE*8-1:0]  oReadData,
    output reg                      oReady
);

    // memory array
    reg [BLOCK_SIZE*8-1:0] mem [0:MEM_DEPTH-1];

    // for saving request
    reg                     rDoRead;
    reg                     rDoWrite;
    reg [31:0]              rAddr;
    reg [BLOCK_SIZE*8-1:0]  rWriteData;

    // latency counter
    reg [$clog2(MEM_LATENCY+1)-1:0] rDelayCnt;

    // mask address for smaller memory
    wire [$clog2(MEM_DEPTH)-1:0] mem_index =
        (rAddr >> $clog2(BLOCK_SIZE)) & (MEM_DEPTH-1);

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rDoRead    <= 1'b0;
            rDoWrite   <= 1'b0;
            rDelayCnt       <= '0;
            oReady     <= 1'b0;
            oReadData  <= '0;
        end else begin
            oReady <= 1'b0;

            // new request
            if (iRead || iWrite) begin
                // save request info
                rDoRead    <= iRead;
                rDoWrite   <= iWrite;
                rAddr      <= iAddr;
                rWriteData <= iWriteData;
                rDelayCnt       <= '0;
            end else if (rDoRead || rDoWrite) begin
                // count latency
                if (rDelayCnt != MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0])
                    rDelayCnt <= rDelayCnt + 1'b1;
                else begin
                    // complete op
                    if (rDoWrite)
                        mem[mem_index] <= rWriteData;
                    else
                        oReadData <= mem[mem_index];

                    oReady   <= 1'b1;
                    rDoRead  <= 1'b0;
                    rDoWrite <= 1'b0;
                end
            end
        end
    end

endmodule