module REPLACE_POLICY #(
    parameter ASSOC      = 2, // 1=direct map, 2=2-way, higher=n-way
    parameter NUM_SETS   = 32,
    parameter BLOCK_SIZE = 16,
    parameter IS_LRU = 1 // 1=LRU, 0=PLRU
) (
    input  wire        iClk,
    input  wire        iRstN,
    // access info from cache
    input  wire [$clog2(NUM_SETS)-1:0] iSetIndex,
    input  wire        iAccessValid,
    input  wire        iHit,
    input  wire [$clog2(ASSOC)-1:0] iHitWay,
    input  wire [ASSOC-1:0] iValidBits,
    // victim selection output
    output wire [$clog2(ASSOC)-1:0] oVictimWay,
    // prefetch
    input  wire [31:0] iAddress,
    input  wire        iMiss,
    output wire        oPrefetchReq,
    output wire [31:0] oPrefetchAddr,
    // prefetch victim query (combinational, separate from demand victim)
    input  wire [$clog2(NUM_SETS)-1:0] iPfSetIndex,
    input  wire [ASSOC-1:0]            iPfValidBits,
    output wire [$clog2(ASSOC)-1:0]    oPfVictimWay,
    // fill notifications: update replacement state when a block is loaded
    input  wire                           iPfFill,
    input  wire [$clog2(NUM_SETS)-1:0]    iPfFillSetIdx,
    input  wire [$clog2(ASSOC)-1:0]       iPfFillWay,
    input  wire                           iDemandFill,
    input  wire [$clog2(NUM_SETS)-1:0]    iDemandFillSetIdx,
    input  wire [$clog2(ASSOC)-1:0]       iDemandFillWay
);

    localparam WAY_BITS  = (ASSOC == 1) ? 1 : $clog2(ASSOC);
    localparam TREE_BITS = (ASSOC > 1) ? (ASSOC-1) : 1;

    // 2-way LRU/PLRU: one bit per set
    reg lruBit  [0:NUM_SETS-1];
    reg plruBit [0:NUM_SETS-1];

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

    // N-way LRU: track age of each way (higher age = least recently used)
    reg [WAY_BITS-1:0] age [0:NUM_SETS-1][0:ASSOC-1];
    reg [WAY_BITS-1:0] lru_victim;

    integer y;
    always @(*) begin : selectlru
        reg [WAY_BITS-1:0] max;
        max = {WAY_BITS{1'b0}};
        lru_victim = {WAY_BITS{1'b0}};
        for (y = 0; y < ASSOC; y = y + 1) begin
            if (iValidBits[y]) begin
                if (age[iSetIndex][y] > max) begin
                    max        = age[iSetIndex][y];
                    lru_victim = y[WAY_BITS-1:0];
                end
            end
        end
    end

    integer z;
    integer k;
    integer e;

    // Delayed-print registers: capture update metadata at posedge, print one cycle later
    reg                        dbg_lru_print;
    reg [$clog2(NUM_SETS)-1:0] dbg_lru_set;
    reg [1:0]                  dbg_lru_kind; // 0=hit, 1=demand_fill, 2=pf_fill
    reg [WAY_BITS-1:0]         dbg_lru_way;
    integer                    dbg_acc; // mirrors CACHE dbg_access for print gating

    task dbg_lru_ages;
        input [$clog2(NUM_SETS)-1:0] set_i;
        integer wi;
        begin
            $write("  lru_ages set[%0d]:", set_i);
            for (wi = 0; wi < ASSOC; wi = wi + 1)
                $write(" way%0d=%0d", wi, age[set_i][wi]);
            $write("\n");
        end
    endtask

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            for (z = 0; z < NUM_SETS; z = z + 1)
                for (k = 0; k < ASSOC; k = k + 1)
                    age[z][k] <= {WAY_BITS{1'b0}};
            dbg_lru_print <= 1'b0;
            dbg_lru_set   <= {$clog2(NUM_SETS){1'b0}};
            dbg_lru_kind  <= 2'd0;
            dbg_lru_way   <= {WAY_BITS{1'b0}};
            dbg_acc       <= 0;
        end else if (iHit && iAccessValid) begin
            for (e = 0; e < ASSOC; e = e + 1) begin
                if (e[WAY_BITS-1:0] == iHitWay)
                    age[iSetIndex][e] <= {WAY_BITS{1'b0}};
                else if (age[iSetIndex][e] <= age[iSetIndex][iHitWay] && age[iSetIndex][e] < {WAY_BITS{1'b1}})
                    age[iSetIndex][e] <= age[iSetIndex][e] + 1'b1;
            end
            dbg_lru_print <= 1'b1;
            dbg_lru_set   <= iSetIndex;
            dbg_lru_kind  <= 2'd0;
            dbg_lru_way   <= iHitWay[WAY_BITS-1:0];
            dbg_acc       <= dbg_acc + 1;
        end else if (iDemandFill) begin
            for (e = 0; e < ASSOC; e = e + 1) begin
                if (e[WAY_BITS-1:0] == iDemandFillWay)
                    age[iDemandFillSetIdx][e] <= {WAY_BITS{1'b0}};
                else if (age[iDemandFillSetIdx][e] <= age[iDemandFillSetIdx][iDemandFillWay] && age[iDemandFillSetIdx][e] < {WAY_BITS{1'b1}})
                    age[iDemandFillSetIdx][e] <= age[iDemandFillSetIdx][e] + 1'b1;
            end
            dbg_lru_print <= 1'b1;
            dbg_lru_set   <= iDemandFillSetIdx;
            dbg_lru_kind  <= 2'd1;
            dbg_lru_way   <= iDemandFillWay;
            dbg_acc       <= dbg_acc + 1;
        end else if (iPfFill) begin
            // mark prefetched way as oldest so demand fills evict it first
            age[iPfFillSetIdx][iPfFillWay] <= {WAY_BITS{1'b1}};
            dbg_lru_print <= 1'b1;
            dbg_lru_set   <= iPfFillSetIdx;
            dbg_lru_kind  <= 2'd2;
            dbg_lru_way   <= iPfFillWay;
        end else begin
            dbg_lru_print <= 1'b0;
        end
    end

    // Delayed print: fires one cycle after the age[] update so values are visible
    always @(posedge iClk) begin
        if (dbg_lru_print && dbg_acc <= 41) begin
            case (dbg_lru_kind)
                2'd0: $display("  [LRU] hit  set=%0d way=%0d -> age reset", dbg_lru_set, dbg_lru_way);
                2'd1: $display("  [LRU] fill set=%0d way=%0d -> age reset", dbg_lru_set, dbg_lru_way);
                2'd2: $display("  [LRU] pf_fill set=%0d way=%0d -> age set MAX", dbg_lru_set, dbg_lru_way);
                default: ;
            endcase
            dbg_lru_ages(dbg_lru_set);
        end
    end

    // N-way PLRU: binary tree per set
    reg [TREE_BITS-1:0] plruTree     [0:NUM_SETS-1];
    reg [WAY_BITS-1:0]  plru_victim;

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
        plru_victim = wayIndex;
    end

    // Pre-compute node/direction for each tree level so loop body uses fixed indices,
    // allowing non-blocking assignments inside the sequential always block.
    reg [WAY_BITS-1:0] plruNode [0:WAY_BITS-1];
    reg                plruDir  [0:WAY_BITS-1];

    integer cp;
    always @(*) begin : plruPrecompute
        reg [WAY_BITS-1:0] n;
        n = {WAY_BITS{1'b0}};
        for (cp = 0; cp < WAY_BITS; cp = cp + 1) begin
            plruNode[cp] = n;
            if (iHitWay[WAY_BITS-1-cp]) begin
                plruDir[cp] = 1'b0;
                n = 2*n + 2;
            end else begin
                plruDir[cp] = 1'b1;
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
            for (lp = 0; lp < WAY_BITS; lp = lp + 1)
                plruTree[iSetIndex][plruNode[lp]] <= plruDir[lp];
        end
    end

    // Prefer filling an invalid (empty) way over evicting a live block
    reg [WAY_BITS-1:0] empty_way;
    reg                has_empty;
    integer i;

    always @(*) begin
        has_empty = 1'b0;
        empty_way = {WAY_BITS{1'b0}};
        for (i = 0; i < ASSOC; i = i + 1) begin
            if (!iValidBits[i] && !has_empty) begin
                has_empty = 1'b1;
                empty_way = i[WAY_BITS-1:0];
            end
        end
    end

    reg [WAY_BITS-1:0] victim_sel;
    always @(*) begin
        if (ASSOC == 1)
            victim_sel = {WAY_BITS{1'b0}};
        else if (ASSOC == 2)
            victim_sel = IS_LRU ? lruVictim2way : plruVictim2way;
        else
            victim_sel = IS_LRU ? lru_victim : plru_victim;

        if (has_empty)
            victim_sel = empty_way;
    end

    assign oVictimWay = victim_sel;

    integer ip, yp;

    reg [WAY_BITS-1:0] pf_empty_way;
    reg                pf_has_empty;
    always @(*) begin
        pf_has_empty = 1'b0;
        pf_empty_way = {WAY_BITS{1'b0}};
        for (ip = 0; ip < ASSOC; ip = ip + 1) begin
            if (!iPfValidBits[ip] && !pf_has_empty) begin
                pf_has_empty = 1'b1;
                pf_empty_way = ip[WAY_BITS-1:0];
            end
        end
    end

    reg [WAY_BITS-1:0] pf_lru_victim;
    always @(*) begin : selectpflru
        reg [WAY_BITS-1:0] mx;
        mx           = {WAY_BITS{1'b0}};
        pf_lru_victim = {WAY_BITS{1'b0}};
        for (yp = 0; yp < ASSOC; yp = yp + 1) begin
            if (iPfValidBits[yp]) begin
                if (age[iPfSetIndex][yp] > mx) begin
                    mx            = age[iPfSetIndex][yp];
                    pf_lru_victim = yp[WAY_BITS-1:0];
                end
            end
        end
    end

    reg [WAY_BITS-1:0] pf_victim_sel;
    always @(*) begin
        pf_victim_sel = pf_lru_victim;
        if (pf_has_empty)
            pf_victim_sel = pf_empty_way;
    end
    assign oPfVictimWay = pf_victim_sel;

    wire [31:0] base = iAddress & ~(32'd0 + BLOCK_SIZE - 1);
    wire [31:0] next = base + BLOCK_SIZE;

    assign oPrefetchReq  = iAccessValid & iMiss;
    assign oPrefetchAddr = next;

endmodule
