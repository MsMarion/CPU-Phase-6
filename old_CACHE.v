/*

TLDR ----

HIT/MISS FLOW
  On i_read or i_write: all ways checked in parallel against tag + valid bit.
  HIT  -> o_hit=1, oStall=0, o_cpu_data returned (sign/zero extended via i_funct)
  MISS -> o_miss=1, oStall=1, o_mem_wr_data/o_mem_wr_addr exposed immediately for Orion.
         oStall drops the same cycle i_mem_valid arrives. CPU must re-issue next cycle.

STATE UPDATES (posedge i_clk only)
  Write-on-hit : dataArray updated by i_funct (SB/SH/SW), dirty bit set.
  Block fill   : on i_mem_valid && miss_pending -> dataArray, tagArray, validBits updated.

*/

module CACHE #(
    parameter CACHE_SIZE = 32,
    parameter BLOCK_SIZE = 64,
    parameter WAYS       = 4,
    parameter EVICT_POLICY = 0
) (
    input  wire                           i_clk,
    input  wire                           i_rstn,

    // CPU-side request
    input  wire [31:0]                    i_addr,
    input  wire                           i_read,
    input  wire                           i_write,
    input  wire [31:0]                    i_cpu_data,
    input  wire [1:0]                     i_funct,  // byte/half/word select

    // Fill from memory (on miss return)
    input  wire                           i_mem_ready,
    input  wire                           i_mem_valid,
    input  wire [BLOCK_SIZE*8-1:0]        i_mem_data,

    // Outputs
    output reg                           o_hit,
    output reg                           o_miss,
    output reg [31:0]                    o_cpu_data,
    
    // Exposed for memory
    output reg                           o_mem_rd,
    output reg                           o_mem_wr,
    output reg [31:0]                    o_mem_rd_addr,  
    output reg [31:0]                    o_mem_wr_addr,  // reconstructed address of evicted block
    output reg [BLOCK_SIZE*8-1:0]        o_mem_rd_data,  
    output reg [BLOCK_SIZE*8-1:0]        o_mem_wr_data   // dirty block data
);

    // Derived parameters
    localparam NUM_BLOCKS = (CACHE_SIZE * 1024) / BLOCK_SIZE;
    localparam NUM_SETS   = NUM_BLOCKS / WAYS;
    localparam INDEX_BITS = $clog2(NUM_SETS);
    localparam OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS;

    // Main storage structures
    reg validBits [0:NUM_SETS-1][0:WAYS-1];
    reg dirtyBits [0:NUM_SETS-1][0:WAYS-1];
    reg [TAG_BITS-1:0] tagArray [0:NUM_SETS-1][0:WAYS-1];
    reg [BLOCK_SIZE*8-1:0] dataArray [0:NUM_SETS-1][0:WAYS-1];
    reg [$clog2(WAYS)-1:0] lru_count [0:NUM_SETS-1][0:WAYS-1];

    // initialize hit and hit_way for this request
    reg hit;
    reg [$clog2(WAYS)-1:0] hit_way;
    reg [$clog2(WAYS)-1:0] victim_way; // which way is being evicted (for writeback)
    reg all_valid;

    integer way, i, j, w, u; // for loops

    reg [OFFSET_BITS-1:0] block_offset;
    reg [INDEX_BITS-1:0]  index;
    reg [TAG_BITS-1:0]    tag;
    reg miss_pending; // to track if waiting for a fill after a miss
    reg fill_phase;   // 0 = first burst, 1 = second burst 

    always @(*)
    begin
        // defaults
        o_hit         = 0;
        o_miss        = 0;
        o_cpu_data    = 0;
        o_mem_rd      = 0;
        o_mem_wr      = 0;
        o_mem_rd_addr = 0;
        o_mem_wr_addr = 0;
        o_mem_rd_data = 0;
        o_mem_wr_data = 0;
        hit           = 1'b0;
        hit_way       = 0;
        victim_way    = 0;
        all_valid     = 1;

        // extract the the components of the address
        block_offset = i_addr[OFFSET_BITS-1:0];
        index = i_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
        tag = i_addr[31:OFFSET_BITS+INDEX_BITS];

        // determine victim way using LRU logic
        for(w = 0; w < WAYS; w = w + 1) begin
            if(!validBits[index][w] && all_valid) begin // stop after first invalid
                victim_way = w;
                all_valid = 0;
            end
        end

        if(all_valid) begin
            victim_way = 0;
            for(w = 1; w < WAYS; w = w + 1) begin
                if(lru_count[index][w] > lru_count[index][victim_way])
                    victim_way = w;
            end
        end

        // check if there's a request for cache 
        if((i_read || i_write) && !miss_pending)
        begin

            // hit detection logic
            for(way = 0; way < WAYS; way = way + 1)
            begin
                // Check if the tag matches and the valid bit is set
                if(tagArray[index][way] == tag && validBits[index][way])
                begin
                    hit = 1'b1;
                    hit_way = way;
                end
            end

            if(hit)
            begin
                // HIT: return data from the matched way
                if(i_read)
                begin
                    // read data from the cache line, select the correct word based on block offset and funct3
                    case(i_funct)
                        2'b00: o_cpu_data = {{24{dataArray[index][hit_way][block_offset*8+7]}},
                                            dataArray[index][hit_way][block_offset*8 +: 8]};  // LB
                        2'b01: o_cpu_data = {{16{dataArray[index][hit_way][block_offset*8+15]}},
                                            dataArray[index][hit_way][block_offset*8 +: 16]}; // LH
                        2'b10: o_cpu_data = dataArray[index][hit_way][block_offset*8 +: 32];    // LW
                        default: o_cpu_data = 32'b0;
                    endcase
                end

                o_hit = 1'b1;
                o_miss = 1'b0;
            end

            else
            begin
                // MISS: signal the FSM to fetch from memory
                o_miss = 1'b1;
                o_hit = 1'b0; 
                
                o_mem_rd = 1'b1; 
                
                // advance address based on phase
                if (fill_phase)
                    o_mem_rd_addr = {tag, index, {OFFSET_BITS{1'b0}}} + BLOCK_SIZE;
                else
                    o_mem_rd_addr = {tag, index, {OFFSET_BITS{1'b0}}};
                
                if(dirtyBits[index][victim_way] && validBits[index][victim_way]) begin
                    o_mem_wr = 1'b1;
                    o_mem_wr_data = dataArray[index][victim_way]; // for simplicity, evict victim_way
                    o_mem_wr_addr = {tagArray[index][victim_way], index, {OFFSET_BITS{1'b0}}}; // reconstruct address of evicted block
                end
            end
        end else if (miss_pending) begin
            // Maintain miss outputs while waiting for memory
            o_miss = 1'b1;
            o_mem_rd = 1'b1;
            if (fill_phase)
                o_mem_rd_addr = {tag, index, {OFFSET_BITS{1'b0}}} + BLOCK_SIZE;
            else
                o_mem_rd_addr = {tag, index, {OFFSET_BITS{1'b0}}};

            if (i_mem_valid && fill_phase) begin
                o_miss = 1'b0;
                o_hit  = 1'b0;
                case(i_funct)
                    2'b00: o_cpu_data = {{24{i_mem_data[BLOCK_SIZE*8-1]}}, i_mem_data[BLOCK_SIZE*8-1 -: 8]};
                    2'b01: o_cpu_data = {{16{i_mem_data[BLOCK_SIZE*8-1]}}, i_mem_data[BLOCK_SIZE*8-1 -: 16]};
                    2'b10: o_cpu_data = i_mem_data[BLOCK_SIZE*8-1 -: 32];
                endcase
            end
        end
    end

    always @(posedge i_clk or negedge i_rstn)
    begin
        // on reset, clear everything
        if(!i_rstn)
        begin
            // reset all valid and dirty bits
            for(i = 0; i < NUM_SETS; i = i + 1)
            begin
                for(j = 0; j < WAYS; j = j + 1)
                begin
                    validBits[i][j] <= 1'b0;
                    dirtyBits[i][j] <= 1'b0;
                    tagArray[i][j]  <= 0;
                    dataArray[i][j] <= 0;
                    lru_count[i][j] <= j;
                end
            end
            miss_pending <= 1'b0;
            fill_phase   <= 1'b0;
        end else begin

            if(i_write && hit) 
            begin
                // write data to the cache line, select the correct word based on block offset and funct3
                case(i_funct)
                    2'b00: dataArray[index][hit_way][block_offset*8 +: 8]  <= i_cpu_data[7:0];  // SB
                    2'b01: dataArray[index][hit_way][block_offset*8 +: 16] <= i_cpu_data[15:0]; // SH
                    2'b10: dataArray[index][hit_way][block_offset*8 +: 32] <= i_cpu_data;       // SW
                endcase
                dirtyBits[index][hit_way] <= 1'b1; // mark as dirty 
            end

            // Fill logic (on miss return from memory)
            if(i_mem_valid && miss_pending) 
            begin
                if (!fill_phase) begin
                    fill_phase <= 1'b1; // First burst done, wait for second
                end else begin
                    fill_phase   <= 1'b0;
                    miss_pending <= 1'b0; // Second burst done, miss resolved
                    dataArray[index][victim_way] <= i_mem_data; 
                    tagArray[index][victim_way] <= tag; 
                    validBits[index][victim_way] <= 1'b1; 
                    dirtyBits[index][victim_way] <= 1'b0; 
                end
            end else if((i_read || i_write) && !hit) begin 
                miss_pending <= 1'b1;
            end

            // Update LRU states
            if(((i_read || i_write) && hit) || (i_mem_valid && miss_pending && fill_phase)) begin
                for(u = 0; u < WAYS; u = u + 1) begin
                    if(u == (hit ? hit_way : victim_way))
                        lru_count[index][u] <= 0;
                    else if(lru_count[index][u] < WAYS-1)
                        lru_count[index][u] <= lru_count[index][u] + 1;
                end
            end
        end
    end

endmodule