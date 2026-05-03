/*
    notes
    i-cache, stores recently fetched instructions so if stage can grab next in cycle
    d-cache, mem stage reads/writes data, holds recently accessed data words 
    on miss, the pipeline is stalled 
    takes 100 cycles in miss
    heap is 0x10040000 – 0xFFFEFFFF
    i-cache 0x00400000 – 0x0FFFFFFF
    d-cache 0x10010000 – 0x1003FFFF
    no need for cache coherence, cache coherence is where multiple caches hold copies of same memory location
    two caches access diff address ranges and diff things, no conflict

    plru is the tree system, 0 left, 1 right
    lru is the linkedin list system, EXPENSIVE
    one policy is picked between the two, should be a flag, lets do both to get 3 points hell yes 

    victim is the cache block that wasn't accessed recently and needs to be kicked out due to lru/plru, when miss happens and the set is full, this is it lol
    dirty, means block was written to and hasn't been saved to main memory (main memory is out of date), dirty bit is flagged as 1
    if dirty block is victim, we need to write it back first and then delete yk

    my module is to do plru lru and outputting ovctimway to know who to victimize
    i can also evict invalid one over a live one (best victim lol)
    when access happens, output oprefetchreq and the addy hey go to this one dude
    
    */

module REPLACE_POLICY #(
    parameter ASSOC      = 2, // 1=direct, 2=2-way, numsets is fully associative
    parameter NUM_SETS   = 32,
    parameter BLOCK_SIZE = 16,
    parameter IS_LRU = 1 // flag for using plru/lru; LRU=1, PLRU=0
) (
    input  wire        iClk,
    input  wire        iRstN,
    // access info from cache
    input  wire [$clog2(NUM_SETS)-1:0] iSetIndex,
    input  wire        iAccessValid,   // a real access happened
    input  wire        iHit,
    input  wire [$clog2(ASSOC)-1:0] iHitWay,
    input  wire [ASSOC-1:0] iValidBits,
    // victim selection output
    output wire [$clog2(ASSOC)-1:0] oVictimWay,
    // prefetch
    input  wire [31:0] iAddress,       // current access address
    input  wire        iMiss,          // current access is a miss
    output wire        oPrefetchReq,   // request to prefetch next block
    output wire [31:0] oPrefetchAddr,  // address of next sequential block
    // prefetch victim query (combinational, separate from demand victim)
    input  wire [$clog2(NUM_SETS)-1:0] iPfSetIndex,
    input  wire [ASSOC-1:0]            iPfValidBits,
    output wire [$clog2(ASSOC)-1:0]    oPfVictimWay,
    // prefetch fill: mark the filled way as LRU so future evictions match update_mru
    input  wire                           iPfFill,
    input  wire [$clog2(NUM_SETS)-1:0]    iPfFillSetIdx,
    input  wire [$clog2(ASSOC)-1:0]       iPfFillWay,
    // BEGIN PATCH
    // demand fill: update LRU when demand memory returns (matches C++ update_lru timing)
    input  wire                           iDemandFill,
    input  wire [$clog2(NUM_SETS)-1:0]    iDemandFillSetIdx,
    input  wire [$clog2(ASSOC)-1:0]       iDemandFillWay
    // END PATCH
);

    // consts for bits
    localparam WAY_BITS  = (ASSOC == 1) ? 1 : $clog2(ASSOC);
    localparam TREE_BITS = (ASSOC > 1) ? (ASSOC-1) : 1;

    // !!! lru 2-way
    reg lruBit  [0:NUM_SETS-1];
    reg plruBit [0:NUM_SETS-1];

    // zero-extend to WAY_BITS to avoid warnings
    wire [WAY_BITS-1:0] lruVictim2way  = {{(WAY_BITS-1){1'b0}}, ~lruBit[iSetIndex]};
    wire [WAY_BITS-1:0] plruVictim2way = {{(WAY_BITS-1){1'b0}},  plruBit[iSetIndex]};

    integer x;
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            for (x = 0; x < NUM_SETS; x = x + 1) begin
                lruBit[x]  <= 1'b0;
                plruBit[x] <= 1'b0;
            end
        end else if (iAccessValid && iHit) begin
            lruBit[iSetIndex]  <= iHitWay[0];
            plruBit[iSetIndex] <= ~iHitWay[0];
        end
    end


    // !!! lru n-way
    reg [WAY_BITS-1:0] lruAge [0:NUM_SETS-1][0:ASSOC-1];
    reg [WAY_BITS-1:0] lruVictimNway;

    integer y;
    always @(*) begin : selectlru
        reg [WAY_BITS-1:0] max;
        max = {WAY_BITS{1'b0}};
        lruVictimNway = {WAY_BITS{1'b0}};
        for (y = 0; y < ASSOC; y = y + 1) begin
            if (iValidBits[y]) begin
                if (lruAge[iSetIndex][y] > max) begin
                    max = lruAge[iSetIndex][y];
                    lruVictimNway = y[WAY_BITS-1:0];
                end
            end
        end
    end

    integer z;
    integer k;
    integer e;
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            for (z = 0; z < NUM_SETS; z = z + 1)
                for (k = 0; k < ASSOC; k = k + 1)
                    lruAge[z][k] <= {WAY_BITS{1'b0}};
        end else if (iHit && iAccessValid) begin
            for (e = 0; e < ASSOC; e = e + 1) begin
                if (e[WAY_BITS-1:0] == iHitWay)
                    lruAge[iSetIndex][e] <= {WAY_BITS{1'b0}};
                else if (lruAge[iSetIndex][e] <= lruAge[iSetIndex][iHitWay] && lruAge[iSetIndex][e] < {WAY_BITS{1'b1}})
                    lruAge[iSetIndex][e] <= lruAge[iSetIndex][e] + 1'b1;
            end
        // BEGIN PATCH
        end else if (iDemandFill) begin
        // update LRU when demand fill completes — matches C++ update_lru(set, way) timing
            for (e = 0; e < ASSOC; e = e + 1) begin
                if (e[WAY_BITS-1:0] == iDemandFillWay)
                    lruAge[iDemandFillSetIdx][e] <= {WAY_BITS{1'b0}};
                else if (lruAge[iDemandFillSetIdx][e] <= lruAge[iDemandFillSetIdx][iDemandFillWay] && lruAge[iDemandFillSetIdx][e] < {WAY_BITS{1'b1}})
                    lruAge[iDemandFillSetIdx][e] <= lruAge[iDemandFillSetIdx][e] + 1'b1;
            end
        // END PATCH
        end else if (iPfFill) begin
            // mirror C++ update_mru: mark prefetched way as LRU so it's evicted before demand fills
            lruAge[iPfFillSetIdx][iPfFillWay] <= {WAY_BITS{1'b1}};
        end
    end


    // !!! plru n-way (tree)
    reg [TREE_BITS-1:0] plruTree     [0:NUM_SETS-1];
    reg [WAY_BITS-1:0]  plruVictimNway;

    always @(*) begin : selectplru
        reg [WAY_BITS-1:0] node;
        reg [WAY_BITS-1:0] wayIndex;
        integer l;
        integer nL;
        node     = {WAY_BITS{1'b0}};
        wayIndex = {WAY_BITS{1'b0}};
        nL = WAY_BITS;
        for (l = 0; l < nL; l = l + 1) begin
            if (plruTree[iSetIndex][node]) begin
                wayIndex[nL-1-l] = 1'b1;
                node = 2*node + 2;
            end else begin
                wayIndex[nL-1-l] = 1'b0;
                node = 2*node + 1;
            end
        end
        plruVictimNway = wayIndex;
    end

    // allow non-blocking assignments to array[variable_index] inside loops).
    //we pre-compute which node each tree level touches combinatorially,
    // then do a single non-blocking write per level using those fixed indices.
    reg [WAY_BITS-1:0] plruNode [0:WAY_BITS-1]; // node index at each level
    reg                plruDir  [0:WAY_BITS-1]; // direction bit to write at each level

    integer cp;
    always @(*) begin : plruPrecompute
        reg [WAY_BITS-1:0] n;
        n = {WAY_BITS{1'b0}};
        for (cp = 0; cp < WAY_BITS; cp = cp + 1) begin
            plruNode[cp] = n;
            if (iHitWay[WAY_BITS-1-cp]) begin
                plruDir[cp] = 1'b0; // point away from right -> left
                n = 2*n + 2;
            end else begin
                plruDir[cp] = 1'b1; // point away from left -> right
                n = 2*n + 1;
            end
        end
    end

    integer gp;
    integer lp;
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            for (gp = 0; gp < NUM_SETS; gp = gp + 1)
                plruTree[gp] <= {TREE_BITS{1'b0}};
        end else if (iHit && iAccessValid) begin
            // each level writes to a statically-known index within the set
            // (plruNode[lp] is combinatorial, not a loop-carried variable here)
            for (lp = 0; lp < WAY_BITS; lp = lp + 1)
                plruTree[iSetIndex][plruNode[lp]] <= plruDir[lp];
        end
    end


    // !!! invalid way scan — prefer empty slot over evicting live line
    reg [WAY_BITS-1:0] invalidWayIndex;
    reg                isInvalid;
    integer i;

    always @(*) begin
        isInvalid      = 1'b0;
        invalidWayIndex = {WAY_BITS{1'b0}};
        for (i = 0; i < ASSOC; i = i + 1) begin
            if (!iValidBits[i] && !isInvalid) begin
                isInvalid       = 1'b1;
                invalidWayIndex = i[WAY_BITS-1:0];
            end
        end
    end

    // !!! victim selection
    reg [WAY_BITS-1:0] oVictimWayTemp;
    always @(*) begin
        if (ASSOC == 1)
            oVictimWayTemp = {WAY_BITS{1'b0}};
        else if (ASSOC == 2)
            oVictimWayTemp = IS_LRU ? lruVictim2way : plruVictim2way;
        else
            oVictimWayTemp = IS_LRU ? lruVictimNway : plruVictimNway;

        if (isInvalid)
            oVictimWayTemp = invalidWayIndex;
    end

    assign oVictimWay = oVictimWayTemp;

    // !!! prefetch victim query — combinational, uses iPfSetIndex/iPfValidBits
    integer ip, yp;

    reg [WAY_BITS-1:0] pfInvalidWayIndex;
    reg                pfIsInvalid;
    always @(*) begin
        pfIsInvalid      = 1'b0;
        pfInvalidWayIndex = {WAY_BITS{1'b0}};
        for (ip = 0; ip < ASSOC; ip = ip + 1) begin
            if (!iPfValidBits[ip] && !pfIsInvalid) begin
                pfIsInvalid       = 1'b1;
                pfInvalidWayIndex = ip[WAY_BITS-1:0];
            end
        end
    end

    reg [WAY_BITS-1:0] pfVictimNway;
    always @(*) begin : selectpflru
        reg [WAY_BITS-1:0] mx;
        mx         = {WAY_BITS{1'b0}};
        pfVictimNway = {WAY_BITS{1'b0}};
        for (yp = 0; yp < ASSOC; yp = yp + 1) begin
            if (iPfValidBits[yp]) begin
                if (lruAge[iPfSetIndex][yp] > mx) begin
                    mx           = lruAge[iPfSetIndex][yp];
                    pfVictimNway = yp[WAY_BITS-1:0];
                end
            end
        end
    end

    reg [WAY_BITS-1:0] oPfVictimWayTemp;
    always @(*) begin
        oPfVictimWayTemp = pfVictimNway;
        if (pfIsInvalid)
            oPfVictimWayTemp = pfInvalidWayIndex;
    end
    assign oPfVictimWay = oPfVictimWayTemp;

    // !!! prefetch — fire on miss
    wire [31:0] base = iAddress & ~(32'd0 + BLOCK_SIZE - 1);
    wire [31:0] next = base + BLOCK_SIZE;

    assign oPrefetchReq  = iAccessValid & iMiss;
    assign oPrefetchAddr = next;

endmodule