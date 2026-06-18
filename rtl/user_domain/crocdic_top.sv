`include "common_cells/registers.svh"

module crocdic_top import user_pkg::*; #(
  // Slave: The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           SbrObiCfg      = obi_pkg::ObiDefaultConfig,
  // Master: The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           MgrObiCfg      = obi_pkg::ObiDefaultConfig,
  // The request struct for the slave.
  parameter type                         sbr_obi_req_t   = logic,
  // The response struct for the slave.
  parameter type                         sbr_obi_rsp_t   = logic,
  // The request struct for the master.
  parameter type                         mgr_obi_req_t   = logic,
  // The response struct for the master.
  parameter type                         mgr_obi_rsp_t   = logic
) (
  // Clock
  input  logic clk_i,
  // Active-low reset
  input  logic rst_ni,

  // OBI request interface (Slave)
  input  sbr_obi_req_t sbr_obi_req_i,
  // OBI response interface (Slave)
  output sbr_obi_rsp_t sbr_obi_rsp_o,
  // OBI request interface (Master)
  output mgr_obi_req_t mgr_obi_req_o,
  // OBI response interface (Master)
  input  mgr_obi_rsp_t mgr_obi_rsp_i
);
  // Memory-Mapped IO Addresses (always increment in steps of 4 because 32-bit addresses adress 4 bytes at a time)
  localparam logic [SbrObiCfg.AddrWidth-1:0] STUDENT_NAMES = croc_pkg::UserBaseAddr; // TODO:  Further, the chip must have a way to output the names of the students in the group. The default way that will be checked automatically is to read from the 0x2000_0000 address (i.e. the start of Croc's user domain) and expect a zero terminated string.  
  localparam logic [SbrObiCfg.AddrWidth-1:0] CROCDIC_START = croc_pkg::UserBaseAddr + 'h4;
  localparam logic [SbrObiCfg.AddrWidth-1:0] CROCDIC_OPERATION = croc_pkg::UserBaseAddr + 'h8;
  localparam logic [SbrObiCfg.AddrWidth-1:0] CROCDIC_SOURCE_ARRAY_ADDRESS = croc_pkg::UserBaseAddr + 'hC;
  localparam logic [SbrObiCfg.AddrWidth-1:0] CROCDIC_NR_OF_ELEMENTS = croc_pkg::UserBaseAddr + 'h10;
  localparam logic [SbrObiCfg.AddrWidth-1:0] CROCDIC_DESTINATION_ARRAY_ADDRESS = croc_pkg::UserBaseAddr + 'h14;
  localparam logic [SbrObiCfg.AddrWidth-1:0] CROCDIC_DONE  = croc_pkg::UserBaseAddr + 'h18;

  // operation_t enum now defined in user_pkg.sv


  // OBI Slave

  // Define registers to hold the inputs received from the OBI request interface (slave)
  logic sbr_req_d, sbr_req_q;
  logic sbr_we_d, sbr_we_q;
  logic [SbrObiCfg.AddrWidth-1:0] sbr_addr_d, sbr_addr_q;
  logic [SbrObiCfg.IdWidth-1:0] sbr_id_d, sbr_id_q;
  logic [SbrObiCfg.DataWidth-1:0] sbr_wdata_d, sbr_wdata_q;

  // Signals used to create the response (slave)
  logic [SbrObiCfg.DataWidth-1:0] sbr_rsp_data;  // Data field of the OBI response
  logic sbr_rsp_err;  // Error field of the OBI reponse

  // Note to avoid writing trivial always_ff statements we can use this macro defined in registers.svh 
  `FF(sbr_req_q, sbr_req_d, '0);
  `FF(sbr_id_q , sbr_id_d , '0);
  `FF(sbr_we_q , sbr_we_d , '0);
  `FF(sbr_wdata_q , sbr_wdata_d , '0);
  `FF(sbr_addr_q , sbr_addr_d , '0);

  // Wire the request (slave)
  assign sbr_req_d = sbr_obi_req_i.req;
  assign sbr_id_d = sbr_obi_req_i.a.aid;
  assign sbr_we_d = sbr_obi_req_i.a.we;
  assign sbr_addr_d = sbr_obi_req_i.a.addr;
  assign sbr_wdata_d = sbr_obi_req_i.a.wdata;

  // Wire the response (slave)
  // A channel
  assign sbr_obi_rsp_o.gnt = sbr_obi_req_i.req;
  // R channel:
  assign sbr_obi_rsp_o.rvalid = sbr_req_q;
  assign sbr_obi_rsp_o.r.rdata = sbr_rsp_data;
  assign sbr_obi_rsp_o.r.rid = sbr_id_q;
  assign sbr_obi_rsp_o.r.err = sbr_rsp_err;
  assign sbr_obi_rsp_o.r.r_optional = '0;


  // OBI Master

  // Define registers to hold the inputs received from the OBI response interface (master)
  logic mgr_gnt_d, mgr_gnt_q;
  logic mgr_rvalid_d, mgr_rvalid_q;
  logic [MgrObiCfg.DataWidth-1:0] mgr_rdata_d, mgr_rdata_q;
  logic [MgrObiCfg.IdWidth-1:0] mgr_rid_d, mgr_rid_q;
  logic mgr_err_d, mgr_err_q;
  // don't care about r_optional: not used

  // Signals used to create the request (master)
  logic mgr_req;
  logic [MgrObiCfg.AddrWidth-1:0] mgr_addr;
  logic mgr_we;
  logic [MgrObiCfg.DataWidth/8-1:0] mgr_be;
  logic [MgrObiCfg.DataWidth-1:0] mgr_wdata;
  logic [MgrObiCfg.IdWidth-1:0] mgr_aid;
  // dont care about a_optional: not used

  // Note to avoid writing trivial always_ff statements we can use this macro defined in registers.svh 
  `FF(mgr_gnt_q, mgr_gnt_d, '0);
  `FF(mgr_rvalid_q , mgr_rvalid_d , '0);
  `FF(mgr_rdata_q , mgr_rdata_d , '0);
  `FF(mgr_rid_q , mgr_rid_d , '0);
  `FF(mgr_err_q , mgr_err_d , '0);

  // Wire the reponse (master)
  assign mgr_gnt_d = mgr_obi_rsp_i.gnt;
  assign mgr_rvalid_d = mgr_obi_rsp_i.rvalid;
  assign mgr_rdata_d = mgr_obi_rsp_i.r.rdata;
  assign mgr_rid_d = mgr_obi_rsp_i.r.rid;
  assign mgr_err_d = mgr_obi_rsp_i.r.err;

  // Wire the request (master)
  assign mgr_obi_req_o.req = mgr_req;
  assign mgr_obi_req_o.a.addr = mgr_addr;
  assign mgr_obi_req_o.a.we = mgr_we;
  assign mgr_obi_req_o.a.be = mgr_be;
  assign mgr_obi_req_o.a.wdata = mgr_wdata;
  assign mgr_obi_req_o.a.aid = mgr_aid;
  assign mgr_obi_req_o.a.a_optional = '0;




  // crocdic_top FSM

  typedef enum logic [2:0] {
    IDLE, 
    READ_ELEMENTS,
    WAIT_READ_RESPONSE,
    START_CORDIC, 
    WAIT_CORDIC,
    WRITE_ELEMENTS,
    WAIT_WRITE_RESPONSE,
    DONE
  } state_t;

  state_t state_d, state_q;

  `FF(state_q, state_d, IDLE);

  // Registers to hold data coming from the CPU (Register File)
  operation_t operation_d, operation_q;
  logic [SbrObiCfg.AddrWidth-1:0] source_array_address_d, source_array_address_q;
  logic [SbrObiCfg.AddrWidth-1:0] number_of_elements_d, number_of_elements_q;
  logic [SbrObiCfg.AddrWidth-1:0] destination_array_address_d, destination_array_address_q;

  `FF(operation_q, operation_d, SIN);
  `FF(source_array_address_q, source_array_address_d, '0);
  `FF(number_of_elements_q, number_of_elements_d, '0);
  `FF(destination_array_address_q, destination_array_address_d, '0);

  // Register to hold elements to be processed and count how many elements have been processed so far
  logic [MgrObiCfg.DataWidth-1:0] elements_d, elements_q;  // one set of registers can be used to store both source and destination elements
  logic [MgrObiCfg.AddrWidth-1:0] element_counter_d, element_counter_q;

  `FF(elements_q, elements_d, '0);
  `FF(element_counter_q, element_counter_d, '0);

  logic cordic_en_0, cordic_en_1, cordic_done_0, cordic_done_1;
  logic [MgrObiCfg.DataWidth/2-1:0] cordic_output_0, cordic_output_1;
 
  always_comb begin
    // Default assignments
    sbr_rsp_data = '0;
    sbr_rsp_err = '0;
    mgr_req = '0;
    mgr_addr = '0;
    mgr_we = '0;
    mgr_be = '0;
    mgr_wdata = '0;
    mgr_aid = '0;
    cordic_en_0 = '0;
    cordic_en_1 = '0;
    state_d = state_q;
    operation_d = operation_q;
    source_array_address_d = source_array_address_q;
    number_of_elements_d = number_of_elements_q;
    destination_array_address_d = destination_array_address_q;
    elements_d = elements_q;
    element_counter_d = element_counter_q;

    case(state_q)
      IDLE: begin
        if (sbr_req_q && sbr_addr_q == CROCDIC_START) begin
          if (sbr_we_q) begin
            if (number_of_elements_q > 0) begin
              element_counter_d = '0;  // reset element counter

              state_d = READ_ELEMENTS;
            end else begin
              state_d = DONE;
            end
          end else begin
            sbr_rsp_err = '1;
          end
        end else if (sbr_req_q && sbr_addr_q == CROCDIC_OPERATION) begin
          if (sbr_we_q) begin
            operation_d = operation_t'(sbr_wdata_q);
          end else begin
            sbr_rsp_err = '1;
          end
        end else if (sbr_req_q && sbr_addr_q == CROCDIC_SOURCE_ARRAY_ADDRESS) begin
          if (sbr_we_q) begin
            source_array_address_d = sbr_wdata_q;
          end else begin
            sbr_rsp_err = '1;
          end
        end else if (sbr_req_q && sbr_addr_q == CROCDIC_NR_OF_ELEMENTS) begin
          if (sbr_we_q) begin
            number_of_elements_d = sbr_wdata_q;
          end else begin
            sbr_rsp_err = '1;
          end
        end else if (sbr_req_q && sbr_addr_q == CROCDIC_DESTINATION_ARRAY_ADDRESS) begin
          if (sbr_we_q) begin
            destination_array_address_d = sbr_wdata_q;
          end else begin
            sbr_rsp_err = '1;
          end
        end
      end
      READ_ELEMENTS: begin
        mgr_req = '1;
        mgr_addr = source_array_address_q + 2 * element_counter_q;

        if (element_counter_q + 1 == number_of_elements_q) begin  // only read 1 element if only 1 more element needs to be read instead of two
          mgr_be = 4'b0011;
        end else begin  // read both 16-bit elements if more than 1 element still needs to be read
          mgr_be = '1;
        end

        if (mgr_gnt_q) begin
          state_d = WAIT_READ_RESPONSE;
        end 
        
      end
      WAIT_READ_RESPONSE: begin
        if (mgr_rvalid_q) begin
          elements_d = mgr_rdata_q;

          state_d = START_CORDIC;
        end
      end
      START_CORDIC: begin
        cordic_en_0 = 1;
        cordic_en_1 = 1;

        state_d = WAIT_CORDIC;
        
      end
      WAIT_CORDIC: begin
        if (cordic_done_0) begin
          elements_d[15:0] = cordic_output_0;
        end

        if (cordic_done_1) begin
          elements_d[31:16] = cordic_output_1;
        end

        if (cordic_done_0 && cordic_done_1) begin
          state_d = WRITE_ELEMENTS;
        end

      end
      WRITE_ELEMENTS: begin
        mgr_req = '1;
        mgr_addr = destination_array_address_q + 2 * element_counter_q;
        mgr_we = '1;
        mgr_wdata = elements_q;

        if (element_counter_q + 1 == number_of_elements_q) begin  // only write 1 element if only 1 more element needs to be written instead of two
          mgr_be = 4'b0011;
        end else begin  // write both 16-bit elements if more than 1 element still needs to be written
          mgr_be = '1;
        end

        if (mgr_gnt_q) begin
          state_d = WAIT_WRITE_RESPONSE;
        end  
      end
      WAIT_WRITE_RESPONSE: begin
        if (mgr_rvalid_q) begin

          element_counter_d = element_counter_q + 2;  // increment element counter by 2 since 2 elements are being processed at once

          if (element_counter_d >= number_of_elements_q) begin
            state_d = DONE;
          end else begin
            state_d = READ_ELEMENTS;
          end
        end
      end
      DONE: begin
        if (sbr_req_q && sbr_addr_q == CROCDIC_DONE) begin
          if (sbr_we_q) begin
            sbr_rsp_err = '1;
          end else begin
            sbr_rsp_data = '1;

            state_d = IDLE;
          end
        end
      end
      default: begin
        state_d = IDLE;
      end
    endcase
  end

  crocdic_cordic i_cordic_0 #(
    .INST (0)
    ) (
    .clk_i (clk_i),
    .rst_ni (rst_ni),
    .cordic_en_i (cordic_en_0),
    .input_element_0_i (elements_0_q[15:0]),
    .input_element_1_i (elements_0_q[31:16]),
    .operation_i (operation_q),

    .cordic_done_o (cordic_done_0),
    .output_element_o (cordic_output_0)
  );

  crocdic_cordic i_cordic_1 #(
    .INST (1)
  ) (
    .clk_i (clk_i),
    .rst_ni (rst_ni),
    .cordic_en_i (cordic_en_1),
    .input_element_0_i (elements_1_q[15:0]),
    .input_element_1_i (elements_1_q[31:16]),
    .operation_i (operation_q),

    .cordic_done_o (cordic_done_1),
    .output_element_o (cordic_output_1)
  );





endmodule