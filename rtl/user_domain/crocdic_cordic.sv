`include "common_cells/registers.svh"

module cordic #(
    parameter int WIDTH = 16,
    parameter int ITER  = 14
)(
    input  logic signed [WIDTH-1:0] xin,
    input  logic signed [WIDTH-1:0] yin,
    input  logic signed [WIDTH-1:0] zin,

    // input  logic direction, // 0 = ROTATION, 1 = VECTORING
    // input  logic [1:0] mode, // 0=CIRCULAR, 1=LINEAR, 2=HYPERBOLIC
    input  logic [2:0] operation,

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

    localparam logic signed [WIDTH-1:0] CORDIC_TAB [0:41] = '{
        16'sd65535, // not used
        16'sd8999,
        16'sd4184,
        16'sd2058,
        16'sd1025,
        16'sd512,
        16'sd256,
        16'sd128,
        16'sd64,
        16'sd32,
        16'sd16,
        16'sd8,
        16'sd4,
        16'sd2,

        // LINEAR (14–27)
        16'sd16384,
        16'sd8192,
        16'sd4096,
        16'sd2048,
        16'sd1024,
        16'sd512,
        16'sd256,
        16'sd128,
        16'sd64,
        16'sd32,
        16'sd16,
        16'sd8,
        16'sd4,
        16'sd2,

        // CIRCULAR (28–41)
        16'sd12867,
        16'sd7596,
        16'sd4013,
        16'sd2037,
        16'sd1022,
        16'sd511,
        16'sd255,
        16'sd127,
        16'sd63,
        16'sd31,
        16'sd15,
        16'sd7,
        16'sd3,
        16'sd1
    }

    localparam logic signed [WIDTH-1:0] HYP_STEPS [0:14] = '{
        16'sd1,
        16'sd2,
        16'sd3,
        16'sd4,
        16'sd4,
        16'sd5,
        16'sd6,
        16'sd7,
        16'sd8,
        16'sd9,
        16'sd10,
        16'sd11,
        16'sd12,
        16'sd13,
        16'sd13,
    }

    logic direction; // 0 = ROTATION, 1 = VECTORING
    logic [1:0] mode;
    logic signed [WIDTH-1:0] x, y, z;
    logic signed [WIDTH-1:0] xbyk, ybyk;
    logic signed [WIDTH-1:0] x1, x2, y1, y2, z1, z2;
    logic d;
    int k, kk;
    int offset;
    int kfinal;
    // ----------------------------
    // CORDIC core
    // ----------------------------
    always_comb begin
        
        case(operation):
            SIN, COSINE: begin
                direction = ROTATION;
                mode = CIRCULAR;
            end
            ATAN: begin
                direction = VECTORING;
                mode = CIRCULAR;
            end
            SQRT: begin
                direction = VECTORING;
                mode = HYPERBOLIC;
            end
            RECIPROCAL: begin
                direction = VECTORING;
                mode = LINEAR;
            end
            INVSQRT: begin
                direction = VECTORING;
                mode = LINEAR;
            end
        endcase

        x = xin;
        y = yin;
        z = zin;

        offset = (mode == HYPERBOLIC) ? 0 :
                 (mode == LINEAR)    ? 14 : 28;

        kfinal = (mode != HYPERBOLIC) ? ITER : ITER + 1;

        for (k = 0; k < kfinal; k++) begin

            d = (direction == ROTATION) ? (z >= 0) : (y < 0);

            kk = (mode != HYPERBOLIC) ? k : HYP_STEP[k];

            xbyk = x >>> kk;

            ybyk = (mode == HYPERBOLIC) ? -(y >>> kk) :
                   (mode == LINEAR)    ? '0 :
                                          (y >>> kk);

            x1 = x - ybyk;
            x2 = x + ybyk;

            y1 = y + xbyk;
            y2 = y - xbyk;

            z1 = z - CORDIC_TAB[kk + offset];
            z2 = z + CORDIC_TAB[kk + offset];

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