`ifndef KB_FWD_ENG_COVERAGE_SV
`define KB_FWD_ENG_COVERAGE_SV

import kb_cxl_pkg::*;


class kb_fwd_eng_coverage extends uvm_component;

  `uvm_component_utils(kb_fwd_eng_coverage)

  // Shared environment configuration provides the generated RAL model used
  // to observe the live credit-manager debug counters.
  kb_fwd_eng_env_cfg h_env_cfg;

  // analysis_fifo to get the internal variables from Scoreboard to Coverage
  uvm_tlm_analysis_fifo #(kb_fwd_eng_cov_seq_item) cov_fifo;

  // Coverage sequence item class handle
  kb_fwd_eng_cov_seq_item h_cov_seq_items;

  // APB, CXL vip analysis fifo's
  uvm_tlm_analysis_fifo #(denaliCdn_apbTransaction) apb_fifo;
  uvm_tlm_analysis_fifo #(kb_cxl_m2s_snap) cxl_m2s_bus_fifo;
  uvm_tlm_analysis_fifo #(kb_cxl_s2m_snap) cxl_s2m_bus_fifo;

  //AXI_FIFO's
  kb_axi4_analysis_fifo address_fifo;
  kb_axi4_analysis_fifo w_fifo;
  kb_axi4_analysis_fifo resp_fifo;

  //kb_apb3_vendor_txn_t  h_apb_txns;
  //kb_cxl_m2s_snap       h_cxl_m2s_items;
  //kb_cxl_s2m_snap       h_cxl_s2m_items;
  //kb_axi4_vendor_txn_t  h_axi_txns;
  //AXI Struct's
  // Local AXI comparison types (QoS and burst are not checked).
  typedef struct packed {
    bit         valid;
    bit [7:0]   id;      
    bit [63:0]  addr;    
    bit [7:0]   len;     
    bit [7:0]   size;    
    bit [127:0] user;    
  } axi_aw_src_t;

  typedef struct packed {
    bit          valid;
    bit [1023:0] data;   
    bit [127:0]  strb;   
    bit          last;
    bit [127:0]  user;   
  } axi_w1024_src_t;

  typedef struct packed {
    bit         valid;
    bit [7:0]   id;      
    bit [63:0]  addr;    
    bit [7:0]   len;     
    bit [7:0]   size;    // Custom integrated field
    bit [127:0] user;    
  } axi_ar_src_t;

  typedef struct packed {
    bit         valid;
    bit [7:0]   id;     
    bit [1:0]   resp;   
    bit [127:0] user;   
  } axi_b_src_t;

  typedef struct packed {
    bit          valid;
    bit [7:0]    id;
    bit [1023:0] data;   
    bit [1:0]    resp;
    bit          last;
    bit [127:0]  user;   
  } axi_r1024_src_t;

  //
  axi_aw_src_t aw;
  axi_w1024_src_t w;
  axi_ar_src_t ar;
  axi_b_src_t b;
  axi_r1024_src_t r;

  // -------------------------------------------------------------------------
  // Local Array Variables for CXL Channels 
  // -------------------------------------------------------------------------
  
  // -------------------------------------------------------------------------
  // Local Array Variables for CXL REQ Channels
  // Sized for 4 lanes in the default 256 B flit mode  
  // -------------------------------------------------------------------------
  
  bit [3:0]  req_valid;
  bit [45:0] req_hpa[4];        // Host Physical Address corresponding to bits [51:6]
  bit [3:0]  req_ld_id[4];      // Logical Device ID mapped from header bits [77:74]
  bit [3:0]  req_opcode[4];     // Request Opcode (expected: MemRd 4'b0001)
  bit [2:0]  req_snp_type[4];   // Snoop Type (expected: No-Op 3'b000)
  bit [1:0]  req_meta_field[4]; // Metadata operation (expected: No-Op 2'b11)
  bit [1:0]  req_meta_value[4]; // Metadata value (reserved when metaField is No-Op)
  bit [15:0] req_tag[4];        // CXL transaction tag
  bit        req_seen_valid[4]; // Previous valid Req observed per lane
  bit [1:0]  req_gap_cycles[4]; // Saturates at 2 (two or more idle cycles)

  
  // 2 RwD Channels
  bit [1:0]  rwd_valid;
  bit [45:0] rwd_hpa[2];
  bit [3:0]  rwd_ld_id[2];
  bit [3:0]  rwd_opcode[2];
  bit [2:0]  rwd_snp_type[2];
  bit [2:0]  rwd_meta_field[2];
  bit [1:0]  rwd_meta_value[2];
  bit        rwd_poison[2];
  bit [15:0] rwd_tag[2];
  bit [511:0] rwd_data[2];
  bit [63:0] byte_enable[2];
  bit        rwd_seen_valid[2];
  int unsigned rwd_gap_cycles[2];
  
  // 6 NDR Channels
  bit [3:0]  ndr_ld_id[6];
  bit [2:0]  ndr_opcode[6];
  bit [1:0]  ndr_meta_field[6];
  bit [1:0]  ndr_meta_value[6];
  bit [15:0] ndr_tag[6];
  bit [1:0]  ndr_dev_load[6];
  
  // 2 DRC/DRS Channels
  bit [3:0]  drc_ld_id[2];
  bit [2:0]  drc_opcode[2];
  bit        drc_poison[2];
  bit [1:0]  drc_meta_field[2];
  bit [1:0]  drc_meta_value[2];
  bit [15:0] drc_tag[2];
  bit [1:0]  drc_dev_load[2];
  bit [511:0] drc_data[2];


  // This component currently observes FE inputs only: APB configuration and
  // CXL M2S traffic. Internal error_response_type and FE outputs are checked
  // elsewhere and are not sampled here without an observable monitor.

  // CXL parser register shadows. Initialize to architectural reset values so
  // traffic seen before the first APB write is sampled with the correct state.
  bit flit_mode_inst                       = 1'b1;
  bit combining_rd_enable_inst             = 1'b1;
  bit combining_wr_enable_inst             = 1'b1;
  bit unsupported_opcode_check_enable_inst = 1'b1;
  bit unsupported_field_check_enable_inst  = 1'b1;
  bit poison_crc_invert_enable_inst        = 1'b1;
  bit mst_req, mst_ack;
  bit mem_app_pending_enable;
  bit nxm_enable;
  bit poison_enable;

  // Shadow register for 0x80b00: fe_interrupt_enable (19 active bits)
  bit [18:0] interrupt_enables_inst = 19'h40000; // Default: irq_global_en=1

  bit reset_seen;

  // Credit-manager FSM state encodings used by cg_fe_credit_manager.
  // Egress: 0=IDLE, 1=INIT, 2=RUN, 3=DEINIT_MST, 4=DEINIT_SLV.
  // Ingress: 0=IDLE, 1=INIT, 2=RUN, 3=DEINIT.
  bit [2:0] credit_egress_state;
  bit [2:0] credit_ingress_state;

  // HDM Decoder APB Storage Arrays (10 instances, 24-bit registers)
  bit [23:0] reg_hpa_base[10];
  bit [23:0] reg_hpa_top[10];
  bit [23:0] reg_dpa_base[10];

  // Bounded queues with exactly ten entries, initialized on reset.
  // Entry i always belongs to region i; these queues are never popped.
  // Each entry holds {region_msb[31:0], region_lsb[31:0]}.
  bit [63:0] hdm_rd_region_count_q[$:9];
  bit [63:0] hdm_wr_region_count_q[$:9];

  // Last observed ECC counter values, indexed AW LSB/MSB, AR LSB/MSB.
  bit [31:0] dcd_sec_count_prev[4];
  bit [31:0] dcd_ded_count_prev[4];
  bit        dcd_sec_count_seen[4];
  bit        dcd_ded_count_seen[4];


  // Tracker variables to allow unified sampling in cg_fe_apb_registers
  bit        is_hdm_update;
  int        current_hdm_idx;
  bit [23:0] current_hpa_base;
  bit [23:0] current_hpa_top;
  bit [23:0] current_dpa_base;

  // WR_Token_Bucket variables
  bit [15:0]  wr_refill_period;
  bit [15:0]  wr_capacity;
  bit [4:0]   wr_refill_rate;
  bit         wr_reset_token;

  // RD_Token_Bucket variables
  bit [15:0]  rd_refill_period;
  bit [15:0]  rd_capacity;
  bit [4:0]   rd_refill_rate;
  bit         rd_reset_token;

  // Tracker variable for fe_error_status register at 0x80a00 (20 active bits)
  bit [19:0] fe_error_status_inst;
  bit [19:0] fe_error_status_prev;
  bit        fe_error_status_prev_valid;

  // Egress Queue Local Variables
  logic [1:0] write_egress_queue_devload;
  logic [1:0] read_egress_queue_devload;
  bit write_backpressure_seen;
  bit read_backpressure_seen;
  bit [1:0] write_fill_class_prev;
  bit [1:0] read_fill_class_prev;

  //Scoreboard variables
  // Each sampling source enables only the fields it actually observes.
  typedef struct packed {
    bit error_valid;
    bit packet_valid;
    bit tag_bounds_valid;
    bit tag_check_enabled;
    bit tag_range_checked;
    bit tag_range_passed;
    bit [1:0] error_type;
    bit nxm_enabled;
    bit poison_enabled;
    bit is_write;
    bit permission_valid;
    bit permission_passed;
    bit axi_valid;
    bit [1:0] axi_id;
    bit region_sample_valid;
    bit [3:0] region_index;
    bit boundary_sample_valid;
    bit [1:0] boundary_class;
    bit ecc_sec_sample_valid;
    bit ecc_ded_sample_valid;
    bit ecc_half_msb;
    bit ecc_found;
    // Pair events are separate from the per-lane and AXI-ID samples.
    bit pair_sample_valid;
    bit [7:0] axi_size;
    bit [1:0] tag_pair_checked;
    bit [1:0] tag_pair_bounds_valid;
    bit [1:0] tag_pair_passed; // [1] = first queued tag, [0] = second.
  } hdm_cov_event_t;
  hdm_cov_event_t hdm_sample;

  // Keep all attributes of one original 64B packet in one queue entry.
  typedef struct packed {
    bit tag_bounds_valid;
    bit tag_range_checked;
    bit tag_range_passed;
  } hdm_tag_result_t;

  typedef struct packed {
    bit [7:0] size; // AXI encoding: 6 = 64B, 7 = 128B per beat.
    bit [7:0] len;  // This FE pairing supports single-beat requests only.
  } hdm_axi_size_t;

  hdm_tag_result_t hdm_rd_tag_q[$];
  hdm_tag_result_t hdm_wr_tag_q[$];
  hdm_axi_size_t   hdm_rd_axi_q[$];
  hdm_axi_size_t   hdm_wr_axi_q[$];
  bit hdm_rd_pairing_blocked;
  bit hdm_wr_pairing_blocked;

  bit [3:0][1:0] err_resp_type;
  bit [3:0] tag_bounds_valid;
  bit [3:0] tag_range_checked;
  bit [3:0] tag_range_passed;
  bit tag_range_check;

  // -------------------------------------------------------------------------
  // REQ input coverage
  // -------------------------------------------------------------------------
  covergroup cg_fe_cxl_parser_req with function sample(
    input bit [3:0]    lane,
    input bit          req_valid,
    input bit          flit_mode,
    input bit [3:0]    opcode,
    input bit [2:0]    snp_type,
    input bit [1:0]    meta_field,
    input bit [1:0]    meta_value,
    input bit [15:0]   tag,
    input bit [45:0]   hpa,
    input bit [3:0]    ld_id,
    input bit          opcode_check_enable,
    input bit          field_check_enable,
    input bit          gap_available,
    input int unsigned gap_class,
    input bit [3:0]    req_valid_p
  );
    option.per_instance = 1;

    cp_fe_flit_mode: coverpoint flit_mode iff (req_valid) {
      bins mode_256b_to_68b = (1'b1 => 1'b0);
      bins mode_68b_to_256b = (1'b0 => 1'b1);
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    //cp_fe_valid: coverpoint req_valid iff (req_valid){
    //  bins valid_1 = {1'b1};
    //  bins valid_0 = {1'b0};
    //}

    cp_fe_valid_gap: coverpoint gap_class iff (gap_available) {
      bins back_to_back = {0}; // no invalid cycle between valid requests
      bins gap_1cyc     = {1}; // one invalid cycle between valid requests
      bins random_gap   = {2}; // two or more invalid cycles
    }

    cp_fe_ld_id: coverpoint ld_id iff (req_valid) { 
      bins supported = {4'h0};
      bins unsupported = default;
    }

    cp_fe_req_channel: coverpoint req_valid_p iff (lane==1'b0);
    
    cp_fe_req_concurrency: coverpoint $countones(req_valid_p);
   // { 
   //   bins no_valid_lane = {0};
   //   bins one_lane      = {1};
   //   bins two_lanes     = {2};
   //   bins three_lanes   = {3};
   //   bins four_lanes    = {4};
   // }

    cp_fe_unsup_req_opcode: coverpoint opcode iff (req_valid) {
      bins supported   = {4'h1};
      bins unsupported = default;
    }

    cp_fe_snp_type: coverpoint snp_type iff (req_valid) {
      bins supported   = {3'b000};
      bins unsupported = default;
    }

    cp_fe_meta_field: coverpoint meta_field iff (req_valid) {
      bins supported   = {2'b11};
      bins unsupported = default;
    }

    cp_fe_meta_value: coverpoint meta_value iff (req_valid);

    cp_fe_tag: coverpoint tag iff (req_valid) {
       bins tags[8]  = {[16'h0000:16'hFFFF]};
    }

    // HPA is represented as HPA[51:6]. Bit 0 therefore identifies whether the
    // 64B line is aligned to the lower or upper half of a 128B boundary.
    cp_fe_hpa_alignment: coverpoint hpa[0] iff (req_valid) {
      bins aligned_128b     = {1'b0};
      bins upper_64b_half   = {1'b1};
    }

    cp_fe_valid_unsupported_req_opcode_enable: coverpoint opcode_check_enable iff (req_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_unsupported_req_filed_chk_enables: coverpoint field_check_enable iff (req_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cr_fe_lane_by_flit_mode: cross cp_fe_flit_mode, cp_fe_req_channel iff (req_valid) {
      illegal_bins mode_68b_upper_lanes =
        binsof(cp_fe_flit_mode) intersect {1'b0} &&
        binsof(cp_fe_req_channel) intersect {[2:3]};
    }

    //cr_fe_opcode_stimulus: cross cp_fe_unsup_req_opcode, cp_fe_valid_unsupported_req_opcode_enable;
    //cr_fe_snp_stimulus:    cross cp_fe_snp_type, cp_fe_unsupported_req_filed_chk_enables;
    //cr_fe_meta_stimulus:   cross cp_fe_meta_field, cp_fe_unsupported_req_filed_chk_enables;

    cr_fe_unsup_req_x_en_by_channel:     cross cp_fe_req_channel, cp_fe_unsup_req_opcode, cp_fe_valid_unsupported_req_opcode_enable iff (req_valid);
    cr_fe_lane_snp_type:   cross cp_fe_req_channel, cp_fe_snp_type, cp_fe_unsupported_req_filed_chk_enables iff (req_valid);
    cr_fe_lane_meta_field: cross cp_fe_req_channel, cp_fe_meta_field, cp_fe_unsupported_req_filed_chk_enables iff (req_valid);
    //cr_fe_lane_meta_value: cross cp_fe_req_channel, cp_fe_meta_value, cp_fe_unsupported_req_filed_chk_enables;
    //cr_fe_lane_ld_id:      cross cp_fe_req_channel, cp_fe_ld_id;

    // Exercises simultaneous supported/unsupported field combinations without
    // assuming the value of an unobservable internal error signal.
    cr_fe_header_fields: cross cp_fe_unsup_req_opcode, cp_fe_snp_type, cp_fe_meta_field iff (req_valid);
  endgroup : cg_fe_cxl_parser_req

  // -------------------------------------------------------------------------
  // RWD input coverage
  // -------------------------------------------------------------------------
  covergroup cg_fe_cxl_parser_rwd with function sample(
    input bit [1:0]    lane,
    input bit          rwd_valid,
    input bit          flit_mode,
    input bit [3:0]    opcode,
    input bit [2:0]    snp_type,
    input bit [1:0]    meta_field,
    input bit [1:0]    meta_value,
    input bit [15:0]   tag,
    input bit [45:0]   hpa,
    input bit [3:0]    ld_id,
    input bit          poison,
    input bit [511:0]  rwd_data,
    input bit [63:0]   byte_enable,
    input bit          opcode_check_enable,
    input bit          field_check_enable,
    input bit          poison_check_enable,
    input bit [1:0]    rwd_valid_p
  );
    option.per_instance = 1;

    cp_fe_valid: coverpoint rwd_valid { 
      bins valid_low = {1'b0};
      bins valid_high = {1'b1};
    }

    cp_fe_flit_mode: coverpoint flit_mode iff(rwd_valid){
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    cp_fe_rwd_channel: coverpoint rwd_valid_p iff(lane==1'b0);
    //{
    //  bins lane_0 = {0};
    //  bins lane_1 = {1};
    //}
    
    cp_fe_rwd_concurrency: coverpoint $countones(rwd_valid_p);
   // { 
   //   bins no_valid_lane = {0};
   //   bins one_lane      = {1};
   //   bins two_lanes     = {2};
   // }

    cp_fe_ld_id: coverpoint ld_id iff(rwd_valid) { 
      bins supported = {4'h1};
      bins unsupported = default;
    }

    cp_fe_unsup_rwd_field_opcode: coverpoint opcode iff(rwd_valid) {
      bins supported   = {4'h1};
      bins unsupported = default;
    }

    cp_fe_unsup_rwd_field_snp_type: coverpoint snp_type iff(rwd_valid) {
      bins supported   = {3'b000};
      bins unsupported = default;
    }

    cp_fe_unsup_rwd_field_meta_field: coverpoint meta_field iff(rwd_valid) {
      bins supported   = {2'b11};
      bins unsupported = default;
    }

    cp_fe_tag: coverpoint tag iff(rwd_valid) {
      bins tags[8]  = {[16'h0000:16'hFFFF]};

    }

    cp_fe_hpa_alignment: coverpoint hpa[0] iff(rwd_valid) {
      bins aligned_128b   = {1'b0};
      bins upper_64b_half = {1'b1};
    }

    cp_fe_poison_received: coverpoint poison iff(rwd_valid) {
      bins clear = {1'b0};
      bins set   = {1'b1};
    }

    cp_fe_unsupported_rwd_opcode_enable: coverpoint opcode_check_enable iff(rwd_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_unsupported_rwd_filed_chk_enables: coverpoint field_check_enable iff(rwd_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_crc_invert_enable: coverpoint poison_check_enable iff(rwd_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_poison_enable: coverpoint poison_enable iff(rwd_valid) { 
      bins poison_enb = {1'b1};
      bins poison_dis_enb = {1'b0};
    }

    cr_fe_lane_by_flit_mode: cross cp_fe_flit_mode, cp_fe_rwd_channel iff(rwd_valid) {
      illegal_bins mode_68b_upper_lane =
        binsof(cp_fe_flit_mode) intersect {1'b0} &&
        binsof(cp_fe_rwd_channel) intersect {1};
    }

    cp_fe_rwd_data: coverpoint rwd_data iff(rwd_valid) {
      bins all_zeros = {'0};
      bins all_ones  = {'1};
      bins others    = default;
    }

    // Byte Enable Coverpoint
    cp_fe_byte_enable: coverpoint byte_enable iff(rwd_valid) {
      bins full_be   = {64'hFFFF_FFFF_FFFF_FFFF};
      bins empty_be  = {64'h0000_0000_0000_0000};
      bins partial   = default;
    }

    //cr_fe_opcode_stimulus: cross cp_fe_unsup_rwd_field_opcode, cp_fe_unsupported_rwd_opcode_enable;
    //cr_fe_snp_stimulus:    cross cp_fe_unsup_rwd_field_snp_type, cp_fe_unsupported_rwd_filed_chk_enables;
    //cr_fe_meta_stimulus:   cross cp_fe_unsup_rwd_field_meta_field, cp_fe_unsupported_rwd_filed_chk_enables;
    //cr_fe_poison_stimulus: cross cp_fe_poison_received, cp_fe_crc_invert_enable, cp_fe_poison_enable;

    cr_fe_unsup_rwd_x_en_opcode_by_channel:     cross cp_fe_rwd_channel, cp_fe_unsup_rwd_field_opcode, cp_fe_unsupported_rwd_opcode_enable iff(rwd_valid);
    cr_fe_unsup_rwd_x_en_snp_type_by_channel:   cross cp_fe_rwd_channel, cp_fe_unsup_rwd_field_snp_type, cp_fe_unsupported_rwd_filed_chk_enables iff(rwd_valid);
    cr_fe_unsup_rwd_x_en_meta_field_by_channel: cross cp_fe_rwd_channel, cp_fe_unsup_rwd_field_meta_field, cp_fe_unsupported_rwd_filed_chk_enables iff(rwd_valid);
    cr_fe_lane_ld_id:      cross cp_fe_rwd_channel, cp_fe_ld_id iff(rwd_valid);
    cr_fe_poison_x_crcinv_by_channel:     cross cp_fe_rwd_channel, cp_fe_poison_received, cp_fe_crc_invert_enable iff(rwd_valid);

    // Poison, unsupported opcode and unsupported fields are independent parser
    // detections, so cover their simultaneous input combinations.
    cr_fe_error_inputs: cross cp_fe_unsup_rwd_field_opcode, cp_fe_unsup_rwd_field_snp_type, cp_fe_unsup_rwd_field_meta_field, cp_fe_poison_received iff(rwd_valid);
  endgroup : cg_fe_cxl_parser_rwd

  //--------------------------------------------------------------------------
  // Egress_Queue Coverage
  //--------------------------------------------------------------------------
covergroup cg_fe_egress_queue with function sample(
  input bit devload_sample_valid,
  input bit write_fill_sample_valid,
  input bit read_fill_sample_valid,
  input bit [7:0] write_fill_level,
  input bit [7:0] read_fill_level
);
  option.per_instance = 1;

  cp_fe_write_egress_queue_devload:
    coverpoint write_egress_queue_devload iff (devload_sample_valid) {
      bins light        = {2'b00};
      bins optimal      = {2'b01};
      bins mod_overload = {2'b10};
      bins severe       = {2'b11};
    }

  cp_fe_read_egress_queue_devload:
    coverpoint read_egress_queue_devload iff (devload_sample_valid) {
      bins light        = {2'b00};
      bins optimal      = {2'b01};
      bins mod_overload = {2'b10};
      bins severe       = {2'b11};
    }

  cp_fe_write_backpressure: coverpoint write_fill_level
    iff (write_fill_sample_valid) {
    bins empty = {8'd0};
    bins low_fill = {[8'd1:8'd32]};
    bins high_fill = {[8'd33:8'd63]};
    bins egress_backpressure_applied = {[8'd64:8'hff]};
  }

  cp_fe_read_backpressure: coverpoint read_fill_level
    iff (read_fill_sample_valid) {
    bins empty = {8'd0};
    bins low_fill = {[8'd1:8'd32]};
    bins high_fill = {[8'd33:8'd63]};
    bins egress_backpressure_applied = {[8'd64:8'hff]};
  }

endgroup : cg_fe_egress_queue


  // -------------------------------------------------------------------------
  // S2M DRC (Data Response) output coverage
  // Exposes 2 DRC channels
  // -------------------------------------------------------------------------
  covergroup cg_fe_cxl_encap_drs with function sample(
    input int unsigned lane,
    input bit [2:0]    opcode,
    input bit [1:0]    meta_field,
    input bit [1:0]    meta_value,
    input bit [15:0]   tag,
    input bit          poison,
    input bit [3:0]    ld_id,
    input bit [1:0]    dev_load,
    input bit [511:0]  s2m_data
  );
    option.per_instance = 1;

    // DRC interface has 2 active channels
    cp_fe_lane: coverpoint lane {
      bins lane_0 = {0};
      bins lane_1 = {1};
    }

    // Only MemData (000) and MemData-NXM (001) are used for DRS
    cp_fe_opcode: coverpoint opcode {
      bins memdata     = {3'b000};
      bins memdata_nxm = {3'b001};
      bins unsupported = default;
    }

    // MetaField and MetaValue are always 0
    cp_fe_meta_field: coverpoint meta_field {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }
    
    cp_fe_meta_value: coverpoint meta_value {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }

    // ld_id is always 0 for single LD device
    cp_fe_ld_id: coverpoint ld_id {
      bins expected_0  = {4'h0};
      bins unsupported = default;
    }

    cp_fe_poison: coverpoint poison {
      bins clear = {1'b0};
      bins set   = {1'b1};
    }

    cp_fe_poison_enable: coverpoint poison_enable { 
      bins poison_enb = {1'b1};
      bins poison_dis_enb = {1'b0};
    }

    // DevLoad comes from egress queue fill level
    cp_fe_dev_load: coverpoint dev_load {
      bins light        = {2'b00};
      bins optimal      = {2'b01};
      bins mod_overload = {2'b10};
      bins severe       = {2'b11};

      // Gradual increase
      bins rise_00_01 = (2'b00 => 2'b01);
      bins rise_01_10 = (2'b01 => 2'b10);
      bins rise_10_11 = (2'b10 => 2'b11);

      // All decreasing-load combinations
      bins fall_01_00 = (2'b01 => 2'b00);
      bins fall_10_01 = (2'b10 => 2'b01);
      bins fall_11_10 = (2'b11 => 2'b10);
      bins fall_10_00 = (2'b10 => 2'b00);
      bins fall_11_01 = (2'b11 => 2'b01);
      bins fall_11_00 = (2'b11 => 2'b00);

      // Load remains unchanged
      bins steady_00 = (2'b00 => 2'b00);
      bins steady_01 = (2'b01 => 2'b01);
      bins steady_10 = (2'b10 => 2'b10);
      bins steady_11 = (2'b11 => 2'b11);

      // Your requested illegal upward jumps
      illegal_bins jump_00_10 = (2'b00 => 2'b10);
      illegal_bins jump_00_11 = (2'b00 => 2'b11);
      illegal_bins jump_01_11 = (2'b01 => 2'b11);
    }

    cp_fe_tag: coverpoint tag {
      bins tags[8] = {[16'h0000:16'hFFFF]};
    }

    cp_fe_s2m_data : coverpoint s2m_data {
    bins all_zeros = {'0};
    bins all_ones  = {'1};
    bins other     = default;
  }

    // MemData can be poisoned or clear; MemData-NXM is typically unpoisoned but 
    // depends on "Poison On Decode Error Enable".
    cr_fe_opcode_poison: cross cp_fe_opcode, cp_fe_poison;

    cr_fe_lane_opcode: cross cp_fe_lane, cp_fe_opcode;
    cr_fe_lane_meta: cross cp_fe_lane, cp_fe_meta_field, cp_fe_meta_value;
    cr_fe_lane_poison: cross cp_fe_lane, cp_fe_poison_enable, cp_fe_poison;
    cr_fe_lane_dev_load: cross cp_fe_lane, cp_fe_dev_load;
    
  endgroup : cg_fe_cxl_encap_drs

  // -------------------------------------------------------------------------
  // S2M NDR (No Data Response) output coverage
  // Exposes 6 NDR channels
  // -------------------------------------------------------------------------
  covergroup cg_fe_cxl_encap_ndr with function sample(
    input int unsigned lane,
    input bit [2:0]    opcode,
    input bit [1:0]    meta_field,
    input bit [1:0]    meta_value,
    input bit [15:0]   tag,
    input bit [3:0]    ld_id,
    input bit [1:0]    dev_load
  );
    option.per_instance = 1;

    // NDR interface has 6 active channels
    cp_fe_lane: coverpoint lane {
      bins lanes[] = {[0:5]};
    }

    // NDR Opcode is always Cmp (000) for HDM-H
    cp_fe_opcode: coverpoint opcode {
      bins cmp         = {3'b000};
      bins unsupported = default;
    }

    // MetaField and MetaValue are always 0
    cp_fe_meta_field: coverpoint meta_field {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }
    
    cp_fe_meta_value: coverpoint meta_value {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }

    // ld_id is always 0 for single LD device
    cp_fe_ld_id: coverpoint ld_id {
      bins expected_0  = {4'h0};
      bins unsupported = default;
    }

    // DevLoad comes from egress queue fill level
    cp_fe_dev_load: coverpoint dev_load {
      bins light        = {2'b00};
      bins optimal      = {2'b01};
      bins mod_overload = {2'b10};
      bins severe       = {2'b11};

      // Gradual increase
      bins rise_00_01 = (2'b00 => 2'b01);
      bins rise_01_10 = (2'b01 => 2'b10);
      bins rise_10_11 = (2'b10 => 2'b11);

      // All decreasing-load combinations
      bins fall_01_00 = (2'b01 => 2'b00);
      bins fall_10_01 = (2'b10 => 2'b01);
      bins fall_11_10 = (2'b11 => 2'b10);
      bins fall_10_00 = (2'b10 => 2'b00);
      bins fall_11_01 = (2'b11 => 2'b01);
      bins fall_11_00 = (2'b11 => 2'b00);

      // Load remains unchanged
      bins steady_00 = (2'b00 => 2'b00);
      bins steady_01 = (2'b01 => 2'b01);
      bins steady_10 = (2'b10 => 2'b10);
      bins steady_11 = (2'b11 => 2'b11);

      // Your requested illegal upward jumps
      illegal_bins jump_00_10 = (2'b00 => 2'b10);
      illegal_bins jump_00_11 = (2'b00 => 2'b11);
      illegal_bins jump_01_11 = (2'b01 => 2'b11);
    }

    cp_fe_tag: coverpoint tag {
      bins tags[8] = {[16'h0000:16'hFFFF]};
    }

    // Cross combinations to ensure no rogue bits appear alongside expected Cmp opcode
    cr_fe_ndr_fields: cross cp_fe_opcode, cp_fe_meta_field, cp_fe_ld_id;

    cr_fe_lane_opcode: cross cp_fe_opcode, cp_fe_lane;
    cr_fe_lane_meta: cross cp_fe_lane, cp_fe_meta_field, cp_fe_meta_value;
    cr_fe_ld_id: cross cp_fe_lane, cp_fe_ld_id;
    cr_fe_dev_load: cross cp_fe_lane, cp_fe_dev_load;

  endgroup : cg_fe_cxl_encap_ndr

  // -------------------------------------------------------------------------
  // Combining-eligibility input coverage
  // -------------------------------------------------------------------------
  // Mirrors the supplied driver's round-robin allocation after observed reset.
  bit req_order_known;
  int unsigned req_next_lane;
  int unsigned req_cycle_start;
  int unsigned req_previous_count;
  bit req_previous_four_lane;
  bit req_partial_previous;
  bit req_comb_snapshot_sample;
  bit req_order_pair_sample;
  bit rwd_order_known;
  int unsigned rwd_next_lane;
  int unsigned rwd_cycle_start;
  int unsigned rwd_previous_count;
  bit rwd_previous_two_lane;
  bit rwd_partial_previous;
  bit rwd_order_pair_sample;

  covergroup cg_fe_cxl_parser_combining with function sample(
    input bit path_is_write,
    input bit combining_rd_enable,
    input bit combining_wr_enable,
    input bit [2:0] pair_id,
    input bit adjacent_pair_present,
    input bit first_hpa_128b_aligned,
    input bit addresses_contiguous
  );
    option.per_instance = 1;

    cp_fe_combine_direction: coverpoint path_is_write iff (!req_comb_snapshot_sample) {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    cp_fe_combine_rd_enable: coverpoint combining_rd_enable iff (!req_comb_snapshot_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_combine_wr_enable: coverpoint combining_wr_enable iff (!req_comb_snapshot_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    // pair_id encoding:
    //   0 = Req lanes 0-1, 1 = Req lanes 1-2, 2 = Req lanes 2-3,
    //   3 = Req lanes 3-0, 4 = RwD lanes 0-1, 5 = RwD lanes 1-0.
    // A pair is combinable only when both lanes are valid in the same sample,
    // the first address is 128 B aligned, and the second address is base+64 B.
    cp_fe_combine_valid_pair: coverpoint pair_id iff (
      !req_comb_snapshot_sample && adjacent_pair_present &&
      first_hpa_128b_aligned &&
      addresses_contiguous
    ) {
      bins req_0_1 = {3'd0};
      bins req_1_2 = {3'd1};
      bins req_2_3 = {3'd2};
      bins req_3_0 = {3'd3};
      bins rwd_0_1 = {3'd4};
      bins rwd_1_0 = {3'd5};
    }

    cp_fe_combine_pair_present: coverpoint adjacent_pair_present iff (!req_comb_snapshot_sample) {
      bins incomplete_pair = {1'b0};
      bins complete_pair   = {1'b1};
    }

    cp_fe_combine_alignment: coverpoint first_hpa_128b_aligned iff (!req_comb_snapshot_sample) {
      bins unaligned = {1'b0};
      bins aligned   = {1'b1};
    }

    cp_fe_combine_contiguous: coverpoint addresses_contiguous iff (!req_comb_snapshot_sample) {
      bins noncontiguous = {1'b0};
      bins contiguous    = {1'b1};
    }

    // Violations that are unambiguously observable from a complete adjacent
    // pair in the current CXL snapshot.
    cp_fe_combine_violation: coverpoint {
      !addresses_contiguous,
      !first_hpa_128b_aligned
    } iff (!req_comb_snapshot_sample && adjacent_pair_present) {
      bins addr_ne_base_plus_64b   = {2'b10};
      bins base_not_128b_aligned   = {2'b01};
      bins multi_violation         = {2'b11};
      ignore_bins no_violation     = {2'b00};
    }

    // The pair type fixes the architectural direction: Req is read and RwD
    // is write. Ignore the impossible pair/direction combinations.
    cr_fe_combine_dir: cross cp_fe_combine_valid_pair,
                             cp_fe_combine_direction iff (!req_comb_snapshot_sample) {
      ignore_bins req_as_write =
        binsof(cp_fe_combine_valid_pair) intersect {[3'd0:3'd3]} &&
        binsof(cp_fe_combine_direction) intersect {1'b1};
      ignore_bins rwd_as_read =
        binsof(cp_fe_combine_valid_pair) intersect {[3'd4:3'd5]} &&
        binsof(cp_fe_combine_direction) intersect {1'b0};
    }

    // Required independent-control cases. Both-enabled and both-disabled are
    // already covered by the individual enable coverpoints.
    cr_fe_combine_rd_wr_indep: cross cp_fe_combine_rd_enable,
                                     cp_fe_combine_wr_enable iff (!req_comb_snapshot_sample) {
      bins rd_only =
        binsof(cp_fe_combine_rd_enable) intersect {1'b1} &&
        binsof(cp_fe_combine_wr_enable) intersect {1'b0};
      bins wr_only =
        binsof(cp_fe_combine_rd_enable) intersect {1'b0} &&
        binsof(cp_fe_combine_wr_enable) intersect {1'b1};
     ignore_bins coupled_settings = 
        !binsof(cp_fe_combine_rd_enable) intersect {1'b1} && !binsof(cp_fe_combine_wr_enable) intersect {1'b0} ||
        (binsof(cp_fe_combine_rd_enable) intersect {1'b0} && binsof(cp_fe_combine_wr_enable) intersect {1'b0}) ||
        (binsof(cp_fe_combine_rd_enable) intersect {1'b1} && binsof(cp_fe_combine_wr_enable) intersect {1'b1});
    }

    cr_fe_combining_inputs: cross
      cp_fe_combine_direction,
      //cp_fe_combine_enable,
      cp_fe_combine_pair_present,
      cp_fe_combine_alignment,
      cp_fe_combine_contiguous iff (!req_comb_snapshot_sample);

    // Four-lane REQ order coverage. Values denote the FIRST valid packet.
    cp_fe_req_start_channel: coverpoint req_cycle_start
      iff (!path_is_write && req_comb_snapshot_sample) {
      bins order_0123 = {0};
      bins order_1230 = {1};
      bins order_2301 = {2};
      bins order_3012 = {3};
    }

    cp_fe_req_partial_to_start: coverpoint req_cycle_start
      iff (!path_is_write && req_comb_snapshot_sample &&
           req_partial_previous) {
      bins next_start_ch0 = {0};
      bins next_start_ch1 = {1};
      bins next_start_ch2 = {2};
      bins next_start_ch3 = {3};
    }

    // Pair-only points: sample together to avoid stale cross values.
    cp_fe_req_order_for_pair: coverpoint req_cycle_start
      iff (req_order_pair_sample && adjacent_pair_present &&
           first_hpa_128b_aligned && addresses_contiguous &&
           combining_rd_enable) {
      bins starts[] = {[0:3]};
    }
    cp_fe_req_eligible_pair: coverpoint pair_id
      iff (req_order_pair_sample && adjacent_pair_present &&
           first_hpa_128b_aligned && addresses_contiguous &&
           combining_rd_enable) {
      bins req_0_1 = {0};
      bins req_1_2 = {1};
      bins req_2_3 = {2};
      bins req_3_0 = {3};
    }
    cr_fe_req_order_x_eligible_pair: cross
      cp_fe_req_order_for_pair, cp_fe_req_eligible_pair
      iff (req_order_pair_sample && adjacent_pair_present &&
           first_hpa_128b_aligned && addresses_contiguous &&
           combining_rd_enable) {
      // Exclude last-to-first, which is not consecutive in packet order.
      ignore_bins end_to_start =
        (binsof(cp_fe_req_order_for_pair) intersect {0} &&
         binsof(cp_fe_req_eligible_pair) intersect {3}) ||
        (binsof(cp_fe_req_order_for_pair) intersect {1} &&
         binsof(cp_fe_req_eligible_pair) intersect {0}) ||
        (binsof(cp_fe_req_order_for_pair) intersect {2} &&
         binsof(cp_fe_req_eligible_pair) intersect {1}) ||
        (binsof(cp_fe_req_order_for_pair) intersect {3} &&
         binsof(cp_fe_req_eligible_pair) intersect {2});
    }

    cp_fe_rwd_start_channel: coverpoint rwd_cycle_start
      iff (path_is_write && req_comb_snapshot_sample) {
      bins order_01 = {0};
      bins order_10 = {1};
    }
    cp_fe_rwd_partial_to_start: coverpoint rwd_cycle_start
      iff (path_is_write && req_comb_snapshot_sample &&
           rwd_partial_previous) {
      bins next_start_ch0 = {0};
      bins next_start_ch1 = {1};
    }
    cp_fe_rwd_order_for_pair: coverpoint rwd_cycle_start
      iff (rwd_order_pair_sample && adjacent_pair_present &&
           first_hpa_128b_aligned && addresses_contiguous &&
           combining_wr_enable) {
      bins starts[] = {[0:1]};
    }
    cp_fe_rwd_eligible_pair: coverpoint pair_id
      iff (rwd_order_pair_sample && adjacent_pair_present &&
           first_hpa_128b_aligned && addresses_contiguous &&
           combining_wr_enable) {
      bins rwd_0_1 = {4};
      bins rwd_1_0 = {5};
    }
    cr_fe_rwd_order_x_eligible_pair: cross
      cp_fe_rwd_order_for_pair, cp_fe_rwd_eligible_pair
      iff (rwd_order_pair_sample && adjacent_pair_present &&
           first_hpa_128b_aligned && addresses_contiguous &&
           combining_wr_enable) {
      ignore_bins reverse_order =
        (binsof(cp_fe_rwd_order_for_pair) intersect {0} &&
         binsof(cp_fe_rwd_eligible_pair) intersect {5}) ||
        (binsof(cp_fe_rwd_order_for_pair) intersect {1} &&
         binsof(cp_fe_rwd_eligible_pair) intersect {4});
    }
  endgroup : cg_fe_cxl_parser_combining

  //--------------------------------------------------------------------------
  // TAG_FIFO'S CoverGroup
  //--------------------------------------------------------------------------

 covergroup cg_fe_tag_fifo with function sample(
  input bit          is_write,
  input int unsigned axi_id
);
  option.per_instance = 1;

  cp_fe_tagfifo_arid: coverpoint axi_id
    iff (!is_write) {
    bins rd_fifo0 = {0};
    bins rd_fifo1 = {1};
    bins rd_fifo2 = {2};
    bins rd_fifo3 = {3};
  }

  cp_fe_tagfifo_awid: coverpoint axi_id
    iff (is_write) {
    bins wr_fifo0 = {0};
    bins wr_fifo1 = {1};
    bins wr_fifo2 = {2};
    bins wr_fifo3 = {3};
  }

endgroup : cg_fe_tag_fifo 

  // -------------------------------------------------------------------------
  // APB configuration coverage
  // -------------------------------------------------------------------------
  covergroup cg_fe_apb_registers;
    option.per_instance = 1;

    cp_fe_flit_mode: coverpoint flit_mode_inst {
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    cp_fe_combining_rd_enable: coverpoint combining_rd_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_combining_wr_enable: coverpoint combining_wr_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_shared_opcode_check_enable: coverpoint unsupported_opcode_check_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_shared_field_check_enable: coverpoint unsupported_field_check_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_crc_invert_enable: coverpoint poison_crc_invert_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_mem_app_pending: coverpoint mem_app_pending_enable {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_nxm_enable: coverpoint nxm_enable {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_poison_enable: coverpoint poison_enable {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    // -------------------------------------------------------------------------
    // HDM Decoder Coverpoints (Conditioned on is_hdm_update)
    // -------------------------------------------------------------------------
    cp_fe_hdm_idx: coverpoint current_hdm_idx iff (is_hdm_update) {
      bins decoders[] = {[0:9]};
    }

    cp_fe_hdm_hpa_base: coverpoint current_hpa_base iff (is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }
    
    cp_fe_hdm_hpa_top: coverpoint current_hpa_top iff (is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }
    
    cp_fe_hdm_dpa_base: coverpoint current_dpa_base iff (is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }

    // -------------------------------------------------------------------------
    // Interrupt Enables Coverpoints
    // -------------------------------------------------------------------------
    cp_fe_hdm_miss_rd      : coverpoint interrupt_enables_inst[0]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_hdm_miss_wr      : coverpoint interrupt_enables_inst[1]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_perm_err_rd      : coverpoint interrupt_enables_inst[2]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_perm_err_wr      : coverpoint interrupt_enables_inst[3]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_tag_range_rd     : coverpoint interrupt_enables_inst[4]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_tag_range_wr     : coverpoint interrupt_enables_inst[5]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_unsupported_req  : coverpoint interrupt_enables_inst[6]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_unsupported_rwd  : coverpoint interrupt_enables_inst[7]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_poison_recv      : coverpoint interrupt_enables_inst[8]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_rd_err    : coverpoint interrupt_enables_inst[9]  { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_wr_err    : coverpoint interrupt_enables_inst[10] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_rd_chk    : coverpoint interrupt_enables_inst[11] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_wr_chk    : coverpoint interrupt_enables_inst[12] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_egress_rd_thresh : coverpoint interrupt_enables_inst[13] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_egress_wr_thresh : coverpoint interrupt_enables_inst[14] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_ndr_credit_ovf   : coverpoint interrupt_enables_inst[15] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_drs_credit_ovf   : coverpoint interrupt_enables_inst[16] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_dcd_ded          : coverpoint interrupt_enables_inst[17] { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_irq_global_en    : coverpoint interrupt_enables_inst[18] { bins disabled = {0}; bins enabled = {1}; }

    // -------------------------------------------------------------------------
    // WR_Token Bucket / WR_Rate Limiter Coverpoints
    // Base address 'h80c00
    // -------------------------------------------------------------------------
    cp_fe_wr_refill_period: coverpoint wr_refill_period {
      bins periods[4] = {[16'h0000:16'hFFFF]}; 
    }

   cp_fe_wr_capacity: coverpoint wr_capacity {
     bins capacities[4] = {[16'h0000:16'hFFFF]}; 
   }

   cp_fe_wr_refill_rate: coverpoint wr_refill_rate {
     bins rates[4] = {[5'h00:5'h1F]}; // 5-bit width
   }

   cp_fe_wr_reset_token: coverpoint wr_reset_token {
     bins deasserted = {1'b0};
     bins asserted   = {1'b1};
   }

    // -------------------------------------------------------------------------
    // RD_Token Bucket / RD_Rate Limiter Coverpoints
    // Base address 'h80d00
    // -------------------------------------------------------------------------
    cp_fe_rd_refill_period: coverpoint rd_refill_period {
      bins periods[4] = {[16'h0000:16'hFFFF]}; 
    }

   cp_fe_rd_capacity: coverpoint rd_capacity {
     bins capacities[4] = {[16'h0000:16'hFFFF]}; 
   }

   cp_fe_rd_refill_rate: coverpoint rd_refill_rate {
     bins rates[4] = {[5'h00:5'h1F]}; // 5-bit width
   }

   cp_fe_rd_reset_token: coverpoint rd_reset_token {
     bins deasserted = {1'b0};
     bins asserted   = {1'b1};
   }
    
    // -------------------------------------------------------------------------
    // FE Error Status Register Coverpoints
    // -------------------------------------------------------------------------
    cp_fe_hdm_miss_rd_status      : coverpoint fe_error_status_inst[0]  { bins clean = {0}; bins error = {1}; }
    cp_fe_hdm_miss_wr_status      : coverpoint fe_error_status_inst[1]  { bins clean = {0}; bins error = {1}; }
    cp_fe_perm_error_rd_status    : coverpoint fe_error_status_inst[2]  { bins clean = {0}; bins error = {1}; }
    cp_fe_perm_error_wr_status    : coverpoint fe_error_status_inst[3]  { bins clean = {0}; bins error = {1}; }
    cp_fe_tag_range_rd_status     : coverpoint fe_error_status_inst[4]  { bins clean = {0}; bins error = {1}; }
    cp_fe_tag_range_wr_status     : coverpoint fe_error_status_inst[5]  { bins clean = {0}; bins error = {1}; }
    cp_fe_unsupported_req_status  : coverpoint fe_error_status_inst[6]  { bins clean = {0}; bins error = {1}; }
    cp_fe_unsupported_rwd_status  : coverpoint fe_error_status_inst[7]  { bins clean = {0}; bins error = {1}; }
    cp_fe_poison_received_status  : coverpoint fe_error_status_inst[8]  { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_rd_err_status    : coverpoint fe_error_status_inst[9]  { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_wr_err_status    : coverpoint fe_error_status_inst[10] { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_rd_chk_status    : coverpoint fe_error_status_inst[11] { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_wr_chk_status    : coverpoint fe_error_status_inst[12] { bins clean = {0}; bins error = {1}; }
    cp_fe_egress_rd_thresh_status : coverpoint fe_error_status_inst[13] { bins clean = {0}; bins error = {1}; }
    cp_fe_egress_wr_thresh_status : coverpoint (|fe_error_status_inst[15:14]) { bins clean = {0}; bins error = {1}; }
    cp_fe_ndr_credit_ovf_status   : coverpoint fe_error_status_inst[16] { bins clean = {0}; bins error = {1}; }
    cp_fe_drs_credit_ovf_status   : coverpoint fe_error_status_inst[17] { bins clean = {0}; bins error = {1}; }
    cp_fe_dcd_ded_status          : coverpoint fe_error_status_inst[18] { bins clean = {0}; bins error = {1}; }


    // Cross Coverage: Verify the reset token triggers across various capacities
    cr_fe_wr_capacity_reset: cross cp_fe_wr_capacity, cp_fe_wr_reset_token;
    cr_fe_rd_capacity_reset: cross cp_fe_rd_capacity, cp_fe_rd_reset_token;

    cr_fe_parser_configuration: cross
      cp_fe_flit_mode,
      cp_fe_combining_rd_enable,
      cp_fe_combining_wr_enable;

    cr_fe_error_configuration: cross
      cp_fe_shared_opcode_check_enable,
      cp_fe_shared_field_check_enable,
      cp_fe_crc_invert_enable;

    // Cross the index with the base to ensure every individual decoder (0-9) gets a valid HPA configuration
    cr_fe_idx_hpa_base: cross cp_fe_hdm_idx, cp_fe_hdm_hpa_base;
  endgroup : cg_fe_apb_registers

  // -------------------------------------------------------------------------
  // FE credit-manager coverage
  // -------------------------------------------------------------------------
  covergroup cg_fe_credit_manager with function sample(
    input bit          fsm_sample_valid,
    input bit [2:0]    egress_fsm_state,
    input bit [2:0]    ingress_fsm_state,
    input bit          credit_sample_valid,
    input bit          credit_is_ingress,
    input int unsigned credit_count,
    input bit          overflow_sample_valid,
    input bit [1:0]    credit_overflow_src,
    input bit          credit_overflow_irq_en
  );
    option.per_instance = 1;

    cp_fe_egress_credit_fsm_state: coverpoint egress_fsm_state
      iff (fsm_sample_valid) {
      bins idle        = {3'd0};
      bins init        = {3'd1};
      bins run         = {3'd2};
      bins deinit_mst  = {3'd3};
      bins deinit_slv  = {3'd4};
      bins startup     = (3'd0 => 3'd1 => 3'd2);
      bins mst_deinit  = (3'd2 => 3'd3 => 3'd0);
      bins slv_deinit  = (3'd2 => 3'd4 => 3'd0);
      illegal_bins run_mst_deinit_init = (3'd2 => 3'd3 => 3'd1);
      illegal_bins run_slv_deinit_init = (3'd2 => 3'd4 => 3'd1);

    }

    cp_fe_ingress_credit_fsm_state: coverpoint ingress_fsm_state
      iff (fsm_sample_valid) {

      bins idle       = {3'd0};
      bins init       = {3'd1};
      bins run        = {3'd2};
      bins deinit_mst = {3'd3};
      bins deinit_slv = {3'd4};

      bins startup    = (3'd0 => 3'd1 => 3'd2);
      bins mst_deinit = (3'd2 => 3'd3 => 3'd0);
      bins slv_deinit = (3'd2 => 3'd4 => 3'd0);
    }

    cp_fe_credit_count_egress: coverpoint credit_count
      iff (credit_sample_valid && !credit_is_ingress) {
      bins empty    = {0};
      bins partial  = {[1:31]};
      bins maximum  = {32};
      bins overflow = {[33:$]};
    }

    cp_fe_credit_count_ingress: coverpoint credit_count
      iff (credit_sample_valid && credit_is_ingress) {
      bins empty    = {0};
      bins partial  = {[1:31]};
      bins maximum  = {32};
      bins overflow = {[33:$]};
    }

    cp_fe_credit_overflow_src: coverpoint credit_overflow_src
      iff (overflow_sample_valid) {
      bins s2m_ndr = {2'd2};
      bins s2m_drs = {2'd3};
    }

    cp_fe_credit_overflow_irq_en: coverpoint credit_overflow_irq_en
      iff (overflow_sample_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cr_fe_credit_ovf_x_irqen: cross cp_fe_credit_overflow_src,
                                      cp_fe_credit_overflow_irq_en;
  endgroup : cg_fe_credit_manager

  // -------------------------------------------------------------------------
  // AXI Address Channel Covergroups (AW / AR)
  // -------------------------------------------------------------------------
  covergroup cg_fe_axi_requestor_aw;
    option.per_instance = 1;
    cp_fe_awid   : coverpoint aw.id { bins ids[4] = {[0:3]}; } // Tag FIFOs map to IDs 0-3
    cp_fe_awlen  : coverpoint aw.len { bins single_beat = {0}; } // CXL FE transactions are single beat
    cp_fe_awsize : coverpoint aw.size { bins size_64b = {6}; bins size_128b = {7}; } // 64B encoding
    cp_fe_aw_user : coverpoint aw.user { bins user_0 = {'h0};
                                      bins user_7 = {'h80};
                                      illegal_bins others = default; }

    cp_fe_poison_check_0: coverpoint rwd_poison[0];
    cp_fe_poison_check_1: coverpoint rwd_poison[1] iff (flit_mode_inst == 1'b1);

    // Cross
    cr_fe_id_size : cross cp_fe_awid, cp_fe_awsize;
    cr_fe_id_poison_0 : cross cp_fe_awid, cp_fe_aw_user, poison_crc_invert_enable_inst, cp_fe_poison_check_0;
    cr_fe_id_poison_1 : cross cp_fe_awid, cp_fe_aw_user, poison_crc_invert_enable_inst, cp_fe_poison_check_1 iff (flit_mode_inst == 1'b1);
  endgroup

  covergroup cg_fe_axi_requestor_ar;
    option.per_instance = 1;
    cp_fe_arid   : coverpoint ar.id { bins ids[4] = {[0:3]}; } 
    cp_fe_arlen  : coverpoint ar.len { bins single_beat = {0}; }
    cp_fe_arsize : coverpoint ar.size { bins size_64b = {6}; bins size_128b = {7}; }
  endgroup

  // -------------------------------------------------------------------------
  // AXI Data & Response Channel Covergroups (W, B, R)
  // -------------------------------------------------------------------------
  covergroup cg_fe_axi_requestor_w;
    option.per_instance = 1;
    cp_fe_wlast : coverpoint w.last { bins asserted = {1'b1}; }
  endgroup

  // Compare the parity of each complete CXL lane against its monitor check
  // bits. A packet fails if any of its byte check bits differs.
  covergroup cg_fe_axi_requestor_parity with function sample(
    input bit direction_is_ingress,
    input bit packet_is_data,
    input bit parity_error
  );
    option.per_instance = 1;

    cp_fe_axi_egress_parity: coverpoint {packet_is_data, parity_error}
      iff (!direction_is_ingress) {
      bins valid_req_parity   = {2'b00};
      bins invalid_req_parity = {2'b01};
      bins valid_rwd_parity   = {2'b10};
      bins invalid_rwd_parity = {2'b11};
    }

    cp_fe_axi_ingress_parity: coverpoint {packet_is_data, parity_error}
      iff (direction_is_ingress) {
      bins valid_ndr_parity   = {2'b00};
      bins invalid_ndr_parity = {2'b01};
      bins valid_drs_parity   = {2'b10};
      bins invalid_drs_parity = {2'b11};
    }
  endgroup : cg_fe_axi_requestor_parity

  // Final error type supplied by the scoreboard coverage item.
  covergroup cg_fe_axi_requestor_error with function sample(
    input bit [1:0] error_resp_type
  );
    option.per_instance = 1;
    cp_fe_err_response_type: coverpoint error_resp_type {
      bins no_error               = {2'b00};
      bins hdm_miss_err           = {2'b01};
      bins cxl_parser_permission  = {2'b10};
      bins tag_range_error        = {2'b11};
    }
  endgroup : cg_fe_axi_requestor_error

    // Sample the local per-lane scoreboard error-response shadow.
  covergroup cg_fe_hdm_decoder_rd with function sample(input hdm_cov_event_t e);
    option.per_instance = 1;

    cp_fe_dcd_ecc_sec: coverpoint {e.ecc_half_msb, e.ecc_found}
      iff (e.ecc_sec_sample_valid) {
      bins ar_lsb_sec_not_found = {2'b00};
      bins ar_lsb_sec_found     = {2'b01};
      bins ar_msb_sec_not_found = {2'b10};
      bins ar_msb_sec_found     = {2'b11};
    }

    cp_fe_dcd_ecc_ded: coverpoint {e.ecc_half_msb, e.ecc_found}
      iff (e.ecc_ded_sample_valid) {
      bins ar_lsb_ded_not_found = {2'b00};
      bins ar_lsb_ded_found     = {2'b01};
      bins ar_msb_ded_not_found = {2'b10};
      bins ar_msb_ded_found     = {2'b11};
    }

    // A dedicated counter sample enables only this region coverpoint.
    cp_fe_hdm_region_match: coverpoint e.region_index iff (e.region_sample_valid) {
      bins hdm_region_0_hit = {4'd0};
      bins hdm_region_1_hit = {4'd1};
      bins hdm_region_2_hit = {4'd2};
      bins hdm_region_3_hit = {4'd3};
      bins hdm_region_4_hit = {4'd4};
      bins hdm_region_5_hit = {4'd5};
      bins hdm_region_6_hit = {4'd6};
      bins hdm_region_7_hit = {4'd7};
      bins hdm_region_8_hit = {4'd8};
      bins hdm_region_9_hit = {4'd9};
    }

    cp_fe_hdm_boundary: coverpoint e.boundary_class
      iff (e.boundary_sample_valid) {
      bins hpa_base_include = {2'd0};
      bins hpa_between_base_and_top_minus_1 = {2'd1};
      bins hpa_top_minus_1 = {2'd2};
      bins hpa_top_excluded = {2'd3};
    }

    cp_fe_error_response_type: coverpoint e.error_type iff (e.error_valid) {
      bins no_error              = {2'b00};
      bins hdm_miss_err          = {2'b01};
      bins cxl_parser_permission = {2'b10};
      bins tag_range_error       = {2'b11};
    }

    cp_fe_hdm_miss: coverpoint e.is_write
      iff (e.error_valid && e.error_type == 2'b01) {
      bins read = {1'b0};
    }

    cp_fe_hdm_miss_nxm_enable: coverpoint e.nxm_enabled
      iff (e.error_valid && e.error_type == 2'b01) {
      bins apb_nxm_disabled = {1'b0};
      bins apb_nxm_enabled  = {1'b1};
    }

    cp_fe_hdm_miss_poison_enable: coverpoint e.poison_enabled
      iff (e.error_valid && e.error_type == 2'b01) {
      bins apb_poison_disabled = {1'b0};
      bins apb_poison_enabled  = {1'b1};
    }

    cr_fe_hdm_miss_x_nxm_x_poison: cross cp_fe_hdm_miss,
      cp_fe_hdm_miss_nxm_enable, cp_fe_hdm_miss_poison_enable;

    cp_fe_dcd_permission_valid: coverpoint e.permission_valid iff (e.error_valid) {
      bins not_checked = {1'b0};
      bins checked     = {1'b1};
    }

    cp_fe_dcd_permission: coverpoint e.permission_passed iff (e.permission_valid) {
      bins rd_ena0_read = {1'b0};
      bins normal_read = {1'b1};
    }

    cp_fe_dcd_axi_id: coverpoint e.axi_id iff (e.axi_valid) {
      bins read_id[4] = {[2'd0:2'd3]};
    }

    cp_fe_tag_range: coverpoint e.tag_range_passed
      iff (e.packet_valid && e.tag_bounds_valid && e.tag_range_checked) {
      bins tag_with_in_range = {1'b1};
      bins tag_out_of_range  = {1'b0};
    }

    cp_fe_tag_check_enable: coverpoint e.tag_check_enabled iff (e.packet_valid) {
      bins tag_check_enable  = {1'b1};
      bins tag_check_disable = {1'b0};
    }

    // A skipped/disabled check has no valid pass/fail result. The enable
    // coverpoint itself still covers disabled packets.
    cr_fe_tagrange_x_en: cross cp_fe_tag_range, cp_fe_tag_check_enable {
      ignore_bins check_disabled =
        binsof(cp_fe_tag_check_enable.tag_check_disable);
    }

    // Sample once per matched 128B AXI request, using both original tags.
    // Unchecked/default-zero tag results must never hit a failure bin.
    cp_fe_tagrange_128b: coverpoint e.tag_pair_passed
      iff (e.pair_sample_valid && e.axi_size == 8'd7 &&
           (&e.tag_pair_checked) && (&e.tag_pair_bounds_valid)) {
      bins both_pass     = {2'b11};
      bins both_fail     = {2'b00};
      bins t1pass_t2fail  = {2'b10};
      bins t1fail_t2pass  = {2'b01};
    }
  endgroup : cg_fe_hdm_decoder_rd

  covergroup cg_fe_hdm_decoder_wr with function sample(input hdm_cov_event_t e);
    option.per_instance = 1;

    cp_fe_dcd_ecc_sec: coverpoint {e.ecc_half_msb, e.ecc_found}
      iff (e.ecc_sec_sample_valid) {
      bins aw_lsb_sec_not_found = {2'b00};
      bins aw_lsb_sec_found     = {2'b01};
      bins aw_msb_sec_not_found = {2'b10};
      bins aw_msb_sec_found     = {2'b11};
    }

    cp_fe_dcd_ecc_ded: coverpoint {e.ecc_half_msb, e.ecc_found}
      iff (e.ecc_ded_sample_valid) {
      bins aw_lsb_ded_not_found = {2'b00};
      bins aw_lsb_ded_found     = {2'b01};
      bins aw_msb_ded_not_found = {2'b10};
      bins aw_msb_ded_found     = {2'b11};
    }

    // A dedicated counter sample enables only this region coverpoint.
    cp_fe_hdm_region_match: coverpoint e.region_index iff (e.region_sample_valid) {
      bins hdm_region_0_hit = {4'd0};
      bins hdm_region_1_hit = {4'd1};
      bins hdm_region_2_hit = {4'd2};
      bins hdm_region_3_hit = {4'd3};
      bins hdm_region_4_hit = {4'd4};
      bins hdm_region_5_hit = {4'd5};
      bins hdm_region_6_hit = {4'd6};
      bins hdm_region_7_hit = {4'd7};
      bins hdm_region_8_hit = {4'd8};
      bins hdm_region_9_hit = {4'd9};
    }

    cp_fe_hdm_boundary: coverpoint e.boundary_class
      iff (e.boundary_sample_valid) {
      bins hpa_base_include = {2'd0};
      bins hpa_between_base_and_top_minus_1 = {2'd1};
      bins hpa_top_minus_1 = {2'd2};
      bins hpa_top_excluded = {2'd3};
    }

    cp_fe_error_response_type: coverpoint e.error_type iff (e.error_valid) {
      bins no_error              = {2'b00};
      bins hdm_miss_err          = {2'b01};
      bins cxl_parser_permission = {2'b10};
      bins tag_range_error       = {2'b11};
    }

    cp_fe_hdm_miss: coverpoint e.is_write
      iff (e.error_valid && e.error_type == 2'b01) {
      bins write = {1'b1};
    }

    cp_fe_hdm_miss_nxm_enable: coverpoint e.nxm_enabled
      iff (e.error_valid && e.error_type == 2'b01) {
      bins apb_nxm_disabled = {1'b0};
      bins apb_nxm_enabled  = {1'b1};
    }

    cp_fe_hdm_miss_poison_enable: coverpoint e.poison_enabled
      iff (e.error_valid && e.error_type == 2'b01) {
      bins apb_poison_disabled = {1'b0};
      bins apb_poison_enabled  = {1'b1};
    }

    cr_fe_hdm_miss_x_nxm_x_poison: cross cp_fe_hdm_miss,
      cp_fe_hdm_miss_nxm_enable, cp_fe_hdm_miss_poison_enable;

    cp_fe_dcd_permission_valid: coverpoint e.permission_valid iff (e.error_valid) {
      bins not_checked = {1'b0};
      bins checked     = {1'b1};
    }

    cp_fe_dcd_permission: coverpoint e.permission_passed iff (e.permission_valid) {
      bins wr_ena0_write = {1'b0};
      bins normal_write = {1'b1};
    }

    cp_fe_dcd_axi_id: coverpoint e.axi_id iff (e.axi_valid) {
      bins write_id[4] = {[2'd0:2'd3]};
    }

    cp_fe_tag_range: coverpoint e.tag_range_passed
      iff (e.packet_valid && e.tag_bounds_valid && e.tag_range_checked) {
      bins tag_with_in_range = {1'b1};
      bins tag_out_of_range  = {1'b0};
    }

    cp_fe_tag_check_enable: coverpoint e.tag_check_enabled iff (e.packet_valid) {
      bins tag_check_enable  = {1'b1};
      bins tag_check_disable = {1'b0};
    }

    // A skipped/disabled check has no valid pass/fail result. The enable
    // coverpoint itself still covers disabled packets.
    cr_fe_tagrange_x_en: cross cp_fe_tag_range, cp_fe_tag_check_enable {
      ignore_bins check_disabled =
        binsof(cp_fe_tag_check_enable.tag_check_disable);
    }

    // Sample once per matched 128B AXI request, using both original tags.
    // Unchecked/default-zero tag results must never hit a failure bin.
    cp_fe_tagrange_128b: coverpoint e.tag_pair_passed
      iff (e.pair_sample_valid && e.axi_size == 8'd7 &&
           (&e.tag_pair_checked) && (&e.tag_pair_bounds_valid)) {
      bins both_pass     = {2'b11};
      bins both_fail     = {2'b00};
      bins t1pass_t2fail  = {2'b10};
      bins t1fail_t2pass  = {2'b01};
    }
  endgroup : cg_fe_hdm_decoder_wr


  // -------------------------------------------------------------------------
  // AXI responder coverage
  //
  // resp is normalized to the AMBA encoding by convert_to_b/convert_to_r:
  //   OKAY=2'b00, EXOKAY=2'b01, SLVERR=2'b10, DECERR=2'b11.
  // -------------------------------------------------------------------------
  covergroup cg_fe_axi_responder with function sample(
    input bit       response_is_read,
    input bit [7:0] response_id,
    input bit [1:0] response,
    input bit       response_last,
    input bit       response_user7
  );
    option.per_instance = 1;

    cp_fe_bresp: coverpoint response iff (!response_is_read) {
      bins okay   = {2'b00};
      bins slverr = {2'b10};
      bins decerr = {2'b11};
      illegal_bins exokay = {2'b01};
    }

    cp_fe_bid: coverpoint response_id iff (!response_is_read) {
      bins id_0 = {8'd0};
      bins id_1 = {8'd1};
      bins id_2 = {8'd2};
      bins id_3 = {8'd3};
      illegal_bins unsupported_id = default;
    }

    cp_fe_rresp: coverpoint response iff (response_is_read) {
      bins okay   = {2'b00};
      bins slverr = {2'b10};
      bins decerr = {2'b11};
      illegal_bins exokay = {2'b01};
    }

    cp_fe_rid: coverpoint response_id iff (response_is_read) {
      bins id_0 = {8'd0};
      bins id_1 = {8'd1};
      bins id_2 = {8'd2};
      bins id_3 = {8'd3};
      illegal_bins unsupported_id = default;
    }

    // FE transactions use ARLEN=0, so every read response must assert RLAST.
    cp_fe_rlast: coverpoint response_last iff (response_is_read) {
      bins asserted = {1'b1};
      ignore_bins deasserted = {1'b0};
    }

    // Encoding: {response_is_read, USER[7]}. Sample only successful
    // responses, as required by the coverage plan.
    cp_fe_resp_crc_user: coverpoint {response_is_read, response_user7}
      iff (response == 2'b00) {
      bins buser7_clear = {2'b00};
      bins buser7_set   = {2'b01};
      bins ruser7_clear = {2'b10};
      bins ruser7_set   = {2'b11};
    }
  endgroup : cg_fe_axi_responder

  // -------------------------------------------------------------------------
  // FE error and interrupt coverage
  // -------------------------------------------------------------------------
  covergroup cg_fe_error_interrupt with function sample(
    input bit       source_valid,
    input bit [3:0] error_source,
    input bit       source_irq_enable,
    input bit       irq_global_enable,
    input bit [1:0] multi_error_event
  );
    option.per_instance = 1;

    cp_fe_error_source: coverpoint error_source iff (source_valid) {
      bins unsupported_req  = {4'd0};
      bins unsupported_rwd  = {4'd1};
      bins poison_received  = {4'd2};
      bins parity_error_req = {4'd3};
      bins parity_error_rwd = {4'd4};
      bins req_fifo_ovf     = {4'd5};
      bins rwd_fifo_ovf     = {4'd6};
      bins hdm_miss         = {4'd7};
      bins permission_error = {4'd8};
      bins tag_range_error  = {4'd9};
      bins eg_queue_ovf     = {4'd10};
      bins drs_credit_ovf   = {4'd11};
      bins ndr_credit_ovf   = {4'd12};
      bins mem_ded          = {4'd13};
    }

    // Event encoding is generated by sample_error_interrupt():
    //   1 = at least three error-status bits active together
    //   2 = exactly one previously-active bit cleared while others remain
    cp_fe_multi_error: coverpoint multi_error_event
      iff (multi_error_event != 2'd0) {
      bins three_or_more_simultaneous = {2'd1};
      bins cleared_one_at_a_time      = {2'd2};
    }

    cp_fe_source_irq_enable: coverpoint source_irq_enable iff (source_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_global_irq_enable: coverpoint irq_global_enable iff (source_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cr_fe_irqen_x_global: cross cp_fe_error_source,
                                  cp_fe_source_irq_enable,
                                  cp_fe_global_irq_enable;
  endgroup : cg_fe_error_interrupt

  extern function new(string name = "kb_fwd_eng_coverage",
                      uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);
  extern function void reset_config_shadow();
  extern task apb();
  extern task cxl_configure();
  extern task axi_configure();
  //extern function void sample_all_credits();
  extern function void sample_req_inputs(kb_cxl_m2s_snap snap);
  extern function void sample_rwd_inputs(kb_cxl_m2s_snap snap);
  extern function void sample_hdm_boundary(
    input bit is_write,
    input bit [45:0] hpa
  );
  extern function void sample_ndr_outputs(kb_cxl_s2m_snap snap);
  extern function void sample_drc_outputs(kb_cxl_s2m_snap snap);
  extern function bit calculate_req_parity_error(kb_cxl_m2s_snap snap,
                                                 int unsigned lane);
  extern function bit calculate_rwd_parity_error(kb_cxl_m2s_snap snap,
                                                 int unsigned lane);
  extern function bit calculate_ndr_parity_error(kb_cxl_s2m_snap snap,
                                                 int unsigned lane);
  extern function bit calculate_drs_parity_error(kb_cxl_s2m_snap snap,
                                                 int unsigned lane);
  extern task apb_configure(kb_apb3_vendor_txn_t txn);
  extern function void convert_to_aw(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_ar(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_w(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_b(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_r(kb_axi4_vendor_txn_t txn);
  extern function void sample_error_interrupt(bit [19:0] status_value);
  extern function void sample_credit_manager_fsm(
    bit rst_n,
    bit mst_req,
    bit mst_ack,
    bit slv_req,
    bit slv_ack
  );
  extern function void sample_credit_count(
    bit          is_ingress,
    int unsigned count
  );
  extern task sample_credit_counters_from_regblock();
  extern task sample_hdm_region_counters_from_regblock();
  extern task sample_dcd_ecc_counters_from_regblock();
  extern task sample_egress_backpressure_from_regblock();
  extern task peek_hdm_region_counter(
    input uvm_reg msb_reg,
    input uvm_reg lsb_reg,
    output bit sample_valid,
    output bit [63:0] counter_value
  );
  extern task sample_scoreboard_items();
  extern function void sample_hdm_event(input hdm_cov_event_t sample_data);
  extern function void queue_hdm_tag(input bit is_write, input hdm_tag_result_t tag_result);
  extern function void queue_hdm_axi(input bit is_write,
                                   input bit [7:0] size, input bit [7:0] len);
  extern function void sample_pending_hdm_pairs(input bit is_write);
  extern function void reset_hdm_tag_queues();

endclass : kb_fwd_eng_coverage

function kb_fwd_eng_coverage::new(
  string name = "kb_fwd_eng_coverage",
  uvm_component parent = null
);
  super.new(name, parent);

  //SB to Coverage fifo
  cov_fifo         = new("cov_fifo", this);

  //Coverage sequence item handle
  h_cov_seq_items = kb_fwd_eng_cov_seq_item::type_id::create("h_cov_seq_items");

  //apb_fifo
  apb_fifo         = new("h_apb_fifo", this);

  //cxl_fifo's
  cxl_m2s_bus_fifo = new("h_cxl_m2s", this);
  cxl_s2m_bus_fifo = new("h_cxl_s2m", this);

  //axi fifo's
  address_fifo    = new("address_fifo", this);
  w_fifo          = new("w_fifo", this);
  resp_fifo       = new("resp_fifo", this);

  //cover groups
  cg_fe_cxl_parser_req             = new();
  cg_fe_cxl_parser_rwd             = new();
  cg_fe_cxl_encap_drs         = new();
  cg_fe_cxl_encap_ndr         = new();
  cg_fe_cxl_parser_combining              = new();
  cg_fe_apb_registers             = new();
  cg_fe_credit_manager                 = new();
  cg_fe_axi_requestor_aw                 = new();
  cg_fe_axi_requestor_w                  = new();
  cg_fe_axi_requestor_parity      = new();
  cg_fe_axi_requestor_error       = new();
  cg_fe_hdm_decoder_rd            = new();
  cg_fe_hdm_decoder_wr            = new();
  cg_fe_axi_responder                    = new();
  cg_fe_error_interrupt                  = new();
  cg_fe_axi_requestor_ar                 = new();
  cg_fe_tag_fifo                         = new();
  cg_fe_egress_queue                     = new();

  reset_seen = 1'b0;
  fe_error_status_prev       = '0;
  fe_error_status_prev_valid = 1'b0;
  credit_egress_state        = 3'd0;
  credit_ingress_state       = 3'd0;
  reset_config_shadow();

  // Record architectural defaults even when a test performs no APB writes.
  cg_fe_apb_registers.sample();
endfunction : new

function void kb_fwd_eng_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (!uvm_config_db#(kb_fwd_eng_env_cfg)::get(this, "", "env_cfg", h_env_cfg))
    `uvm_fatal(get_type_name(), "Missing env_cfg; cannot sample credit counters from the RAL model")

  if (!h_env_cfg.has_regblock_en || h_env_cfg.h_regblock == null)
    `uvm_fatal(get_type_name(), "RAL model is disabled or h_regblock is null")
endfunction : build_phase

function void kb_fwd_eng_coverage::reset_config_shadow();
  reset_hdm_tag_queues();
  write_backpressure_seen = 1'b0;
  read_backpressure_seen = 1'b0;
  write_fill_class_prev = '0;
  read_fill_class_prev = '0;
  foreach (dcd_sec_count_prev[i]) begin
    dcd_sec_count_prev[i] = '0;
    dcd_ded_count_prev[i] = '0;
    dcd_sec_count_seen[i] = 1'b0;
    dcd_ded_count_seen[i] = 1'b0;
  end
  hdm_rd_region_count_q.delete();
  hdm_wr_region_count_q.delete();
  foreach (reg_hpa_base[i]) begin
    reg_hpa_base[i] = '0;
    reg_hpa_top[i]  = '0;
    reg_dpa_base[i] = '0;
    hdm_rd_region_count_q.push_back(64'd0);
    hdm_wr_region_count_q.push_back(64'd0);
  end
  req_order_known = 1'b0;
  rwd_order_known = 1'b0;
  req_comb_snapshot_sample = 1'b0;
  req_order_pair_sample = 1'b0;
  rwd_order_pair_sample = 1'b0;
  flit_mode_inst                       = 1'b1;
  combining_rd_enable_inst             = 1'b1;
  combining_wr_enable_inst             = 1'b1;
  unsupported_opcode_check_enable_inst = 1'b1;
  unsupported_field_check_enable_inst  = 1'b1;
  tag_range_check                     = 1'b0;
  poison_crc_invert_enable_inst        = 1'b1;
  nxm_enable                           = 1'b0;
  poison_enable                        = 1'b0;
  fe_error_status_inst                 = '0;
  fe_error_status_prev                 = '0;
  fe_error_status_prev_valid           = 1'b0;
  credit_egress_state                  = 3'd0;
  credit_ingress_state                 = 3'd0;

  foreach (req_seen_valid[i]) begin
    req_seen_valid[i] = 1'b0;
    req_gap_cycles[i] = 0;
  end
endfunction : reset_config_shadow

task kb_fwd_eng_coverage::run_phase(uvm_phase phase);
  fork
    apb();
    cxl_configure();
    axi_configure();
    sample_scoreboard_items();
  join_none
endtask : run_phase

task kb_fwd_eng_coverage::apb();
  forever begin
    kb_apb3_vendor_txn_t  h_apb_txns;

    apb_fifo.get(h_apb_txns);
    apb_configure(h_apb_txns);
  end
endtask : apb

task kb_fwd_eng_coverage::cxl_configure();
  forever begin
    kb_cxl_m2s_snap       h_cxl_m2s_items;
    kb_cxl_s2m_snap       h_cxl_s2m_items;

    cxl_m2s_bus_fifo.get(h_cxl_m2s_items);
    cxl_s2m_bus_fifo.get(h_cxl_s2m_items);

    sample_credit_manager_fsm(
      h_cxl_m2s_items.rst_n,
      h_cxl_m2s_items.mst_req,
      h_cxl_m2s_items.mst_ack,
      h_cxl_s2m_items.slv_req,
      h_cxl_s2m_items.slv_ack
    );

    if (!h_cxl_m2s_items.rst_n) begin
      if (!reset_seen) begin
        reset_config_shadow();
        cg_fe_apb_registers.sample();
        reset_seen = 1'b1;
      end
      // Synchronize rotation pointers on reset; both helpers return without
      // sampling packet or combining coverpoints while rst_n is low.
      sample_req_inputs(h_cxl_m2s_items);
      sample_rwd_inputs(h_cxl_m2s_items);
      continue;
    end

    reset_seen = 1'b0;
    sample_credit_counters_from_regblock();
    sample_hdm_region_counters_from_regblock();
    sample_dcd_ecc_counters_from_regblock();
    sample_egress_backpressure_from_regblock();
    sample_req_inputs(h_cxl_m2s_items);
    sample_rwd_inputs(h_cxl_m2s_items);
    sample_ndr_outputs(h_cxl_s2m_items);
    sample_drc_outputs(h_cxl_s2m_items);
  end
endtask : cxl_configure

// Read the live hardware values through the generated register model's RTL
// backdoor. This observes the counters without adding APB traffic or depending
// on software to read the volatile RO registers first.
task kb_fwd_eng_coverage::sample_credit_counters_from_regblock();
  uvm_status_e   status;
  uvm_reg_data_t count;

  h_env_cfg.h_regblock.credit_manager_debug.m2s_req_crd_cnt.peek(
    status, count, "RTL"
  );
  if (status == UVM_IS_OK)
    sample_credit_count(1'b0, int'(count));

  h_env_cfg.h_regblock.credit_manager_debug.m2s_rwd_crd_cnt.peek(
    status, count, "RTL"
  );
  if (status == UVM_IS_OK)
    sample_credit_count(1'b0, int'(count));

  h_env_cfg.h_regblock.credit_manager_debug.s2m_ndr_crd_cnt0.peek(
    status, count, "RTL"
  );
  if (status == UVM_IS_OK)
    sample_credit_count(1'b1, int'(count));

  h_env_cfg.h_regblock.credit_manager_debug.s2m_ndr_crd_cnt1.peek(
    status, count, "RTL"
  );
  if (status == UVM_IS_OK)
    sample_credit_count(1'b1, int'(count));

  h_env_cfg.h_regblock.credit_manager_debug.s2m_drs_crd_cnt.peek(
    status, count, "RTL"
  );
  if (status == UVM_IS_OK)
    sample_credit_count(1'b1, int'(count));
endtask : sample_credit_counters_from_regblock

// Read a coherent 64-bit counter through the same RTL backdoor used by
// sample_credit_counters_from_regblock(). No APB read side effects are applied.
task kb_fwd_eng_coverage::peek_hdm_region_counter(
  input uvm_reg msb_reg,
  input uvm_reg lsb_reg,
  output bit sample_valid,
  output bit [63:0] counter_value
);
  uvm_status_e status;
  uvm_reg_data_t msb_before;
  uvm_reg_data_t lsb;
  uvm_reg_data_t msb_after;

  sample_valid = 1'b0;
  counter_value = '0;
  if (msb_reg == null || lsb_reg == null) return;

  // Retry if low-half rollover changes the MSB between peeks.
  for (int attempt = 0; attempt < 3; attempt++) begin
    msb_reg.peek(status, msb_before, "RTL");
    if (status != UVM_IS_OK || $isunknown(msb_before[31:0])) return;

    lsb_reg.peek(status, lsb, "RTL");
    if (status != UVM_IS_OK || $isunknown(lsb[31:0])) return;

    msb_reg.peek(status, msb_after, "RTL");
    if (status != UVM_IS_OK || $isunknown(msb_after[31:0])) return;

    if (msb_before[31:0] == msb_after[31:0]) begin
      counter_value = {msb_after[31:0], lsb[31:0]};
      sample_valid = 1'b1;
      return;
    end
  end
  // Leave sample_valid low; the next CXL snapshot will retry.
endtask : peek_hdm_region_counter

// Each queue entry is the last successfully observed count for its region.
// A nonzero first observation also hits, because reset initializes counts to 0.
// One sample records an observed increase, not every individual counted access.
task kb_fwd_eng_coverage::sample_hdm_region_counters_from_regblock();
  bit counter_valid;
  bit [63:0] counter_value;
  hdm_cov_event_t region_sample;

  if (reset_seen) return;
  foreach (reg_hpa_base[i]) begin
    peek_hdm_region_counter(
      h_env_cfg.h_regblock.hdm_decoder[i].rd_region_msb,
      h_env_cfg.h_regblock.hdm_decoder[i].rd_region_lsb,
      counter_valid,
      counter_value
    );
    if (reset_seen) return;
    if (counter_valid) begin
      if (counter_value > hdm_rd_region_count_q[i]) begin
        region_sample = '0;
        region_sample.is_write = 1'b0;
        region_sample.region_sample_valid = 1'b1;
        region_sample.region_index = i[3:0];
        sample_hdm_event(region_sample);
      end
      // A decrease re-establishes the baseline without inventing a new hit.
      hdm_rd_region_count_q[i] = counter_value;
    end

    peek_hdm_region_counter(
      h_env_cfg.h_regblock.hdm_decoder[i].wr_region_msb,
      h_env_cfg.h_regblock.hdm_decoder[i].wr_region_lsb,
      counter_valid,
      counter_value
    );
    if (reset_seen) return;
    if (counter_valid) begin
      if (counter_value > hdm_wr_region_count_q[i]) begin
        region_sample = '0;
        region_sample.is_write = 1'b1;
        region_sample.region_sample_valid = 1'b1;
        region_sample.region_index = i[3:0];
        sample_hdm_event(region_sample);
      end
      hdm_wr_region_count_q[i] = counter_value;
    end
  end
endtask : sample_hdm_region_counters_from_regblock

// Sample the first valid observation (including zero), then only changes.
// A nonzero value samples found; zero samples not-found.
// Indices 0/1 are AW LSB/MSB; indices 2/3 are AR LSB/MSB.
task kb_fwd_eng_coverage::sample_dcd_ecc_counters_from_regblock();
  uvm_status_e status;
  uvm_reg_data_t count;
  hdm_cov_event_t ecc_sample;

  if (reset_seen) return;
  for (int i = 0; i < 4; i++) begin
    h_env_cfg.h_regblock.fe_error_counters.dcd_sec_cnt[i].peek(
      status, count, "RTL"
    );
    if (reset_seen) return;
    if (status == UVM_IS_OK && !$isunknown(count[31:0])) begin
      if (!dcd_sec_count_seen[i] || count[31:0] != dcd_sec_count_prev[i]) begin
        ecc_sample = '0;
        ecc_sample.is_write = (i < 2);
        ecc_sample.ecc_sec_sample_valid = 1'b1;
        ecc_sample.ecc_half_msb = i[0];
        ecc_sample.ecc_found = (count[31:0] != 0);
        sample_hdm_event(ecc_sample);
      end
      dcd_sec_count_prev[i] = count[31:0];
      dcd_sec_count_seen[i] = 1'b1;
    end

    h_env_cfg.h_regblock.fe_error_counters.dcd_ded_cnt[i].peek(
      status, count, "RTL"
    );
    if (reset_seen) return;
    if (status == UVM_IS_OK && !$isunknown(count[31:0])) begin
      if (!dcd_ded_count_seen[i] || count[31:0] != dcd_ded_count_prev[i]) begin
        ecc_sample = '0;
        ecc_sample.is_write = (i < 2);
        ecc_sample.ecc_ded_sample_valid = 1'b1;
        ecc_sample.ecc_half_msb = i[0];
        ecc_sample.ecc_found = (count[31:0] != 0);
        sample_hdm_event(ecc_sample);
      end
      dcd_ded_count_prev[i] = count[31:0];
      dcd_ded_count_seen[i] = 1'b1;
    end
  end
endtask : sample_dcd_ecc_counters_from_regblock

// Sample live devload and each fill-level class on its first observation
// or when it moves into another bin.
task kb_fwd_eng_coverage::sample_egress_backpressure_from_regblock();
  uvm_status_e status;
  uvm_reg_data_t fill_level;
  bit write_valid;
  bit read_valid;
  bit [7:0] write_fill_level;
  bit [7:0] read_fill_level;
  bit [1:0] write_fill_class;
  bit [1:0] read_fill_class;

  if (reset_seen) return;
  write_valid = 1'b0;
  read_valid = 1'b0;
  write_fill_level = '0;
  read_fill_level = '0;

  h_env_cfg.h_regblock.egress_queue_registers.devload_congestion_threshold.peek(
    status, fill_level, "RTL"
  );
  if (reset_seen) return;
  if (status == UVM_IS_OK && !$isunknown(fill_level[3:0])) begin
    write_egress_queue_devload = fill_level[3:2];
    read_egress_queue_devload = fill_level[1:0];
    cg_fe_egress_queue.sample(1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
  end

  h_env_cfg.h_regblock.fifo_occupancy_register.egress_ar_w_aw_fill_level.egress_aw_fill_level.peek(
    status, fill_level, "RTL"
  );
  if (reset_seen) return;
  if (status == UVM_IS_OK && !$isunknown(fill_level[7:0])) begin
    write_fill_level = fill_level[7:0];
    write_fill_class = (write_fill_level == 0) ? 2'd0 :
                       (write_fill_level <= 8'd32) ? 2'd1 :
                       (write_fill_level < 8'd64) ? 2'd2 : 2'd3;
    write_valid = !write_backpressure_seen ||
                  (write_fill_class != write_fill_class_prev);
    write_fill_class_prev = write_fill_class;
    write_backpressure_seen = 1'b1;
  end

  h_env_cfg.h_regblock.fifo_occupancy_register.egress_ar_w_aw_fill_level.egress_ar_fill_level.peek(
    status, fill_level, "RTL"
  );
  if (reset_seen) return;
  if (status == UVM_IS_OK && !$isunknown(fill_level[7:0])) begin
    read_fill_level = fill_level[7:0];
    read_fill_class = (read_fill_level == 0) ? 2'd0 :
                      (read_fill_level <= 8'd32) ? 2'd1 :
                      (read_fill_level < 8'd64) ? 2'd2 : 2'd3;
    read_valid = !read_backpressure_seen ||
                 (read_fill_class != read_fill_class_prev);
    read_fill_class_prev = read_fill_class;
    read_backpressure_seen = 1'b1;
  end

  if (write_valid || read_valid)
    cg_fe_egress_queue.sample(
      1'b0, write_valid, read_valid, write_fill_level, read_fill_level
    );
endtask : sample_egress_backpressure_from_regblock

task kb_fwd_eng_coverage::axi_configure();
  fork
    forever begin
      kb_axi4_vendor_txn_t  h_axi_txns;
      
      address_fifo.get(h_axi_txns);
      if (h_axi_txns.Direction == DENALI_CDN_AXI_DIRECTION_WRITE)
        convert_to_aw(h_axi_txns);
      else
        convert_to_ar(h_axi_txns);
    end

    forever begin
      kb_axi4_vendor_txn_t  h_axi_txns;
      w_fifo.get(h_axi_txns);
      if (h_axi_txns.Direction == DENALI_CDN_AXI_DIRECTION_WRITE)
        convert_to_w(h_axi_txns);
    end

    forever begin
      kb_axi4_vendor_txn_t  h_axi_txns;
      resp_fifo.get(h_axi_txns);
      if (h_axi_txns.Direction == DENALI_CDN_AXI_DIRECTION_WRITE)
        convert_to_b(h_axi_txns);
      else
        convert_to_r(h_axi_txns);
    end
  join
endtask : axi_configure


//====================================================================
// TODO: Need to discuss how to get the credit counters from scoreboard
//====================================================================
//
//function void kb_fwd_eng_coverage::sample_all_credits();
//    // Sample M2S REQ (4 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_REQ; i++)
//      sample_credit_count(1'b0, exp_req_credits[i]);
//      
//    // Sample M2S RWD (2 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_RWD; i++)
//      sample_credit_count(1'b0, exp_rwd_credits[i]);
//      
//    // Sample S2M NDR (6 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_NDR; i++)
//      sample_credit_count(1'b1, exp_s2m_ndr_credits[i]);
//      
//    // Sample S2M DRC (2 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_DRC; i++)
//      sample_credit_count(1'b1, exp_s2m_drc_credits[i]);
//  endfunction

// The error flag is local to each call, so it starts clear for every packet.
// REQ is 100 bits; append four zero bits at the LSB to form 13 bytes,
// matching the updated CXL driver. Each check bit uses odd parity.
function bit kb_fwd_eng_coverage::calculate_req_parity_error(
  kb_cxl_m2s_snap snap,
  int unsigned lane
);
  bit parity_error;
  logic [KB_CXL_REQ_SIZE-1:0] req_packet;
  logic [(KB_CXL_REQ_CHK_SIZE*8)-1:0] req_padded;
  logic [KB_CXL_REQ_CHK_SIZE-1:0] received_parity;

  parity_error = 1'b0;
  req_packet = snap.m2s_req[lane*KB_CXL_REQ_SIZE +: KB_CXL_REQ_SIZE];
  req_padded = {req_packet, 4'b0000};
  received_parity = snap.m2s_req_chk[
    lane*KB_CXL_REQ_CHK_SIZE +: KB_CXL_REQ_CHK_SIZE
  ];

  for (int byte_idx = 0; byte_idx < KB_CXL_REQ_CHK_SIZE; byte_idx++) begin
    if ((~(^req_padded[byte_idx*8 +: 8])) !== received_parity[byte_idx])
      parity_error = 1'b1;
  end

  return parity_error;
endfunction : calculate_req_parity_error

function bit kb_fwd_eng_coverage::calculate_rwd_parity_error(
  kb_cxl_m2s_snap snap,
  int unsigned lane
);
  bit parity_error;
  logic [KB_CXL_RWD_SIZE-1:0] rwd_packet;
  logic [KB_CXL_RWD_CHK_SIZE-1:0] received_parity;

  parity_error = 1'b0;
  rwd_packet = snap.m2s_rwd[lane*KB_CXL_RWD_SIZE +: KB_CXL_RWD_SIZE];
  received_parity = snap.m2s_rwd_chk[
    lane*KB_CXL_RWD_CHK_SIZE +: KB_CXL_RWD_CHK_SIZE
  ];

  for (int byte_idx = 0; byte_idx < KB_CXL_RWD_CHK_SIZE; byte_idx++) begin
    if ((~(^rwd_packet[byte_idx*8 +: 8])) !== received_parity[byte_idx])
      parity_error = 1'b1;
  end

  return parity_error;
endfunction : calculate_rwd_parity_error

function bit kb_fwd_eng_coverage::calculate_ndr_parity_error(
  kb_cxl_s2m_snap snap,
  int unsigned lane
);
  bit parity_error;
  logic [KB_CXL_NDR_SIZE-1:0] ndr_packet;
  logic [KB_CXL_NDR_CHK_SIZE-1:0] received_parity;

  parity_error = 1'b0;
  ndr_packet = snap.s2m_ndr[lane*KB_CXL_NDR_SIZE +: KB_CXL_NDR_SIZE];
  received_parity = snap.s2m_ndr_chk[
    lane*KB_CXL_NDR_CHK_SIZE +: KB_CXL_NDR_CHK_SIZE
  ];

  for (int byte_idx = 0; byte_idx < KB_CXL_NDR_CHK_SIZE; byte_idx++) begin
    if ((~(^ndr_packet[byte_idx*8 +: 8])) !== received_parity[byte_idx])
      parity_error = 1'b1;
  end

  return parity_error;
endfunction : calculate_ndr_parity_error

function bit kb_fwd_eng_coverage::calculate_drs_parity_error(
  kb_cxl_s2m_snap snap,
  int unsigned lane
);
  bit parity_error;
  logic [KB_CXL_DRC_SIZE-1:0] drs_packet;
  logic [KB_CXL_DRC_CHK_SIZE-1:0] received_parity;

  parity_error = 1'b0;
  drs_packet = snap.s2m_drc[lane*KB_CXL_DRC_SIZE +: KB_CXL_DRC_SIZE];
  received_parity = snap.s2m_drc_chk[
    lane*KB_CXL_DRC_CHK_SIZE +: KB_CXL_DRC_CHK_SIZE
  ];

  for (int byte_idx = 0; byte_idx < KB_CXL_DRC_CHK_SIZE; byte_idx++) begin
    if ((~(^drs_packet[byte_idx*8 +: 8])) !== received_parity[byte_idx])
      parity_error = 1'b1;
  end

  return parity_error;
endfunction : calculate_drs_parity_error

// Classify one accepted CXL address against the programmed HDM regions.
// The comparison intentionally uses only HPA[51:28]. The CXL monitor supplies
// HPA[51:6], so hpa[45:22] is the matching 24-bit field. HPA[27:6] is ignored.
function void kb_fwd_eng_coverage::sample_hdm_boundary(
  input bit is_write,
  input bit [45:0] hpa
);
  hdm_cov_event_t boundary_sample;
  bit             classification_valid;
  bit [1:0]       classification;
  bit             excluded_candidate_valid;
  bit [23:0]      hpa_51_28;
  bit [23:0]      excluded_candidate_base;

  classification_valid     = 1'b0;
  classification           = '0;
  excluded_candidate_valid = 1'b0;
  hpa_51_28                 = hpa[45:22];
  excluded_candidate_base  = '0;

  // First priority: an exact base is included. This also handles an
  // adjacent handoff where one region's exclusive top is the next base.
  foreach (reg_hpa_base[i]) begin
    if (reg_hpa_top[i] > reg_hpa_base[i] &&
        hpa_51_28 == reg_hpa_base[i]) begin
      classification_valid = 1'b1;
      classification       = 2'd0;
      break;
    end
  end

  // Second priority: the final included HPA[51:28] value is top-1.
  // A one-unit region was already classified as its base above.
  if (!classification_valid) begin
    foreach (reg_hpa_base[i]) begin
      if (reg_hpa_top[i] > reg_hpa_base[i] &&
          hpa_51_28 == (reg_hpa_top[i] - 24'd1)) begin
        classification_valid = 1'b1;
        classification       = 2'd2;
        break;
      end
    end
  end

  // Third priority: a strict interior address. Base and top-1 are excluded
  // here because they have dedicated bins.
  if (!classification_valid) begin
    foreach (reg_hpa_base[i]) begin
      if (reg_hpa_top[i] > reg_hpa_base[i] &&
          hpa_51_28 > reg_hpa_base[i] &&
          hpa_51_28 < (reg_hpa_top[i] - 24'd1)) begin
        classification_valid = 1'b1;
        classification       = 2'd1;
        break;
      end
    end
  end

  // If the address did not belong to a region, associate it with the
  // nearest programmed region below it. This yields one excluded sample,
  // rather than one false sample for every lower-numbered region.
  if (!classification_valid) begin
    foreach (reg_hpa_base[i]) begin
      if (reg_hpa_top[i] > reg_hpa_base[i] &&
          hpa_51_28 >= reg_hpa_top[i] &&
          (!excluded_candidate_valid ||
           reg_hpa_base[i] > excluded_candidate_base)) begin
        excluded_candidate_valid = 1'b1;
        excluded_candidate_base  = reg_hpa_base[i];
      end
    end
    if (excluded_candidate_valid) begin
      classification_valid = 1'b1;
      classification       = 2'd3;
    end
  end

  if (classification_valid) begin
    boundary_sample                       = '0;
    boundary_sample.is_write              = is_write;
    boundary_sample.boundary_sample_valid = 1'b1;
    boundary_sample.boundary_class        = classification;
    sample_hdm_event(boundary_sample);
  end
endfunction : sample_hdm_boundary

function void kb_fwd_eng_coverage::sample_req_inputs(
  kb_cxl_m2s_snap snap
);
  int unsigned max_req_lanes;
  bit [3:0] current_mask;
  int unsigned ordered_lanes[4];
  int unsigned packet_count;
  int unsigned lane_base;

  // rst_n is active low. Discard partial gap history while reset is asserted.
  req_comb_snapshot_sample = 1'b0;
  if (!snap.rst_n) begin
    req_order_known = 1'b1;
    req_next_lane = 0;
    req_previous_count = 0;
    req_previous_four_lane = 1'b0;
    req_order_pair_sample = 1'b0;
    foreach (req_seen_valid[i]) begin
      req_seen_valid[i] = 1'b0;
      req_gap_cycles[i] = 0;
    end
    return;
  end

  max_req_lanes = flit_mode_inst ? 4 : 2;

  // Build the full current-cycle valid vector before any per-lane sampling.
  current_mask = '0;
  for (int i = 0; i < KB_CXL_MAX_NUM_REQ; i++) begin
    req_valid[i] = (i < max_req_lanes) ? snap.req_items[i].valid : 1'b0;
    if (i < 4) current_mask[i] = req_valid[i];
  end

  for (int i = 0; i < max_req_lanes; i++) begin
    bit gap_available;
    int unsigned gap_class;
    int unsigned req_concurrency = 0;

    gap_available = 1'b0;
    gap_class = 0;

    if (snap.req_items[i].valid) begin
      cg_fe_axi_requestor_parity.sample(
        1'b0, 1'b0, calculate_req_parity_error(snap, i)
      );
      gap_available = req_seen_valid[i];
      gap_class = req_gap_cycles[i];
      req_concurrency++;

      // 1. Populate the local arrays for the active lane
      
      req_valid[i]      = snap.req_items[i].valid;
      req_opcode[i]     = snap.req_items[i].opcode;
      req_snp_type[i]   = snap.req_items[i].snp_type;
      req_meta_field[i] = snap.req_items[i].meta_field;
      req_meta_value[i] = snap.req_items[i].meta_value;
      req_tag[i]        = snap.req_items[i].tag;
      req_hpa[i]        = snap.req_items[i].hpa;
      req_ld_id[i]      = snap.req_items[i].ld_id;

      sample_hdm_boundary(1'b0, req_hpa[i]);

      req_seen_valid[i] = 1'b1;
      req_gap_cycles[i] = 0;
    end else if (req_seen_valid[i] && req_gap_cycles[i] < 2) begin
      // This function is called for each CXL snapshot, so invalid snapshots
      // between requests accumulate the per-lane gap.
      req_gap_cycles[i]++;
    end

    // Sample every active lane each cycle so cp_valid sees both values.
    // Packet coverpoints/crosses are gated by req_valid inside the covergroup.
    cg_fe_cxl_parser_req.sample(
      i,
      req_valid[i],
      flit_mode_inst,
      req_opcode[i],
      req_snp_type[i],
      req_meta_field[i],
      req_meta_value[i],
      req_tag[i],
      req_hpa[i],
      req_ld_id[i],
      unsupported_opcode_check_enable_inst,
      unsupported_field_check_enable_inst,
      gap_available,
      gap_class,
      req_valid
    );
  end

  // Lanes 2 and 3 are inactive in 68B mode; don't carry history across modes.
  for (int i = max_req_lanes; i < KB_CXL_MAX_NUM_REQ; i++) begin
    req_seen_valid[i] = 1'b0;
    req_gap_cycles[i] = 0;
  end

  // The driver starts at req_lane_ptr % num_req, skips credit-starved
  // lanes, and advances its pointer after each actual packet.
  if (req_order_known) begin
    lane_base = req_next_lane % max_req_lanes;
    packet_count = 0;
    for (int k = 0; k < max_req_lanes; k++) begin
      int unsigned lane;
      lane = (lane_base + k) % max_req_lanes;
      if (current_mask[lane]) begin
        ordered_lanes[packet_count] = lane;
        packet_count++;
        req_next_lane = (lane + 1) % max_req_lanes;
      end
    end

    if (packet_count != 0) begin
      req_cycle_start = ordered_lanes[0];
      req_partial_previous = req_previous_four_lane &&
                             req_previous_count inside {[1:3]};

      // Exactly one order sample per nonempty four-lane REQ snapshot.
      // Legacy points are gated off for this bookkeeping call.
      if (max_req_lanes == 4) begin
        req_comb_snapshot_sample = 1'b1;
        cg_fe_cxl_parser_combining.sample(
          1'b0, combining_rd_enable_inst, combining_wr_enable_inst,
          3'd0, 1'b0, 1'b0, 1'b0);
        req_comb_snapshot_sample = 1'b0;
      end

      // Visit physical adjacent pairs in order, but never last -> first.
      // Invalid lanes remain visible to the existing incomplete-pair bins.
      for (int k = 0; k < max_req_lanes - 1; k++) begin
        int unsigned i;
        int unsigned j;
        bit pair_present;
        bit aligned;
        bit contiguous;
        i = (req_cycle_start + k) % max_req_lanes;
        j = (i + 1) % max_req_lanes;
        // Existing 68B plan contains only Req 0->1.
        if (max_req_lanes == 2 && i != 0) continue;
        pair_present = current_mask[i] && current_mask[j];
        aligned = pair_present && !snap.req_items[i].hpa[0];
        contiguous = pair_present &&
          (snap.req_items[j].hpa == (snap.req_items[i].hpa + 46'd1));

        req_order_pair_sample = (max_req_lanes == 4);
        if (current_mask[i] || current_mask[j])
          cg_fe_cxl_parser_combining.sample(
            1'b0, combining_rd_enable_inst, combining_wr_enable_inst,
            i, pair_present, aligned, contiguous);
        req_order_pair_sample = 1'b0;
      end
    end
    // Idle snapshots break the "immediately previous cycle was partial" test.
    req_previous_count = packet_count;
    req_previous_four_lane = (max_req_lanes == 4);
  end
endfunction : sample_req_inputs

function void kb_fwd_eng_coverage::sample_rwd_inputs(
  kb_cxl_m2s_snap snap
);
  int unsigned max_rwd_lanes;
  int unsigned packet_count;
  int unsigned lane_base;

  // rst_n is active low. Discard partial gap history while reset is asserted.
  rwd_order_pair_sample = 1'b0;
  if (!snap.rst_n) begin
    rwd_order_known = 1'b1;
    rwd_next_lane = 0;
    rwd_previous_count = 0;
    rwd_previous_two_lane = 1'b0;
    foreach (rwd_seen_valid[i]) begin
      rwd_seen_valid[i] = 1'b0;
      rwd_gap_cycles[i] = 0;
    end
    return;
  end

  max_rwd_lanes = flit_mode_inst ? 2 : 1;

  for (int i = 0; i < KB_CXL_MAX_NUM_RWD; i++)
    rwd_valid[i] = (i < max_rwd_lanes) ? snap.rwd_items[i].valid : 1'b0;

  for (int i = 0; i < KB_CXL_MAX_NUM_RWD; i++) begin

    bit rwd_gap_available;
    int unsigned rwd_gap_class;
    int unsigned rwd_concurrency = 0;

    rwd_gap_available = 1'b0;
    rwd_gap_class = 0;

    if (rwd_valid[i]) begin
      cg_fe_axi_requestor_parity.sample(
        1'b0, 1'b1, calculate_rwd_parity_error(snap, i)
      );
      rwd_gap_available = rwd_seen_valid[i];
      rwd_gap_class = rwd_gap_cycles[i];
      rwd_concurrency++;
      // 1. Populate the local arrays for the active lane
      rwd_valid[i]      = snap.rwd_items[i].valid;
      rwd_opcode[i]     = snap.rwd_items[i].opcode;
      rwd_snp_type[i]   = snap.rwd_items[i].snp_type;
      rwd_meta_field[i] = snap.rwd_items[i].meta_field;
      rwd_meta_value[i] = snap.rwd_items[i].meta_value;
      rwd_tag[i]        = snap.rwd_items[i].tag;
      rwd_hpa[i]        = snap.rwd_items[i].hpa;
      rwd_ld_id[i]      = snap.rwd_items[i].ld_id;
      rwd_poison[i]     = snap.rwd_items[i].poison;

      sample_hdm_boundary(1'b1, rwd_hpa[i]);
      
      // Note: rwd_data and byte_enable are populated here for completeness, 
      // even if cg_fe_cxl_parser_rwd does not currently sample them.
      rwd_data[i]       = snap.rwd_items[i].wdata;
      byte_enable[i]    = snap.rwd_items[i].byte_enable;

      // 2. Sample the covergroup using the local array variables
      cg_fe_cxl_parser_rwd.sample(
        i,
        rwd_valid[i],
        flit_mode_inst,
        rwd_opcode[i],
        rwd_snp_type[i],
        rwd_meta_field[i],
        rwd_meta_value[i],
        rwd_tag[i],
        rwd_hpa[i],
        rwd_ld_id[i],
        rwd_poison[i],
        rwd_data[i],
        byte_enable[i],
        unsupported_opcode_check_enable_inst,
        unsupported_field_check_enable_inst,
        poison_crc_invert_enable_inst,
        rwd_valid
      );
    end
  end

  if (rwd_order_known) begin
    packet_count = 0;
    lane_base = rwd_next_lane % max_rwd_lanes;
    for (int k = 0; k < max_rwd_lanes; k++) begin
      int unsigned lane;
      lane = (lane_base + k) % max_rwd_lanes;
      if (rwd_valid[lane]) begin
        if (packet_count == 0) rwd_cycle_start = lane;
        packet_count++;
        rwd_next_lane = (lane + 1) % max_rwd_lanes;
      end
    end

    if (max_rwd_lanes == 2 && packet_count != 0) begin
      int unsigned i;
      int unsigned j;
      bit pair_present;
      bit aligned;
      bit contiguous;

      rwd_partial_previous = rwd_previous_two_lane &&
                             (rwd_previous_count == 1);
      // Bookkeeping sample, gated out of all legacy pair coverpoints.
      req_comb_snapshot_sample = 1'b1;
      cg_fe_cxl_parser_combining.sample(
        1'b1, combining_rd_enable_inst, combining_wr_enable_inst,
        3'd4, 1'b0, 1'b0, 1'b0);
      req_comb_snapshot_sample = 1'b0;

      i = rwd_cycle_start;
      j = (i + 1) % 2;
      pair_present = rwd_valid[i] && rwd_valid[j];
      aligned = pair_present && !snap.rwd_items[i].hpa[0];
      contiguous = pair_present &&
        (snap.rwd_items[j].hpa == (snap.rwd_items[i].hpa + 46'd1));
      // Only first -> second in THIS snapshot; never previous-cycle HPA.
      rwd_order_pair_sample = 1'b1;
      cg_fe_cxl_parser_combining.sample(
        1'b1, combining_rd_enable_inst, combining_wr_enable_inst,
        (i == 0) ? 3'd4 : 3'd5, pair_present, aligned, contiguous);
      rwd_order_pair_sample = 1'b0;
    end
    rwd_previous_count = packet_count;
    rwd_previous_two_lane = (max_rwd_lanes == 2);
  end
endfunction : sample_rwd_inputs
/*
function void kb_fwd_eng_coverage::sample_ndr_outputs(kb_cxl_s2m_snap snap);
  for (int i = 0; i < KB_CXL_MAX_NUM_NDR; i++) begin
    if (snap.ndr_items[i].valid) begin
      cg_fe_cxl_encap_ndr.sample(
        i,
        snap.ndr_items[i].s2m_ndr_opcode,
        snap.ndr_items[i].s2m_meta_field,
        snap.ndr_items[i].s2m_meta_value,
        snap.ndr_items[i].s2m_tag,
        snap.ndr_items[i].s2m_ld_id,
        snap.ndr_items[i].s2m_dev_load
      );
    end
  end
endfunction : sample_ndr_outputs
*/
function void kb_fwd_eng_coverage::sample_ndr_outputs(kb_cxl_s2m_snap snap);
  int unsigned max_ndr_lanes;

  // Set the active lane count based on the current flit mode
  max_ndr_lanes = flit_mode_inst ? KB_CXL_MAX_NUM_NDR : 2; // MAX_NUM = 6

  for (int i = 0; i < max_ndr_lanes; i++) begin
    if (snap.ndr_items[i].valid) begin
      cg_fe_axi_requestor_parity.sample(
        1'b1, 1'b0, calculate_ndr_parity_error(snap, i)
      );
      // 1. Populate the local arrays for the active NDR lane
      ndr_opcode[i]     = snap.ndr_items[i].s2m_ndr_opcode;
      ndr_meta_field[i] = snap.ndr_items[i].s2m_meta_field;
      ndr_meta_value[i] = snap.ndr_items[i].s2m_meta_value;
      ndr_tag[i]        = snap.ndr_items[i].s2m_tag;
      ndr_ld_id[i]      = snap.ndr_items[i].s2m_ld_id;
      ndr_dev_load[i]   = snap.ndr_items[i].s2m_dev_load;

      // 2. Sample the covergroup using the local array variables
      cg_fe_cxl_encap_ndr.sample(
        i,
        ndr_opcode[i],
        ndr_meta_field[i],
        ndr_meta_value[i],
        ndr_tag[i],
        ndr_ld_id[i],
        ndr_dev_load[i]
      );
    end
  end
endfunction : sample_ndr_outputs


function void kb_fwd_eng_coverage::sample_drc_outputs(kb_cxl_s2m_snap snap);
  for (int i = 0; i < KB_CXL_MAX_NUM_DRC; i++) begin
    if (snap.drc_items[i].valid) begin
      cg_fe_axi_requestor_parity.sample(
        1'b1, 1'b1, calculate_drs_parity_error(snap, i)
      );
      // 1. Populate the local arrays for the active DRC lane
      drc_opcode[i]     = snap.drc_items[i].s2m_drc_opcode;
      drc_meta_field[i] = snap.drc_items[i].s2m_meta_field;
      drc_meta_value[i] = snap.drc_items[i].s2m_meta_value;
      drc_tag[i]        = snap.drc_items[i].s2m_tag;
      drc_poison[i]     = snap.drc_items[i].s2m_poison;
      drc_ld_id[i]      = snap.drc_items[i].s2m_ld_id;
      drc_dev_load[i]   = snap.drc_items[i].s2m_dev_load;
      drc_data[i]       = snap.drc_items[i].s2m_data;

      // 2. Sample the covergroup using the local array variables, 
      // explicitly passing the lane index 'i' as the first argument[cite: 2]
      cg_fe_cxl_encap_drs.sample(
        i,
        drc_opcode[i],
        drc_meta_field[i],
        drc_meta_value[i],
        drc_tag[i],
        drc_poison[i],
        drc_ld_id[i],
        drc_dev_load[i],
        drc_data[i]
      );
    end
  end
endfunction : sample_drc_outputs

function void kb_fwd_eng_coverage::sample_credit_manager_fsm(
  bit rst_n,
  bit mst_req,
  bit mst_ack,
  bit slv_req,
  bit slv_ack
);
  if (!rst_n) begin
    credit_egress_state  = 3'd0;
    credit_ingress_state = 3'd0;
  end else begin

    // Egress: distinguish INIT from DEINIT_SLV using state history.
    case ({mst_req, mst_ack})
      2'b00: credit_egress_state = 3'd0; // IDLE
      2'b11: credit_egress_state = 3'd2; // RUN
      2'b01: credit_egress_state = 3'd3; // DEINIT_MST

      2'b10: begin
        if (credit_egress_state inside {3'd2, 3'd4})
          credit_egress_state = 3'd4;    // DEINIT_SLV
        else
          credit_egress_state = 3'd1;    // INIT
      end
    endcase

    // Ingress: use its own state history.
    case ({slv_req, slv_ack})
      2'b00: credit_ingress_state = 3'd0; // IDLE
      2'b11: credit_ingress_state = 3'd2; // RUN
      2'b01: credit_ingress_state = 3'd3; // DEINIT_MST

      2'b10: begin
        if (credit_ingress_state inside {3'd2, 3'd4})
          credit_ingress_state = 3'd4;    // DEINIT_SLV
        else
          credit_ingress_state = 3'd1;    // INIT
      end
    endcase
  end

  cg_fe_credit_manager.sample(
    1'b1,                  // fsm_sample_valid
    credit_egress_state,
    credit_ingress_state,
    1'b0,                  // credit_sample_valid
    1'b0,                  // credit_is_ingress
    0,                     // credit_count
    1'b0,                  // overflow_sample_valid
    2'd0,                  // credit_overflow_src
    1'b0                   // credit_overflow_irq_en
  );
endfunction : sample_credit_manager_fsm

// Call this method from the RTL-probe or scoreboard path for every observed
// ingress/egress credit counter. The current CXL snapshots do not carry the
// counter values themselves.
function void kb_fwd_eng_coverage::sample_credit_count(
  bit          is_ingress,
  int unsigned count
);
  cg_fe_credit_manager.sample(
    1'b0,
    credit_egress_state,
    credit_ingress_state,
    1'b1,
    is_ingress,
    count,
    1'b0,
    2'd0,
    1'b0
  );
endfunction : sample_credit_count

function void kb_fwd_eng_coverage::sample_error_interrupt(
  bit [19:0] status_value
);
  bit [1:0] multi_error_event;

  multi_error_event = 2'd0;

  if ($countones(status_value) >= 3) begin
    multi_error_event = 2'd1;
  end else if (fe_error_status_prev_valid &&
               ($countones(fe_error_status_prev) > 1) &&
               ($countones(fe_error_status_prev & ~status_value) == 1) &&
               ((status_value & ~fe_error_status_prev) == '0)) begin
    multi_error_event = 2'd2;
  end

  // Multi-error behavior is sampled once for each status observation.
  cg_fe_error_interrupt.sample(
    1'b0,
    4'd0,
    1'b0,
    interrupt_enables_inst[18],
    multi_error_event
  );

  // Sample every asserted physical status bit. Related read/write and checker
  // status bits map into the logical error-source categories in the plan.
  for (int unsigned i = 0; i < 20; i++) begin
    bit       mapped;
    bit [3:0] source;
    int unsigned irq_idx;

    mapped = 1'b1;
    source = '0;
    irq_idx = i;

    case (i)
      0, 1:  source = 4'd7;   // HDM miss
      2, 3:  source = 4'd8;   // Permission error
      4, 5:  source = 4'd9;   // Tag-range error
      6:     source = 4'd0;   // Unsupported Req
      7:     source = 4'd1;   // Unsupported RwD
      8:     source = 4'd2;   // Poison received
      9, 11: source = 4'd3;   // Req/read-path parity error
      10,12: source = 4'd4;   // RwD/write-path parity error
      16: begin source = 4'd12; irq_idx = 15; end // NDR credit overflow
      17: begin source = 4'd11; irq_idx = 16; end // DRS credit overflow
      18: begin source = 4'd13; irq_idx = 17; end // Memory/DCD DED
      // Bits 13..15 are RD/AW/W queue thresholds, not queue overflows.
      // Bit 19 has no dedicated IRQ-enable field or logical error-source bin
      // in this coverage model; do not invent an interrupt mapping for it.
      default: mapped = 1'b0;
    endcase

    if (status_value[i] && mapped) begin
      cg_fe_error_interrupt.sample(
        1'b1,
        source,
        interrupt_enables_inst[irq_idx],
        interrupt_enables_inst[18],
        2'd0
      );

      // The current status register exposes the S2M NDR/DRS credit-overflow
      // sources. M2S Req/RwD overflow sources require additional probes.
      if (i == 16 || i == 17) begin
        cg_fe_credit_manager.sample(
          1'b0,
          credit_egress_state,
          credit_ingress_state,
          1'b0,
          1'b0,
          0,
          1'b1,
          (i == 16) ? 2'd2 : 2'd3,
          interrupt_enables_inst[irq_idx]
        );
      end
    end
  end

  fe_error_status_inst       = status_value;
  fe_error_status_prev       = status_value;
  fe_error_status_prev_valid = 1'b1;
endfunction : sample_error_interrupt

task kb_fwd_eng_coverage::apb_configure(
  kb_apb3_vendor_txn_t txn
);
  int unsigned idx;
  int unsigned offset;

  // These flags describe only the APB transaction being sampled.
  is_hdm_update = 1'b0;
  wr_reset_token = 1'b0;
  rd_reset_token = 1'b0;

  if (txn.Direction == DENALI_CDN_APB_DIRECTION_READ) begin
    case (txn.Addr)
      'h81028: begin
      write_egress_queue_devload = txn.Data[3:2];
      read_egress_queue_devload  = txn.Data[1:0];

      cg_fe_egress_queue.sample(1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    end

      'h80a00: begin // fe_error_status: 20 bits, read-clear
        sample_error_interrupt(txn.Data[19:0]);
        cg_fe_apb_registers.sample();
        // The returned value has been covered; do not replay it on writes.
        fe_error_status_inst = '0;
      end
      'h80600: begin // cxl_mem_mst_req: software read-only
        mst_req = txn.Data[0];
        cg_fe_apb_registers.sample();
      end
      'h80604: begin // cxl_mem_mst_ack: hardware/software writable
        mst_ack = txn.Data[0];
        cg_fe_apb_registers.sample();
      end
      default: begin end
    endcase
    return;
  end

  if (txn.Direction != DENALI_CDN_APB_DIRECTION_WRITE)
    return;

  // Region i starts at 0x80300 + i*0x1C.
  // +00 HPA base, +04 HPA top, +08 DPA base: writable, 24-bit shadows.
  // +0C/+10 RD MSB/LSB, +14/+18 WR MSB/LSB: read-only counters,
  // captured through the region-counter peek task rather than APB writes.
  if (txn.Addr >= 'h80300 &&
      txn.Addr < ('h80300 + 10 * 'h1c)) begin
    idx    = (txn.Addr - 'h80300) / 'h1c;
    offset = (txn.Addr - 'h80300) % 'h1c;

    case (offset)
      'h00: reg_hpa_base[idx] = txn.Data[23:0];
      'h04: reg_hpa_top[idx]  = txn.Data[23:0];
      'h08: reg_dpa_base[idx] = txn.Data[23:0];
      default: return; // Read-only counters or unaligned addresses
    endcase

    is_hdm_update    = 1'b1;
    current_hdm_idx  = idx;
    current_hpa_base = reg_hpa_base[idx];
    current_hpa_top  = reg_hpa_top[idx];
    current_dpa_base = reg_dpa_base[idx];
    cg_fe_apb_registers.sample();
    is_hdm_update = 1'b0;
    return;
  end

  case (txn.Addr)
    'h80100: tag_range_check = txn.Data[0]; // dcd_control.tag_enable

    'h80500: begin // cxl_parser_control
      flit_mode_inst           = txn.Data[0];
      combining_rd_enable_inst = txn.Data[1];
      combining_wr_enable_inst = txn.Data[2];
    end

    'h80604: mst_ack = txn.Data[0];

    'h80800: begin // fe_datapath_control
      unsupported_opcode_check_enable_inst = txn.Data[0];
      unsupported_field_check_enable_inst  = txn.Data[1];
      poison_crc_invert_enable_inst         = txn.Data[2];
    end

    'h80b00: interrupt_enables_inst = txn.Data[18:0];

    // Each token-bucket field occupies a separate register.
    'h80c00: wr_refill_period = txn.Data[15:0];
    'h80c04: wr_refill_rate   = txn.Data[4:0];
    'h80c08: wr_capacity      = txn.Data[15:0];
    'h80c0c: wr_reset_token   = txn.Data[0];

    'h80d00: rd_refill_period = txn.Data[15:0];
    'h80d04: rd_refill_rate   = txn.Data[4:0];
    'h80d08: rd_capacity      = txn.Data[15:0];
    'h80d0c: rd_reset_token   = txn.Data[0];

    'h80e00: begin // cxl_encap_control
      mem_app_pending_enable = txn.Data[0];
      nxm_enable             = txn.Data[1];
      poison_enable          = txn.Data[2];
    end

    default: return; // No existing shadow coverage for this address
  endcase

  cg_fe_apb_registers.sample();

  // reset_token is a singlepulse command, not a persistent setting.
  wr_reset_token = 1'b0;
  rd_reset_token = 1'b0;
endtask : apb_configure


// ---------------------------------------------------------------------------
// AXI Denali VIP to Local Struct Conversions & Sampling
// ---------------------------------------------------------------------------
function void kb_fwd_eng_coverage::convert_to_aw(kb_axi4_vendor_txn_t txn);
  if (txn.Direction == DENALI_CDN_AXI_DIRECTION_WRITE) begin
    aw.valid = 1'b1;
    aw.addr  = txn.StartAddress;
    aw.len   = txn.Alen;
    aw.size  = txn.Size - 1;
    aw.id    = txn.IdTag;
    
    aw.user = '0;
    foreach (txn.Auser[i]) begin
      aw.user[(i * 32) +: 32] = txn.Auser[i];
    end
    
    cg_fe_axi_requestor_aw.sample();

    hdm_sample = '0;
    hdm_sample.axi_valid = 1'b1;
    hdm_sample.is_write  = 1'b1;
    hdm_sample.axi_id    = aw.id[1:0];
    sample_hdm_event(hdm_sample);
    queue_hdm_axi(1'b1, aw.size, aw.len);

    //For aw_id covergroup
    cg_fe_tag_fifo.sample(1'b1, txn.IdTag);
  end
endfunction : convert_to_aw

function void kb_fwd_eng_coverage::convert_to_ar(kb_axi4_vendor_txn_t txn);
  if (txn.Direction == DENALI_CDN_AXI_DIRECTION_READ) begin
    ar.valid = 1'b1;
    ar.addr  = txn.StartAddress;
    ar.len   = txn.Alen;
    ar.size  = txn.Size - 1;
    ar.id    = txn.IdTag;
    
    ar.user = '0;
    foreach (txn.Auser[i]) begin
      ar.user[(i * 32) +: 32] = txn.Auser[i];
    end
    
    cg_fe_axi_requestor_ar.sample();

    hdm_sample = '0;
    hdm_sample.axi_valid = 1'b1;
    hdm_sample.is_write  = 1'b0;
    hdm_sample.axi_id    = ar.id[1:0];
    sample_hdm_event(hdm_sample);
    queue_hdm_axi(1'b0, ar.size, ar.len);

    //For ar_id covergrop
    cg_fe_tag_fifo.sample(1'b0, txn.IdTag);
  end
endfunction : convert_to_ar

function void kb_fwd_eng_coverage::convert_to_w(kb_axi4_vendor_txn_t txn);
  if (txn.Direction == DENALI_CDN_AXI_DIRECTION_WRITE) begin
    w.valid = 1'b1;
    w.last  = txn.Last;
    w.data  = '0;
    w.strb  = {txn.Strobe[127:0]};
    w.user  = '0;
    
    foreach (txn.PhysicalData[i]) begin
      w.data[(i * 32) +: 32] = txn.PhysicalData[i];
    end
    foreach (txn.User[i]) begin
      w.user[(i * 32) +: 32] = txn.User[i];
    end
    
    cg_fe_axi_requestor_w.sample();
  end
endfunction : convert_to_w

function void kb_fwd_eng_coverage::convert_to_b(kb_axi4_vendor_txn_t txn);
  if (txn.Direction == DENALI_CDN_AXI_DIRECTION_WRITE) begin
    b.valid = 1'b1;
    b.id    = txn.IdTag;
    b.resp  = txn.Resp - 1; // Denali encoding is AMBA response + 1[cite: 2]
    
    b.user = '0;
    foreach (txn.Buser[i]) begin
      b.user[(i * 32) +: 32] = txn.Buser[i];
    end
    
    cg_fe_axi_responder.sample(
      1'b0,
      b.id,
      b.resp,
      1'b0,
      b.user[7]
    );
  end
endfunction : convert_to_b

function void kb_fwd_eng_coverage::convert_to_r(kb_axi4_vendor_txn_t txn);
  if (txn.Direction == DENALI_CDN_AXI_DIRECTION_READ) begin
    r.valid = 1'b1;
    r.id    = txn.IdTag;
    r.resp  = txn.Resp - 1; // Denali encoding is AMBA response + 1[cite: 2]
    r.last  = txn.Last;
    
    r.user  = '0;
    r.data  = '0;
    foreach (txn.PhysicalData[i]) begin
      r.data[(i * 32) +: 32] = txn.PhysicalData[i];
    end
    foreach (txn.User[i]) begin
      r.user[(i * 32) +: 32] = txn.User[i];
    end
    
    cg_fe_axi_responder.sample(
      1'b1,
      r.id,
      r.resp,
      r.last,
      r.user[7]
    );
  end
endfunction : convert_to_r

// Route each event to exactly one direction's embedded covergroup.
function void kb_fwd_eng_coverage::sample_hdm_event(input hdm_cov_event_t sample_data);
  if (reset_seen) return;
  if (sample_data.is_write)
    cg_fe_hdm_decoder_wr.sample(sample_data);
  else
    cg_fe_hdm_decoder_rd.sample(sample_data);
endfunction : sample_hdm_event

function void kb_fwd_eng_coverage::reset_hdm_tag_queues();
  hdm_rd_tag_q.delete();
  hdm_wr_tag_q.delete();
  hdm_rd_axi_q.delete();
  hdm_wr_axi_q.delete();
  hdm_rd_pairing_blocked = 1'b0;
  hdm_wr_pairing_blocked = 1'b0;
endfunction : reset_hdm_tag_queues

function void kb_fwd_eng_coverage::queue_hdm_tag(
  input bit is_write,
  input hdm_tag_result_t tag_result
);
  if (reset_seen) return;
  if (is_write) begin
    if (hdm_wr_pairing_blocked) return;
    hdm_wr_tag_q.push_back(tag_result);
  end else begin
    if (hdm_rd_pairing_blocked) return;
    hdm_rd_tag_q.push_back(tag_result);
  end
  sample_pending_hdm_pairs(is_write);
endfunction : queue_hdm_tag

function void kb_fwd_eng_coverage::queue_hdm_axi(
  input bit is_write,
  input bit [7:0] size,
  input bit [7:0] len
);
  hdm_axi_size_t observation;

  if (reset_seen) return;
  if ((is_write && hdm_wr_pairing_blocked) ||
      (!is_write && hdm_rd_pairing_blocked)) return;

  // Existing FE monitor conversion normalizes txn.Size to AXI AxSIZE.
  // Do not treat other sizes or multi-beat bursts as a single 64B packet.
  if ((len != 8'd0) || !(size inside {8'd6, 8'd7})) begin
    if (is_write) begin
      hdm_wr_pairing_blocked = 1'b1;
      hdm_wr_tag_q.delete();
      hdm_wr_axi_q.delete();
    end else begin
      hdm_rd_pairing_blocked = 1'b1;
      hdm_rd_tag_q.delete();
      hdm_rd_axi_q.delete();
    end
    `uvm_error("HDM_TAG_AXI_FORMAT", $sformatf(
      "Unsupported AXI format: write=%0b size=%0d len=%0d; tag pairing for this direction is disabled until reset",
      is_write, size, len))
    return;
  end

  observation.size = size;
  observation.len  = len;
  if (is_write) hdm_wr_axi_q.push_back(observation);
  else          hdm_rd_axi_q.push_back(observation);
  sample_pending_hdm_pairs(is_write);
endfunction : queue_hdm_axi

function void kb_fwd_eng_coverage::sample_pending_hdm_pairs(input bit is_write);
  hdm_axi_size_t observation;
  hdm_tag_result_t tag1;
  hdm_tag_result_t tag2;
  hdm_cov_event_t pair_sample;
  int unsigned required_tags;

  if (reset_seen) return;
  if ((is_write && hdm_wr_pairing_blocked) ||
      (!is_write && hdm_rd_pairing_blocked)) return;

  forever begin
    tag2 = '0;
    if (is_write) begin
      if (hdm_wr_axi_q.size() == 0) return;
      observation = hdm_wr_axi_q[0];
      required_tags = (observation.size == 8'd7) ? 2 : 1;
      // Leave BOTH queues untouched until a complete match is available.
      if (hdm_wr_tag_q.size() < required_tags) return;
      observation = hdm_wr_axi_q.pop_front();
      tag1 = hdm_wr_tag_q.pop_front();
      if (required_tags == 2) tag2 = hdm_wr_tag_q.pop_front();
    end else begin
      if (hdm_rd_axi_q.size() == 0) return;
      observation = hdm_rd_axi_q[0];
      required_tags = (observation.size == 8'd7) ? 2 : 1;
      if (hdm_rd_tag_q.size() < required_tags) return;
      observation = hdm_rd_axi_q.pop_front();
      tag1 = hdm_rd_tag_q.pop_front();
      if (required_tags == 2) tag2 = hdm_rd_tag_q.pop_front();
    end

    // 64B consumes one result to maintain alignment, without a pair sample.
    if (required_tags == 2) begin
      pair_sample = '0;
      pair_sample.is_write = is_write;
      pair_sample.pair_sample_valid = 1'b1;
      pair_sample.axi_size = observation.size;
      pair_sample.tag_pair_checked = {tag1.tag_range_checked, tag2.tag_range_checked};
      pair_sample.tag_pair_bounds_valid = {tag1.tag_bounds_valid, tag2.tag_bounds_valid};
      pair_sample.tag_pair_passed = {tag1.tag_range_passed, tag2.tag_range_passed};
      // Other event flags remain zero: only cp_fe_tagrange_128b may hit.
      sample_hdm_event(pair_sample);
    end
  end
endfunction : sample_pending_hdm_pairs

task kb_fwd_eng_coverage::sample_scoreboard_items();
  kb_fwd_eng_cov_seq_item h_txn;

  forever begin
    cov_fifo.get(h_txn);
    if (reset_seen) continue;
    tag_bounds_valid  = h_txn.tag_bounds_valid;
    tag_range_checked = h_txn.tag_range_checked;
    tag_range_passed  = h_txn.tag_range_passed;
    
    foreach (h_txn.error_resp_type[i]) begin
      err_resp_type[i] = h_txn.error_resp_type[i];
      if (h_txn.valid_lanes[i]) begin
        hdm_sample = '0;
        hdm_sample.error_valid       = 1'b1;
        hdm_sample.packet_valid      = 1'b1;
        hdm_sample.tag_bounds_valid  = tag_bounds_valid[i];
        hdm_sample.tag_check_enabled = tag_range_check;
        hdm_sample.tag_range_checked = tag_range_checked[i];
        hdm_sample.tag_range_passed  = tag_range_passed[i];
        hdm_sample.error_type        = err_resp_type[i];
        hdm_sample.nxm_enabled       = nxm_enable;
        hdm_sample.poison_enabled    = poison_enable;
        hdm_sample.is_write          = h_txn.is_write;
        hdm_sample.permission_valid  = h_txn.permission_checked[i];
        hdm_sample.permission_passed = h_txn.permission_passed[i];
        sample_hdm_event(hdm_sample);
        // Publisher contract: valid entries in this iteration order are in
        // AXI request order within this direction. A merged request supplies
        // two consecutive original-tag entries, each with its own result.
        // Enqueue even if checking was skipped: every packet occupies a slot.
        queue_hdm_tag(h_txn.is_write, '{
          tag_bounds_valid: tag_bounds_valid[i],
          tag_range_checked: tag_range_checked[i],
          tag_range_passed: tag_range_passed[i]
        });
        cg_fe_axi_requestor_error.sample(h_txn.error_resp_type[i]);
      end
    end

  end
endtask : sample_scoreboard_items


function void kb_fwd_eng_coverage::report_phase(uvm_phase phase);
  super.report_phase(phase);

  `uvm_info(get_type_name(), "===== FE INPUT COVERAGE SUMMARY =====", UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  HDM Read Decoder Cov  : %0.2f%%", cg_fe_hdm_decoder_rd.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  HDM Write Decoder Cov : %0.2f%%", cg_fe_hdm_decoder_wr.get_coverage()), UVM_LOW)
  if (hdm_rd_tag_q.size() || hdm_rd_axi_q.size() ||
      hdm_wr_tag_q.size() || hdm_wr_axi_q.size()) begin
    `uvm_warning("HDM_TAG_PENDING", $sformatf(
      "Unmatched HDM entries at end of test: read tags=%0d AXI=%0d; write tags=%0d AXI=%0d",
      hdm_rd_tag_q.size(), hdm_rd_axi_q.size(),
      hdm_wr_tag_q.size(), hdm_wr_axi_q.size()))
  end
  `uvm_info(get_type_name(), $sformatf("  REQ Input Coverage     : %0.2f%%", cg_fe_cxl_parser_req.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  RWD Input Coverage     : %0.2f%%", cg_fe_cxl_parser_rwd.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  CXL Parity Coverage    : %0.2f%%", cg_fe_axi_requestor_parity.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Scoreboard Error Cov   : %0.2f%%", cg_fe_axi_requestor_error.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Combining Coverage     : %0.2f%%", cg_fe_cxl_parser_combining.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  AXI Responder Coverage : %0.2f%%", cg_fe_axi_responder.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Error/IRQ Coverage     : %0.2f%%", cg_fe_error_interrupt.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  APB Config Coverage    : %0.2f%%", cg_fe_apb_registers.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Credit Manager Coverage: %0.2f%%", cg_fe_credit_manager.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), "=====================================", UVM_LOW)
endfunction : report_phase

`endif // KB_FWD_ENG_COVERAGE_SV


