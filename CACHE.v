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
    input  i_mem_ready,
    input  i_mem_valid,
    input  [BLOCK_SIZE*8-1:0] i_mem_rd_data,
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

    localparam TOTAL_SIZE_BYTES = CACHE_SIZE * 1024;
    localparam NUM_SETS         = TOTAL_SIZE_BYTES / (BLOCK_SIZE * NUM_WAYS);
    localparam OFF_BITS         = $clog2(BLOCK_SIZE);
    localparam IDX_BITS         = $clog2(NUM_SETS);
    localparam TAG_BITS         = 32 - IDX_BITS - OFF_BITS;

    // Internal Storage
    reg [TAG_BITS-1:0]        tagStore      [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg                       vld     [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg                       dirty     [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [BLOCK_SIZE*8-1:0]    dataArray      [NUM_SETS-1:0][NUM_WAYS-1:0];

    localparam IDLE         = 3'd0;
    localparam MISS_REQ     = 3'd1;
    localparam MISS_VALID   = 3'd2;
    localparam WB_READY     = 3'd3;
    localparam PREFETCH_WAIT= 3'd4;
    localparam REFILL_DONE  = 3'd5;
    localparam PREFETCH_REQ = 3'd6;
    localparam PF_WB_READY  = 3'd7;

    reg [2:0] state, next_state;

    wire [TAG_BITS-1:0] req_tag = i_addr[31 : IDX_BITS+OFF_BITS];
    wire [IDX_BITS-1:0] req_idx = i_addr[IDX_BITS+OFF_BITS-1 : OFF_BITS];
    wire [OFF_BITS-1:0] req_off = i_addr[OFF_BITS-1 : 0];

    reg hit;
    reg [$clog2(NUM_WAYS)-1:0] hit_w;
    integer w;
    always @(*) begin
        hit   = 1'b0;
        hit_w = 0;
        for (w = 0; w < NUM_WAYS; w = w + 1) begin
            if (vld[req_idx][w] && (tagStore[req_idx][w] == req_tag)) begin
                hit   = 1'b1;
                hit_w = w[$clog2(NUM_WAYS)-1:0];
            end
        end
    end

    // Pack vld bits for current set into a vector for replacement policy
    reg [NUM_WAYS-1:0] set_vld;
    integer v;
    always @(*) begin
        for (v = 0; v < NUM_WAYS; v = v + 1) set_vld[v] = vld[req_idx][v];
    end

    wire        prefetch_req;
    wire [31:0] prefetch_addr;
    wire [IDX_BITS-1:0] pf_idx_wire = prefetch_addr[IDX_BITS+OFF_BITS-1 : OFF_BITS];
    wire [TAG_BITS-1:0] pf_tag_wire = prefetch_addr[31 : IDX_BITS+OFF_BITS];

    reg [NUM_WAYS-1:0] pf_set_vld;
    integer pv;
    always @(*) begin
        for (pv = 0; pv < NUM_WAYS; pv = pv + 1)
            pf_set_vld[pv] = vld[pf_idx_wire][pv];
    end

    wire miss_now    = (state == IDLE) && (i_read || i_write) && !hit;
    wire evict_dirty = vld[req_idx][victim_way] && dirty[req_idx][victim_way];

    wire [$clog2(NUM_WAYS)-1:0] victim_way;
    wire [$clog2(NUM_WAYS)-1:0] pf_victim_way_wire;
    REPLACE_POLICY #(
        .ASSOC(NUM_WAYS),
        .NUM_SETS(NUM_SETS),
        .BLOCK_SIZE(BLOCK_SIZE),
        .IS_LRU(EVICT_POLICY == 0)
    ) replace_logic (
        .iClk(i_clk),
        .iRstN(i_rstn),
        .iSetIndex(req_idx),
        .iAccessValid(((state == IDLE) || (state == REFILL_DONE)) && (i_read || i_write)),
        .iHit(hit),
        .iHitWay(hit_w),
        .iValidBits(set_vld),
        .oVictimWay(victim_way),
        .iAddress(i_addr),
        .iMiss(miss_now),
        .oPrefetchReq(prefetch_req),
        .oPrefetchAddr(prefetch_addr),
        .iPfSetIndex  (pf_idx_wire),
        .iPfValidBits (pf_set_vld),
        .oPfVictimWay (pf_victim_way_wire),
        .iPfFill      ((state == PREFETCH_WAIT) && i_mem_valid),
        .iPfFillSetIdx(pf_idx_latched),
        .iPfFillWay   (pf_victim_way_reg),
        .iDemandFill    ((state == MISS_VALID) && i_mem_valid),
        .iDemandFillSetIdx(miss_idx),
        .iDemandFillWay (evict_way)
    );

    reg [TAG_BITS-1:0]         miss_tag;
    reg [IDX_BITS-1:0]         miss_idx;
    reg [OFF_BITS-1:0]         miss_offset;
    reg [$clog2(NUM_WAYS)-1:0] evict_way;
    reg [TAG_BITS-1:0]         wb_tag;
    reg [(BLOCK_SIZE*8)-1:0]   wb_data;

    reg        miss_was_write;
    reg        miss_was_read;
    reg [1:0]  miss_funct;
    reg [31:0] miss_cpu_data;

    reg        prefetch_pending;
    reg [31:0] prefetch_addr_reg;

    reg [$clog2(NUM_WAYS)-1:0] pf_victim_way_reg;
    reg                        pf_victim_dirty_reg;
    reg [TAG_BITS-1:0]         pf_victim_tag_reg;
    reg [(BLOCK_SIZE*8)-1:0]   pf_victim_data_reg;
    reg [TAG_BITS-1:0]         pf_tag_latched;
    reg [IDX_BITS-1:0]         pf_idx_latched;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            state <= IDLE;
            prefetch_pending    <= 1'b0;
            prefetch_addr_reg   <= 32'b0;
            pf_victim_way_reg   <= {$clog2(NUM_WAYS){1'b0}};
            pf_victim_dirty_reg <= 1'b0;
            pf_victim_tag_reg   <= {TAG_BITS{1'b0}};
            pf_victim_data_reg  <= {(BLOCK_SIZE*8){1'b0}};
            pf_tag_latched      <= {TAG_BITS{1'b0}};
            pf_idx_latched      <= {IDX_BITS{1'b0}};
            for (integer i = 0; i < NUM_SETS; i++) begin
                for (integer j = 0; j < NUM_WAYS; j++) begin
                    vld[i][j] <= 1'b0;
                    dirty[i][j] <= 1'b0;
                    tagStore[i][j]  <= {(TAG_BITS){1'b0}};
                    dataArray[i][j]  <= {(BLOCK_SIZE*8){1'b0}};
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
                                    2'b00: dataArray[req_idx][hit_w][req_off*8 +: 8]  <= i_cpu_data[7:0];
                                    2'b01: dataArray[req_idx][hit_w][req_off*8 +: 16] <= i_cpu_data[15:0];
                                    2'b10: dataArray[req_idx][hit_w][req_off*8 +: 32] <= i_cpu_data;
                                    default: ;
                                endcase
                                dirty[req_idx][hit_w] <= 1'b1;
                            end
                        end else begin
                            miss_tag        <= req_tag;
                            miss_idx        <= req_idx;
                            miss_offset     <= req_off;
                            evict_way       <= victim_way;
                            wb_tag          <= tagStore[req_idx][victim_way];
                            wb_data         <= dataArray[req_idx][victim_way];
                            miss_was_write  <= i_write;
                            miss_was_read   <= i_read;
                            miss_funct      <= i_funct;
                            miss_cpu_data   <= i_cpu_data;

                            if (prefetch_req) begin
                                prefetch_pending  <= 1'b1;
                                prefetch_addr_reg <= prefetch_addr;
                                pf_idx_latched    <= pf_idx_wire;
                                pf_tag_latched    <= pf_tag_wire;
                            end else begin
                                prefetch_pending  <= 1'b0;
                                prefetch_addr_reg <= 32'b0;
                            end
                        end
                    end
                end

                MISS_VALID: begin
                    if (i_mem_valid) begin
                        dataArray[miss_idx][evict_way]  <= i_mem_rd_data;
                        tagStore[miss_idx][evict_way]  <= miss_tag;
                        vld[miss_idx][evict_way] <= 1'b1;
                        dirty[miss_idx][evict_way] <= 1'b0;
                    end
                end

                PREFETCH_WAIT: begin
                    if (i_mem_valid) begin
                        dataArray [pf_idx_latched][pf_victim_way_reg] <= i_mem_rd_data;
                        tagStore [pf_idx_latched][pf_victim_way_reg] <= pf_tag_latched;
                        vld[pf_idx_latched][pf_victim_way_reg] <= 1'b1;
                        dirty[pf_idx_latched][pf_victim_way_reg] <= 1'b0;
                        prefetch_pending <= 1'b0;
                    end
                end

                WB_READY: begin
                    dirty[miss_idx][evict_way] <= 1'b0;
                end

                MISS_REQ: begin
                    vld[miss_idx][evict_way] <= 1'b0;
                end

                REFILL_DONE: begin
                    if (miss_was_write) begin
                        case (miss_funct)
                            2'b00: dataArray[miss_idx][evict_way][miss_offset*8 +: 8]  <= miss_cpu_data[7:0];
                            2'b01: dataArray[miss_idx][evict_way][miss_offset*8 +: 16] <= miss_cpu_data[15:0];
                            2'b10: dataArray[miss_idx][evict_way][miss_offset*8 +: 32] <= miss_cpu_data;
                            default: ;
                        endcase
                        dirty[miss_idx][evict_way] <= 1'b1;
                    end

                    // CPU presents next access while o_miss=0; handle hit here
                    if ((i_read || i_write) && hit) begin
                        if (i_write) begin
                            case (i_funct)
                                2'b00: dataArray[req_idx][hit_w][req_off*8 +: 8]  <= i_cpu_data[7:0];
                                2'b01: dataArray[req_idx][hit_w][req_off*8 +: 16] <= i_cpu_data[15:0];
                                2'b10: dataArray[req_idx][hit_w][req_off*8 +: 32] <= i_cpu_data;
                                default: ;
                            endcase
                            dirty[req_idx][hit_w] <= 1'b1;
                        end
                    end
                end

                PREFETCH_REQ: begin
                    // Capture prefetch victim after demand fill's LRU update has been applied
                    pf_victim_way_reg   <= pf_victim_way_wire;
                    pf_victim_dirty_reg <= vld[pf_idx_latched][pf_victim_way_wire]
                                          && dirty[pf_idx_latched][pf_victim_way_wire];
                    pf_victim_tag_reg   <= tagStore[pf_idx_latched][pf_victim_way_wire];
                    pf_victim_data_reg  <= dataArray[pf_idx_latched][pf_victim_way_wire];
                end

                PF_WB_READY: begin
                end

                default: ;
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
                        o_miss = 1'b1;
                        if (evict_dirty) begin
                            next_state = WB_READY;
                        end else begin
                            next_state = MISS_REQ;
                        end
                    end
                end
            end

            WB_READY: begin
                o_miss        = 1'b1;
                o_mem_wr      = 1'b1;
                o_mem_wr_addr = {wb_tag, miss_idx, {OFF_BITS{1'b0}}};
                o_mem_wr_data = wb_data;
                next_state    = MISS_REQ;
            end

            MISS_REQ: begin
                o_miss        = 1'b1;
                o_mem_rd      = 1'b1;
                o_mem_rd_addr = {miss_tag, miss_idx, {OFF_BITS{1'b0}}};
                next_state    = MISS_VALID;
            end

            MISS_VALID: begin
                o_miss = 1'b1;
                if (i_mem_valid) begin
                    if (prefetch_pending) begin
                        next_state = PREFETCH_REQ;
                    end else begin
                        next_state = REFILL_DONE;
                    end
                end
            end

            PREFETCH_REQ: begin
                o_miss        = 1'b1;
                o_mem_rd      = 1'b1;
                o_mem_rd_addr = prefetch_addr_reg;
                next_state    = PREFETCH_WAIT;
            end

            PREFETCH_WAIT: begin
                o_miss = 1'b1;
                if (i_mem_valid) begin
                    if (pf_victim_dirty_reg) begin
                        next_state = PF_WB_READY;
                    end else begin
                        next_state = REFILL_DONE;
                    end
                end
            end

            PF_WB_READY: begin
                o_miss        = 1'b1;
                o_mem_wr      = 1'b1;
                o_mem_wr_addr = {pf_victim_tag_reg, pf_idx_latched, {OFF_BITS{1'b0}}};
                o_mem_wr_data = pf_victim_data_reg;
                next_state    = REFILL_DONE;
            end

            REFILL_DONE: begin
                o_hit = miss_was_read ? 1'b1 : 1'b0;
                if ((i_read || i_write) && hit)
                    o_hit = 1'b1;
                next_state = IDLE;
            end

            default: ;
        endcase
    end

    always @(*) begin
        o_cpu_data = 32'b0;

        if (state == REFILL_DONE && (i_read || i_write) && hit) begin
            case (i_funct)
                2'b00: o_cpu_data = {24'b0, dataArray[req_idx][hit_w][req_off*8 +: 8]};
                2'b01: o_cpu_data = {16'b0, dataArray[req_idx][hit_w][req_off*8 +: 16]};
                2'b10: o_cpu_data = dataArray[req_idx][hit_w][req_off*8 +: 32];
                default: o_cpu_data = 32'b0;
            endcase
        end else if (state == REFILL_DONE && miss_was_read) begin
            case (miss_funct)
                2'b00: o_cpu_data = {24'b0, dataArray[miss_idx][evict_way][miss_offset*8 +: 8]};
                2'b01: o_cpu_data = {16'b0, dataArray[miss_idx][evict_way][miss_offset*8 +: 16]};
                2'b10: o_cpu_data = dataArray[miss_idx][evict_way][miss_offset*8 +: 32];
                default: o_cpu_data = 32'b0;
            endcase
        end else if (hit && state == IDLE) begin
            case (i_funct)
                2'b00: o_cpu_data = {24'b0, dataArray[req_idx][hit_w][req_off*8 +: 8]};
                2'b01: o_cpu_data = {16'b0, dataArray[req_idx][hit_w][req_off*8 +: 16]};
                2'b10: o_cpu_data = dataArray[req_idx][hit_w][req_off*8 +: 32];
                default: o_cpu_data = 32'b0;
            endcase
        end
    end

endmodule
