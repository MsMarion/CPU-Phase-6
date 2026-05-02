/*
    Updated miss_handler.v to act as a Bus Arbiter/Memory Controller.
    - Interfaces with two caches using the Ready/Valid handshake.
    - Prioritizes D-Cache over I-Cache.
    - Connects to SHARED_MEM for actual data persistence and latency.
*/

module MISS_HANDLER #(
    parameter BLOCK_SIZE = 64
) (
    input  wire iClk,
    input  wire iRstN,

    // I-Cache interface
    output reg  oIMemReady,
    output reg  oIMemValid,
    output wire [BLOCK_SIZE*8-1:0] oIMemData,
    input  wire iIMemRd,
    input  wire iIMemWr,
    input  wire [31:0] iIMemRdAddr,
    input  wire [31:0] iIMemWrAddr,
    input  wire [BLOCK_SIZE*8-1:0] iIMemWrData, // write-back data

    // D-Cache interface
    output reg  oDMemReady,
    output reg  oDMemValid,
    output wire [BLOCK_SIZE*8-1:0] oDMemData,
    input  wire iDMemRd,
    input  wire iDMemWr,
    input  wire [31:0] iDMemRdAddr,
    input  wire [31:0] iDMemWrAddr,
    input  wire [BLOCK_SIZE*8-1:0] iDMemWrData,

    // Pipeline control
    output wire oStall
);

    // Arbiter States
    localparam IDLE      = 2'd0;
    localparam SERVING_D = 2'd1;
    localparam SERVING_I = 2'd2;

    reg [1:0] state, next_state;

    // Memory Interface
    reg         memRead;
    reg         memWrite;
    reg [31:0]  memAddr;
    reg [BLOCK_SIZE*8-1:0] memWriteData;
    wire [BLOCK_SIZE*8-1:0] memReadData;
    wire        memReady; // from shared_mem

    SHARED_MEM #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .MEM_LATENCY(100)
    ) main_mem (
        .iClk(iClk),
        .iRstN(iRstN),
        .iRead(memRead),
        .iWrite(memWrite),
        .iAddr(memAddr),
        .iWriteData(memWriteData),
        .oReadData(memReadData),
        .oReady(memReady)
    );

    assign oIMemData = memReadData;
    assign oDMemData = memReadData;
    assign oStall    = (state != IDLE);

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        oIMemReady = 1'b0;
        oIMemValid = 1'b0;
        oDMemReady = 1'b0;
        oDMemValid = 1'b0;
        memRead    = 1'b0;
        memWrite   = 1'b0;
        memAddr    = 32'b0;
        memWriteData = 0;

        case (state)
            IDLE: begin
                if (iDMemRd || iDMemWr) begin
                    oDMemReady = 1'b1;
                    next_state = SERVING_D;
                end else if (iIMemRd || iIMemWr) begin
                    oIMemReady = 1'b1;
                    next_state = SERVING_I;
                end
            end

            SERVING_D: begin
                oDMemReady = 1'b1;  // Keep ready high while servicing
                memRead    = iDMemRd;
                memWrite   = iDMemWr;
                memAddr    = iDMemRd ? iDMemRdAddr : iDMemWrAddr;
                memWriteData = iDMemWrData;
                
                if (memReady) begin
                    oDMemValid = 1'b1;
                    next_state = IDLE;
                end
            end

            SERVING_I: begin
                oIMemReady = 1'b1;  // Keep ready high while servicing
                memRead    = iIMemRd;
                memWrite   = iIMemWr;
                memAddr    = iIMemRd ? iIMemRdAddr : iIMemWrAddr;
                memWriteData = iIMemWrData;

                if (memReady) begin
                    oIMemValid = 1'b1;
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule