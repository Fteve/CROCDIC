`include "common_cells/registers.svh"

module crocdic_cordic import user_pkg::*; #(
    parameter int WIDTH = 16,
    parameter int ITER  = 14
) (
    input logic clk_i,
    // Active-low reset
    input logic rst_ni,
    input logic cordic_en_i,
    input logic [WIDTH-1:0] input_element_0_i,
    input logic [WIDTH-1:0] input_element_1_i,
    input operation_t operation_i,

    output logic cordic_done_o,
    output logic [WIDTH-1:0] output_element_o
);

  localparam logic [1:0] ROTATION = 0;
  localparam logic [1:0] VECTORING = 1;
  localparam logic [1:0] CIRCULAR = 0;
  localparam logic [1:0] LINEAR = 1;
  localparam logic [1:0] HYPERBOLIC = 2;

  localparam logic [WIDTH-1:0] CORDIC_1K = 16'd9949;
  localparam logic [WIDTH-1:0] CORDIC_1KP = 16'd19783;
  localparam logic [WIDTH-1:0] MUL = 16'd16384;

  // ----------------------------
  // Lookup tables
  // ----------------------------

  localparam logic [WIDTH-1:0] CORDIC_TAB[0:3*ITER-1] = '{
    16'd65535,  // not used
    16'd8999,
    16'd4184,
    16'd2058,
    16'd1025,
    16'd512,
    16'd256,
    16'd128,
    16'd64,
    16'd32,
    16'd16,
    16'd8,
    16'd4,
    16'd2,

    // LINEAR (14–27)
    16'd16384,
    16'd8192,
    16'd4096,
    16'd2048,
    16'd1024,
    16'd512,
    16'd256,
    16'd128,
    16'd64,
    16'd32,
    16'd16,
    16'd8,
    16'd4,
    16'd2,

    // CIRCULAR (28–41)
    16'd12867,
    16'd7596,
    16'd4013,
    16'd2037,
    16'd1022,
    16'd511,
    16'd255,
    16'd127,
    16'd63,
    16'd31,
    16'd15,
    16'd7,
    16'd3,
    16'd1
  };

  localparam logic [WIDTH-1:0] HYP_STEPS[0:14] = '{
    16'd1,
    16'd2,
    16'd3,
    16'd4,
    16'd4,
    16'd5,
    16'd6,
    16'd7,
    16'd8,
    16'd9,
    16'd10,
    16'd11,
    16'd12,
    16'd13,
    16'd13
  };

  logic direction;  // 0 = ROTATION, 1 = VECTORING
  logic [1:0] mode;
  logic [WIDTH-1:0] xbyk, ybyk;
  logic [WIDTH-1:0] x1, x2, y1, y2, z1, z2;
  logic d;
  logic [WIDTH-1:0] kk;
  logic [WIDTH-1:0] offset;
  logic [WIDTH-1:0] kfinal;





  // ----------------------------
  // Counter
  // ----------------------------

  logic [3:0] count_d, count_q;

  `FF(count_q, count_d, '0);

  // ----------------------------
  // CORDIC core
  // ----------------------------
  logic [WIDTH-1:0] x_iteration_d, x_iteration_q;
  logic [WIDTH-1:0] y_iteration_d, y_iteration_q;
  logic [WIDTH-1:0] z_iteration_d, z_iteration_q;

  `FF(x_iteration_q, x_iteration_d, '0);
  `FF(y_iteration_q, y_iteration_d, '0);
  `FF(z_iteration_q, z_iteration_d, '0);

  // Next state logic

  typedef enum logic [1:0] {
    IDLE,
    CALCULATE,
    DONE
  } state_t;

  state_t state_d, state_q;

  `FF(state_q, state_d, IDLE);


  always_comb begin
    // Default Assignments
    d = '0;
    kk = '0;
    xbyk = '0;
    ybyk = '0;
    x1 = '0;
    x2 = '0;
    y1 = '0;
    y2 = '0;
    z1 = '0;
    z2 = '0;
    state_d = state_q;
    count_d = count_q;
    x_iteration_d = x_iteration_q;
    y_iteration_d = y_iteration_q;
    z_iteration_d = z_iteration_q;

    mode = ( operation_i == SIN || operation_i == COS || operation_i == ATAN) ? CIRCULAR :
               ( operation_i == SQRT ) ? HYPERBOLIC : LINEAR ;

    direction = (operation_i == SIN || operation_i == COS) ? ROTATION : VECTORING;

    offset = (mode == HYPERBOLIC) ? 0 : (mode == LINEAR) ? 14 : 28;

    kfinal = (mode != HYPERBOLIC) ? ITER : ITER + 1;

    case (state_q)
      IDLE: begin
        count_d = '0;

        case (operation_i)
          SIN, COS: begin
            x_iteration_d = CORDIC_1K;
            y_iteration_d = '0;
            z_iteration_d = input_element_0_i;
          end
          ATAN, SQRT: begin
            x_iteration_d = input_element_0_i;
            y_iteration_d = input_element_1_i;
            z_iteration_d = '0;
          end
          RECIPROCAL: begin
            x_iteration_d = input_element_0_i;
            y_iteration_d = MUL;
            z_iteration_d = '0;
          end
        endcase

        if (cordic_en_i) begin
          state_d = CALCULATE;
        end
      end
      CALCULATE: begin
        d = ((direction == ROTATION) ? (($signed(z_iteration_q) >= 0) ? 0 : 1) : (($signed(y_iteration_q) < 0) ? 0 : 1));
        kk = ((mode != HYPERBOLIC) ? count_q : HYP_STEPS[count_q]);
        xbyk = ($signed(x_iteration_q) >>> kk);
        ybyk = ((mode == HYPERBOLIC) ? -($signed(y_iteration_q) >>> kk) : ((mode == LINEAR) ? 0 : ($signed(y_iteration_q) >>> kk)));

        x1 = x_iteration_q - ybyk;
        x2 = x_iteration_q + ybyk;
        y1 = y_iteration_q + xbyk;
        y2 = y_iteration_q - xbyk;
        z1 = z_iteration_q - CORDIC_TAB[kk+offset];
        z2 = z_iteration_q + CORDIC_TAB[kk+offset];

        x_iteration_d = ((d == 0) ? x1 : x2);
        y_iteration_d = ((d == 0) ? y1 : y2);
        z_iteration_d = ((d == 0) ? z1 : z2);

        // increment counter
        if (count_q == kfinal - 1) begin
          state_d = DONE;
        end else begin
          count_d = count_q + 1;
        end
      end
      DONE: begin
        state_d = IDLE;
      end
      default: begin
        state_d = IDLE;
      end
    endcase
  end

  // Output logic
  always_comb begin
    output_element_o = '0;
    cordic_done_o = '0;

    if (state_q == DONE) begin
      cordic_done_o = 1;

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
          output_element_o =  CORDIC_1KP * x_iteration_q; // Remember to divide by MUL once in SW for Q2.14 form, twice for normal decimal form
        end
        RECIPROCAL: begin
          output_element_o = z_iteration_q; 
        end
        default: begin
          output_element_o = '0;
        end
      endcase

    end
  end
  

endmodule
