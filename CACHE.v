/*
    Updated CACHE.v to match Phase 6 Handshake Specification.
    - Parameterized EVICT_POLICY, WAYS, CACHE_SIZE (KB), BLOCK_SIZE (B).
    - Handshake logic for memory interface (i_mem_ready, i_mem_valid).
    - Integrated replacement policy.
*/

module CACHE #(
    parameter EVICT_POLICY = 0, // 0 = LRU, 1 = PLRU
    parameter WAYS         = 4,
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
    input  [BLOCK_SIZE*8-1:0] i_mem_data,
    // CPU interface outputs
    output reg o_hit,
    output reg o_miss,
    output reg [31:0] o_cpu_data,
    // MEM interface outputs
    output reg o_mem_rd,
    output reg o_mem_wr,
    output reg [31:0] o_mem_rd_addr,
    output reg [31:0] o_mem_wr_addr,
    output reg [BLOCK_SIZE*8-1:0] o_mem_rd_data, // usually unused by memory
    output reg [BLOCK_SIZE*8-1:0] o_mem_wr_data
);

    // Derived parameters
    localparam TOTAL_SIZE_BYTES = CACHE_SIZE * 1024;
    localparam NUM_SETS         = TOTAL_SIZE_BYTES / (BLOCK_SIZE * WAYS);
    localparam OFF_BITS         = $clog2(BLOCK_SIZE);
    localparam IDX_BITS         = $clog2(NUM_SETS);
    localparam TAG_BITS         = 32 - IDX_BITS - OFF_BITS;

    // Internal Storage
    reg [TAG_BITS-1:0]        tagArray   [NUM_SETS-1:0][WAYS-1:0];
    reg                       validBits  [NUM_SETS-1:0][WAYS-1:0];
    reg                       dirtyBits  [NUM_SETS-1:0][WAYS-1:0];
    reg [BLOCK_SIZE*8-1:0]    dataArray  [NUM_SETS-1:0][WAYS-1:0];

    // FSM States
    localparam IDLE       = 3'd0;
    localparam LOOKUP     = 3'd1;
    localparam MISS_READY = 3'd2; // Wait for memory ready
    localparam MISS_VALID = 3'd3; // Wait for memory valid (data return)
    localparam WB_READY   = 3'd4; // Wait for memory ready (writeback)
    localparam WB_VALID   = 3'd5; // Wait for memory finish (writeback)

    reg [2:0] state, next_state;

    // Address decomposition
    wire [TAG_BITS-1:0] current_tag = i_addr[31 : IDX_BITS+OFF_BITS];
    wire [IDX_BITS-1:0] current_idx = i_addr[IDX_BITS+OFF_BITS-1 : OFF_BITS];
    wire [OFF_BITS-1:0] current_off = i_addr[OFF_BITS-1 : 0];

    // Hit detection
    reg hit;
    reg [$clog2(WAYS)-1:0] hit_way;
    integer w;
    always @(*) begin
        hit = 1'b0;
        hit_way = 0;
        for (w = 0; w < WAYS; w = w + 1) begin
            if (validBits[current_idx][w] && (tagArray[current_idx][w] == current_tag)) begin
                hit = 1'b1;
                hit_way = w[$clog2(WAYS)-1:0];
            end
        end
    end

    // Replacement Policy instantiation
    wire [$clog2(WAYS)-1:0] victim_way;
    REPLACE_POLICY #(
        .ASSOC(WAYS),
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
        .iValidBits(8'b0), // Need to pack valid bits correctly for n-way
        .oVictimWay(victim_way)
        // prefetch signals left unconnected for now
    );

    // Pack valid bits for replacement policy input
    reg [WAYS-1:0] packed_valid;
    integer v;
    always @(*) begin
        for (v = 0; v < WAYS; v = v + 1) packed_valid[v] = validBits[current_idx][v];
    end

    // FSM logic
    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            state <= IDLE;
            // Reset arrays (simulation only usually, but good practice)
            for (integer i=0; i<NUM_SETS; i++) begin
                for (integer j=0; j<WAYS; j++) begin
                    validBits[i][j] <= 1'b0;
                    dirtyBits[i][j] <= 1'b0;
                end
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (i_read || i_write) begin
                        if (hit) begin
                            if (i_write) begin
                                // Perform write
                                case (i_funct)
                                    2'b00: dataArray[current_idx][hit_way][current_off*8 +: 8]  <= i_cpu_data[7:0];
                                    2'b01: dataArray[current_idx][hit_way][current_off*8 +: 16] <= i_cpu_data[15:0];
                                    2'b10: dataArray[current_idx][hit_way][current_off*8 +: 32] <= i_cpu_data;
                                endcase
                                dirtyBits[current_idx][hit_way] <= 1'b1;
                            end
                        end
                    end
                end

                MISS_VALID: begin
                    if (i_mem_valid) begin
                        // Fill line
                        dataArray[current_idx][victim_way] <= i_mem_data;
                        tagArray[current_idx][victim_way]  <= current_tag;
                        validBits[current_idx][victim_way] <= 1'b1;
                        dirtyBits[current_idx][victim_way] <= 1'b0;
                    end
                end
                
                WB_VALID: begin
                    if (i_mem_valid) begin
                        // Writeback complete, now fetch the new block
                        // Handled in next_state logic
                    end
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        o_mem_rd = 1'b0;
        o_mem_wr = 1'b0;
        o_hit    = 1'b0;
        o_miss   = 1'b0;

        case (state)
            IDLE: begin
                if (i_read || i_write) begin
                    if (hit) begin
                        o_hit = 1'b1;
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
                o_miss = 1'b1;
                o_mem_wr = 1'b1;
                o_mem_wr_addr = {tagArray[current_idx][victim_way], current_idx, {OFF_BITS{1'b0}}};
                o_mem_wr_data = dataArray[current_idx][victim_way];
                if (i_mem_ready) next_state = WB_VALID;
            end

            WB_VALID: begin
                o_miss = 1'b1;
                if (i_mem_valid) next_state = MISS_READY;
            end

            MISS_READY: begin
                o_miss = 1'b1;
                o_mem_rd = 1'b1;
                o_mem_rd_addr = {current_tag, current_idx, {OFF_BITS{1'b0}}};
                if (i_mem_ready) next_state = MISS_VALID;
            end

            MISS_VALID: begin
                o_miss = 1'b1;
                if (i_mem_valid) next_state = IDLE; // Return to IDLE to re-check hit (will be a hit now)
            end
        endcase
    end

    // o_cpu_data read logic
    always @(*) begin
        o_cpu_data = 32'b0;
        if (hit) begin
            case (i_funct)
                2'b00: o_cpu_data = {{24{dataArray[current_idx][hit_way][current_off*8+7]}}, dataArray[current_idx][hit_way][current_off*8 +: 8]};
                2'b01: o_cpu_data = {{16{dataArray[current_idx][hit_way][current_off*8+15]}}, dataArray[current_idx][hit_way][current_off*8 +: 16]};
                2'b10: o_cpu_data = dataArray[current_idx][hit_way][current_off*8 +: 32];
            endcase
        end
    end

endmodule