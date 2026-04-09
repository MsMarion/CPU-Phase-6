module REPLACE_POLICY #(
    parameter ASSOC      = 2,
    parameter NUM_SETS   = 32,
    parameter BLOCK_SIZE = 16
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


endmodule