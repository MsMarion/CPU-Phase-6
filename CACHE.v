/*

NOTES ----

Cache is made of different components:

    - Tag Array: A tag is the upper portion of data address. When the CPU asks for data, the cache compares 
                 the incoming address's tag against every stored tag to check for a match.

    - Valid Bits: A single bit per cache line that determines if it holds real data. 
                  On power-up or after a reset, all valid bits are 0. A hit requires both a tag match and a valid bit of 1.

    - Dirty Bits: This only matters for a write-back cache policy. If the CPU writes to a cached block, 
                  instead of immediately writing back to main memory, you just mark that block as "dirty." 
                  The dirty bit means: this block has been modified and is out of sync with main memory. When that block 
                  eventually gets evicted, the dirty bit tells the system to write it back before discarding it.

    - Data Array: Actual storage. Indexed by set and way 


    Addresses are divided into 3 parts:
        | Tag | Index | Block Offset |
        tag: memory
        index: which cache set to look in
        block offset: which byte within the cache line


    Hit Detection Logic
        When the CPU requests an address, the cache:

        Extracts the index to find the right set.
        Simultaneously compares the incoming tag against all N ways in that set.
        Also checks that the matching way's valid bit is 1.
        If both conditions are true → HIT, return the data from the matched way.
        If no way matches (or valid = 0) → MISS, signal the FSM.
*/

