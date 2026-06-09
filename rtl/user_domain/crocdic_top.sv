`include "common_cells/registers.svh"

module crocdic_top #(
  // The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  // The request struct.
  parameter type                         obi_req_t   = logic,
  // The response struct.
  parameter type                         obi_rsp_t   = logic
) (
  // Clock
  input  logic clk_i,
  // Active-low reset
  input  logic rst_ni,

  // OBI request interface (Slave)
  input  obi_req_t obi_req_i,
  // OBI response interface (Slave)
  output obi_rsp_t obi_rsp_o
);
  // Memory-Mapped IO Addresses (always increment in steps of 4 because 32-bit addresses adress 4 bytes at a time)
  localparam logic [ObiCfg.AddrWidth-1:0] STUDENT_NAMES = croc_pkg::UserBaseAddr; // TODO:  Further, the chip must have a way to output the names of the students in the group. The default way that will be checked automatically is to read from the 0x2000_0000 address (i.e. the start of Croc's user domain) and expect a zero terminated string.  
  localparam logic [ObiCfg.AddrWidth-1:0] CROCDIC_START = croc_pkg::UserBaseAddr + 'h4;
  localparam logic [ObiCfg.AddrWidth-1:0] CROCDIC_DONE  = croc_pkg::UserBaseAddr + 'h8;


  // OBI Slave

  // Define registers to hold the inputs received from the OBI request interface (slave)
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  // Signals used to create the response (slave)
  logic [ObiCfg.DataWidth-1:0] rsp_data;  // Data field of the OBI response
  logic rsp_err;  // Error field of the OBI reponse

  // Note to avoid writing trivial always_ff statements we can use this macro defined in registers.svh 
  `FF(req_q, req_d, '0);
  `FF(id_q , id_d , '0);
  `FF(we_q , we_d , '0);
  `FF(wdata_q , wdata_d , '0);
  `FF(addr_q , addr_d , '0);

  // Wire the request (slave)
  assign req_d = obi_req_i.req;
  assign id_d = obi_req_i.a.aid;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;
  assign wdata_d = obi_req_i.a.wdata;

  // Wire the response (slave)
  // A channel
  assign obi_rsp_o.gnt = obi_req_i.req;
  // R channel:
  assign obi_rsp_o.rvalid = req_q;
  assign obi_rsp_o.r.rdata = rsp_data;
  assign obi_rsp_o.r.rid = id_q;
  assign obi_rsp_o.r.err = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;



  // crocdic_top FSM

  typedef enum logic [7:0] {
    IDLE, 
    ACTIVE, 
    WAIT, 
    DONE
  } state_t;

  state_t state_d, state_q;

  `FF(state_q, state_d, IDLE);

  always_comb begin
    // Default assignments
    rsp_data = '0;
    rsp_err = '0;
    state_d = state_q;

    case(state_q)
      IDLE: begin
        if (req_q && addr_q == CROCDIC_START) begin
          if (we_q) begin
            state_d = ACTIVE;
          end else begin
            rsp_err = '1;
          end
        end
      end
      ACTIVE: begin
        if (req_q && addr_q == CROCDIC_DONE) begin
          if (we_q) begin
            rsp_err = '1;
          end else begin
            rsp_data = '1;

            state_d = IDLE;
          end
        end
      end
      default: begin
        state_d = IDLE;
      end
    endcase



  end







endmodule