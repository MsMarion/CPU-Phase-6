
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
    // Access info from CACHE
    input  wire [$clog2(NUM_SETS)-1:0] iSetIndex,
    input  wire        iAccessValid,   // a real access happened
    input  wire        iHit,
    input  wire [$clog2(ASSOC)-1:0] iHitWay,
    input  wire [ASSOC-1:0] iValidBits,
    // Victim selection output
    output wire [$clog2(ASSOC)-1:0] oVictimWay,
    // Prefetch
    input  wire [31:0] iAddress,       // current access address
    input  wire        iMiss,          // current access is a miss
    output wire        oPrefetchReq,   // request to prefetch next block
    output wire [31:0] oPrefetchAddr   // address of next sequential block
);

    // !!! lru
    // assoc=2
    reg lruBit [0:NUM_SETS-1];
    wire lruVictim2way  = ~lruBit[iSetIndex];

    reg plruBit [0:NUM_SETS-1];
    wire plruVictim2way  = plruBit[iSetIndex];

    integer x;
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            for (x = 0; x < NUM_SETS; x = x + 1) begin
                lruBit[x]  <= 1'b0;
                plruBit[x] <= 1'b0;
            end
        end else if (iAccessValid && iHit) begin
            lruBit[iSetIndex]  <= iHitWay[0]; // record last used way
            plruBit[iSetIndex] <= ~iHitWay[0]; // point away from used way (invert to opp lol)
        end

    end


    // assoc=nway

    reg [$clog2(ASSOC)-1:0] lruAge [0:NUM_SETS-1][0:ASSOC-1];
    reg [$clog2(ASSOC)-1:0] lruVictimNway;

    integer y;
    always @(*) begin : selectlru
        reg [$clog2(ASSOC)-1:0] max = {$clog2(ASSOC){1'b0}};
        lruVictimNway={$clog2(ASSOC){1'b0}};
        for(y=0; y<ASSOC; y=y+1) begin
            if(iValidBits[y]) begin
                if(lruAge[iSetIndex][y]>max) begin
                    max = lruAge[iSetIndex][y];
                    lruVictimNway = y[$clog2(ASSOC)-1:0];

                end

            end
        end 
    end

    integer z;
    integer k;
    integer e;
    always @(posedge iClk or negedge iRstN) begin
        if(!iRstN) begin
            for(z=0; z<NUM_SETS; z=z+1) begin
                for (k = 0; k < ASSOC; k = k + 1) begin
                    lruAge[z][k] <= k[$clog2(ASSOC)-1:0];
                end

            end

            
        end else if(iHit && iAccessValid) begin
            for(e=0; e<ASSOC; e=e+1) begin
               if(e[$clog2(ASSOC)-1:0]==iHitWay) begin
                    lruAge[iSetIndex][e]<={$clog2(ASSOC){1'b0}};

               end else if(lruAge[iSetIndex][e] < lruAge[iSetIndex][iHitway]) begin
                    lruAge[iSetIndex][e]<=lruAge[iSetIndex][e] + 1'b1;

               end 


            end


        end



    end


    // plru
    // [$clog2(ASSOC)-1:0]
    // {$clog2(ASSOC){1'b0}}

    // 0 l 1 r
    reg [ASSOC-2:0] plruTree [0:NUM_SETS-1];
    reg [$clog2(ASSOC)-1:0] plruVictimNway;

    always @(*) begin : selectplru 

       
        reg [$clog2(ASSOC)-1:0] node;
        node = {$clog2(ASSOC){1'b0}};
        reg [$clog2(ASSOC)-1:0] wayIndex;
        wayIndex = {$clog2(ASSOC){1'b0}};

        integer l;
        integer nL;
        nL=$clog2(ASSOC);

        for(l=0; l<nL; l=l+1) begin
           if(plruTree[iSetIndex][node]) begin
                // right
                wayIndex[nL-1-l]=1'b1;
                node=2*node+2;
                

           end else begin
                wayIndex[nL-1-l]=1'b0;
                node=2*node+1;

           end

        end

        plruVictimNway=wayIndex;
        

    end

    // set the nodes we visited
    integer g;
    if(!iRstN) begin
        for(g=0; g<NUM_SETS; g=g+1) begin
            plruTree[g]<={(ASSOC-1){1'b0}};

        end

    end else if(iHit && iAccessValid) begin
       
        begin : plruUpdate
            reg [$clog2(ASSOC)-1:0] node;
            integer l;
            integer nL;
            node       = {$clog2(ASSOC){1'b0}};
            nL = $clog2(ASSOC);
            for (l = 0; l < nL; l = l + 1) begin
                if (iHitWay[nL-1-l]) begin
                    plruTree[iSetIndex][node] <= 1'b0; // go away
                    node = 2*node + 2; // right
                end else begin
                    plru_tree[iSetIndex][node] <= 1'b1; // go away
                    node = 2*node + 1; // left
                end
            end
        end

    end


    // !!! selecting victim
    // either plru or lru depending on parameter
    // check if empty way, if so, go that route lol

    // invalid scan
    reg [$clog2(ASSOC)-1:0] invalidWayIndex;
    reg isInvalid = 1'b0;
    integer i;

    always @(*) begin
        invalidWayIndex = {$clog2(ASSOC){1'b0}};
        for (i = 0; i < ASSOC; i = i + 1) begin
            if (!iValidBits[i] && !isInvalid) begin
                isInvalid = 1'b1;
                invalidWayIndex = i[$clog2(ASSOC)-1:0];
            end
        end
    end

    // selecting victim
    reg [$clog2(ASSOC)-1:0] oVictimWayTemp;
    always @(*) begin
        if(ASSOC=1) begin
            oVictimWayTemp={$clog2(ASSOC){1'b0}};
            
        end else if(ASSOC=2) begin
            oVictimWayTemp=IS_LRU ? lruVictim2way : plruVictim2way;

        end else begin 
            oVictimWayTemp=IS_LRU ? lruVictimNway : plruVictimNway;
        
        end
       
        if(isInvalid) begin
            oVictimWay=invalidWayIndex;
        end

    end 

    assign oVictimWay = oVictimWayTemp; 

    // !!! prefetch
    // so we only fire on miss lol
    wire [31:0] base  = iAddress & ~(32'd0 + BLOCK_SIZE - 1);
    wire [31:0] next  = base + BLOCK_SIZE;

    assign oPrefetchReq  = iAccessValid & iMiss; // if miss and valid, we gotta a prefetch houston
    assign oPrefetchAddr = next;



endmodule