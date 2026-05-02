module CACHE #(
    parameter EVICT_POLICY = 0, // 0 = LRU, 1 = PLRU
    parameter NUM_WAYS     = 4,
    parameter CACHE_SIZE   = 32, // KB
    parameter BLOCK_SIZE   = 64  // B
) (
    input  i_clk,
    input  i_rstn,
    // CPU interface inputs
    input  i_read,
    input  i_write,
    input  [1:0] i_funct,       // 00=LB, 01=LH, 10=LW
    input  [31:0] i_addr,
    input  [31:0] i_cpu_data,
    // MEM interface inputs
    input  i_mem_ready,         // Memory is ready for a request
    input  i_mem_valid,         // Memory data is valid (returning from read)
    input  [BLOCK_SIZE*8-1:0] i_mem_rd_data, // data returned from memory on read
    // CPU interface outputs
    output reg o_hit,
    output reg o_miss,
    output reg [31:0] o_cpu_data,
    // MEM interface outputs
    output reg o_mem_rd,
    output reg o_mem_wr,
    output reg [31:0] o_mem_rd_addr,
    output reg [31:0] o_mem_wr_addr,
    output reg [BLOCK_SIZE*8-1:0] o_mem_wr_data
);

    // Derived parameters
    localparam TOTAL_SIZE_BYTES = CACHE_SIZE * 1024;
    localparam NUM_SETS         = TOTAL_SIZE_BYTES / (BLOCK_SIZE * NUM_WAYS);
    localparam OFF_BITS         = $clog2(BLOCK_SIZE);
    localparam IDX_BITS         = $clog2(NUM_SETS);
    localparam TAG_BITS         = 32 - IDX_BITS - OFF_BITS;

    // Internal Storage
    reg [TAG_BITS-1:0]        tagArray   [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg                       validBits  [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg                       dirtyBits  [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [BLOCK_SIZE*8-1:0]    dataArray  [NUM_SETS-1:0][NUM_WAYS-1:0];

    localparam IDLE        = 3'd0;
    localparam MISS_REQ    = 3'd1; // issue read request (o_miss + o_mem_rd)
    localparam MISS_VALID  = 3'd2; // wait for i_mem_valid
    localparam WB_READY    = 3'd3; // writeback dirty line
    localparam WB_VALID    = 3'd4; // (unused, can be kept or removed)
    localparam REFILL_DONE = 3'd5;

    reg [2:0] state, next_state;

    wire [TAG_BITS-1:0] current_tag = i_addr[31 : IDX_BITS+OFF_BITS];
    wire [IDX_BITS-1:0] current_idx = i_addr[IDX_BITS+OFF_BITS-1 : OFF_BITS];
    wire [OFF_BITS-1:0] current_off = i_addr[OFF_BITS-1 : 0];

    reg hit;
    reg [$clog2(NUM_WAYS)-1:0] hit_way;
    integer w;
    always @(*) begin
        hit = 1'b0;
        hit_way = 0;
        for (w = 0; w < NUM_WAYS; w = w + 1) begin
            if (validBits[current_idx][w] && (tagArray[current_idx][w] == current_tag)) begin
                hit = 1'b1;
                hit_way = w[$clog2(NUM_WAYS)-1:0];
            end
        end
    end

    reg [NUM_WAYS-1:0] packed_valid;
    integer v;
    always @(*) begin
        for (v = 0; v < NUM_WAYS; v = v + 1) packed_valid[v] = validBits[current_idx][v];
    end

    wire        prefetch_req;
    wire [31:0] prefetch_addr;
    wire miss_pulse = (state == IDLE) && (i_read || i_write) && !hit;

    wire [$clog2(NUM_WAYS)-1:0] victim_way;
    REPLACE_POLICY #(
        .ASSOC(NUM_WAYS),
        .NUM_SETS(NUM_SETS),
        .BLOCK_SIZE(BLOCK_SIZE),
        .IS_LRU(EVICT_POLICY == 0)
    ) replace_logic (
        .iClk(i_clk),
        .iRstN(i_rstn),
        .iSetIndex(current_idx),
        .iAccessValid((state == IDLE) && (i_read || i_write)),
        .iHit(hit),
        .iHitWay(hit_way),
        .iValidBits(packed_valid),
        .oVictimWay(victim_way),
        .iAddress(i_addr),
        .iMiss(miss_pulse),       // FIX (Bug 5): was o_miss (multi-cycle)
        .oPrefetchReq(prefetch_req),
        .oPrefetchAddr(prefetch_addr)
    );

    // Registers to hold miss address info
    reg [TAG_BITS-1:0]        miss_tag;
    reg [IDX_BITS-1:0]        miss_idx;
    reg [OFF_BITS-1:0]        miss_offset;
    reg [$clog2(NUM_WAYS)-1:0] miss_victim_way;

    reg        miss_was_write;
    reg        miss_was_read;
    reg [1:0]  miss_funct;
    reg [31:0] miss_cpu_data;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            state <= IDLE;
            for (integer i = 0; i < NUM_SETS; i++) begin
                for (integer j = 0; j < NUM_WAYS; j++) begin
                    validBits[i][j] <= 1'b0;
                    dirtyBits[i][j] <= 1'b0;
                    tagArray[i][j] <= {(TAG_BITS){1'b0}};
                    dataArray[i][j] <= {(BLOCK_SIZE*8){1'b0}};
                end
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (i_read || i_write) begin
                        if (hit) begin
                            if (i_write) begin
                                case (i_funct)
                                    2'b00: dataArray[current_idx][hit_way][current_off*8 +: 8]  <= i_cpu_data[7:0];
                                    2'b01: dataArray[current_idx][hit_way][current_off*8 +: 16] <= i_cpu_data[15:0];
                                    2'b10: dataArray[current_idx][hit_way][current_off*8 +: 32] <= i_cpu_data;
                                    default: ; // no-op
                                endcase
                                dirtyBits[current_idx][hit_way] <= 1'b1;
                            end
                        end else begin
                            // Save all miss context so states after IDLE are self-contained
                            miss_tag        <= current_tag;
                            miss_idx        <= current_idx;
                            miss_offset     <= current_off;
                            miss_victim_way <= victim_way;
                            miss_was_write  <= i_write;
                            miss_was_read   <= i_read;
                            miss_funct      <= i_funct;
                            miss_cpu_data   <= i_cpu_data;
                        end
                    end
                end

                MISS_VALID: begin
                    if (i_mem_valid) begin
                        // Fill the line from memory
                        dataArray[miss_idx][miss_victim_way] <= i_mem_rd_data;
                        tagArray[miss_idx][miss_victim_way]  <= miss_tag;
                        validBits[miss_idx][miss_victim_way] <= 1'b1;
                        dirtyBits[miss_idx][miss_victim_way] <= 1'b0;
                    end
                end

                REFILL_DONE: begin
                    // Apply deferred write if this was a write miss
                    if (miss_was_write) begin
                        case (miss_funct)
                            2'b00: dataArray[miss_idx][miss_victim_way][miss_offset*8 +: 8]  <= miss_cpu_data[7:0];
                            2'b01: dataArray[miss_idx][miss_victim_way][miss_offset*8 +: 16] <= miss_cpu_data[15:0];
                            2'b10: dataArray[miss_idx][miss_victim_way][miss_offset*8 +: 32] <= miss_cpu_data;
                            default: ;
                        endcase
                        dirtyBits[miss_idx][miss_victim_way] <= 1'b1;
                    end
                end

                WB_VALID: begin
                    if (i_mem_valid) begin
                        // Writeback complete - miss fetch starts next
                    end
                end

                default: ; // no-op
            endcase
        end
    end

    always @(*) begin
        next_state    = state;
        o_mem_rd      = 1'b0;
        o_mem_wr      = 1'b0;
        o_hit         = 1'b0;
        o_miss        = 1'b0;
        o_mem_rd_addr = 32'b0;
        o_mem_wr_addr = 32'b0;
        o_mem_wr_data = {(BLOCK_SIZE*8){1'b0}};

        case (state)
            IDLE: begin
                if (i_read || i_write) begin
                    if (hit) begin
                        o_hit = 1'b1;
                    end else begin
                        // miss: decide if we must write back first
                        if (dirtyBits[current_idx][victim_way] && validBits[current_idx][victim_way]) begin
                            // dirty victim: write back first
                            next_state = WB_READY;
                        end else begin
                            // clean victim: defer issuing the read until MISS_REQ
                            // (the harness will already be stalled by then)
                            o_miss     = 1'b1;   // optional: one-cycle pulse
                            next_state = MISS_REQ;
                        end
                    end
                end
            end


            WB_READY: begin
                // write back dirty victim line (no stall protocol in harness)
                o_mem_wr      = 1'b1;
                o_mem_wr_addr = {tagArray[miss_idx][miss_victim_way], miss_idx, {OFF_BITS{1'b0}}};
                o_mem_wr_data = dataArray[miss_idx][miss_victim_way];
                // next cycle: issue the read miss request
                next_state    = MISS_REQ;
            end

            MISS_REQ: begin
                // now issue the read request and start the stall in the harness
                o_miss        = 1'b1;
                o_mem_rd      = 1'b1;
                o_mem_rd_addr = {miss_tag, miss_idx, {OFF_BITS{1'b0}}};
                next_state    = MISS_VALID;
            end

            WB_VALID: begin
                // no protocol for writeback completion in harness; you can leave this unused
                next_state = WB_VALID;
            end

            MISS_VALID: begin
                if (i_mem_valid) next_state = REFILL_DONE;
            end

            REFILL_DONE: begin
                o_hit = miss_was_read ? 1'b1 : 1'b0;  // Only assert hit for read misses
                next_state = IDLE;
            end

            default: ; // no-op
        endcase
    end

    // Combinational data extraction logic
    always @(*) begin
        o_cpu_data = 32'b0;

        // Extract data from cache lines
        if (state == REFILL_DONE && miss_was_read) begin
            // Data just filled — serve read from the saved miss context
            case (miss_funct)
                2'b00: o_cpu_data = {{24{dataArray[miss_idx][miss_victim_way][miss_offset*8+7]}},
                                         dataArray[miss_idx][miss_victim_way][miss_offset*8 +: 8]};
                2'b01: o_cpu_data = {{16{dataArray[miss_idx][miss_victim_way][miss_offset*8+15]}},
                                         dataArray[miss_idx][miss_victim_way][miss_offset*8 +: 16]};
                2'b10: o_cpu_data = dataArray[miss_idx][miss_victim_way][miss_offset*8 +: 32];
                default: o_cpu_data = 32'b0;
            endcase
        end else if (hit && state == IDLE) begin
            // Normal hit path - output data for both reads and writes (old value on write)
            case (i_funct)
                2'b00: o_cpu_data = {{24{dataArray[current_idx][hit_way][current_off*8+7]}},
                                         dataArray[current_idx][hit_way][current_off*8 +: 8]};
                2'b01: o_cpu_data = {{16{dataArray[current_idx][hit_way][current_off*8+15]}},
                                         dataArray[current_idx][hit_way][current_off*8 +: 16]};
                2'b10: o_cpu_data = dataArray[current_idx][hit_way][current_off*8 +: 32];
                default: o_cpu_data = 32'b0;
            endcase
        end
    end

endmodule