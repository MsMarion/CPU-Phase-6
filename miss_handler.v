module MISS_HANDLER #(
    parameter BLOCK_SIZE = 16,
    parameter MEM_LATENCY = 100
) (
    input  wire        iClk,
    input  wire        iRstN,

    // i-cache miss
    input  wire        iIMiss,
    input  wire [31:0] iIAddress,
    output wire        oIFillEn,
    output wire [BLOCK_SIZE*8-1:0] oIFillData,

    // d-cache miss
    input  wire        iDMiss,
    input  wire [31:0] iDAddr,
    input  wire        iDCacheDirty,
    input  wire [BLOCK_SIZE*8-1:0] iDEvictData,
    input  wire [31:0] iDEvictAddr,
    output wire        oDFillEn,
    output wire [BLOCK_SIZE*8-1:0] oDFillData,

    // prefetch request
    input  wire        iPrefetchReq,
    input  wire [31:0] iPrefetchAddr,
    input  wire        iPrefetchCache,
    output wire        oPrefetchFillEn,
    output wire [BLOCK_SIZE*8-1:0] oPrefetchFillData,

    // pipeline control
    output wire        oStall,
    output wire        oBusy
);

    // states
    localparam S_IDLE          = 3'd0;
    localparam S_WB_REQ        = 3'd1;
    localparam S_WB_WAIT       = 3'd2;
    localparam S_RD_REQ        = 3'd3;
    localparam S_RD_WAIT       = 3'd4;
    localparam S_FILL          = 3'd5;
    localparam S_PREFETCH      = 3'd6;
    localparam S_PREFETCH_WAIT = 3'd7;

    reg [2:0] state, next_state;

    // latency counter
    reg [$clog2(MEM_LATENCY+1)-1:0] rStallCnt;

    // miss context
    reg        rMissIsI;
    reg [31:0] rMissAddr;

    // prefetch context
    reg        rDoPrefetch = 1'b0;
    reg [31:0] rPrefetchAddr;

    // outputs
    reg                     rIFillEn;
    reg [BLOCK_SIZE*8-1:0]  rIFillData;
    reg                     rDFillEn;
    reg [BLOCK_SIZE*8-1:0]  rDFillData;
    reg                     rPrefetchFillEn;
    reg [BLOCK_SIZE*8-1:0]  rPrefetchFillData;
    reg                     rStall;
    reg                     rBusy;

    // memory interface
    reg                     oMemRead;
    reg                     oMemWrite;
    reg [31:0]              oMemAddr;
    reg [BLOCK_SIZE*8-1:0]  oMemWriteData;
    wire [BLOCK_SIZE*8-1:0] iMemReadData;

    // sequential logic
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            state            <= S_IDLE;
            rStallCnt             <= '0;
            rMissIsI         <= 1'b0;
            rMissAddr        <= 32'b0;
            rDoPrefetch      <= 1'b0;
            rPrefetchAddr    <= 32'b0;

            rIFillEn         <= 1'b0;
            rIFillData       <= {BLOCK_SIZE*8{1'b0}};
            rDFillEn         <= 1'b0;
            rDFillData       <= {BLOCK_SIZE*8{1'b0}};
            rPrefetchFillEn  <= 1'b0;
            rPrefetchFillData<= {BLOCK_SIZE*8{1'b0}};

            oMemRead         <= 1'b0;
            oMemWrite        <= 1'b0;
            oMemAddr         <= 32'b0;
            oMemWriteData    <= {BLOCK_SIZE*8{1'b0}};

            rStall           <= 1'b0;
            rBusy            <= 1'b0;
        end else begin
            state <= next_state;

            // reset old values
            rIFillEn        <= 1'b0;
            rDFillEn        <= 1'b0;
            rPrefetchFillEn <= 1'b0;

            // update stall counter
            if (state == S_WB_WAIT || state == S_RD_WAIT || state == S_PREFETCH_WAIT) begin
                if (rStallCnt != MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0])
                    rStallCnt <= rStallCnt + 1'b1;
            end else begin
                rStallCnt <= '0;
            end

            // stall/busy
            rBusy  <= (next_state != S_IDLE);
            rStall <= (next_state != S_IDLE);

            case (state)
                S_IDLE: begin
                    oMemRead  <= 1'b0;
                    oMemWrite <= 1'b0;
                    rDoPrefetch <= 1'b0;

                    // choose which miss to service
                    // double misses are solved assuming cache's iIMiss & iDMiss
                    // are held high until their FillEn are set
                    if (iIMiss && iDMiss) begin
                        // choose I first
                        rMissIsI  <= 1'b1;
                        rMissAddr <= iIAddress;
                    end else if (iIMiss) begin
                        rMissIsI  <= 1'b1;
                        rMissAddr <= iIAddress;
                    end else if (iDMiss) begin
                        rMissIsI  <= 1'b0;
                        rMissAddr <= iDAddr;
                    end

                    // acknowledge prefetch
                    if (iPrefetchReq) begin
                        rDoPrefetch   <= 1'b1;
                        rPrefetchAddr <= iPrefetchAddr;
                    end
                end

                S_WB_REQ: begin
                    oMemWrite     <= 1'b1;
                    oMemRead      <= 1'b0;
                    oMemAddr      <= iDEvictAddr;
                    oMemWriteData <= iDEvictData;
                end

                S_WB_WAIT: begin
                    oMemWrite <= 1'b0;
                end

                S_RD_REQ: begin
                    oMemWrite <= 1'b0;
                    oMemRead  <= 1'b1;
                    oMemAddr  <= rMissAddr;
                end

                S_RD_WAIT: begin
                    oMemRead <= 1'b0;
                end

                S_FILL: begin
                    if (rMissIsI) begin
                        rIFillEn   <= 1'b1;
                        rIFillData <= iMemReadData;
                    end else begin
                        rDFillEn   <= 1'b1;
                        rDFillData <= iMemReadData;
                    end
                end

                // make second request and stall
                S_PREFETCH: begin
                    oMemRead  <= 1'b1;
                    oMemWrite <= 1'b0;
                    oMemAddr  <= rPrefetchAddr;
                end

                S_PREFETCH_WAIT: begin
                    oMemRead  <= 1'b0;
                    if (rStallCnt == MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]) begin
                        rPrefetchFillEn   <= 1'b1;
                        rPrefetchFillData <= iMemReadData;
                    end
                end
            endcase
        end
    end

    // next state logic
    always @(*) begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (iIMiss)
                    next_state = S_RD_REQ;
                else if (iDMiss)
                    next_state = iDCacheDirty ? S_WB_REQ : S_RD_REQ;
            end

            S_WB_REQ:        next_state = S_WB_WAIT;
            S_WB_WAIT:       if (rStallCnt == MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]) next_state = S_RD_REQ;
            S_RD_REQ:        next_state = S_RD_WAIT;
            S_RD_WAIT:       if (rStallCnt == MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]) next_state = S_FILL;
            S_FILL:          next_state = rDoPrefetch ? S_PREFETCH : S_IDLE;
            S_PREFETCH:      next_state = S_PREFETCH_WAIT;
            S_PREFETCH_WAIT: if (rStallCnt == MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]) next_state = S_IDLE;
        endcase
    end

    assign oIFillEn         = rIFillEn;
    assign oIFillData       = rIFillData;
    assign oDFillEn         = rDFillEn;
    assign oDFillData       = rDFillData;
    assign oPrefetchFillEn  = rPrefetchFillEn;
    assign oPrefetchFillData= rPrefetchFillData;
    assign oStall           = rStall;
    assign oBusy            = rBusy;

endmodule