module CACHE #(
    parameter CACHE_SIZE = 1024,
    parameter BLOCK_SIZE = 16,
    parameter ASSOC      = 2
) (
    input  wire                           iClk,
    input  wire                           iRstN,

    // CPU-side request
    input  wire [31:0]                    iAddress,
    input  wire                           iReadEn,
    input  wire                           iWriteEn,
    input  wire [31:0]                    iWriteData,
    input  wire [2:0]                     iFunct3,        // byte/half/word select

    // Fill from memory (on miss return)
    input  wire                           iFillEn,
    input  wire [BLOCK_SIZE*8-1:0]        iFillData,
    input  wire [$clog2(ASSOC)-1:0]        iFillWay,  // which way to fill

    input wire [$clog2(ASSOC)-1:0]         iVictimWay, // which way is being evicted (for writeback)

    // Outputs
    output reg                           oHit,
    output reg                           oMiss,
    output reg [31:0]                    oReadData,
    output reg                           oDirty,                          // victim is dirty?
    output reg [BLOCK_SIZE*8-1:0]        oEvictData,          // dirty block data
    output reg [31:0]                    oEvictAddr,                      // reconstructed address of evicted block
    output reg [$clog2(ASSOC)-1:0]        oHitWay,            // which way hit
    // Exposed for replacement policy
    output reg [ASSOC-1:0]               oValidBits,                 // valid bits for accessed set
    output reg [ASSOC-1:0]               oDirtyBits,                  // dirty bits for accessed set
    output reg                           oStall                            // stall CPU on miss until fill completes
);

    // Derived parameters
    localparam NUM_BLOCKS = CACHE_SIZE / BLOCK_SIZE;
    localparam NUM_SETS   = NUM_BLOCKS / ASSOC;
    localparam INDEX_BITS = $clog2(NUM_SETS);
    localparam OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS;

    // Main storage structures
    reg [NUM_SETS-1:0][ASSOC-1:0] validBits;
    reg [NUM_SETS-1:0][ASSOC-1:0] dirtyBits;
    reg [NUM_SETS-1:0][ASSOC-1:0][TAG_BITS-1:0] tagArray;
    reg [NUM_SETS-1:0][ASSOC-1:0][BLOCK_SIZE*8-1:0] dataArray;

    // initialize hit and hit_way for this request
    reg hit = 1'b0;
    reg [$clog2(ASSOC)-1:0] hit_way = 1'b0;
    integer way, i, j; // for loops

    reg [OFFSET_BITS-1:0] block_offset;
    reg [INDEX_BITS-1:0]  index;
    reg [TAG_BITS-1:0]    tag;
    reg miss_pending; // to track if waiting for a fill after a miss

    always @(*)
    begin
        // defaults
        oHit      = 0;
        oMiss     = 0;
        oStall    = 0;
        oReadData = 0;
        oDirty    = 0;
        oEvictData = 0;
        oEvictAddr = 0;
        oHitWay   = 0;
        oValidBits = 0;
        oDirtyBits = 0;
        hit = 1'b0;
        hit_way = 0;

        // extract the the components of the address
        block_offset = iAddress[OFFSET_BITS-1:0];
        index = iAddress[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
        tag = iAddress[31:OFFSET_BITS+INDEX_BITS];

        // check if there's a request for cache 
        if((iReadEn || iWriteEn))
        begin

            // hit detection logic
            for(way = 0; way < ASSOC; way = way + 1)
            begin
                // Check if the tag matches and the valid bit is set
                if(tagArray[index][way] == tag && validBits[index][way] == 1'b1)
                begin
                    hit = 1'b1;
                    hit_way = way;
                end
            end

            if(hit)
            begin
                // HIT: return data from the matched way
                if(iReadEn)
                begin
                    // read data from the cache line, select the correct word based on block offset and funct3
                    case(iFunct3)
                        3'b000: oReadData = {{24{dataArray[index][hit_way][block_offset*8+7]}}, 
                                            dataArray[index][hit_way][block_offset*8 +: 8]}; // LB
                        3'b001: oReadData = {{16{dataArray[index][hit_way][block_offset*8+15]}}, 
                                            dataArray[index][hit_way][block_offset*8 +: 16]}; // LH
                        3'b010: oReadData = dataArray[index][hit_way][block_offset*8 +: 32]; // LW
                        3'b100: oReadData = {24'b0, dataArray[index][hit_way][block_offset*8 +: 8]}; // LBU
                        3'b101: oReadData = {16'b0, dataArray[index][hit_way][block_offset*8 +: 16]}; // LHU
                        default: oReadData = 32'b0;
                    endcase
                end

                oHitWay = hit_way;
                oDirtyBits = dirtyBits[index]; // expose dirty bits for replacement policy
                oValidBits = validBits[index]; // expose valid bits for replacement policy
                oHit = 1'b1;
                oMiss = 1'b0;
                oStall = 1'b0; // no stall on hit
            end

            else
            begin
                // MISS: signal the FSM to fetch from memory
                oMiss = 1'b1;
                oHitWay = 1'b0; // no hit way on miss
                oHit = 1'b0; 
                oDirtyBits = dirtyBits[index]; // expose dirty bits for replacement policy
                oValidBits = validBits[index]; // expose valid bits for replacement policy
                
                oEvictData = dataArray[index][iVictimWay]; // for simplicity, evict way 0 
                oEvictAddr = {tagArray[index][iVictimWay], index, {OFFSET_BITS{1'b0}}}; // reconstruct address of evicted block
                oDirty = dirtyBits[index][iVictimWay]; // indicate if the victim block is dirty
                
                oStall = !iFillEn; // stall CPU until fill completes
            end
        end
    end

    always @(posedge iClk or negedge iRstN)
    begin
        // on reset, clear everything
        if(!iRstN)
        begin
            // reset all valid and dirty bits
            for(i = 0; i < NUM_SETS; i = i + 1)
            begin
                for(j = 0; j < ASSOC; j = j + 1)
                begin
                    validBits[i][j] <= 1'b0;
                    dirtyBits[i][j] <= 1'b0;
                    tagArray[i][j] <= {TAG_BITS{1'b0}};
                    dataArray[i][j] <= {BLOCK_SIZE*8{1'b0}};
                end
            end
            miss_pending <= 1'b0;
        end else begin

            if(iWriteEn && hit) 
            begin
                // write data to the cache line, select the correct word based on block offset and funct3
                case(iFunct3)
                    3'b000: dataArray[index][hit_way][block_offset*8 +: 8]  <= iWriteData[7:0];  // SB
                    3'b001: dataArray[index][hit_way][block_offset*8 +: 16] <= iWriteData[15:0]; // SH
                    3'b010: dataArray[index][hit_way][block_offset*8 +: 32] <= iWriteData;       // SW
                endcase
                dirtyBits[index][hit_way] <= 1'b1; // mark as dirty 
            end

            if(iFillEn) begin
                miss_pending <= 1'b0;
            end else if((iReadEn || iWriteEn) && !hit) begin // if miss
                miss_pending <= 1'b1;
            end

            // Fill logic (on miss return from memory)
            if(iFillEn && miss_pending) 
            begin
                dataArray[index][iFillWay] <= iFillData; // fill the block
                tagArray[index][iFillWay] <= tag; // update the tag
                validBits[index][iFillWay] <= 1'b1; // mark as valid
                dirtyBits[index][iFillWay] <= 1'b0; // clear dirty bit
            end
        end
    end

endmodule