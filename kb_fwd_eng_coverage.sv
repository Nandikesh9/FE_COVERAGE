`ifndef KB_FWD_ENG_COVERAGE_SV
`define KB_FWD_ENG_COVERAGE_SV

import kb_cxl_pkg::*;


class kb_fwd_eng_coverage extends uvm_component;

  `uvm_component_utils(kb_fwd_eng_coverage)

  // analysis_fifo to get the internal variables from Scoreboard to Coverage
  uvm_tlm_analysis_fifo #(kb_fwd_eng_seq_cov_item) cov_fifo;

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
  bit [1:0]  rwd_meta_field[2];
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

  // Shadow register for 0x80900: fe_interrupt_enable (19 active bits)
  bit [18:0] interrupt_enables_inst = 19'h40000; // Default: irq_global_en=1

  bit reset_seen;

  // HDM Decoder APB Storage Arrays (10 instances, 24-bit registers)
  bit [23:0] reg_hpa_base[10];
  bit [23:0] reg_hpa_top[10];
  bit [23:0] reg_dpa_base[10];

  // Tracker variables to allow unified sampling in cg_apb_config
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

  // Tracker variable for fe_error_status register (18 active bits)
  bit [17:0] fe_error_status_inst;

  // -------------------------------------------------------------------------
  // REQ input coverage
  // -------------------------------------------------------------------------
  covergroup cg_req_packet with function sample(
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

    cp_flit_mode: coverpoint flit_mode iff (req_valid) {
      bins mode_256b_to_68b = (1'b1 => 1'b0);
      bins mode_68b_to_256b = (1'b0 => 1'b1);
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    cp_valid: coverpoint req_valid iff (req_valid){
      bins valid_1 = {1'b1};
      bins valid_0 = {1'b0};
    }

    cp_fe_valid_gap: coverpoint gap_class iff (gap_available) {
      bins back_to_back = {0}; // no invalid cycle between valid requests
      bins gap_1cyc     = {1}; // one invalid cycle between valid requests
      bins random_gap   = {2}; // two or more invalid cycles
    }

    cp_ld_id: coverpoint ld_id iff (req_valid) { 
      bins supported = {4'h0};
      bins unsupported = default;
    }

    cp_lane: coverpoint req_valid_p iff (lane==1'b0);
    
    cp_req_concurency: coverpoint $countones(req_valid_p);
   // { 
   //   bins no_valid_lane = {0};
   //   bins one_lane      = {1};
   //   bins two_lanes     = {2};
   //   bins three_lanes   = {3};
   //   bins four_lanes    = {4};
   // }

    cp_opcode: coverpoint opcode iff (req_valid) {
      bins supported   = {4'h1};
      bins unsupported = default;
    }

    cp_snp_type: coverpoint snp_type iff (req_valid) {
      bins supported   = {3'b000};
      bins unsupported = default;
    }

    cp_meta_field: coverpoint meta_field iff (req_valid) {
      bins supported   = {2'b11};
      bins unsupported = default;
    }

    cp_meta_value: coverpoint meta_value iff (req_valid);

    cp_tag: coverpoint tag iff (req_valid) {
       bins tags[8]  = {[16'h0000:16'hFFFF]};
    }

    // HPA is represented as HPA[51:6]. Bit 0 therefore identifies whether the
    // 64B line is aligned to the lower or upper half of a 128B boundary.
    cp_hpa_alignment: coverpoint hpa[0] iff (req_valid) {
      bins aligned_128b     = {1'b0};
      bins upper_64b_half   = {1'b1};
    }

    cp_opcode_check_enable: coverpoint opcode_check_enable iff (req_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_field_check_enable: coverpoint field_check_enable iff (req_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cr_lane_by_flit_mode: cross cp_flit_mode, cp_lane iff (req_valid) {
      illegal_bins mode_68b_upper_lanes =
        binsof(cp_flit_mode) intersect {1'b0} &&
        binsof(cp_lane) intersect {[2:3]};
    }

    //cr_opcode_stimulus: cross cp_opcode, cp_opcode_check_enable;
    //cr_snp_stimulus:    cross cp_snp_type, cp_field_check_enable;
    //cr_meta_stimulus:   cross cp_meta_field, cp_field_check_enable;

    cr_lane_opcode:     cross cp_lane, cp_opcode, cp_opcode_check_enable iff (req_valid);
    cr_lane_snp_type:   cross cp_lane, cp_snp_type, cp_field_check_enable iff (req_valid);
    cr_lane_meta_field: cross cp_lane, cp_meta_field, cp_field_check_enable iff (req_valid);
    //cr_lane_meta_value: cross cp_lane, cp_meta_value, cp_field_check_enable;
    //cr_lane_ld_id:      cross cp_lane, cp_ld_id;

    // Exercises simultaneous supported/unsupported field combinations without
    // assuming the value of an unobservable internal error signal.
    cr_header_fields: cross cp_opcode, cp_snp_type, cp_meta_field iff (req_valid);
  endgroup : cg_req_packet

  // -------------------------------------------------------------------------
  // RWD input coverage
  // -------------------------------------------------------------------------
  covergroup cg_rwd_packet with function sample(
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

    cp_valid: coverpoint rwd_valid { 
      bins valid_low = {1'b0};
      bins valid_high = {1'b1};
    }

    cp_flit_mode: coverpoint flit_mode iff(rwd_valid){
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    cp_lane: coverpoint lane iff(lane==1'b0);
    //{
    //  bins lane_0 = {0};
    //  bins lane_1 = {1};
    //}
    
    cp_rwd_concurency: coverpoint $countones(rwd_valid_p);
   // { 
   //   bins no_valid_lane = {0};
   //   bins one_lane      = {1};
   //   bins two_lanes     = {2};
   // }

    cp_ld_id: coverpoint ld_id iff(rwd_valid) { 
      bins supported = {4'h1};
      bins unsupported = default;
    }

    cp_opcode: coverpoint opcode iff(rwd_valid) {
      bins supported   = {4'h1};
      bins unsupported = default;
    }

    cp_snp_type: coverpoint snp_type iff(rwd_valid) {
      bins supported   = {3'b000};
      bins unsupported = default;
    }

    cp_meta_field: coverpoint meta_field iff(rwd_valid) {
      bins supported   = {2'b11};
      bins unsupported = default;
    }

    cp_tag: coverpoint tag iff(rwd_valid) {
      bins tags[8]  = {[16'h0000:16'hFFFF]};

    }

    cp_hpa_alignment: coverpoint hpa[0] iff(rwd_valid) {
      bins aligned_128b   = {1'b0};
      bins upper_64b_half = {1'b1};
    }

    cp_poison: coverpoint poison iff(rwd_valid) {
      bins clear = {1'b0};
      bins set   = {1'b1};
    }

    cp_opcode_check_enable: coverpoint opcode_check_enable iff(rwd_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_field_check_enable: coverpoint field_check_enable iff(rwd_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_poison_check_enable: coverpoint poison_check_enable iff(rwd_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_poison_enable: coverpoint poison_enable iff(rwd_valid) { 
      bins poison_enb = {1'b1};
      bins poison_dis_enb = {1'b0};
    }

    cr_lane_by_flit_mode: cross cp_flit_mode, cp_lane iff(rwd_valid) {
      illegal_bins mode_68b_upper_lane =
        binsof(cp_flit_mode) intersect {1'b0} &&
        binsof(cp_lane) intersect {1};
    }

    cp_rwd_data: coverpoint rwd_data iff(rwd_valid) {
      bins all_zeros = {'0};
      bins all_ones  = {'1};
      bins others    = default;
    }

    // Byte Enable Coverpoint
    cp_byte_enable: coverpoint byte_enable iff(rwd_valid) {
      bins full_be   = {64'hFFFF_FFFF_FFFF_FFFF};
      bins empty_be  = {64'h0000_0000_0000_0000};
      bins partial   = default;
    }

    //cr_opcode_stimulus: cross cp_opcode, cp_opcode_check_enable;
    //cr_snp_stimulus:    cross cp_snp_type, cp_field_check_enable;
    //cr_meta_stimulus:   cross cp_meta_field, cp_field_check_enable;
    //cr_poison_stimulus: cross cp_poison, cp_poison_check_enable, cp_poison_enable;

    cr_lane_opcode:     cross cp_lane, cp_opcode, cp_opcode_check_enable iff(rwd_valid);
    cr_lane_snp_type:   cross cp_lane, cp_snp_type, cp_field_check_enable iff(rwd_valid);
    cr_lane_meta_field: cross cp_lane, cp_meta_field, cp_field_check_enable iff(rwd_valid);
    cr_lane_ld_id:      cross cp_lane, cp_ld_id iff(rwd_valid);
    cr_lane_poison:     cross cp_lane, cp_poison, cp_poison_check_enable iff(rwd_valid);

    // Poison, unsupported opcode and unsupported fields are independent parser
    // detections, so cover their simultaneous input combinations.
    cr_error_inputs: cross cp_opcode, cp_snp_type, cp_meta_field, cp_poison iff(rwd_valid);
  endgroup : cg_rwd_packet

  // -------------------------------------------------------------------------
  // S2M DRC (Data Response) output coverage
  // Exposes 2 DRC channels
  // -------------------------------------------------------------------------
  covergroup cg_s2m_drc_packet with function sample(
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
    cp_lane: coverpoint lane {
      bins lane_0 = {0};
      bins lane_1 = {1};
    }

    // Only MemData (000) and MemData-NXM (001) are used for DRS
    cp_opcode: coverpoint opcode {
      bins memdata     = {3'b000};
      bins memdata_nxm = {3'b001};
      bins unsupported = default;
    }

    // MetaField and MetaValue are always 0
    cp_meta_field: coverpoint meta_field {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }
    
    cp_meta_value: coverpoint meta_value {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }

    // ld_id is always 0 for single LD device
    cp_ld_id: coverpoint ld_id {
      bins expected_0  = {4'h0};
      bins unsupported = default;
    }

    cp_poison: coverpoint poison {
      bins clear = {1'b0};
      bins set   = {1'b1};
    }

    cp_poison_enable: coverpoint poison_enable { 
      bins poison_enb = {1'b1};
      bins poison_dis_enb = {1'b0};
    }

    // DevLoad comes from egress queue fill level
    cp_dev_load: coverpoint dev_load;

    cp_tag: coverpoint tag {
      bins tags[8] = {[16'h0000:16'hFFFF]};
    }

    cp_s2m_data : coverpoint s2m_data {
    bins all_zeros = {'0};
    bins all_ones  = {'1};
    bins other     = default;
  }

    // MemData can be poisoned or clear; MemData-NXM is typically unpoisoned but 
    // depends on "Poison On Decode Error Enable".
    cr_opcode_poison: cross cp_opcode, cp_poison;

    cr_lane_opcode: cross cp_lane, cp_opcode;
    cr_lane_meta: cross cp_lane, cp_meta_field, cp_meta_value;
    cr_lane_poison: cross cp_lane, cp_poison_enable, cp_poison;
    cr_lane_dev_load: cross cp_lane, cp_dev_load;
    
  endgroup : cg_s2m_drc_packet

  // -------------------------------------------------------------------------
  // S2M NDR (No Data Response) output coverage
  // Exposes 6 NDR channels
  // -------------------------------------------------------------------------
  covergroup cg_s2m_ndr_packet with function sample(
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
    cp_lane: coverpoint lane {
      bins lanes[] = {[0:5]};
    }

    // NDR Opcode is always Cmp (000) for HDM-H
    cp_opcode: coverpoint opcode {
      bins cmp         = {3'b000};
      bins unsupported = default;
    }

    // MetaField and MetaValue are always 0
    cp_meta_field: coverpoint meta_field {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }
    
    cp_meta_value: coverpoint meta_value {
      bins expected_0  = {2'b00};
      bins unsupported = default;
    }

    // ld_id is always 0 for single LD device
    cp_ld_id: coverpoint ld_id {
      bins expected_0  = {4'h0};
      bins unsupported = default;
    }

    // DevLoad comes from egress queue fill level
    cp_dev_load: coverpoint dev_load;

    cp_tag: coverpoint tag {
      bins tags[8] = {[16'h0000:16'hFFFF]};
    }

    // Cross combinations to ensure no rogue bits appear alongside expected Cmp opcode
    cr_ndr_fields: cross cp_opcode, cp_meta_field, cp_ld_id;

    cr_lane_opcode: cross cp_opcode, cp_lane;
    cr_lane_meta: cross cp_lane, cp_meta_field, cp_meta_value;
    cr_ld_id: cross cp_lane, cp_ld_id;
    cr_dev_load: cross cp_lane, cp_dev_load;

  endgroup : cg_s2m_ndr_packet

  // -------------------------------------------------------------------------
  // Combining-eligibility input coverage
  // -------------------------------------------------------------------------
  covergroup cg_combining with function sample(
    input bit path_is_write,
    input bit combining_enable,
    input bit adjacent_pair_present,
    input bit first_hpa_128b_aligned,
    input bit addresses_contiguous
  );
    option.per_instance = 1;

    cp_path: coverpoint path_is_write {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    cp_enable: coverpoint combining_enable {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_pair_present: coverpoint adjacent_pair_present {
      bins incomplete_pair = {1'b0};
      bins complete_pair   = {1'b1};
    }

    cp_alignment: coverpoint first_hpa_128b_aligned {
      bins unaligned = {1'b0};
      bins aligned   = {1'b1};
    }

    cp_contiguous: coverpoint addresses_contiguous {
      bins noncontiguous = {1'b0};
      bins contiguous    = {1'b1};
    }

    cr_combining_inputs: cross
      cp_path,
      cp_enable,
      cp_pair_present,
      cp_alignment,
      cp_contiguous;
  endgroup : cg_combining

  // -------------------------------------------------------------------------
  // APB configuration coverage
  // -------------------------------------------------------------------------
  covergroup cg_apb_config;
    option.per_instance = 1;

    cp_flit_mode: coverpoint flit_mode_inst {
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    cp_combining_rd_enable: coverpoint combining_rd_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_combining_wr_enable: coverpoint combining_wr_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_opcode_check_enable: coverpoint unsupported_opcode_check_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_field_check_enable: coverpoint unsupported_field_check_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_poison_check_enable: coverpoint poison_crc_invert_enable_inst {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_mem_app_pending: coverpoint mem_app_pending_enable {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_nxm_enable: coverpoint nxm_enable {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_poison_enable: coverpoint poison_enable {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    // -------------------------------------------------------------------------
    // HDM Decoder Coverpoints (Conditioned on is_hdm_update)
    // -------------------------------------------------------------------------
    cp_hdm_idx: coverpoint current_hdm_idx iff (is_hdm_update) {
      bins decoders[] = {[0:9]};
    }

    cp_hdm_hpa_base: coverpoint current_hpa_base iff (is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }
    
    cp_hdm_hpa_top: coverpoint current_hpa_top iff (is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }
    
    cp_hdm_dpa_base: coverpoint current_dpa_base iff (is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }

    // -------------------------------------------------------------------------
    // Interrupt Enables Coverpoints
    // -------------------------------------------------------------------------
    cp_hdm_miss_rd      : coverpoint interrupt_enables_inst[0]  { bins disabled = {0}; bins enabled = {1}; }
    cp_hdm_miss_wr      : coverpoint interrupt_enables_inst[1]  { bins disabled = {0}; bins enabled = {1}; }
    cp_perm_err_rd      : coverpoint interrupt_enables_inst[2]  { bins disabled = {0}; bins enabled = {1}; }
    cp_perm_err_wr      : coverpoint interrupt_enables_inst[3]  { bins disabled = {0}; bins enabled = {1}; }
    cp_tag_range_rd     : coverpoint interrupt_enables_inst[4]  { bins disabled = {0}; bins enabled = {1}; }
    cp_tag_range_wr     : coverpoint interrupt_enables_inst[5]  { bins disabled = {0}; bins enabled = {1}; }
    cp_unsupported_req  : coverpoint interrupt_enables_inst[6]  { bins disabled = {0}; bins enabled = {1}; }
    cp_unsupported_rwd  : coverpoint interrupt_enables_inst[7]  { bins disabled = {0}; bins enabled = {1}; }
    cp_poison_recv      : coverpoint interrupt_enables_inst[8]  { bins disabled = {0}; bins enabled = {1}; }
    cp_parity_rd_err    : coverpoint interrupt_enables_inst[9]  { bins disabled = {0}; bins enabled = {1}; }
    cp_parity_wr_err    : coverpoint interrupt_enables_inst[10] { bins disabled = {0}; bins enabled = {1}; }
    cp_parity_rd_chk    : coverpoint interrupt_enables_inst[11] { bins disabled = {0}; bins enabled = {1}; }
    cp_parity_wr_chk    : coverpoint interrupt_enables_inst[12] { bins disabled = {0}; bins enabled = {1}; }
    cp_egress_rd_thresh : coverpoint interrupt_enables_inst[13] { bins disabled = {0}; bins enabled = {1}; }
    cp_egress_wr_thresh : coverpoint interrupt_enables_inst[14] { bins disabled = {0}; bins enabled = {1}; }
    cp_ndr_credit_ovf   : coverpoint interrupt_enables_inst[15] { bins disabled = {0}; bins enabled = {1}; }
    cp_drs_credit_ovf   : coverpoint interrupt_enables_inst[16] { bins disabled = {0}; bins enabled = {1}; }
    cp_dcd_ded          : coverpoint interrupt_enables_inst[17] { bins disabled = {0}; bins enabled = {1}; }
    cp_irq_global_en    : coverpoint interrupt_enables_inst[18] { bins disabled = {0}; bins enabled = {1}; }

    // -------------------------------------------------------------------------
    // WR_Token Bucket / WR_Rate Limiter Coverpoints
    // Address 'h80a00
    // -------------------------------------------------------------------------
    cp_wr_refill_period: coverpoint wr_refill_period {
      bins periods[4] = {[16'h0000:16'hFFFF]}; 
    }

   cp_wr_capacity: coverpoint wr_capacity {
     bins capacities[4] = {[16'h0000:16'hFFFF]}; 
   }

   cp_wr_refill_rate: coverpoint wr_refill_rate {
     bins rates[4] = {[5'h00:5'h1F]}; // 5-bit width
   }

   cp_wr_reset_token: coverpoint wr_reset_token {
     bins deasserted = {1'b0};
     bins asserted   = {1'b1};
   }

    // -------------------------------------------------------------------------
    // RD_Token Bucket / RD_Rate Limiter Coverpoints
    // Address 'h80a00
    // -------------------------------------------------------------------------
    cp_rd_refill_period: coverpoint rd_refill_period {
      bins periods[4] = {[16'h0000:16'hFFFF]}; 
    }

   cp_rd_capacity: coverpoint rd_capacity {
     bins capacities[4] = {[16'h0000:16'hFFFF]}; 
   }

   cp_rd_refill_rate: coverpoint rd_refill_rate {
     bins rates[4] = {[5'h00:5'h1F]}; // 5-bit width
   }

   cp_rd_reset_token: coverpoint rd_reset_token {
     bins deasserted = {1'b0};
     bins asserted   = {1'b1};
   }
    
    // -------------------------------------------------------------------------
    // FE Error Status Register Coverpoints
    // -------------------------------------------------------------------------
    cp_hdm_miss_rd_status      : coverpoint fe_error_status_inst[0]  { bins clean = {0}; bins error = {1}; }
    cp_hdm_miss_wr_status      : coverpoint fe_error_status_inst[1]  { bins clean = {0}; bins error = {1}; }
    cp_perm_error_rd_status    : coverpoint fe_error_status_inst[2]  { bins clean = {0}; bins error = {1}; }
    cp_perm_error_wr_status    : coverpoint fe_error_status_inst[3]  { bins clean = {0}; bins error = {1}; }
    cp_tag_range_rd_status     : coverpoint fe_error_status_inst[4]  { bins clean = {0}; bins error = {1}; }
    cp_tag_range_wr_status     : coverpoint fe_error_status_inst[5]  { bins clean = {0}; bins error = {1}; }
    cp_unsupported_req_status  : coverpoint fe_error_status_inst[6]  { bins clean = {0}; bins error = {1}; }
    cp_unsupported_rwd_status  : coverpoint fe_error_status_inst[7]  { bins clean = {0}; bins error = {1}; }
    cp_poison_received_status  : coverpoint fe_error_status_inst[8]  { bins clean = {0}; bins error = {1}; }
    cp_parity_rd_err_status    : coverpoint fe_error_status_inst[9]  { bins clean = {0}; bins error = {1}; }
    cp_parity_wr_err_status    : coverpoint fe_error_status_inst[10] { bins clean = {0}; bins error = {1}; }
    cp_parity_rd_chk_status    : coverpoint fe_error_status_inst[11] { bins clean = {0}; bins error = {1}; }
    cp_parity_wr_chk_status    : coverpoint fe_error_status_inst[12] { bins clean = {0}; bins error = {1}; }
    cp_egress_rd_thresh_status : coverpoint fe_error_status_inst[13] { bins clean = {0}; bins error = {1}; }
    cp_egress_wr_thresh_status : coverpoint fe_error_status_inst[14] { bins clean = {0}; bins error = {1}; }
    cp_ndr_credit_ovf_status   : coverpoint fe_error_status_inst[15] { bins clean = {0}; bins error = {1}; }
    cp_drs_credit_ovf_status   : coverpoint fe_error_status_inst[16] { bins clean = {0}; bins error = {1}; }
    cp_dcd_ded_status          : coverpoint fe_error_status_inst[17] { bins clean = {0}; bins error = {1}; }


    // Cross Coverage: Verify the reset token triggers across various capacities
    cr_wr_capacity_reset: cross cp_wr_capacity, cp_wr_reset_token;
    cr_rd_capacity_reset: cross cp_rd_capacity, cp_rd_reset_token;

    // Cross the Global Enable against a subset of critical datapath errors
    cr_global_mask_hdm_miss  : cross cp_irq_global_en, cp_hdm_miss_rd;
    cr_global_mask_dcd_fatal : cross cp_irq_global_en, cp_dcd_ded;
    cr_global_mask_ovf       : cross cp_irq_global_en, cp_ndr_credit_ovf;

    cr_parser_configuration: cross
      cp_flit_mode,
      cp_combining_rd_enable,
      cp_combining_wr_enable;

    cr_error_configuration: cross
      cp_opcode_check_enable,
      cp_field_check_enable,
      cp_poison_check_enable;

    // Cross the index with the base to ensure every individual decoder (0-9) gets a valid HPA configuration
    cr_idx_hpa_base: cross cp_hdm_idx, cp_hdm_hpa_base;
  endgroup : cg_apb_config

  // -------------------------------------------------------------------------
  // Observable M2S link input coverage
  // -------------------------------------------------------------------------
  covergroup cg_m2s_link with function sample(
    input bit rst_n,
    input bit mst_req,
    input bit mst_ack
  );
    option.per_instance = 1;

    cp_reset: coverpoint rst_n {
      bins asserted   = {1'b0};
      bins deasserted = {1'b1};
      bins assertion  = (1'b1 => 1'b0);
      bins reset_release = (1'b0 => 1'b1);
    }

    cp_mst_req: coverpoint mst_req {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
      bins rise       = (1'b0 => 1'b1);
      bins fall       = (1'b1 => 1'b0);
    }

    cp_mst_ack: coverpoint mst_ack {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
      bins rise       = (1'b0 => 1'b1);
      bins fall       = (1'b1 => 1'b0);
    }

    cr_handshake: cross cp_mst_req, cp_mst_ack;
  endgroup : cg_m2s_link

  // -------------------------------------------------------------------------
  // Observable S2M link input coverage
  // -------------------------------------------------------------------------
  covergroup cg_s2m_link with function sample(
    input bit rst_n,
    input bit slv_req,
    input bit slv_ack
  );
    option.per_instance = 1;

    // Track reset assertions
    cp_reset: coverpoint rst_n {
      bins asserted      = {1'b0};
      bins deasserted    = {1'b1};
      bins assertion     = (1'b1 => 1'b0);
      bins reset_release = (1'b0 => 1'b1);
    }

    // S2M interface activation request (DUT -> TB)
    cp_slv_req: coverpoint slv_req {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
      bins rise       = (1'b0 => 1'b1);
      bins fall       = (1'b1 => 1'b0);
    }

    // S2M interface active acknowledge (TB -> DUT)
    cp_slv_ack: coverpoint slv_ack {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
      bins rise       = (1'b0 => 1'b1);
      bins fall       = (1'b1 => 1'b0);
    }

    // Cross-coverage automatically bins all 4 static FSM states (2'b00, 2'b01, 2'b10, 2'b11) 
    // to verify the link walks through IDLE, INIT, RUN, and DEINIT
    cr_s2m_handshake: cross cp_slv_req, cp_slv_ack;

  endgroup : cg_s2m_link

  // -------------------------------------------------------------------------
  // Credit Counters Coverage
  // Covers the 14 individual 6-bit per-channel credit counters defined in the 
  // fe_rdl and modeled by the persistent arrays in CXL_Test_bench.
  // -------------------------------------------------------------------------
  covergroup cg_credit_counters with function sample(
    input int unsigned lane_idx,
    input bit [1:0]    channel_type, // 00: REQ, 01: RWD, 10: NDR, 11: DRC
    input int unsigned credit_count
  );
    option.per_instance = 1;

    // Max lanes across all interfaces is 6 (for NDR)
    cp_lane_idx: coverpoint lane_idx {
      bins lanes[] = {[0:5]};
    }

    // 4 distinct credit interfaces
    cp_channel_type: coverpoint channel_type {
      bins req = {2'b00};
      bins rwd = {2'b01};
      bins ndr = {2'b10};
      bins drc = {2'b11};
    }

    // 6-bit counters tracking up to 32 max credits
    cp_credit_count: coverpoint credit_count {
      bins empty    = {0};
      bins partial  = {[1:31]};
      bins full     = {32};
      bins overflow = {[33:63]}; // Catches sync loss / overflow conditions
    }

    // Cross to ensure every active lane on every interface hits all credit levels
    cr_type_lane_count: cross cp_channel_type, cp_lane_idx, cp_credit_count {
      
      // Ignore non-existent lanes for REQ (valid: 0-3)
      ignore_bins invalid_req_lanes = binsof(cp_channel_type) intersect {2'b00} && 
                                      binsof(cp_lane_idx) intersect {[4:5]};
                                      
      // Ignore non-existent lanes for RWD (valid: 0-1)
      ignore_bins invalid_rwd_lanes = binsof(cp_channel_type) intersect {2'b01} && 
                                      binsof(cp_lane_idx) intersect {[2:5]};
                                      
      // Ignore non-existent lanes for DRC (valid: 0-1)      
      ignore_bins invalid_drc_lanes = binsof(cp_channel_type) intersect {2'b11} && 
                                      binsof(cp_lane_idx) intersect {[2:5]};
                                      
      // NDR uses all 0-5 lanes, so no ignore_bins are needed
    }
  endgroup : cg_credit_counters

  // -------------------------------------------------------------------------
  // AXI Address Channel Covergroups (AW / AR)
  // -------------------------------------------------------------------------
  covergroup cg_axi_aw;
    option.per_instance = 1;
    cp_id   : coverpoint aw.id { bins ids[4] = {[0:3]}; } // Tag FIFOs map to IDs 0-3
    cp_len  : coverpoint aw.len { bins single_beat = {0}; } // CXL FE transactions are single beat
    cp_size : coverpoint aw.size { bins size_64b = {6}; bins size_128b = {7}; } // 64B encoding
    cp_aw_user : coverpoint aw.user { bins user_0 = {'h0};
                                      bins user_7 = {'h80};
                                      illegal_bins others = default; }

    cp_poison_check_0: coverpoint rwd_poison[0];
    cp_poison_check_1: coverpoint rwd_poison[1] iff (flit_mode_inst == 1'b1);

    // Cross
    cr_id_size : cross cp_id, cp_size;
    cr_id_poison_0 : cross cp_id, cp_aw_user, poison_crc_invert_enable_inst, cp_poison_check_0;
    cr_id_poison_1 : cross cp_id, cp_aw_user, poison_crc_invert_enable_inst, cp_poison_check_1 iff (flit_mode_inst == 1'b1);
  endgroup

  covergroup cg_axi_ar;
    option.per_instance = 1;
    cp_id   : coverpoint ar.id { bins ids[4] = {[0:3]}; } 
    cp_len  : coverpoint ar.len { bins single_beat = {0}; }
    cp_size : coverpoint ar.size { bins size_64b = {6}; bins size_128b = {7}; }
  endgroup

  // -------------------------------------------------------------------------
  // AXI Data & Response Channel Covergroups (W, B, R)
  // -------------------------------------------------------------------------
  covergroup cg_axi_w;
    option.per_instance = 1;
    cp_last : coverpoint w.last { bins asserted = {1'b1}; }
  endgroup

  covergroup cg_axi_b;
    option.per_instance = 1;
    cp_id   : coverpoint b.id { bins ids[4] = {[0:3]}; }
    cp_resp : coverpoint b.resp { 
      bins okay   = {2'b01};
      bins slverr = {2'b11};
      //bins decerr = {2'b11};
    }
  endgroup

  covergroup cg_axi_r;
    option.per_instance = 1;
    cp_id   : coverpoint r.id { bins ids[4] = {[0:3]}; }
    cp_last : coverpoint r.last { bins asserted = {1'b1}; }
    cp_resp : coverpoint r.resp { 
      bins okay   = {2'b01};
      bins slverr = {2'b11};
      //bins decerr = {2'b11};
    }
  endgroup

  extern function new(string name = "kb_fwd_eng_coverage",
                      uvm_component parent = null);
  extern task run_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);
  extern function void reset_config_shadow();
  extern task apb();
  extern task cxl_configure();
  extern task axi_configure();
  //extern function void sample_all_credits();
  extern function void sample_req_inputs(kb_cxl_m2s_snap snap);
  extern function void sample_rwd_inputs(kb_cxl_m2s_snap snap);
  extern function void sample_ndr_outputs(kb_cxl_s2m_snap snap);
  extern function void sample_drc_outputs(kb_cxl_s2m_snap snap);
  extern task apb_configure(kb_apb3_vendor_txn_t txn);
  extern function void convert_to_aw(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_ar(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_w(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_b(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_r(kb_axi4_vendor_txn_t txn);

endclass : kb_fwd_eng_coverage

function kb_fwd_eng_coverage::new(
  string name = "kb_fwd_eng_coverage",
  uvm_component parent = null
);
  super.new(name, parent);
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
  cg_req_packet             = new();
  cg_rwd_packet             = new();
  cg_s2m_drc_packet         = new();
  cg_s2m_ndr_packet         = new();
  cg_combining              = new();
  cg_apb_config             = new();
  cg_m2s_link               = new();
  cg_s2m_link               = new();
  cg_credit_counters        = new();
  cg_axi_aw                 = new();
  cg_axi_w                  = new();
  cg_axi_b                  = new();
  cg_axi_ar                 = new();
  cg_axi_r                  = new();

  reset_seen = 1'b0;
  reset_config_shadow();

  // Record architectural defaults even when a test performs no APB writes.
  cg_apb_config.sample();
endfunction : new

function void kb_fwd_eng_coverage::reset_config_shadow();
  flit_mode_inst                       = 1'b1;
  combining_rd_enable_inst             = 1'b1;
  combining_wr_enable_inst             = 1'b1;
  unsupported_opcode_check_enable_inst = 1'b1;
  unsupported_field_check_enable_inst  = 1'b1;
  poison_crc_invert_enable_inst        = 1'b1;

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

    cg_m2s_link.sample(
      h_cxl_m2s_items.rst_n,
      h_cxl_m2s_items.mst_req,
      h_cxl_m2s_items.mst_ack
    );

    cg_s2m_link.sample(
    h_cxl_s2m_items.rst_n,
    h_cxl_s2m_items.slv_req,
    h_cxl_s2m_items.slv_ack
  );

    if (!h_cxl_m2s_items.rst_n) begin
      if (!reset_seen) begin
        reset_config_shadow();
        cg_apb_config.sample();
        reset_seen = 1'b1;
      end
      continue;
    end

    reset_seen = 1'b0;
    sample_req_inputs(h_cxl_m2s_items);
    sample_rwd_inputs(h_cxl_m2s_items);
    sample_ndr_outputs(h_cxl_s2m_items);
    sample_drc_outputs(h_cxl_s2m_items);
  end
endtask : cxl_configure

task kb_fwd_eng_coverage::axi_configure();
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

endtask : axi_configure


//====================================================================
// TODO: Need to discuss how to get the credit counters from scoreboard
//====================================================================
//
//function void kb_fwd_eng_coverage::sample_all_credits();
//    // Sample M2S REQ (4 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_REQ; i++)
//      cg_credit_counters.sample(i, 2'b00, exp_req_credits[i]);
//      
//    // Sample M2S RWD (2 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_RWD; i++)
//      cg_credit_counters.sample(i, 2'b01, exp_rwd_credits[i]);
//      
//    // Sample S2M NDR (6 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_NDR; i++)
//      cg_credit_counters.sample(i, 2'b10, exp_s2m_ndr_credits[i]);
//      
//    // Sample S2M DRC (2 channels)
//    for (int i = 0; i < KB_CXL_MAX_NUM_DRC; i++)
//      cg_credit_counters.sample(i, 2'b11, exp_s2m_drc_credits[i]);
//  endfunction

function void kb_fwd_eng_coverage::sample_req_inputs(
  kb_cxl_m2s_snap snap
);
  int unsigned max_req_lanes;

  // rst_n is active low. Discard partial gap history while reset is asserted.
  if (!snap.rst_n) begin
    foreach (req_seen_valid[i]) begin
      req_seen_valid[i] = 1'b0;
      req_gap_cycles[i] = 0;
    end
    return;
  end

  max_req_lanes = flit_mode_inst ? 4 : 2;

  for (int i = 0; i < max_req_lanes; i++) begin
    bit gap_available;
    int unsigned gap_class;
    int unsigned req_concurrency = 0;

    gap_available = 1'b0;
    gap_class = 0;

    if (snap.req_items[i].valid) begin
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

      req_seen_valid[i] = 1'b1;
      req_gap_cycles[i] = 0;
    end else if (req_seen_valid[i] && req_gap_cycles[i] < 2) begin
      // This function is called for each CXL snapshot, so invalid snapshots
      // between requests accumulate the per-lane gap.
      req_gap_cycles[i]++;
    end

    // Sample every active lane each cycle so cp_valid sees both values.
    // Packet coverpoints/crosses are gated by req_valid inside the covergroup.
    cg_req_packet.sample(
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

  // Sample each adjacent pair that can be presented in the active flit mode.
  for (int i = 0; i < (max_req_lanes - 1); i++) begin
    bit pair_present;
    bit aligned;
    bit contiguous;

    pair_present = snap.req_items[i].valid &&
                   snap.req_items[i+1].valid;
                   
    // Evaluate alignment and contiguity using the local arrays when both are valid
    if (pair_present) begin
      aligned    = !req_hpa[i][0];
      contiguous = (req_hpa[i+1] == (req_hpa[i] + 1'b1));
    end else begin
      aligned    = 1'b0;
      contiguous = 1'b0;
    end

    if (snap.req_items[i].valid || snap.req_items[i+1].valid) begin
      cg_combining.sample(
        1'b0,
        combining_rd_enable_inst,
        pair_present,
        aligned,
        contiguous
      );
    end
  end
endfunction : sample_req_inputs

function void kb_fwd_eng_coverage::sample_rwd_inputs(
  kb_cxl_m2s_snap snap
);
  int unsigned max_rwd_lanes;

  // rst_n is active low. Discard partial gap history while reset is asserted.
  if (!snap.rst_n) begin
    foreach (req_seen_valid[i]) begin
      rwd_seen_valid[i] = 1'b0;
      rwd_gap_cycles[i] = 0;
    end
    return;
  end

  max_rwd_lanes = flit_mode_inst ? 2 : 1;

  for (int i = 0; i < KB_CXL_MAX_NUM_RWD; i++) begin

    bit rwd_gap_available;
    int unsigned rwd_gap_class;
    int unsigned rwd_concurrency = 0;

    rwd_gap_available = 1'b0;
    rwd_gap_class = 0;

    if (snap.rwd_items[i].valid) begin
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
      
      // Note: rwd_data and byte_enable are populated here for completeness, 
      // even if cg_rwd_packet does not currently sample them.
      rwd_data[i]       = snap.rwd_items[i].wdata;
      byte_enable[i]    = snap.rwd_items[i].byte_enable;

      // 2. Sample the covergroup using the local array variables
      cg_rwd_packet.sample(
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

  if (max_rwd_lanes == 2) begin
    bit pair_present;
    bit aligned;
    bit contiguous;

    pair_present = snap.rwd_items[0].valid &&
                   snap.rwd_items[1].valid;
                   
    // Evaluate alignment and contiguity using the local arrays when both are valid
    if (pair_present) begin
      aligned    = !rwd_hpa[0][0];
      contiguous = (rwd_hpa[1] == (rwd_hpa[0] + 1'b1));
    end else begin
      aligned    = 1'b0;
      contiguous = 1'b0;
    end

    if (snap.rwd_items[0].valid || snap.rwd_items[1].valid) begin
      cg_combining.sample(
        1'b1,
        combining_wr_enable_inst,
        pair_present,
        aligned,
        contiguous
      );
    end
  end
endfunction : sample_rwd_inputs
/*
function void kb_fwd_eng_coverage::sample_ndr_outputs(kb_cxl_s2m_snap snap);
  for (int i = 0; i < KB_CXL_MAX_NUM_NDR; i++) begin
    if (snap.ndr_items[i].valid) begin
      cg_s2m_ndr_packet.sample(
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
      // 1. Populate the local arrays for the active NDR lane
      ndr_opcode[i]     = snap.ndr_items[i].s2m_ndr_opcode;
      ndr_meta_field[i] = snap.ndr_items[i].s2m_meta_field;
      ndr_meta_value[i] = snap.ndr_items[i].s2m_meta_value;
      ndr_tag[i]        = snap.ndr_items[i].s2m_tag;
      ndr_ld_id[i]      = snap.ndr_items[i].s2m_ld_id;
      ndr_dev_load[i]   = snap.ndr_items[i].s2m_dev_load;

      // 2. Sample the covergroup using the local array variables
      cg_s2m_ndr_packet.sample(
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
      cg_s2m_drc_packet.sample(
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

task kb_fwd_eng_coverage::apb_configure(
  kb_apb3_vendor_txn_t txn
);
  if (txn.Direction != DENALI_CDN_APB_DIRECTION_WRITE)
    return;

  // Default to 0; will be set to 1 if the address hits the decoder range
  is_hdm_update = 1'b0;

  // ------------------------------------------------------------------------- 
  // Dynamic HDM Decoder Array (Indices 0 to 9)
  // Base: 0x80200, Stride: 0xC, End: 0x80277 
  // ------------------------------------------------------------------------- 
  if (txn.Addr >= 'h80200 && txn.Addr <= 'h80277) begin
    int unsigned idx;
    bit [7:0]    offset;
    
    idx    = (txn.Addr - 'h80200) / 'hC;
    offset = (txn.Addr - 'h80200) % 'hC;

    if (idx < 10) begin
      case (offset)
        8'h00: reg_hpa_base[idx] = txn.Data[23:0];
        8'h04: reg_hpa_top[idx]  = txn.Data[23:0];
        8'h08: reg_dpa_base[idx] = txn.Data[23:0];
      endcase
      
      // Update trackers for the covergroup
      is_hdm_update    = 1'b1;
      current_hdm_idx  = idx;
      current_hpa_base = reg_hpa_base[idx];
      current_hpa_top  = reg_hpa_top[idx];
      current_dpa_base = reg_dpa_base[idx];
    end
  end

  case (txn.Addr)
    'h80800: begin
      flit_mode_inst           = txn.Data[0];
      combining_rd_enable_inst = txn.Data[1];
      combining_wr_enable_inst = txn.Data[2];
      cg_apb_config.sample();
    end

    'h80400: begin 
        mst_req = txn.Data;
        cg_apb_config.sample();
    end
      
    'h80404: begin
        mst_ack = txn.Data;
        cg_apb_config.sample();
    end

    'h80600: begin
      unsupported_opcode_check_enable_inst = txn.Data[0];
      unsupported_field_check_enable_inst  = txn.Data[1];
      poison_crc_invert_enable_inst         = txn.Data[2];
      cg_apb_config.sample();
    end

    'h80c00: begin
      mem_app_pending_enable    = txn.Data[0]; 
      nxm_enable                = txn.Data[1];
      poison_enable             = txn.Data[2];
      cg_apb_config.sample();
    end

    'h80800: begin
      fe_error_status_inst = txn.Data;
    end

    'h80900: begin
        // The fe_interrupt_enable register maps 19 contiguous bits
        interrupt_enables_inst = txn.Data[18:0]; 
      end

    'h80a00: begin
        // Write token bucket
        wr_refill_period   = txn.Data;
        wr_refill_rate     = txn.Data;
        wr_capacity        = txn.Data;
        wr_reset_token     = txn.Data;
      end

      'h80b00: begin
        // Write token bucket
        rd_refill_period   = txn.Data;
        rd_refill_rate     = txn.Data;
        rd_capacity        = txn.Data;
        rd_reset_token     = txn.Data;
      end

    default: begin
    end
  endcase
  cg_apb_config.sample();
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
    
    cg_axi_aw.sample();
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
    
    cg_axi_ar.sample();
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
    
    cg_axi_w.sample();
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
    
    cg_axi_b.sample();
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
    
    cg_axi_r.sample();
  end
endfunction : convert_to_r


function void kb_fwd_eng_coverage::report_phase(uvm_phase phase);
  super.report_phase(phase);

  `uvm_info(get_type_name(), "===== FE INPUT COVERAGE SUMMARY =====", UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  REQ Input Coverage     : %0.2f%%", cg_req_packet.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  RWD Input Coverage     : %0.2f%%", cg_rwd_packet.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Combining Coverage     : %0.2f%%", cg_combining.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  APB Config Coverage    : %0.2f%%", cg_apb_config.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  M2S Link Coverage      : %0.2f%%", cg_m2s_link.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), "=====================================", UVM_LOW)
endfunction : report_phase

`endif // KB_FWD_ENG_COVERAGE_SV



