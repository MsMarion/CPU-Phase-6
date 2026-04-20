`timescale 1ns/1ps
// =============================================================================
//  tb_cache.sv  –  Self-checking testbench for the CACHE module
//  • Drives 50 stimulus cycles from hardcoded vectors
//  • Compares every output against the golden reference
//  • Writes a pass/fail summary and a waveform VCD
//  • BLOCK_SIZE is set to 8 (bytes) to match the 8-byte test vectors
// =============================================================================
module tb_cache;

  // ── Parameters ─────────────────────────────────────────────────────────────
  parameter EVICT_POLICY = 0;
  parameter WAYS         = 4;
  parameter CACHE_SIZE   = 32;
  parameter BLOCK_SIZE   = 8;            // 8 B  → 64-bit wide memory bus
  localparam DW          = BLOCK_SIZE*8; // 64

  // ── DUT ports ───────────────────────────────────────────────────────────────
  reg         clk  = 1'b0;
  reg         rstn = 1'b0;

  reg         i_read, i_write;
  reg  [1:0]  i_funct;
  reg  [31:0] i_addr, i_cpu_data;
  reg         i_mem_ready, i_mem_valid;
  reg  [DW-1:0] i_mem_data;

  wire        o_hit,  o_miss;
  wire [31:0] o_cpu_data;
  wire        o_mem_rd, o_mem_wr;
  wire [31:0] o_mem_rd_addr, o_mem_wr_addr;
  wire [DW-1:0] o_mem_rd_data, o_mem_wr_data;

  // ── DUT instance ────────────────────────────────────────────────────────────
  CACHE #(
    .EVICT_POLICY(EVICT_POLICY),
    .WAYS        (WAYS),
    .CACHE_SIZE  (CACHE_SIZE),
    .BLOCK_SIZE  (BLOCK_SIZE)
  ) dut (
    .i_clk         (clk),
    .i_rstn        (rstn),
    .i_read        (i_read),
    .i_write       (i_write),
    .i_funct       (i_funct),
    .i_addr        (i_addr),
    .i_cpu_data    (i_cpu_data),
    .i_mem_ready   (i_mem_ready),
    .i_mem_valid   (i_mem_valid),
    .i_mem_data    (i_mem_data),
    .o_hit         (o_hit),
    .o_miss        (o_miss),
    .o_cpu_data    (o_cpu_data),
    .o_mem_rd      (o_mem_rd),
    .o_mem_wr      (o_mem_wr),
    .o_mem_rd_addr (o_mem_rd_addr),
    .o_mem_wr_addr (o_mem_wr_addr),
    .o_mem_rd_data (o_mem_rd_data),
    .o_mem_wr_data (o_mem_wr_data)
  );

  // ── Clock: 10 ns period ─────────────────────────────────────────────────────
  always #5 clk = ~clk;

  // ── Test-vector storage ─────────────────────────────────────────────────────
  localparam N = 50;

  // Inputs
  reg        tv_read      [0:N-1];
  reg        tv_write     [0:N-1];
  reg [1:0]  tv_funct     [0:N-1];
  reg [31:0] tv_addr      [0:N-1];
  reg [31:0] tv_cpu_data  [0:N-1];
  reg        tv_mem_ready [0:N-1];
  reg        tv_mem_valid [0:N-1];
  reg [DW-1:0] tv_mem_data [0:N-1];

  // Expected outputs
  reg        exp_hit         [0:N-1];
  reg        exp_miss        [0:N-1];
  reg [31:0] exp_cpu_data    [0:N-1];
  reg        exp_mem_rd      [0:N-1];
  reg        exp_mem_wr      [0:N-1];
  reg [31:0] exp_mem_rd_addr [0:N-1];
  reg [DW-1:0] exp_mem_rd_data [0:N-1];

  // Helper macro: pack 8 decimal bytes into a 64-bit word (b7 = MSB)
  `define B8(b7,b6,b5,b4,b3,b2,b1,b0) \
    {8'd``b7,8'd``b6,8'd``b5,8'd``b4,8'd``b3,8'd``b2,8'd``b1,8'd``b0}

  // ── Load input vectors ──────────────────────────────────────────────────────
  initial begin
    //        rd wr fn  addr       cpu_data    rdy vld  mem_data[MSB→LSB]
    {tv_read[0],tv_write[0],tv_funct[0],tv_addr[0],tv_cpu_data[0],tv_mem_ready[0],tv_mem_valid[0]} = {1'b1,1'b0,2'b00,32'd163596,32'd1914837113,1'b1,1'b0};
    tv_mem_data[0]  = {8'd95,8'd203,8'd243,8'd46,8'd187,8'd199,8'd153,8'd152};

    {tv_read[1],tv_write[1],tv_funct[1],tv_addr[1],tv_cpu_data[1],tv_mem_ready[1],tv_mem_valid[1]} = {1'b1,1'b0,2'b00,32'd163596,32'd1914837113,1'b0,1'b0};
    tv_mem_data[1]  = {8'd14,8'd117,8'd221,8'd85,8'd153,8'd36,8'd181,8'd166};

    {tv_read[2],tv_write[2],tv_funct[2],tv_addr[2],tv_cpu_data[2],tv_mem_ready[2],tv_mem_valid[2]} = {1'b1,1'b0,2'b00,32'd163596,32'd1914837113,1'b1,1'b1};
    tv_mem_data[2]  = {8'd5,8'd14,8'd248,8'd184,8'd213,8'd240,8'd54,8'd0};

    {tv_read[3],tv_write[3],tv_funct[3],tv_addr[3],tv_cpu_data[3],tv_mem_ready[3],tv_mem_valid[3]} = {1'b1,1'b0,2'b00,32'd163596,32'd1914837113,1'b0,1'b0};
    tv_mem_data[3]  = {8'd46,8'd254,8'd46,8'd158,8'd77,8'd156,8'd134,8'd1};

    {tv_read[4],tv_write[4],tv_funct[4],tv_addr[4],tv_cpu_data[4],tv_mem_ready[4],tv_mem_valid[4]} = {1'b1,1'b0,2'b00,32'd163596,32'd1914837113,1'b1,1'b1};
    tv_mem_data[4]  = {8'd110,8'd5,8'd74,8'd134,8'd156,8'd102,8'd35,8'd11};

    {tv_read[5],tv_write[5],tv_funct[5],tv_addr[5],tv_cpu_data[5],tv_mem_ready[5],tv_mem_valid[5]} = {1'b0,1'b1,2'b10,32'd209372,32'd1642661739,1'b1,1'b1};
    tv_mem_data[5]  = {8'd74,8'd249,8'd93,8'd59,8'd116,8'd23,8'd201,8'd158};

    {tv_read[6],tv_write[6],tv_funct[6],tv_addr[6],tv_cpu_data[6],tv_mem_ready[6],tv_mem_valid[6]} = {1'b0,1'b1,2'b10,32'd209372,32'd1642661739,1'b0,1'b0};
    tv_mem_data[6]  = {8'd151,8'd119,8'd11,8'd220,8'd155,8'd174,8'd43,8'd115};

    {tv_read[7],tv_write[7],tv_funct[7],tv_addr[7],tv_cpu_data[7],tv_mem_ready[7],tv_mem_valid[7]} = {1'b0,1'b1,2'b10,32'd209372,32'd1642661739,1'b1,1'b1};
    tv_mem_data[7]  = {8'd16,8'd3,8'd242,8'd241,8'd247,8'd144,8'd206,8'd98};

    {tv_read[8],tv_write[8],tv_funct[8],tv_addr[8],tv_cpu_data[8],tv_mem_ready[8],tv_mem_valid[8]} = {1'b0,1'b1,2'b10,32'd209372,32'd1642661739,1'b0,1'b0};
    tv_mem_data[8]  = {8'd77,8'd4,8'd25,8'd59,8'd175,8'd61,8'd112,8'd174};

    {tv_read[9],tv_write[9],tv_funct[9],tv_addr[9],tv_cpu_data[9],tv_mem_ready[9],tv_mem_valid[9]} = {1'b0,1'b1,2'b10,32'd209372,32'd1642661739,1'b1,1'b1};
    tv_mem_data[9]  = {8'd31,8'd156,8'd126,8'd213,8'd8,8'd44,8'd232,8'd100};

    {tv_read[10],tv_write[10],tv_funct[10],tv_addr[10],tv_cpu_data[10],tv_mem_ready[10],tv_mem_valid[10]} = {1'b1,1'b0,2'b00,32'd573264,32'd2438254339,1'b1,1'b1};
    tv_mem_data[10] = {8'd66,8'd46,8'd169,8'd193,8'd79,8'd108,8'd133,8'd53};

    {tv_read[11],tv_write[11],tv_funct[11],tv_addr[11],tv_cpu_data[11],tv_mem_ready[11],tv_mem_valid[11]} = {1'b1,1'b0,2'b00,32'd573264,32'd2438254339,1'b0,1'b0};
    tv_mem_data[11] = {8'd248,8'd215,8'd198,8'd115,8'd240,8'd101,8'd229,8'd237};

    {tv_read[12],tv_write[12],tv_funct[12],tv_addr[12],tv_cpu_data[12],tv_mem_ready[12],tv_mem_valid[12]} = {1'b1,1'b0,2'b00,32'd573264,32'd2438254339,1'b1,1'b1};
    tv_mem_data[12] = {8'd153,8'd186,8'd235,8'd83,8'd22,8'd146,8'd50,8'd133};

    {tv_read[13],tv_write[13],tv_funct[13],tv_addr[13],tv_cpu_data[13],tv_mem_ready[13],tv_mem_valid[13]} = {1'b1,1'b0,2'b00,32'd573264,32'd2438254339,1'b0,1'b0};
    tv_mem_data[13] = {8'd11,8'd246,8'd83,8'd216,8'd99,8'd191,8'd69,8'd138};

    {tv_read[14],tv_write[14],tv_funct[14],tv_addr[14],tv_cpu_data[14],tv_mem_ready[14],tv_mem_valid[14]} = {1'b1,1'b0,2'b00,32'd573264,32'd2438254339,1'b1,1'b1};
    tv_mem_data[14] = {8'd212,8'd150,8'd91,8'd247,8'd71,8'd155,8'd138,8'd70};

    {tv_read[15],tv_write[15],tv_funct[15],tv_addr[15],tv_cpu_data[15],tv_mem_ready[15],tv_mem_valid[15]} = {1'b1,1'b0,2'b00,32'd809756,32'd1696003200,1'b1,1'b1};
    tv_mem_data[15] = {8'd36,8'd75,8'd205,8'd42,8'd19,8'd4,8'd252,8'd108};

    {tv_read[16],tv_write[16],tv_funct[16],tv_addr[16],tv_cpu_data[16],tv_mem_ready[16],tv_mem_valid[16]} = {1'b1,1'b0,2'b00,32'd809756,32'd1696003200,1'b0,1'b0};
    tv_mem_data[16] = {8'd1,8'd3,8'd208,8'd50,8'd180,8'd182,8'd186,8'd202};

    {tv_read[17],tv_write[17],tv_funct[17],tv_addr[17],tv_cpu_data[17],tv_mem_ready[17],tv_mem_valid[17]} = {1'b1,1'b0,2'b00,32'd809756,32'd1696003200,1'b1,1'b1};
    tv_mem_data[17] = {8'd197,8'd155,8'd18,8'd237,8'd91,8'd166,8'd29,8'd234};

    {tv_read[18],tv_write[18],tv_funct[18],tv_addr[18],tv_cpu_data[18],tv_mem_ready[18],tv_mem_valid[18]} = {1'b1,1'b0,2'b00,32'd809756,32'd1696003200,1'b0,1'b0};
    tv_mem_data[18] = {8'd220,8'd217,8'd159,8'd115,8'd84,8'd24,8'd16,8'd94};

    {tv_read[19],tv_write[19],tv_funct[19],tv_addr[19],tv_cpu_data[19],tv_mem_ready[19],tv_mem_valid[19]} = {1'b1,1'b0,2'b00,32'd809756,32'd1696003200,1'b1,1'b1};
    tv_mem_data[19] = {8'd79,8'd171,8'd83,8'd170,8'd186,8'd151,8'd163,8'd70};

    {tv_read[20],tv_write[20],tv_funct[20],tv_addr[20],tv_cpu_data[20],tv_mem_ready[20],tv_mem_valid[20]} = {1'b0,1'b1,2'b00,32'd797740,32'd3099804676,1'b1,1'b1};
    tv_mem_data[20] = {8'd227,8'd143,8'd120,8'd98,8'd30,8'd248,8'd182,8'd217};

    {tv_read[21],tv_write[21],tv_funct[21],tv_addr[21],tv_cpu_data[21],tv_mem_ready[21],tv_mem_valid[21]} = {1'b0,1'b1,2'b00,32'd797740,32'd3099804676,1'b0,1'b0};
    tv_mem_data[21] = {8'd197,8'd65,8'd126,8'd10,8'd133,8'd181,8'd109,8'd28};

    {tv_read[22],tv_write[22],tv_funct[22],tv_addr[22],tv_cpu_data[22],tv_mem_ready[22],tv_mem_valid[22]} = {1'b0,1'b1,2'b00,32'd797740,32'd3099804676,1'b1,1'b1};
    tv_mem_data[22] = {8'd6,8'd112,8'd27,8'd51,8'd8,8'd229,8'd162,8'd121};

    {tv_read[23],tv_write[23],tv_funct[23],tv_addr[23],tv_cpu_data[23],tv_mem_ready[23],tv_mem_valid[23]} = {1'b0,1'b1,2'b00,32'd797740,32'd3099804676,1'b0,1'b0};
    tv_mem_data[23] = {8'd80,8'd144,8'd130,8'd178,8'd232,8'd35,8'd63,8'd154};

    {tv_read[24],tv_write[24],tv_funct[24],tv_addr[24],tv_cpu_data[24],tv_mem_ready[24],tv_mem_valid[24]} = {1'b0,1'b1,2'b00,32'd797740,32'd3099804676,1'b1,1'b1};
    tv_mem_data[24] = {8'd105,8'd138,8'd193,8'd51,8'd58,8'd241,8'd19,8'd153};

    {tv_read[25],tv_write[25],tv_funct[25],tv_addr[25],tv_cpu_data[25],tv_mem_ready[25],tv_mem_valid[25]} = {1'b0,1'b0,2'b01,32'd664168,32'd453094388,1'b1,1'b1};
    tv_mem_data[25] = {8'd74,8'd177,8'd41,8'd225,8'd238,8'd159,8'd206,8'd75};

    {tv_read[26],tv_write[26],tv_funct[26],tv_addr[26],tv_cpu_data[26],tv_mem_ready[26],tv_mem_valid[26]} = {1'b0,1'b0,2'b01,32'd846660,32'd524363766,1'b1,1'b1};
    tv_mem_data[26] = {8'd205,8'd55,8'd47,8'd106,8'd228,8'd226,8'd138,8'd83};

    {tv_read[27],tv_write[27],tv_funct[27],tv_addr[27],tv_cpu_data[27],tv_mem_ready[27],tv_mem_valid[27]} = {1'b0,1'b0,2'b00,32'd857748,32'd1514271692,1'b1,1'b1};
    tv_mem_data[27] = {8'd81,8'd232,8'd28,8'd69,8'd58,8'd165,8'd109,8'd0};

    {tv_read[28],tv_write[28],tv_funct[28],tv_addr[28],tv_cpu_data[28],tv_mem_ready[28],tv_mem_valid[28]} = {1'b0,1'b1,2'b00,32'd125684,32'd1157117161,1'b1,1'b1};
    tv_mem_data[28] = {8'd1,8'd42,8'd130,8'd136,8'd106,8'd124,8'd56,8'd177};

    {tv_read[29],tv_write[29],tv_funct[29],tv_addr[29],tv_cpu_data[29],tv_mem_ready[29],tv_mem_valid[29]} = {1'b0,1'b1,2'b00,32'd125684,32'd1157117161,1'b0,1'b0};
    tv_mem_data[29] = {8'd241,8'd43,8'd82,8'd56,8'd132,8'd142,8'd179,8'd103};

    {tv_read[30],tv_write[30],tv_funct[30],tv_addr[30],tv_cpu_data[30],tv_mem_ready[30],tv_mem_valid[30]} = {1'b0,1'b1,2'b00,32'd125684,32'd1157117161,1'b1,1'b1};
    tv_mem_data[30] = {8'd93,8'd16,8'd248,8'd65,8'd246,8'd63,8'd64,8'd178};

    {tv_read[31],tv_write[31],tv_funct[31],tv_addr[31],tv_cpu_data[31],tv_mem_ready[31],tv_mem_valid[31]} = {1'b0,1'b1,2'b00,32'd125684,32'd1157117161,1'b0,1'b0};
    tv_mem_data[31] = {8'd127,8'd182,8'd77,8'd37,8'd72,8'd255,8'd9,8'd68};

    {tv_read[32],tv_write[32],tv_funct[32],tv_addr[32],tv_cpu_data[32],tv_mem_ready[32],tv_mem_valid[32]} = {1'b0,1'b1,2'b00,32'd125684,32'd1157117161,1'b1,1'b1};
    tv_mem_data[32] = {8'd156,8'd250,8'd128,8'd105,8'd13,8'd8,8'd71,8'd88};

    {tv_read[33],tv_write[33],tv_funct[33],tv_addr[33],tv_cpu_data[33],tv_mem_ready[33],tv_mem_valid[33]} = {1'b1,1'b0,2'b01,32'd1033528,32'd2374657733,1'b1,1'b1};
    tv_mem_data[33] = {8'd232,8'd162,8'd61,8'd174,8'd37,8'd135,8'd125,8'd114};

    {tv_read[34],tv_write[34],tv_funct[34],tv_addr[34],tv_cpu_data[34],tv_mem_ready[34],tv_mem_valid[34]} = {1'b1,1'b0,2'b01,32'd1033528,32'd2374657733,1'b0,1'b0};
    tv_mem_data[34] = {8'd172,8'd20,8'd194,8'd94,8'd60,8'd61,8'd186,8'd205};

    {tv_read[35],tv_write[35],tv_funct[35],tv_addr[35],tv_cpu_data[35],tv_mem_ready[35],tv_mem_valid[35]} = {1'b1,1'b0,2'b01,32'd1033528,32'd2374657733,1'b1,1'b1};
    tv_mem_data[35] = {8'd94,8'd120,8'd161,8'd251,8'd162,8'd102,8'd137,8'd209};

    {tv_read[36],tv_write[36],tv_funct[36],tv_addr[36],tv_cpu_data[36],tv_mem_ready[36],tv_mem_valid[36]} = {1'b1,1'b0,2'b01,32'd1033528,32'd2374657733,1'b0,1'b0};
    tv_mem_data[36] = {8'd23,8'd204,8'd213,8'd38,8'd82,8'd130,8'd47,8'd178};

    {tv_read[37],tv_write[37],tv_funct[37],tv_addr[37],tv_cpu_data[37],tv_mem_ready[37],tv_mem_valid[37]} = {1'b1,1'b0,2'b01,32'd1033528,32'd2374657733,1'b1,1'b1};
    tv_mem_data[37] = {8'd10,8'd219,8'd151,8'd83,8'd173,8'd56,8'd4,8'd182};

    {tv_read[38],tv_write[38],tv_funct[38],tv_addr[38],tv_cpu_data[38],tv_mem_ready[38],tv_mem_valid[38]} = {1'b0,1'b1,2'b01,32'd724500,32'd1707558823,1'b1,1'b1};
    tv_mem_data[38] = {8'd131,8'd207,8'd57,8'd89,8'd165,8'd24,8'd44,8'd240};

    {tv_read[39],tv_write[39],tv_funct[39],tv_addr[39],tv_cpu_data[39],tv_mem_ready[39],tv_mem_valid[39]} = {1'b0,1'b1,2'b01,32'd724500,32'd1707558823,1'b0,1'b0};
    tv_mem_data[39] = {8'd239,8'd214,8'd35,8'd172,8'd87,8'd188,8'd29,8'd53};

    {tv_read[40],tv_write[40],tv_funct[40],tv_addr[40],tv_cpu_data[40],tv_mem_ready[40],tv_mem_valid[40]} = {1'b0,1'b1,2'b01,32'd724500,32'd1707558823,1'b1,1'b1};
    tv_mem_data[40] = {8'd236,8'd138,8'd224,8'd178,8'd66,8'd58,8'd168,8'd44};

    {tv_read[41],tv_write[41],tv_funct[41],tv_addr[41],tv_cpu_data[41],tv_mem_ready[41],tv_mem_valid[41]} = {1'b0,1'b1,2'b01,32'd724500,32'd1707558823,1'b0,1'b0};
    tv_mem_data[41] = {8'd209,8'd251,8'd142,8'd132,8'd135,8'd66,8'd61,8'd255};

    {tv_read[42],tv_write[42],tv_funct[42],tv_addr[42],tv_cpu_data[42],tv_mem_ready[42],tv_mem_valid[42]} = {1'b0,1'b1,2'b01,32'd724500,32'd1707558823,1'b1,1'b1};
    tv_mem_data[42] = {8'd23,8'd247,8'd229,8'd142,8'd230,8'd225,8'd162,8'd48};

    {tv_read[43],tv_write[43],tv_funct[43],tv_addr[43],tv_cpu_data[43],tv_mem_ready[43],tv_mem_valid[43]} = {1'b0,1'b0,2'b10,32'd930176,32'd1737349173,1'b1,1'b1};
    tv_mem_data[43] = {8'd86,8'd71,8'd89,8'd179,8'd185,8'd216,8'd229,8'd219};

    {tv_read[44],tv_write[44],tv_funct[44],tv_addr[44],tv_cpu_data[44],tv_mem_ready[44],tv_mem_valid[44]} = {1'b1,1'b0,2'b01,32'd635884,32'd2494030077,1'b1,1'b1};
    tv_mem_data[44] = {8'd164,8'd217,8'd21,8'd239,8'd41,8'd201,8'd230,8'd171};

    {tv_read[45],tv_write[45],tv_funct[45],tv_addr[45],tv_cpu_data[45],tv_mem_ready[45],tv_mem_valid[45]} = {1'b1,1'b0,2'b01,32'd635884,32'd2494030077,1'b0,1'b0};
    tv_mem_data[45] = {8'd25,8'd240,8'd169,8'd249,8'd1,8'd72,8'd41,8'd78};

    {tv_read[46],tv_write[46],tv_funct[46],tv_addr[46],tv_cpu_data[46],tv_mem_ready[46],tv_mem_valid[46]} = {1'b1,1'b0,2'b01,32'd635884,32'd2494030077,1'b1,1'b1};
    tv_mem_data[46] = {8'd140,8'd124,8'd177,8'd114,8'd166,8'd254,8'd57,8'd45};

    {tv_read[47],tv_write[47],tv_funct[47],tv_addr[47],tv_cpu_data[47],tv_mem_ready[47],tv_mem_valid[47]} = {1'b1,1'b0,2'b01,32'd635884,32'd2494030077,1'b0,1'b0};
    tv_mem_data[47] = {8'd182,8'd4,8'd60,8'd126,8'd83,8'd45,8'd191,8'd93};

    {tv_read[48],tv_write[48],tv_funct[48],tv_addr[48],tv_cpu_data[48],tv_mem_ready[48],tv_mem_valid[48]} = {1'b1,1'b0,2'b01,32'd635884,32'd2494030077,1'b1,1'b1};
    tv_mem_data[48] = {8'd166,8'd190,8'd217,8'd184,8'd168,8'd78,8'd145,8'd138};

    {tv_read[49],tv_write[49],tv_funct[49],tv_addr[49],tv_cpu_data[49],tv_mem_ready[49],tv_mem_valid[49]} = {1'b0,1'b1,2'b01,32'd1020272,32'd4204312805,1'b1,1'b1};
    tv_mem_data[49] = {8'd23,8'd130,8'd94,8'd162,8'd67,8'd64,8'd62,8'd151};
  end

  // ── Load expected-output vectors ────────────────────────────────────────────
  initial begin
    //       hit  miss  cpu_data   mem_rd mem_wr  mem_rd_addr   mem_rd_data
    {exp_hit[0],exp_miss[0],exp_cpu_data[0],exp_mem_rd[0],exp_mem_wr[0],exp_mem_rd_addr[0],exp_mem_rd_data[0]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd163592,64'h0};
    {exp_hit[1],exp_miss[1],exp_cpu_data[1],exp_mem_rd[1],exp_mem_wr[1],exp_mem_rd_addr[1],exp_mem_rd_data[1]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd163592,64'h0};
    {exp_hit[2],exp_miss[2],exp_cpu_data[2],exp_mem_rd[2],exp_mem_wr[2],exp_mem_rd_addr[2],exp_mem_rd_data[2]} = {1'b0,1'b1,32'd5,       1'b1,1'b0,32'd163600,64'h0};
    {exp_hit[3],exp_miss[3],exp_cpu_data[3],exp_mem_rd[3],exp_mem_wr[3],exp_mem_rd_addr[3],exp_mem_rd_data[3]} = {1'b0,1'b1,32'd5,       1'b1,1'b0,32'd163600,64'h0};
    {exp_hit[4],exp_miss[4],exp_cpu_data[4],exp_mem_rd[4],exp_mem_wr[4],exp_mem_rd_addr[4],exp_mem_rd_data[4]} = {1'b0,1'b0,32'd110,     1'b0,1'b0,32'd163600,64'h0};
    {exp_hit[5],exp_miss[5],exp_cpu_data[5],exp_mem_rd[5],exp_mem_wr[5],exp_mem_rd_addr[5],exp_mem_rd_data[5]} = {1'b0,1'b1,32'd110,     1'b1,1'b0,32'd209368,64'h0};
    {exp_hit[6],exp_miss[6],exp_cpu_data[6],exp_mem_rd[6],exp_mem_wr[6],exp_mem_rd_addr[6],exp_mem_rd_data[6]} = {1'b0,1'b1,32'd110,     1'b1,1'b0,32'd209368,64'h0};
    {exp_hit[7],exp_miss[7],exp_cpu_data[7],exp_mem_rd[7],exp_mem_wr[7],exp_mem_rd_addr[7],exp_mem_rd_data[7]} = {1'b0,1'b1,32'd110,     1'b1,1'b0,32'd209376,64'h0};
    {exp_hit[8],exp_miss[8],exp_cpu_data[8],exp_mem_rd[8],exp_mem_wr[8],exp_mem_rd_addr[8],exp_mem_rd_data[8]} = {1'b0,1'b1,32'd110,     1'b1,1'b0,32'd209376,64'h0};
    {exp_hit[9],exp_miss[9],exp_cpu_data[9],exp_mem_rd[9],exp_mem_wr[9],exp_mem_rd_addr[9],exp_mem_rd_data[9]} = {1'b0,1'b0,32'd110,     1'b0,1'b0,32'd209376,64'h0};
    {exp_hit[10],exp_miss[10],exp_cpu_data[10],exp_mem_rd[10],exp_mem_wr[10],exp_mem_rd_addr[10],exp_mem_rd_data[10]} = {1'b0,1'b1,32'd110,     1'b1,1'b0,32'd573264,64'h0};
    {exp_hit[11],exp_miss[11],exp_cpu_data[11],exp_mem_rd[11],exp_mem_wr[11],exp_mem_rd_addr[11],exp_mem_rd_data[11]} = {1'b0,1'b1,32'd110,     1'b1,1'b0,32'd573264,64'h0};
    {exp_hit[12],exp_miss[12],exp_cpu_data[12],exp_mem_rd[12],exp_mem_wr[12],exp_mem_rd_addr[12],exp_mem_rd_data[12]} = {1'b0,1'b1,32'd153,     1'b1,1'b1,32'd573272,64'h0};
    {exp_hit[13],exp_miss[13],exp_cpu_data[13],exp_mem_rd[13],exp_mem_wr[13],exp_mem_rd_addr[13],exp_mem_rd_data[13]} = {1'b0,1'b1,32'd153,     1'b1,1'b1,32'd573272,64'h0};
    {exp_hit[14],exp_miss[14],exp_cpu_data[14],exp_mem_rd[14],exp_mem_wr[14],exp_mem_rd_addr[14],exp_mem_rd_data[14]} = {1'b0,1'b0,32'd212,     1'b0,1'b0,32'd573272,64'h0};
    {exp_hit[15],exp_miss[15],exp_cpu_data[15],exp_mem_rd[15],exp_mem_wr[15],exp_mem_rd_addr[15],exp_mem_rd_data[15]} = {1'b0,1'b1,32'd212,     1'b1,1'b0,32'd809752,64'h0};
    {exp_hit[16],exp_miss[16],exp_cpu_data[16],exp_mem_rd[16],exp_mem_wr[16],exp_mem_rd_addr[16],exp_mem_rd_data[16]} = {1'b0,1'b1,32'd212,     1'b1,1'b0,32'd809752,64'h0};
    {exp_hit[17],exp_miss[17],exp_cpu_data[17],exp_mem_rd[17],exp_mem_wr[17],exp_mem_rd_addr[17],exp_mem_rd_data[17]} = {1'b0,1'b1,32'd197,     1'b1,1'b0,32'd809760,64'h0};
    {exp_hit[18],exp_miss[18],exp_cpu_data[18],exp_mem_rd[18],exp_mem_wr[18],exp_mem_rd_addr[18],exp_mem_rd_data[18]} = {1'b0,1'b1,32'd197,     1'b1,1'b0,32'd809760,64'h0};
    {exp_hit[19],exp_miss[19],exp_cpu_data[19],exp_mem_rd[19],exp_mem_wr[19],exp_mem_rd_addr[19],exp_mem_rd_data[19]} = {1'b0,1'b0,32'd79,      1'b0,1'b0,32'd809760,64'h0};
    {exp_hit[20],exp_miss[20],exp_cpu_data[20],exp_mem_rd[20],exp_mem_wr[20],exp_mem_rd_addr[20],exp_mem_rd_data[20]} = {1'b0,1'b1,32'd79,      1'b1,1'b0,32'd797736,64'h0};
    {exp_hit[21],exp_miss[21],exp_cpu_data[21],exp_mem_rd[21],exp_mem_wr[21],exp_mem_rd_addr[21],exp_mem_rd_data[21]} = {1'b0,1'b1,32'd79,      1'b1,1'b0,32'd797736,64'h0};
    {exp_hit[22],exp_miss[22],exp_cpu_data[22],exp_mem_rd[22],exp_mem_wr[22],exp_mem_rd_addr[22],exp_mem_rd_data[22]} = {1'b0,1'b1,32'd79,      1'b1,1'b0,32'd797744,64'h0};
    {exp_hit[23],exp_miss[23],exp_cpu_data[23],exp_mem_rd[23],exp_mem_wr[23],exp_mem_rd_addr[23],exp_mem_rd_data[23]} = {1'b0,1'b1,32'd79,      1'b1,1'b0,32'd797744,64'h0};
    {exp_hit[24],exp_miss[24],exp_cpu_data[24],exp_mem_rd[24],exp_mem_wr[24],exp_mem_rd_addr[24],exp_mem_rd_data[24]} = {1'b0,1'b0,32'd79,      1'b0,1'b0,32'd797744,64'h0};
    {exp_hit[25],exp_miss[25],exp_cpu_data[25],exp_mem_rd[25],exp_mem_wr[25],exp_mem_rd_addr[25],exp_mem_rd_data[25]} = {1'b0,1'b0,32'd0,       1'b0,1'b0,32'd0,    64'h0};
    {exp_hit[26],exp_miss[26],exp_cpu_data[26],exp_mem_rd[26],exp_mem_wr[26],exp_mem_rd_addr[26],exp_mem_rd_data[26]} = {1'b0,1'b0,32'd0,       1'b0,1'b0,32'd0,    64'h0};
    {exp_hit[27],exp_miss[27],exp_cpu_data[27],exp_mem_rd[27],exp_mem_wr[27],exp_mem_rd_addr[27],exp_mem_rd_data[27]} = {1'b0,1'b0,32'd0,       1'b0,1'b0,32'd0,    64'h0};
    {exp_hit[28],exp_miss[28],exp_cpu_data[28],exp_mem_rd[28],exp_mem_wr[28],exp_mem_rd_addr[28],exp_mem_rd_data[28]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd125680,64'h0};
    {exp_hit[29],exp_miss[29],exp_cpu_data[29],exp_mem_rd[29],exp_mem_wr[29],exp_mem_rd_addr[29],exp_mem_rd_data[29]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd125680,64'h0};
    {exp_hit[30],exp_miss[30],exp_cpu_data[30],exp_mem_rd[30],exp_mem_wr[30],exp_mem_rd_addr[30],exp_mem_rd_data[30]} = {1'b0,1'b1,32'd0,       1'b1,1'b1,32'd125688,64'h0};
    {exp_hit[31],exp_miss[31],exp_cpu_data[31],exp_mem_rd[31],exp_mem_wr[31],exp_mem_rd_addr[31],exp_mem_rd_data[31]} = {1'b0,1'b1,32'd0,       1'b1,1'b1,32'd125688,64'h0};
    {exp_hit[32],exp_miss[32],exp_cpu_data[32],exp_mem_rd[32],exp_mem_wr[32],exp_mem_rd_addr[32],exp_mem_rd_data[32]} = {1'b0,1'b0,32'd0,       1'b0,1'b0,32'd125688,64'h0};
    {exp_hit[33],exp_miss[33],exp_cpu_data[33],exp_mem_rd[33],exp_mem_wr[33],exp_mem_rd_addr[33],exp_mem_rd_data[33]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd1033528,64'h0};
    {exp_hit[34],exp_miss[34],exp_cpu_data[34],exp_mem_rd[34],exp_mem_wr[34],exp_mem_rd_addr[34],exp_mem_rd_data[34]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd1033528,64'h0};
    {exp_hit[35],exp_miss[35],exp_cpu_data[35],exp_mem_rd[35],exp_mem_wr[35],exp_mem_rd_addr[35],exp_mem_rd_data[35]} = {1'b0,1'b1,32'd30814,   1'b1,1'b1,32'd1033536,64'h0};
    {exp_hit[36],exp_miss[36],exp_cpu_data[36],exp_mem_rd[36],exp_mem_wr[36],exp_mem_rd_addr[36],exp_mem_rd_data[36]} = {1'b0,1'b1,32'd30814,   1'b1,1'b1,32'd1033536,64'h0};
    {exp_hit[37],exp_miss[37],exp_cpu_data[37],exp_mem_rd[37],exp_mem_wr[37],exp_mem_rd_addr[37],exp_mem_rd_data[37]} = {1'b0,1'b0,32'd56074,   1'b0,1'b0,32'd1033536,64'h0};
    {exp_hit[38],exp_miss[38],exp_cpu_data[38],exp_mem_rd[38],exp_mem_wr[38],exp_mem_rd_addr[38],exp_mem_rd_data[38]} = {1'b0,1'b1,32'd56074,   1'b1,1'b0,32'd724496,64'h0};
    {exp_hit[39],exp_miss[39],exp_cpu_data[39],exp_mem_rd[39],exp_mem_wr[39],exp_mem_rd_addr[39],exp_mem_rd_data[39]} = {1'b0,1'b1,32'd56074,   1'b1,1'b0,32'd724496,64'h0};
    {exp_hit[40],exp_miss[40],exp_cpu_data[40],exp_mem_rd[40],exp_mem_wr[40],exp_mem_rd_addr[40],exp_mem_rd_data[40]} = {1'b0,1'b1,32'd56074,   1'b1,1'b0,32'd724504,64'h0};
    {exp_hit[41],exp_miss[41],exp_cpu_data[41],exp_mem_rd[41],exp_mem_wr[41],exp_mem_rd_addr[41],exp_mem_rd_data[41]} = {1'b0,1'b1,32'd56074,   1'b1,1'b0,32'd724504,64'h0};
    {exp_hit[42],exp_miss[42],exp_cpu_data[42],exp_mem_rd[42],exp_mem_wr[42],exp_mem_rd_addr[42],exp_mem_rd_data[42]} = {1'b0,1'b0,32'd56074,   1'b0,1'b0,32'd724504,64'h0};
    {exp_hit[43],exp_miss[43],exp_cpu_data[43],exp_mem_rd[43],exp_mem_wr[43],exp_mem_rd_addr[43],exp_mem_rd_data[43]} = {1'b0,1'b0,32'd0,       1'b0,1'b0,32'd0,    64'h0};
    {exp_hit[44],exp_miss[44],exp_cpu_data[44],exp_mem_rd[44],exp_mem_wr[44],exp_mem_rd_addr[44],exp_mem_rd_data[44]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd635880,64'h0};
    {exp_hit[45],exp_miss[45],exp_cpu_data[45],exp_mem_rd[45],exp_mem_wr[45],exp_mem_rd_addr[45],exp_mem_rd_data[45]} = {1'b0,1'b1,32'd0,       1'b1,1'b0,32'd635880,64'h0};
    {exp_hit[46],exp_miss[46],exp_cpu_data[46],exp_mem_rd[46],exp_mem_wr[46],exp_mem_rd_addr[46],exp_mem_rd_data[46]} = {1'b0,1'b1,32'd31884,   1'b1,1'b1,32'd635888,64'h0};
    {exp_hit[47],exp_miss[47],exp_cpu_data[47],exp_mem_rd[47],exp_mem_wr[47],exp_mem_rd_addr[47],exp_mem_rd_data[47]} = {1'b0,1'b1,32'd31884,   1'b1,1'b1,32'd635888,64'h0};
    {exp_hit[48],exp_miss[48],exp_cpu_data[48],exp_mem_rd[48],exp_mem_wr[48],exp_mem_rd_addr[48],exp_mem_rd_data[48]} = {1'b0,1'b0,32'd48806,   1'b0,1'b0,32'd635888,64'h0};
    {exp_hit[49],exp_miss[49],exp_cpu_data[49],exp_mem_rd[49],exp_mem_wr[49],exp_mem_rd_addr[49],exp_mem_rd_data[49]} = {1'b0,1'b1,32'd48806,   1'b1,1'b0,32'd1020272,64'h0};
  end

  // ── Main stimulus & checker ─────────────────────────────────────────────────
  integer pass_cnt, fail_cnt, cyc;
  integer log_fd;

  initial begin
    $dumpfile("tb_cache.vcd");
    $dumpvars(0, tb_cache);

    log_fd = $fopen("tb_cache_results.csv", "w");
    $fwrite(log_fd,
      "cycle,o_hit,exp_hit,o_miss,exp_miss,o_cpu_data,exp_cpu_data,");
    $fwrite(log_fd,
      "o_mem_rd,exp_mem_rd,o_mem_wr,exp_mem_wr,o_mem_rd_addr,exp_mem_rd_addr,RESULT\n");

    pass_cnt = 0;
    fail_cnt = 0;

    // Assert reset for 2 clock cycles
    rstn = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    rstn = 1;

    for (cyc = 0; cyc < N; cyc = cyc + 1) begin
      // Drive inputs just after rising edge
      @(posedge clk); #1;
      i_read      = tv_read     [cyc];
      i_write     = tv_write    [cyc];
      i_funct     = tv_funct    [cyc];
      i_addr      = tv_addr     [cyc];
      i_cpu_data  = tv_cpu_data [cyc];
      i_mem_ready = tv_mem_ready[cyc];
      i_mem_valid = tv_mem_valid[cyc];
      i_mem_data  = tv_mem_data [cyc];

      // Sample outputs at end of cycle (just before next rising edge)
      @(negedge clk);
      check_cycle(cyc);
    end

    // De-assert all inputs after the last cycle
    @(posedge clk); #1;
    i_read = 0; i_write = 0; i_mem_ready = 0; i_mem_valid = 0;

    $fclose(log_fd);

    $display("──────────────────────────────────────");
    $display("  RESULTS:  %0d / %0d PASSED", pass_cnt, N);
    if (fail_cnt == 0)
      $display("  *** ALL TESTS PASSED ***");
    else
      $display("  *** %0d TEST(S) FAILED – see tb_cache_results.csv ***", fail_cnt);
    $display("──────────────────────────────────────");
    $finish;
  end

  // ── Per-cycle checker task ───────────────────────────────────────────────────
  task check_cycle;
    input integer c;
    reg fail;
    begin
      fail = 1'b0;

      if (o_hit          !== exp_hit[c])          fail = 1;
      if (o_miss         !== exp_miss[c])         fail = 1;
      if (o_cpu_data     !== exp_cpu_data[c])     fail = 1;
      if (o_mem_rd       !== exp_mem_rd[c])       fail = 1;
      if (o_mem_wr       !== exp_mem_wr[c])       fail = 1;
      if (o_mem_rd_addr  !== exp_mem_rd_addr[c])  fail = 1;
      if (o_mem_rd_data  !== exp_mem_rd_data[c])  fail = 1;

      if (fail) begin
        fail_cnt = fail_cnt + 1;
        $display("FAIL  cycle %0d", c);
        if (o_hit         !== exp_hit[c])
          $display("      o_hit:         got %b  exp %b", o_hit,         exp_hit[c]);
        if (o_miss        !== exp_miss[c])
          $display("      o_miss:        got %b  exp %b", o_miss,        exp_miss[c]);
        if (o_cpu_data    !== exp_cpu_data[c])
          $display("      o_cpu_data:    got %0d  exp %0d", o_cpu_data,  exp_cpu_data[c]);
        if (o_mem_rd      !== exp_mem_rd[c])
          $display("      o_mem_rd:      got %b  exp %b", o_mem_rd,      exp_mem_rd[c]);
        if (o_mem_wr      !== exp_mem_wr[c])
          $display("      o_mem_wr:      got %b  exp %b", o_mem_wr,      exp_mem_wr[c]);
        if (o_mem_rd_addr !== exp_mem_rd_addr[c])
          $display("      o_mem_rd_addr: got %0d  exp %0d", o_mem_rd_addr, exp_mem_rd_addr[c]);
        if (o_mem_rd_data !== exp_mem_rd_data[c])
          $display("      o_mem_rd_data: got %h  exp %h", o_mem_rd_data, exp_mem_rd_data[c]);
      end else begin
        pass_cnt = pass_cnt + 1;
        $display("PASS  cycle %0d", c);
      end

      // Log to CSV regardless
      $fwrite(log_fd, "%0d,%b,%b,%b,%b,%0d,%0d,%b,%b,%b,%b,%0d,%0d,%s\n",
        c,
        o_hit,         exp_hit[c],
        o_miss,        exp_miss[c],
        o_cpu_data,    exp_cpu_data[c],
        o_mem_rd,      exp_mem_rd[c],
        o_mem_wr,      exp_mem_wr[c],
        o_mem_rd_addr, exp_mem_rd_addr[c],
        fail ? "FAIL" : "PASS");
    end
  endtask

endmodule