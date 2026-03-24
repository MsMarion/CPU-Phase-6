module mux2 (
    input wire i0,
    input wire i1,
    input wire j,
    output wire o
);
    assign o = (j == 1'b0) ? i0 : i1;
endmodule

module rl1_32(input wire [31:0] i, input wire is_left, input wire fill, output wire [31:0] o);
    assign o[0]  = is_left ? 1'b0 : i[1];
    assign o[1]  = is_left ? i[0]  : i[2];
    assign o[2]  = is_left ? i[1]  : i[3];
    assign o[3]  = is_left ? i[2]  : i[4];
    assign o[4]  = is_left ? i[3]  : i[5];
    assign o[5]  = is_left ? i[4]  : i[6];
    assign o[6]  = is_left ? i[5]  : i[7];
    assign o[7]  = is_left ? i[6]  : i[8];
    assign o[8]  = is_left ? i[7]  : i[9];
    assign o[9]  = is_left ? i[8]  : i[10];
    assign o[10] = is_left ? i[9]  : i[11];
    assign o[11] = is_left ? i[10] : i[12];
    assign o[12] = is_left ? i[11] : i[13];
    assign o[13] = is_left ? i[12] : i[14];
    assign o[14] = is_left ? i[13] : i[15];
    assign o[15] = is_left ? i[14] : i[16];
    assign o[16] = is_left ? i[15] : i[17];
    assign o[17] = is_left ? i[16] : i[18];
    assign o[18] = is_left ? i[17] : i[19];
    assign o[19] = is_left ? i[18] : i[20];
    assign o[20] = is_left ? i[19] : i[21];
    assign o[21] = is_left ? i[20] : i[22];
    assign o[22] = is_left ? i[21] : i[23];
    assign o[23] = is_left ? i[22] : i[24];
    assign o[24] = is_left ? i[23] : i[25];
    assign o[25] = is_left ? i[24] : i[26];
    assign o[26] = is_left ? i[25] : i[27];
    assign o[27] = is_left ? i[26] : i[28];
    assign o[28] = is_left ? i[27] : i[29];
    assign o[29] = is_left ? i[28] : i[30];
    assign o[30] = is_left ? i[29] : i[31];
    assign o[31] = is_left ? i[30] : fill;
endmodule

module rl2_32(input wire [31:0] i, input wire is_left, input wire fill, output wire [31:0] o);
    assign o[0]  = is_left ? 1'b0 : i[2];
    assign o[1]  = is_left ? 1'b0 : i[3];
    assign o[2]  = is_left ? i[0]  : i[4];
    assign o[3]  = is_left ? i[1]  : i[5];
    assign o[4]  = is_left ? i[2]  : i[6];
    assign o[5]  = is_left ? i[3]  : i[7];
    assign o[6]  = is_left ? i[4]  : i[8];
    assign o[7]  = is_left ? i[5]  : i[9];
    assign o[8]  = is_left ? i[6]  : i[10];
    assign o[9]  = is_left ? i[7]  : i[11];
    assign o[10] = is_left ? i[8]  : i[12];
    assign o[11] = is_left ? i[9]  : i[13];
    assign o[12] = is_left ? i[10] : i[14];
    assign o[13] = is_left ? i[11] : i[15];
    assign o[14] = is_left ? i[12] : i[16];
    assign o[15] = is_left ? i[13] : i[17];
    assign o[16] = is_left ? i[14] : i[18];
    assign o[17] = is_left ? i[15] : i[19];
    assign o[18] = is_left ? i[16] : i[20];
    assign o[19] = is_left ? i[17] : i[21];
    assign o[20] = is_left ? i[18] : i[22];
    assign o[21] = is_left ? i[19] : i[23];
    assign o[22] = is_left ? i[20] : i[24];
    assign o[23] = is_left ? i[21] : i[25];
    assign o[24] = is_left ? i[22] : i[26];
    assign o[25] = is_left ? i[23] : i[27];
    assign o[26] = is_left ? i[24] : i[28];
    assign o[27] = is_left ? i[25] : i[29];
    assign o[28] = is_left ? i[26] : i[30];
    assign o[29] = is_left ? i[27] : i[31];
    assign o[30] = is_left ? i[28] : fill;
    assign o[31] = is_left ? i[29] : fill;
endmodule

module rl4_32(input wire [31:0] i, input wire is_left, input wire fill, output wire [31:0] o);
    assign o[0]  = is_left ? 1'b0 : i[4];
    assign o[1]  = is_left ? 1'b0 : i[5];
    assign o[2]  = is_left ? 1'b0 : i[6];
    assign o[3]  = is_left ? 1'b0 : i[7];
    assign o[4]  = is_left ? i[0]  : i[8];
    assign o[5]  = is_left ? i[1]  : i[9];
    assign o[6]  = is_left ? i[2]  : i[10];
    assign o[7]  = is_left ? i[3]  : i[11];
    assign o[8]  = is_left ? i[4]  : i[12];
    assign o[9]  = is_left ? i[5]  : i[13];
    assign o[10] = is_left ? i[6]  : i[14];
    assign o[11] = is_left ? i[7]  : i[15];
    assign o[12] = is_left ? i[8]  : i[16];
    assign o[13] = is_left ? i[9]  : i[17];
    assign o[14] = is_left ? i[10] : i[18];
    assign o[15] = is_left ? i[11] : i[19];
    assign o[16] = is_left ? i[12] : i[20];
    assign o[17] = is_left ? i[13] : i[21];
    assign o[18] = is_left ? i[14] : i[22];
    assign o[19] = is_left ? i[15] : i[23];
    assign o[20] = is_left ? i[16] : i[24];
    assign o[21] = is_left ? i[17] : i[25];
    assign o[22] = is_left ? i[18] : i[26];
    assign o[23] = is_left ? i[19] : i[27];
    assign o[24] = is_left ? i[20] : i[28];
    assign o[25] = is_left ? i[21] : i[29];
    assign o[26] = is_left ? i[22] : i[30];
    assign o[27] = is_left ? i[23] : i[31];
    assign o[28] = is_left ? i[24] : fill;
    assign o[29] = is_left ? i[25] : fill;
    assign o[30] = is_left ? i[26] : fill;
    assign o[31] = is_left ? i[27] : fill;
endmodule

module rl8_32(input wire [31:0] i, input wire is_left, input wire fill, output wire [31:0] o);
    assign o[0]  = is_left ? 1'b0 : i[8];
    assign o[1]  = is_left ? 1'b0 : i[9];
    assign o[2]  = is_left ? 1'b0 : i[10];
    assign o[3]  = is_left ? 1'b0 : i[11];
    assign o[4]  = is_left ? 1'b0 : i[12];
    assign o[5]  = is_left ? 1'b0 : i[13];
    assign o[6]  = is_left ? 1'b0 : i[14];
    assign o[7]  = is_left ? 1'b0 : i[15];
    assign o[8]  = is_left ? i[0]  : i[16];
    assign o[9]  = is_left ? i[1]  : i[17];
    assign o[10] = is_left ? i[2]  : i[18];
    assign o[11] = is_left ? i[3]  : i[19];
    assign o[12] = is_left ? i[4]  : i[20];
    assign o[13] = is_left ? i[5]  : i[21];
    assign o[14] = is_left ? i[6]  : i[22];
    assign o[15] = is_left ? i[7]  : i[23];
    assign o[16] = is_left ? i[8]  : i[24];
    assign o[17] = is_left ? i[9]  : i[25];
    assign o[18] = is_left ? i[10] : i[26];
    assign o[19] = is_left ? i[11] : i[27];
    assign o[20] = is_left ? i[12] : i[28];
    assign o[21] = is_left ? i[13] : i[29];
    assign o[22] = is_left ? i[14] : i[30];
    assign o[23] = is_left ? i[15] : i[31];
    assign o[24] = is_left ? i[16] : fill;
    assign o[25] = is_left ? i[17] : fill;
    assign o[26] = is_left ? i[18] : fill;
    assign o[27] = is_left ? i[19] : fill;
    assign o[28] = is_left ? i[20] : fill;
    assign o[29] = is_left ? i[21] : fill;
    assign o[30] = is_left ? i[22] : fill;
    assign o[31] = is_left ? i[23] : fill;
endmodule

module rl16_32(input wire [31:0] i, input wire is_left, input wire fill, output wire [31:0] o);
    assign o[0]  = is_left ? 1'b0 : i[16];
    assign o[1]  = is_left ? 1'b0 : i[17];
    assign o[2]  = is_left ? 1'b0 : i[18];
    assign o[3]  = is_left ? 1'b0 : i[19];
    assign o[4]  = is_left ? 1'b0 : i[20];
    assign o[5]  = is_left ? 1'b0 : i[21];
    assign o[6]  = is_left ? 1'b0 : i[22];
    assign o[7]  = is_left ? 1'b0 : i[23];
    assign o[8]  = is_left ? 1'b0 : i[24];
    assign o[9]  = is_left ? 1'b0 : i[25];
    assign o[10] = is_left ? 1'b0 : i[26];
    assign o[11] = is_left ? 1'b0 : i[27];
    assign o[12] = is_left ? 1'b0 : i[28];
    assign o[13] = is_left ? 1'b0 : i[29];
    assign o[14] = is_left ? 1'b0 : i[30];
    assign o[15] = is_left ? 1'b0 : i[31];
    assign o[16] = is_left ? i[0]  : fill;
    assign o[17] = is_left ? i[1]  : fill;
    assign o[18] = is_left ? i[2]  : fill;
    assign o[19] = is_left ? i[3]  : fill;
    assign o[20] = is_left ? i[4]  : fill;
    assign o[21] = is_left ? i[5]  : fill;
    assign o[22] = is_left ? i[6]  : fill;
    assign o[23] = is_left ? i[7]  : fill;
    assign o[24] = is_left ? i[8]  : fill;
    assign o[25] = is_left ? i[9]  : fill;
    assign o[26] = is_left ? i[10] : fill;
    assign o[27] = is_left ? i[11] : fill;
    assign o[28] = is_left ? i[12] : fill;
    assign o[29] = is_left ? i[13] : fill;
    assign o[30] = is_left ? i[14] : fill;
    assign o[31] = is_left ? i[15] : fill;
endmodule

module bitshift_stage_manual16(input wire [31:0] i, input wire s, input wire is_left, input wire fill, output wire [31:0] o);
    wire [31:0] t;
    rl16_32 r (i, is_left, fill, t);
    mux2 m0(i[0], t[0], s, o[0]); mux2 m1(i[1], t[1], s, o[1]); mux2 m2(i[2], t[2], s, o[2]); mux2 m3(i[3], t[3], s, o[3]);
    mux2 m4(i[4], t[4], s, o[4]); mux2 m5(i[5], t[5], s, o[5]); mux2 m6(i[6], t[6], s, o[6]); mux2 m7(i[7], t[7], s, o[7]);
    mux2 m8(i[8], t[8], s, o[8]); mux2 m9(i[9], t[9], s, o[9]); mux2 m10(i[10], t[10], s, o[10]); mux2 m11(i[11], t[11], s, o[11]);
    mux2 m12(i[12], t[12], s, o[12]); mux2 m13(i[13], t[13], s, o[13]); mux2 m14(i[14], t[14], s, o[14]); mux2 m15(i[15], t[15], s, o[15]);
    mux2 m16(i[16], t[16], s, o[16]); mux2 m17(i[17], t[17], s, o[17]); mux2 m18(i[18], t[18], s, o[18]); mux2 m19(i[19], t[19], s, o[19]);
    mux2 m20(i[20], t[20], s, o[20]); mux2 m21(i[21], t[21], s, o[21]); mux2 m22(i[22], t[22], s, o[22]); mux2 m23(i[23], t[23], s, o[23]);
    mux2 m24(i[24], t[24], s, o[24]); mux2 m25(i[25], t[25], s, o[25]); mux2 m26(i[26], t[26], s, o[26]); mux2 m27(i[27], t[27], s, o[27]);
    mux2 m28(i[28], t[28], s, o[28]); mux2 m29(i[29], t[29], s, o[29]); mux2 m30(i[30], t[30], s, o[30]); mux2 m31(i[31], t[31], s, o[31]);
endmodule

module bitshift_stage_manual8(input wire [31:0] i, input wire s, input wire is_left, input wire fill, output wire [31:0] o);
    wire [31:0] t;
    rl8_32 r (i, is_left, fill, t);
    mux2 m0(i[0], t[0], s, o[0]); mux2 m1(i[1], t[1], s, o[1]); mux2 m2(i[2], t[2], s, o[2]); mux2 m3(i[3], t[3], s, o[3]);
    mux2 m4(i[4], t[4], s, o[4]); mux2 m5(i[5], t[5], s, o[5]); mux2 m6(i[6], t[6], s, o[6]); mux2 m7(i[7], t[7], s, o[7]);
    mux2 m8(i[8], t[8], s, o[8]); mux2 m9(i[9], t[9], s, o[9]); mux2 m10(i[10], t[10], s, o[10]); mux2 m11(i[11], t[11], s, o[11]);
    mux2 m12(i[12], t[12], s, o[12]); mux2 m13(i[13], t[13], s, o[13]); mux2 m14(i[14], t[14], s, o[14]); mux2 m15(i[15], t[15], s, o[15]);
    mux2 m16(i[16], t[16], s, o[16]); mux2 m17(i[17], t[17], s, o[17]); mux2 m18(i[18], t[18], s, o[18]); mux2 m19(i[19], t[19], s, o[19]);
    mux2 m20(i[20], t[20], s, o[20]); mux2 m21(i[21], t[21], s, o[21]); mux2 m22(i[22], t[22], s, o[22]); mux2 m23(i[23], t[23], s, o[23]);
    mux2 m24(i[24], t[24], s, o[24]); mux2 m25(i[25], t[25], s, o[25]); mux2 m26(i[26], t[26], s, o[26]); mux2 m27(i[27], t[27], s, o[27]);
    mux2 m28(i[28], t[28], s, o[28]); mux2 m29(i[29], t[29], s, o[29]); mux2 m30(i[30], t[30], s, o[30]); mux2 m31(i[31], t[31], s, o[31]);
endmodule

module bitshift_stage_manual4(input wire [31:0] i, input wire s, input wire is_left, input wire fill, output wire [31:0] o);
    wire [31:0] t;
    rl4_32 r (i, is_left, fill, t);
    mux2 m0(i[0], t[0], s, o[0]); mux2 m1(i[1], t[1], s, o[1]); mux2 m2(i[2], t[2], s, o[2]); mux2 m3(i[3], t[3], s, o[3]);
    mux2 m4(i[4], t[4], s, o[4]); mux2 m5(i[5], t[5], s, o[5]); mux2 m6(i[6], t[6], s, o[6]); mux2 m7(i[7], t[7], s, o[7]);
    mux2 m8(i[8], t[8], s, o[8]); mux2 m9(i[9], t[9], s, o[9]); mux2 m10(i[10], t[10], s, o[10]); mux2 m11(i[11], t[11], s, o[11]);
    mux2 m12(i[12], t[12], s, o[12]); mux2 m13(i[13], t[13], s, o[13]); mux2 m14(i[14], t[14], s, o[14]); mux2 m15(i[15], t[15], s, o[15]);
    mux2 m16(i[16], t[16], s, o[16]); mux2 m17(i[17], t[17], s, o[17]); mux2 m18(i[18], t[18], s, o[18]); mux2 m19(i[19], t[19], s, o[19]);
    mux2 m20(i[20], t[20], s, o[20]); mux2 m21(i[21], t[21], s, o[21]); mux2 m22(i[22], t[22], s, o[22]); mux2 m23(i[23], t[23], s, o[23]);
    mux2 m24(i[24], t[24], s, o[24]); mux2 m25(i[25], t[25], s, o[25]); mux2 m26(i[26], t[26], s, o[26]); mux2 m27(i[27], t[27], s, o[27]);
    mux2 m28(i[28], t[28], s, o[28]); mux2 m29(i[29], t[29], s, o[29]); mux2 m30(i[30], t[30], s, o[30]); mux2 m31(i[31], t[31], s, o[31]);
endmodule

module bitshift_stage_manual2(input wire [31:0] i, input wire s, input wire is_left, input wire fill, output wire [31:0] o);
    wire [31:0] t;
    rl2_32 r (i, is_left, fill, t);
    mux2 m0(i[0], t[0], s, o[0]); mux2 m1(i[1], t[1], s, o[1]); mux2 m2(i[2], t[2], s, o[2]); mux2 m3(i[3], t[3], s, o[3]);
    mux2 m4(i[4], t[4], s, o[4]); mux2 m5(i[5], t[5], s, o[5]); mux2 m6(i[6], t[6], s, o[6]); mux2 m7(i[7], t[7], s, o[7]);
    mux2 m8(i[8], t[8], s, o[8]); mux2 m9(i[9], t[9], s, o[9]); mux2 m10(i[10], t[10], s, o[10]); mux2 m11(i[11], t[11], s, o[11]);
    mux2 m12(i[12], t[12], s, o[12]); mux2 m13(i[13], t[13], s, o[13]); mux2 m14(i[14], t[14], s, o[14]); mux2 m15(i[15], t[15], s, o[15]);
    mux2 m16(i[16], t[16], s, o[16]); mux2 m17(i[17], t[17], s, o[17]); mux2 m18(i[18], t[18], s, o[18]); mux2 m19(i[19], t[19], s, o[19]);
    mux2 m20(i[20], t[20], s, o[20]); mux2 m21(i[21], t[21], s, o[21]); mux2 m22(i[22], t[22], s, o[22]); mux2 m23(i[23], t[23], s, o[23]);
    mux2 m24(i[24], t[24], s, o[24]); mux2 m25(i[25], t[25], s, o[25]); mux2 m26(i[26], t[26], s, o[26]); mux2 m27(i[27], t[27], s, o[27]);
    mux2 m28(i[28], t[28], s, o[28]); mux2 m29(i[29], t[29], s, o[29]); mux2 m30(i[30], t[30], s, o[30]); mux2 m31(i[31], t[31], s, o[31]);
endmodule

module bitshift_stage_manual1(input wire [31:0] i, input wire s, input wire is_left, input wire fill, output wire [31:0] o);
    wire [31:0] t;
    rl1_32 r (i, is_left, fill, t);
    mux2 m0(i[0], t[0], s, o[0]); mux2 m1(i[1], t[1], s, o[1]); mux2 m2(i[2], t[2], s, o[2]); mux2 m3(i[3], t[3], s, o[3]);
    mux2 m4(i[4], t[4], s, o[4]); mux2 m5(i[5], t[5], s, o[5]); mux2 m6(i[6], t[6], s, o[6]); mux2 m7(i[7], t[7], s, o[7]);
    mux2 m8(i[8], t[8], s, o[8]); mux2 m9(i[9], t[9], s, o[9]); mux2 m10(i[10], t[10], s, o[10]); mux2 m11(i[11], t[11], s, o[11]);
    mux2 m12(i[12], t[12], s, o[12]); mux2 m13(i[13], t[13], s, o[13]); mux2 m14(i[14], t[14], s, o[14]); mux2 m15(i[15], t[15], s, o[15]);
    mux2 m16(i[16], t[16], s, o[16]); mux2 m17(i[17], t[17], s, o[17]); mux2 m18(i[18], t[18], s, o[18]); mux2 m19(i[19], t[19], s, o[19]);
    mux2 m20(i[20], t[20], s, o[20]); mux2 m21(i[21], t[21], s, o[21]); mux2 m22(i[22], t[22], s, o[22]); mux2 m23(i[23], t[23], s, o[23]);
    mux2 m24(i[24], t[24], s, o[24]); mux2 m25(i[25], t[25], s, o[25]); mux2 m26(i[26], t[26], s, o[26]); mux2 m27(i[27], t[27], s, o[27]);
    mux2 m28(i[28], t[28], s, o[28]); mux2 m29(i[29], t[29], s, o[29]); mux2 m30(i[30], t[30], s, o[30]); mux2 m31(i[31], t[31], s, o[31]);
endmodule

module barrel_shifter(
    input  wire [31:0] i,
    input  wire [4:0]  s,
    input  wire        is_left_shift,
    input  wire        is_sra,
    output wire [31:0] o
);
    wire [31:0] t16, t8, t4, t2;
    wire fill = is_sra ? i[31] : 1'b0;

    

    bitshift_stage_manual16 b16 (i,   s[4], is_left_shift, fill, t16);
    bitshift_stage_manual8  b8  (t16, s[3], is_left_shift, fill, t8);
    bitshift_stage_manual4  b4  (t8,  s[2], is_left_shift, fill, t4);
    bitshift_stage_manual2  b2  (t4,  s[1], is_left_shift, fill, t2);
    bitshift_stage_manual1  b1  (t2,  s[0], is_left_shift, fill, o);
endmodule
