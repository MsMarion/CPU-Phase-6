module CACHE #(
    parameter EVICT_POLICY = 0, // 0 = LRU, 1 = PLRU
    parameter NUM_WAYS     = 4,
    parameter CACHE_SIZE   = 32, // KB
    parameter BLOCK_SIZE   = 64  // B
) (
    input  i_clk,
    input  i_rstn,
    input  i_read,
    input  i_write,
    input  [1:0] i_funct,
    input  [31:0] i_addr,
    input  [31:0] i_cpu_data,
    input  i_mem_ready,
    input  i_mem_valid,
    input  [BLOCK_SIZE*8-1:0] i_mem_rd_data,
    output reg o_hit,
    output reg o_miss,
    output reg [31:0] o_cpu_data,
    output reg o_mem_rd,
    output reg o_mem_wr,
    output reg [31:0] o_mem_rd_addr,
    output reg [31:0] o_mem_wr_addr,
    output reg [BLOCK_SIZE*8-1:0] o_mem_rd_data,
    output reg [BLOCK_SIZE*8-1:0] o_mem_wr_data
);

    localparam TOTAL_SIZE_BYTES = CACHE_SIZE * 1024;
    localparam NUM_SETS         = TOTAL_SIZE_BYTES / (BLOCK_SIZE * NUM_WAYS);
    localparam OFF_BITS         = $clog2(BLOCK_SIZE);
    localparam IDX_BITS         = $clog2(NUM_SETS);
    localparam TAG_BITS         = 32 - IDX_BITS - OFF_BITS;

    reg [TAG_BITS-1:0]        tagArray   [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg                       validBits  [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg                       dirtyBits  [NUM_SETS-1:0][NUM_WAYS-1:0];
    reg [BLOCK_SIZE*8-1:0]    dataArray  [NUM_SETS-1:0][NUM_WAYS-1:0];

    localparam IDLE        = 3'd0;
    localparam MISS_READY  = 3'd1;
    localparam MISS_VALID  = 3'd2;
    localparam WB_READY    = 3'd3;
    localparam WB_VALID    = 3'd4;
    localparam REFILL_DONE = 3'd5;

    reg [2:0] state, next_state;

    wire [TAG_BITS-1:0] current_tag = i_addr[31 : IDX_BITS+OFF_BITS];
    wire [IDX_BITS-1:0] current_idx = i_addr[IDX_BITS+OFF_BITS-1 : OFF_BITS];
    wire [OFF_BITS-1:0] current_off = i_addr[OFF_BITS-1 : 0];

    reg [TAG_BITS-1:0]         saved_tag;
    reg [IDX_BITS-1:0]         saved_idx;
    reg [OFF_BITS-1:0]         saved_off;
    reg [1:0]                  saved_funct;
    reg                        saved_write;
    reg [31:0]                 saved_cpu_data;
    reg [$clog2(NUM_WAYS)-1:0] saved_victim;

    reg hit;
    reg [$clog2(NUM_WAYS)-1:0] hit_way;
    integer w;
    always @(*) begin
        hit     = 1'b0;
        hit_way = 0;
        for (w = 0; w < NUM_WAYS; w = w + 1) begin
            if (validBits[current_idx][w] && (tagArray[current_idx][w] == current_tag)) begin
                hit     = 1'b1;
                hit_way = w[$clog2(NUM_WAYS)-1:0];
            end
        end
    end

    reg [NUM_WAYS-1:0] packed_valid;
    integer v;
    always @(*) begin
        for (v = 0; v < NUM_WAYS; v = v + 1)
            packed_valid[v] = validBits[current_idx][v];
    end

    wire        prefetch_req;
    wire [31:0] prefetch_addr;

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
        .iAccessValid(i_read || i_write),
        .iHit(hit),
        .iHitWay(hit_way),
        .iValidBits(packed_valid),
        .oVictimWay(victim_way),
        .iAddress(i_addr),
        .iMiss(o_miss),
        .oPrefetchReq(prefetch_req),
        .oPrefetchAddr(prefetch_addr)
    );

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            state <= IDLE;
            for (integer i = 0; i < NUM_SETS; i = i + 1)
                for (integer j = 0; j < NUM_WAYS; j = j + 1) begin
                    validBits[i][j] <= 1'b0;
                    dirtyBits[i][j] <= 1'b0;
                end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (i_read || i_write) begin
                        saved_tag      <= current_tag;
                        saved_idx      <= current_idx;
                        saved_off      <= current_off;
                        saved_funct    <= i_funct;
                        saved_write    <= i_write;
                        saved_cpu_data <= i_cpu_data;
                        saved_victim   <= victim_way;

                        if (hit && i_write) begin
                            case (i_funct)
                                2'b00: dataArray[current_idx][hit_way][current_off*8 +: 8]  <= i_cpu_data[7:0];
                                2'b01: dataArray[current_idx][hit_way][current_off*8 +: 16] <= i_cpu_data[15:0];
                                2'b10: dataArray[current_idx][hit_way][current_off*8 +: 32] <= i_cpu_data;
                                default: ;
                            endcase
                            dirtyBits[current_idx][hit_way] <= 1'b1;
                        end
                    end
                end

                MISS_VALID: begin
                    if (i_mem_valid) begin
                        dataArray[saved_idx][saved_victim] <= i_mem_rd_data;
                        tagArray [saved_idx][saved_victim] <= saved_tag;
                        validBits[saved_idx][saved_victim] <= 1'b1;
                        dirtyBits[saved_idx][saved_victim] <= 1'b0;

                        if (saved_write) begin
                            case (saved_funct)
                                2'b00: dataArray[saved_idx][saved_victim][saved_off*8 +: 8]  <= saved_cpu_data[7:0];
                                2'b01: dataArray[saved_idx][saved_victim][saved_off*8 +: 16] <= saved_cpu_data[15:0];
                                2'b10: dataArray[saved_idx][saved_victim][saved_off*8 +: 32] <= saved_cpu_data;
                                default: ;
                            endcase
                            dirtyBits[saved_idx][saved_victim] <= 1'b1;
                        end
                    end
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
        o_cpu_data    = 32'b0;
        o_mem_rd_addr = 32'b0;
        o_mem_wr_addr = 32'b0;
        o_mem_rd_data = {(BLOCK_SIZE*8){1'b0}};
        o_mem_wr_data = {(BLOCK_SIZE*8){1'b0}};

        case (state)
            IDLE: begin
                if (i_read || i_write) begin
                    if (hit) begin
                        o_hit = 1'b1;
                        case (i_funct)
                            2'b00: o_cpu_data = {{24{dataArray[current_idx][hit_way][current_off*8+7]}},
                                                    dataArray[current_idx][hit_way][current_off*8 +: 8]};
                            2'b01: o_cpu_data = {{16{dataArray[current_idx][hit_way][current_off*8+15]}},
                                                    dataArray[current_idx][hit_way][current_off*8 +: 16]};
                            2'b10: o_cpu_data =     dataArray[current_idx][hit_way][current_off*8 +: 32];
                            default: o_cpu_data = 32'b0;
                        endcase
                        next_state = IDLE;
                    end else begin
                        o_miss = 1'b1;
                        if (dirtyBits[current_idx][victim_way] && validBits[current_idx][victim_way])
                            next_state = WB_READY;
                        else
                            next_state = MISS_READY;
                    end
                end
            end

            WB_READY: begin
                o_miss        = 1'b1;
                o_mem_wr      = 1'b1;
                o_mem_wr_addr = {tagArray[saved_idx][saved_victim], saved_idx, {OFF_BITS{1'b0}}};
                o_mem_wr_data = dataArray[saved_idx][saved_victim];
                if (i_mem_ready) next_state = WB_VALID;
            end

            WB_VALID: begin
                o_miss = 1'b1;
                if (i_mem_valid) next_state = MISS_READY;
            end

            MISS_READY: begin
                o_miss        = 1'b1;
                o_mem_rd      = 1'b1;
                o_mem_rd_addr = {saved_tag, saved_idx, {OFF_BITS{1'b0}}};
                if (i_mem_ready) next_state = MISS_VALID;
            end

            MISS_VALID: begin
                o_miss = 1'b1;
                if (i_mem_valid) next_state = REFILL_DONE;
            end

            REFILL_DONE: begin
                o_hit = 1'b1;
                case (saved_funct)
                    2'b00: o_cpu_data = {{24{dataArray[saved_idx][saved_victim][saved_off*8+7]}},
                                            dataArray[saved_idx][saved_victim][saved_off*8 +: 8]};
                    2'b01: o_cpu_data = {{16{dataArray[saved_idx][saved_victim][saved_off*8+15]}},
                                            dataArray[saved_idx][saved_victim][saved_off*8 +: 16]};
                    2'b10: o_cpu_data =     dataArray[saved_idx][saved_victim][saved_off*8 +: 32];
                    default: o_cpu_data = 32'b0;
                endcase
                next_state = IDLE;
            end

            default: ;
        endcase
    end

endmodule