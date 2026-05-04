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
    input  wire [BLOCK_SIZE*8-1:0] iIMemWrData,

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
    reg         rd_req;
    reg         wr_req;
    reg [31:0]  req_addr;
    reg [BLOCK_SIZE*8-1:0] wr_data;
    wire [BLOCK_SIZE*8-1:0] rd_data;
    wire        mem_done;

    SHARED_MEM #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .MEM_LATENCY(100)
    ) main_mem (
        .iClk(iClk),
        .iRstN(iRstN),
        .iRead(rd_req),
        .iWrite(wr_req),
        .iAddr(req_addr),
        .iWriteData(wr_data),
        .oReadData(rd_data),
        .oReady(mem_done)
    );

    assign oIMemData = rd_data;
    assign oDMemData = rd_data;
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
        rd_req     = 1'b0;
        wr_req     = 1'b0;
        req_addr   = 32'b0;
        wr_data    = 0;

        case (state)
            IDLE: begin
                // D-Cache gets priority
                if (iDMemRd || iDMemWr) begin
                    oDMemReady = 1'b1;
                    next_state = SERVING_D;
                end else if (iIMemRd || iIMemWr) begin
                    oIMemReady = 1'b1;
                    next_state = SERVING_I;
                end
            end

            SERVING_D: begin
                oDMemReady = 1'b1;
                rd_req     = iDMemRd;
                wr_req     = iDMemWr;
                req_addr   = iDMemRd ? iDMemRdAddr : iDMemWrAddr;
                wr_data    = iDMemWrData;

                if (mem_done) begin
                    oDMemValid = 1'b1;
                    next_state = IDLE;
                end
            end

            SERVING_I: begin
                oIMemReady = 1'b1;
                rd_req     = iIMemRd;
                wr_req     = iIMemWr;
                req_addr   = iIMemRd ? iIMemRdAddr : iIMemWrAddr;
                wr_data    = iIMemWrData;

                if (mem_done) begin
                    oIMemValid = 1'b1;
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule
