`include "common_cells/registers.svh"

module cordic #(
    parameter int WIDTH = 16,
    parameter int ITER  = 14
)(
    input  logic signed [WIDTH-1:0] xin,
    input  logic signed [WIDTH-1:0] yin,
    input  logic signed [WIDTH-1:0] zin,

    input  logic direction, // 0 = ROTATION, 1 = VECTORING
    input  logic [1:0] mode, // 0=CIRCULAR, 1=LINEAR, 2=HYPERBOLIC

    output logic signed [WIDTH-1:0] xout,
    output logic signed [WIDTH-1:0] yout,
    output logic signed [WIDTH-1:0] zout
);

    localparam logic [1:0] ROTATION  = 0;
    localparam logic [1:0] VECTORING = 1;
    localparam logic [1:0] CIRCULAR  = 0;
    localparam logic [1:0] LINEAR    = 1;
    localparam logic [1:0] HYPERBOLIC = 2;

    // ----------------------------
    // Lookup tables
    // ----------------------------
    logic signed [WIDTH-1:0] cordic_tab [0:42]; // 3*14 = 42

    initial begin
        // HYPERBOLIC (0–13)
        cordic_tab[0]  = 16'sd65535; // not used
        cordic_tab[1]  = 16'sd8999;
        cordic_tab[2]  = 16'sd4184;
        cordic_tab[3]  = 16'sd2058;
        cordic_tab[4]  = 16'sd1025;
        cordic_tab[5]  = 16'sd512;
        cordic_tab[6]  = 16'sd256;
        cordic_tab[7]  = 16'sd128;
        cordic_tab[8]  = 16'sd64;
        cordic_tab[9]  = 16'sd32;
        cordic_tab[10] = 16'sd16;
        cordic_tab[11] = 16'sd8;
        cordic_tab[12] = 16'sd4;
        cordic_tab[13] = 16'sd2;

        // LINEAR (14–27)
        cordic_tab[14] = 16'sd16384;
        cordic_tab[15] = 16'sd8192;
        cordic_tab[16] = 16'sd4096;
        cordic_tab[17] = 16'sd2048;
        cordic_tab[18] = 16'sd1024;
        cordic_tab[19] = 16'sd512;
        cordic_tab[20] = 16'sd256;
        cordic_tab[21] = 16'sd128;
        cordic_tab[22] = 16'sd64;
        cordic_tab[23] = 16'sd32;
        cordic_tab[24] = 16'sd16;
        cordic_tab[25] = 16'sd8;
        cordic_tab[26] = 16'sd4;
        cordic_tab[27] = 16'sd2;

        // CIRCULAR (28–41)
        cordic_tab[28] = 16'sd12867;
        cordic_tab[29] = 16'sd7596;
        cordic_tab[30] = 16'sd4013;
        cordic_tab[31] = 16'sd2037;
        cordic_tab[32] = 16'sd1022;
        cordic_tab[33] = 16'sd511;
        cordic_tab[34] = 16'sd255;
        cordic_tab[35] = 16'sd127;
        cordic_tab[36] = 16'sd63;
        cordic_tab[37] = 16'sd31;
        cordic_tab[38] = 16'sd15;
        cordic_tab[39] = 16'sd7;
        cordic_tab[40] = 16'sd3;
        cordic_tab[41] = 16'sd1;
    end

    // hyperbolic step repetition
    function automatic int hyp_step(input int k);
        case (k)
            4:  return 4;
            13: return 13;
            default: return k;
        endcase
    endfunction

    // ----------------------------
    // CORDIC core
    // ----------------------------
    always_comb begin
        logic signed [WIDTH-1:0] x, y, z;
        logic signed [WIDTH-1:0] xbyk, ybyk;
        logic signed [WIDTH-1:0] x1, x2, y1, y2, z1, z2;
        logic d;
        int k, kk;
        int offset;
        int kfinal;

        x = xin;
        y = yin;
        z = zin;

        offset = (mode == HYPERBOLIC) ? 0 :
                 (mode == LINEAR)    ? 14 : 28;

        kfinal = (mode != HYPERBOLIC) ? ITER : ITER + 1;

        for (k = 0; k < kfinal; k++) begin

            d = (direction == ROTATION) ? (z >= 0) : (y < 0);

            kk = (mode != HYPERBOLIC) ? k : hyp_step(k);

            xbyk = x >>> kk;

            ybyk = (mode == HYPERBOLIC) ? -(y >>> kk) :
                   (mode == LINEAR)    ? '0 :
                                          (y >>> kk);

            x1 = x - ybyk;
            x2 = x + ybyk;

            y1 = y + xbyk;
            y2 = y - xbyk;

            z1 = z - cordic_tab[kk + offset];
            z2 = z + cordic_tab[kk + offset];

            if (d == 0) begin
                x = x1;
                y = y1;
                z = z1;
            end else begin
                x = x2;
                y = y2;
                z = z2;
            end
        end

        xout = x;
        yout = y;
        zout = z;
    end

endmodule