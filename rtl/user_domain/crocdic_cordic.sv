`include "common_cells/registers.svh"

module crocdic_cordic import user_pkg::*; #(
    parameter int WIDTH = 16,
    parameter int ITER  = 14
)(
    input  logic clk_i,
    // Active-low reset
    input  logic rst_ni,
    input  logic cordic_en_i,
    input  logic signed [WIDTH-1:0] input_element_i,
    input  operation_t operation_i,

    output logic cordic_done_o,
    output logic signed [WIDTH-1:0] output_element_o
);

    localparam logic [1:0] ROTATION  = 0;
    localparam logic [1:0] VECTORING = 1;
    localparam logic [1:0] CIRCULAR  = 0;
    localparam logic [1:0] LINEAR    = 1;
    localparam logic [1:0] HYPERBOLIC = 2;

    localparam logic [15:0] CORDIC_1K = 16'd9949;
    localparam logic [15:0] CORDIC_1KP = 16'd19783;

    // ----------------------------
    // Lookup tables
    // ----------------------------

    localparam logic signed [WIDTH-1:0] CORDIC_TAB [0:41] = '{
        16'sd0,            // 16'sd65535, // not used
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
    };

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
        16'sd13
    };

    logic direction; // 0 = ROTATION, 1 = VECTORING
    logic [1:0] mode;
    // logic signed [WIDTH-1:0] x, y, z, xout, yout, zout;
    logic signed [WIDTH-1:0] xbyk, ybyk;
    logic signed [WIDTH-1:0] x1, x2, y1, y2, z1, z2;
    logic d;
    int kk;
    int offset;
    int kfinal;

    logic [3:0] count_d, count_q;
    logic [WIDTH-1:0] x_iteration_d, x_iteration_q;
    logic [WIDTH-1:0] y_iteration_d, y_iteration_q;
    logic [WIDTH-1:0] z_iteration_d, z_iteration_q;


    // ----------------------------
    // Counter
    // ----------------------------

    `FF(count_q, count_d, '0);
    
    always_comb begin
        count_d = 0;
        if (cordic_en_i) begin
            count_d = count_q + 1;
        end
    end

    // ----------------------------
    // CORDIC core
    // ----------------------------
    `FF(x_iteration_q, x_iteration_d, '0);
    `FF(y_iteration_q, y_iteration_d, '0);
    `FF(z_iteration_q, z_iteration_d, '0);
    
    // Next state logic

    always_comb begin
        direction = 0;
        mode = 0;
        d = 0;
        kk = 0;
        xbyk = 0;
        ybyk = 0;
        x1 = 0;
        x2 = 0;
        y1 = 0;
        y2 = 0;
        z1 = 0;
        z2 = 0;
        x_iteration_d = x_iteration_q;
        y_iteration_d = y_iteration_q;
        z_iteration_d = z_iteration_q;

        offset = (mode == HYPERBOLIC) ? 0 :
                 (mode == LINEAR)    ? 14 : 28;

        kfinal = (mode != HYPERBOLIC) ? ITER : ITER + 1;

        if (cordic_en_i) begin
            if (count_q == 0) begin
                case(operation_i)
                    SIN, COS: begin
                        direction = ROTATION;
                        mode = CIRCULAR;
                        x_iteration_d = CORDIC_1K;
                        y_iteration_d = 0;
                        z_iteration_d = input_element_i;
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
                    INVERSE_SQRT: begin
                        direction = VECTORING;
                        mode = LINEAR;
                    end
                endcase
            end else begin
                d = (direction == ROTATION) ? (z_iteration_q >= 0) : (y_iteration_q < 0);

                kk = (mode != HYPERBOLIC) ? count_q : HYP_STEPS[count_q];

                xbyk = x_iteration_q >>> kk;

                ybyk = (mode == HYPERBOLIC) ? -(y_iteration_q >>> kk) :
                    (mode == LINEAR)    ? '0 :
                                            (y_iteration_q >>> kk);

                x1 = x_iteration_q - ybyk;
                x2 = x_iteration_q + ybyk;

                y1 = y_iteration_q + xbyk;
                y2 = y_iteration_q - xbyk;

                z1 = z_iteration_q - CORDIC_TAB[kk + offset];
                z2 = z_iteration_q + CORDIC_TAB[kk + offset];

                if (d == 0) begin
                    x_iteration_d = x1;
                    y_iteration_d = y1;
                    z_iteration_d = z1;
                end else begin
                    x_iteration_d = x2;
                    y_iteration_d = y2;
                    z_iteration_d = z2;
                end
            end
        end
    end

    // Output logic
    always_comb begin
        output_element_o = 0;
        cordic_done_o = 0;

        if (cordic_en_i) begin
            if (count_q >= 14) begin
                case (operation_i)
                    COS: begin
                        output_element_o = x_iteration_q;
                    end
                    SIN: begin
                        output_element_o = y_iteration_q;
                    end
                    ATAN: begin
                        output_element_o = z_iteration_q;
                    end
                    SQRT: begin
                        output_element_o = x_iteration_q;
                    end
                    RECIPROCAL: begin
                        output_element_o = z_iteration_q;
                    end
                    INVERSE_SQRT: begin
                        output_element_o = z_iteration_q;
                    end
                    default: begin
                        output_element_o = 0;
                    end
                endcase

                cordic_done_o = 1;
                
            end else begin
                cordic_done_o = 0;
            end
        end else begin
            cordic_done_o = 1;
        end

    end


    // // assign z = input_element_i;

    // always_comb begin
    //     direction = 0;
    //     mode = 0;
    //     x = 0;
    //     y = 0;
    //     output_element_o = 0;

    //     case(operation_i):
    //         SIN, COSINE: begin
    //             direction = ROTATION;
    //             mode = CIRCULAR;
    //             x = CORDIC_1K;
    //             y = 0;
    //             output_element_o = zout;
    //         end
    //         ATAN: begin
    //             direction = VECTORING;
    //             mode = CIRCULAR;
    //         end
    //         SQRT: begin
    //             direction = VECTORING;
    //             mode = HYPERBOLIC;
    //         end
    //         RECIPROCAL: begin
    //             direction = VECTORING;
    //             mode = LINEAR;
    //         end
    //         INVSQRT: begin
    //             direction = VECTORING;
    //             mode = LINEAR;
    //         end
    //     endcase

    //     // x = xin;
    //     // y = yin;
    //     // z = zin;

    //     offset = (mode == HYPERBOLIC) ? 0 :
    //              (mode == LINEAR)    ? 14 : 28;

    //     kfinal = (mode != HYPERBOLIC) ? ITER : ITER + 1;

    //     for (k = 0; k < kfinal; k++) begin

    //         d = (direction == ROTATION) ? (z >= 0) : (y < 0);

    //         kk = (mode != HYPERBOLIC) ? k : HYP_STEP[k];

    //         xbyk = x >>> kk;

    //         ybyk = (mode == HYPERBOLIC) ? -(y >>> kk) :
    //                (mode == LINEAR)    ? '0 :
    //                                       (y >>> kk);

    //         x1 = x - ybyk;
    //         x2 = x + ybyk;

    //         y1 = y + xbyk;
    //         y2 = y - xbyk;

    //         z1 = z - CORDIC_TAB[kk + offset];
    //         z2 = z + CORDIC_TAB[kk + offset];

    //         if (d == 0) begin
    //             x = x1;
    //             y = y1;
    //             z = z1;
    //         end else begin
    //             x = x2;
    //             y = y2;
    //             z = z2;
    //         end
    //     end

    //     xout = x;
    //     yout = y;
    //     zout = z;
    // end

endmodule