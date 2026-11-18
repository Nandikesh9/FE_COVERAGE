`ifndef KB_FWD_ENG_COVERAGE_SV
`define KB_FWD_ENG_COVERAGE_SV

import kb_cxl_pkg::*;

typedef enum int unsigned {
  FE_FILL_REQ_0,
  FE_FILL_REQ_1,
  FE_FILL_REQ_2,
  FE_FILL_REQ_3,
  FE_FILL_RWD_0,
  FE_FILL_RWD_1,
  FE_FILL_NDR_0,
  FE_FILL_NDR_1,
  FE_FILL_NDR_2,
  FE_FILL_NDR_3,
  FE_FILL_NDR_4,
  FE_FILL_NDR_5,
  FE_FILL_DRS_0,
  FE_FILL_DRS_1,
  FE_FILL_RD_TAG_0,
  FE_FILL_RD_TAG_1,
  FE_FILL_RD_TAG_2,
  FE_FILL_RD_TAG_3,
  FE_FILL_WR_TAG_0,
  FE_FILL_WR_TAG_1,
  FE_FILL_WR_TAG_2,
  FE_FILL_WR_TAG_3,
  FE_FILL_EGRESS_AR,
  FE_FILL_EGRESS_W,
  FE_FILL_EGRESS_AW,
  FE_FILL_INGRESS_B,
  FE_FILL_INGRESS_RRESP
} fe_fill_fifo_id_e;

// Reusable covergroup type. It is declared at package scope because a
// covergroup declared inside a class is an embedded instance, not a datatype.
covergroup cg_fe_tag_toggle with function sample(input bit [15:0] tag);
  option.per_instance = 1;

  cp_fe_tag_toggle: coverpoint tag {
    wildcard bins bit0_rise  = (16'b???????????????0 => 16'b???????????????1);
    wildcard bins bit0_fall  = (16'b???????????????1 => 16'b???????????????0);
    wildcard bins bit1_rise  = (16'b??????????????0? => 16'b??????????????1?);
    wildcard bins bit1_fall  = (16'b??????????????1? => 16'b??????????????0?);
    wildcard bins bit2_rise  = (16'b?????????????0?? => 16'b?????????????1??);
    wildcard bins bit2_fall  = (16'b?????????????1?? => 16'b?????????????0??);
    wildcard bins bit3_rise  = (16'b????????????0??? => 16'b????????????1???);
    wildcard bins bit3_fall  = (16'b????????????1??? => 16'b????????????0???);
    wildcard bins bit4_rise  = (16'b???????????0???? => 16'b???????????1????);
    wildcard bins bit4_fall  = (16'b???????????1???? => 16'b???????????0????);
    wildcard bins bit5_rise  = (16'b??????????0????? => 16'b??????????1?????);
    wildcard bins bit5_fall  = (16'b??????????1????? => 16'b??????????0?????);
    wildcard bins bit6_rise  = (16'b?????????0?????? => 16'b?????????1??????);
    wildcard bins bit6_fall  = (16'b?????????1?????? => 16'b?????????0??????);
    wildcard bins bit7_rise  = (16'b????????0??????? => 16'b????????1???????);
    wildcard bins bit7_fall  = (16'b????????1??????? => 16'b????????0???????);
    wildcard bins bit8_rise  = (16'b???????0???????? => 16'b???????1????????);
    wildcard bins bit8_fall  = (16'b???????1???????? => 16'b???????0????????);
    wildcard bins bit9_rise  = (16'b??????0????????? => 16'b??????1?????????);
    wildcard bins bit9_fall  = (16'b??????1????????? => 16'b??????0?????????);
    wildcard bins bit10_rise = (16'b?????0?????????? => 16'b?????1??????????);
    wildcard bins bit10_fall = (16'b?????1?????????? => 16'b?????0??????????);
    wildcard bins bit11_rise = (16'b????0??????????? => 16'b????1???????????);
    wildcard bins bit11_fall = (16'b????1??????????? => 16'b????0???????????);
    wildcard bins bit12_rise = (16'b???0???????????? => 16'b???1????????????);
    wildcard bins bit12_fall = (16'b???1???????????? => 16'b???0????????????);
    wildcard bins bit13_rise = (16'b??0????????????? => 16'b??1?????????????);
    wildcard bins bit13_fall = (16'b??1????????????? => 16'b??0?????????????);
    wildcard bins bit14_rise = (16'b?0?????????????? => 16'b?1??????????????);
    wildcard bins bit14_fall = (16'b?1?????????????? => 16'b?0??????????????);
    wildcard bins bit15_rise = (16'b0??????????????? => 16'b1???????????????);
    wildcard bins bit15_fall = (16'b1??????????????? => 16'b0???????????????);
  }
endgroup : cg_fe_tag_toggle


class kb_fwd_eng_coverage extends uvm_component;

  `uvm_component_utils(kb_fwd_eng_coverage)

  // Shared environment configuration provides the generated RAL model used
  // to observe the live credit-manager debug counters.
  kb_fwd_eng_env_cfg h_env_cfg;
  bit allow_extended_read_response = 1'b0;

  // analysis_fifo to get the internal variables from Scoreboard to Coverage
  uvm_tlm_analysis_fifo #(kb_fwd_eng_cov_seq_item) cov_fifo;

  // Coverage sequence item class handle
  kb_fwd_eng_cov_seq_item h_cov_seq_items;

  // APB, CXL vip analysis fifo's
  uvm_tlm_analysis_fifo #(denaliCdn_apbTransaction) apb_fifo;
  uvm_tlm_analysis_fifo #(kb_cxl_m2s_snap) cxl_m2s_bus_fifo;
  uvm_tlm_analysis_fifo #(kb_cxl_s2m_snap) cxl_s2m_bus_fifo;

  // Error-status snapshots published by the IRQ service path.
  uvm_tlm_analysis_fifo #(logic [19:0]) irq_fifo;

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
    bit [7:0] user;    
  } axi_aw_src_t;

  typedef struct packed {
    bit          valid;
    bit [1023:0] data;   
    bit [127:0]  strb;   
    bit          last;
    bit [31:0]  user;   
  } axi_w1024_src_t;

  typedef struct packed {
    bit         valid;
    bit [7:0]   id;      
    bit [63:0]  addr;    
    bit [7:0]   len;     
    bit [7:0]   size;    // Custom integrated field
    bit [7:0] user;    
  } axi_ar_src_t;

  typedef struct packed {
    bit         valid;
    bit [7:0]   id;     
    bit [1:0]   resp;   
    bit [7:0] user;   
  } axi_b_src_t;

  typedef struct packed {
    bit          valid;
    bit [7:0]    id;
    bit [1023:0] data;   
    bit [1:0]    resp;
    bit          last;
    bit [31:0]  user;   
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
  bit [45:0] req_hpa[4];        // REQ HPA[51:6]; 68B Address[5] is omitted
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
  bit [9:0] hdm_config_pending;
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
  // Reset-token commands observed since the last packet in each direction.
  bit         wr_rate_reset_pending;
  bit         rd_rate_reset_pending;

  // Tracker variable for fe_error_status register at 0x80a00 (20 active bits)
  bit [19:0] fe_error_status_inst;
  bit [19:0] fe_error_status_prev;
  bit        fe_error_status_prev_valid;
  // Latest consumed S2M observation; retain X/Z until a real sample arrives.
  bit      fe_irq_line_inst;
  bit        fe_irq_line_valid;

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
    bit [2:0] tag_position; // {at_low, at_high, strictly_between}
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
    bit programming_sample_valid;
    bit [9:0] programmed_regions;
    bit programmed_pair_valid;
    bit [3:0] programmed_region_a;
    bit [3:0] programmed_region_b;
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

  typedef struct packed {
    bit [1:0] resp;
    bit last;
    bit user7;
    bit [31:0] user_value;
  } priority_response_t;
  logic [7:0] priority_aw_q[256][$];
  logic [7:0] priority_ar_q[256][$];
  priority_response_t priority_b_q[256][$];
  priority_response_t priority_r_q[256][$];
  bit [7:0] br_buser_q[$];
  bit [31:0] br_ruser_q[$];
  extern function void sample_pending_br_users();
  extern function void sample_pending_response_priority(bit is_read, bit [7:0] id);
  bit [3:0][1:0] err_resp_type;
  bit [1:0] encap_rd_ert_q[$], encap_wr_ert_q[$];
  // Response-time configuration: {nxm_enable, poison_enable}.
  bit [1:0] encap_drs_config_q[$], encap_ndr_config_q[$];
  extern function void sample_pending_encap_errors(bit is_write);

  // SB: Four queues. Size and length travel with the observed USER bit.
  // Requires scoreboard entries in AXI order per direction, including two
  // final-error entries for each merged 128B request. No dropped requests.
  typedef struct packed {
    logic       erruser;
    logic [2:0] size;
    logic [7:0] len;
  } axi_error_observation_t;
  bit [1:0] rd_ert_q[$];
  bit [1:0] wr_ert_q[$];
  axi_error_observation_t rd_erruser_q[$];
  axi_error_observation_t wr_erruser_q[$];
  bit [3:0] tag_bounds_valid;
  bit [3:0] tag_range_checked;
  bit [3:0] tag_range_passed;
  bit tag_range_check;
  bit [4:0] dcd_enable;

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

    // Exact four-lane REQ-valid pattern in 256B mode, sampled once per snapshot.
    cp_fe_req_channel: coverpoint req_valid_p
      iff (lane == 0 && (|req_valid_p)) {
      bins valid_patterns[] = {
        4'b0000,
        4'b0001,
        4'b0010,
        4'b0011,
        4'b0100,
        4'b0110,
        4'b0111,
        4'b1000,
        4'b1001,
        4'b1011,
        4'b1100,
        4'b1101,
        4'b1110,
        4'b1111
      };
      illegal_bins pattern_0101 = {4'b0101};
      illegal_bins pattern_1010 = {4'b1010};
    }

    // Physical lane is kept separate from the valid-pattern coverpoint.
    cp_fe_req_lane: coverpoint lane iff (req_valid) {
      bins channel_0 = {0};
      bins channel_1 = {1};
      bins channel_2 = {2};
      bins channel_3 = {3};
      illegal_bins unsupported_channel = default;
    }
    
    cp_fe_req_concurrency: coverpoint $countones(req_valid_p) iff (lane == 0);
   // { 
   //   bins no_valid_lane = {0};
   //   bins one_lane      = {1};
   //   bins two_lanes     = {2};
   //   bins three_lanes   = {3};
   //   bins four_lanes    = {4};
   // }

    cp_fe_unsup_req_opcode: coverpoint opcode iff (req_valid) {
      bins supported   = {4'h1};
      bins unsupported = {[0:$]} with (item != 4'h1);
    }

    cp_fe_snp_type: coverpoint snp_type iff (req_valid) {
      bins supported   = {3'b000};
      bins unsupported = {[0:$]} with (item != 3'b000);
    }

    cp_fe_meta_field: coverpoint meta_field iff (req_valid) {
      bins supported   = {2'b11};
      bins unsupported = {[0:$]} with (item != 2'b11);
    }

    cp_fe_meta_value: coverpoint meta_value iff (req_valid) {
      bins expected  = {2'b00, 2'b01, 2'b10, 2'b11};
    }

    // ld_id is always 0 for single LD device
    cp_fe_ld_id: coverpoint ld_id iff (req_valid) {
      bins expected_0  = {4'h0};
      bins unsupported = {[0:$]} with (item != 4'b0);
    }

    cp_fe_tag: coverpoint tag iff (req_valid) {
       bins tags[8]  = {[16'h0000:16'hFFFF]};
    }

    // HPA is HPA[51:6] in both modes; bit 0 is Address[6].
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

    cr_fe_lane_by_flit_mode: cross cp_fe_flit_mode, cp_fe_req_lane iff (req_valid) {
      illegal_bins mode_68b_upper_lanes =
        binsof(cp_fe_flit_mode) intersect {1'b0} &&
        binsof(cp_fe_req_lane) intersect {[2:3]};
    }

    //cr_fe_opcode_stimulus: cross cp_fe_unsup_req_opcode, cp_fe_valid_unsupported_req_opcode_enable;
    //cr_fe_snp_stimulus:    cross cp_fe_snp_type, cp_fe_unsupported_req_filed_chk_enables;
    //cr_fe_meta_stimulus:   cross cp_fe_meta_field, cp_fe_unsupported_req_filed_chk_enables;

    cr_fe_flit_x_opcode:     cross cp_fe_flit_mode, cp_fe_unsup_req_opcode, cp_fe_valid_unsupported_req_opcode_enable iff (req_valid);
    cr_fe_flit_x_snp_type:   cross cp_fe_flit_mode, cp_fe_snp_type, cp_fe_unsupported_req_filed_chk_enables iff (req_valid);
    cr_fe_flit_x_meta_field: cross cp_fe_flit_mode, cp_fe_meta_field, cp_fe_unsupported_req_filed_chk_enables iff (req_valid);
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

    // Exact two-lane RWD-valid pattern, sampled once through lane 0.
    cp_fe_rwd_channel: coverpoint rwd_valid_p iff (lane == 0);

    // Physical lane is kept separate from the valid-pattern coverpoint.
    cp_fe_rwd_lane: coverpoint lane iff (rwd_valid) {
      bins channel_0 = {0};
      bins channel_1 = {1};
      illegal_bins unsupported_channel = default;
    }
    
    cp_fe_rwd_concurrency: coverpoint $countones(rwd_valid_p) iff (lane == 0);
   // { 
   //   bins no_valid_lane = {0};
   //   bins one_lane      = {1};
   //   bins two_lanes     = {2};
   // }

    cp_fe_unsup_rwd_field_opcode: coverpoint opcode iff(rwd_valid) {
      bins supported   = {4'h1};
      bins unsupported = {[0:$]} with (item != 4'h1);
    }

    cp_fe_unsup_rwd_field_snp_type: coverpoint snp_type iff(rwd_valid) {
      bins supported   = {3'b000};
      bins unsupported = {[0:$]} with (item != 3'b000);
    }

    cp_fe_unsup_rwd_field_meta_field: coverpoint meta_field iff(rwd_valid) {
      bins supported   = {2'b11};
      bins unsupported = {[0:$]} with (item != 2'b11);
    }

    cp_fe_meta_value: coverpoint meta_value iff (rwd_valid) {
      bins expected  = {2'b00, 2'b01, 2'b10, 2'b11};
    }

    // ld_id is always 0 for single LD device
    cp_fe_ld_id: coverpoint ld_id iff (rwd_valid) {
      bins expected_0  = {4'h0};
      bins unsupported = {[0:$]} with (item != 4'b0);
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

    cr_fe_lane_by_flit_mode: cross cp_fe_flit_mode, cp_fe_rwd_lane iff(rwd_valid) {
      illegal_bins mode_68b_upper_lane =
        binsof(cp_fe_flit_mode) intersect {1'b0} &&
        binsof(cp_fe_rwd_lane) intersect {1};
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

    cr_fe_flit_x_en_opcode:     cross cp_fe_flit_mode, cp_fe_unsup_rwd_field_opcode, cp_fe_unsupported_rwd_opcode_enable iff(rwd_valid);
    cr_fe_flit_x_en_snp_type:   cross cp_fe_flit_mode, cp_fe_unsup_rwd_field_snp_type, cp_fe_unsupported_rwd_filed_chk_enables iff(rwd_valid);
    cr_fe_flit_x_en_meta_field: cross cp_fe_flit_mode, cp_fe_unsup_rwd_field_meta_field, cp_fe_unsupported_rwd_filed_chk_enables iff(rwd_valid);
    cr_fe_flit_x_poison_x_crcinv:     cross cp_fe_flit_mode, cp_fe_poison_received, cp_fe_crc_invert_enable iff(rwd_valid);
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
    input bit [511:0]  s2m_data,
    input bit ert_sample_valid = 1'b0,
    input bit [1:0] error_resp_type = 0,
    input bit sampled_nxm_enable = 0,
    input bit sampled_poison_enable = 0
  );
    option.per_instance = 1;

    // DRC interface has 2 active channels
    cp_fe_lane: coverpoint lane iff (!ert_sample_valid) {
      bins lane_0 = {0};
      bins lane_1 = {1};
    }

    // Only MemData (000) and MemData-NXM (001) are used for DRS
    cp_fe_opcode: coverpoint opcode iff (!ert_sample_valid) {
      bins memdata     = {3'b000};
      bins memdata_nxm = {3'b001};
      bins unsupported = {[0:$]} with (!(item inside {3'b000, 3'b001}));
    }

    // MetaField and MetaValue are always 0
    cp_fe_meta_field: coverpoint meta_field iff (!ert_sample_valid) {
      bins expected_0  = {2'b00};
      bins unsupported = {[0:$]} with (item != 2'b00);
    }
    
    cp_fe_meta_value: coverpoint meta_value iff (!ert_sample_valid) {
      bins expected_0  = {2'b00, 2'b01, 2'b10, 2'b11};
    }

    // ld_id is always 0 for single LD device
    cp_fe_ld_id: coverpoint ld_id iff (!ert_sample_valid) {
      bins expected_0  = {4'h0};
      bins unsupported = {[0:$]} with (item != 4'b0);
    }

    cp_fe_poison: coverpoint poison iff (!ert_sample_valid) {
      bins clear = {1'b0};
      bins set   = {1'b1};
    }

    cp_fe_poison_enable: coverpoint poison_enable iff (!ert_sample_valid) { 
      bins poison_enb = {1'b1};
      bins poison_dis_enb = {1'b0};
    }

    // DevLoad comes from egress queue fill level
    cp_fe_dev_load: coverpoint dev_load iff (!ert_sample_valid) {
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

	  // Rapid increase in dev_load
      bins jump_00_10 = (2'b00 => 2'b10);
      bins jump_00_11 = (2'b00 => 2'b11);
      bins jump_01_11 = (2'b01 => 2'b11);
    }

    cp_fe_tag: coverpoint tag iff (!ert_sample_valid) {
      bins tags[8] = {[16'h0000:16'hFFFF]};
    }

    cp_fe_s2m_data : coverpoint s2m_data iff (!ert_sample_valid) {
    bins all_zeros = {'0};
    bins all_ones  = {'1};
    bins other     = default;
  }

    cp_fe_error_response_type: coverpoint error_resp_type iff (ert_sample_valid) {
      bins no_error = {0};
      bins hdm_miss_err = {1};
      bins cxl_parser_permission = {2};
      bins tag_range_error = {3};
    }
    cp_fe_ert_nxm_enable: coverpoint sampled_nxm_enable iff (ert_sample_valid) {
      bins disabled = {0};
      bins enabled = {1};
    }
    cp_fe_ert_poison_enable: coverpoint sampled_poison_enable iff (ert_sample_valid) {
      bins disabled = {0};
      bins enabled = {1};
    }
    
    // MemData can be poisoned or clear; MemData-NXM is typically unpoisoned but 
    // depends on "Poison On Decode Error Enable".
    cr_fe_opcode_poison: cross cp_fe_opcode, cp_fe_poison iff (!ert_sample_valid);

    cr_fe_flit_x_opcode: cross flit_mode_inst, cp_fe_opcode iff (!ert_sample_valid);
    cr_fe_flit_x_meta: cross flit_mode_inst, cp_fe_meta_field, cp_fe_meta_value iff (!ert_sample_valid);
    cr_fe_flit_x_poison_en: cross flit_mode_inst, cp_fe_poison_enable iff (!ert_sample_valid);
    cr_fe_flit_x_poison: cross flit_mode_inst, cp_fe_poison iff (!ert_sample_valid);
    cr_fe_flit_x_dev_load: cross flit_mode_inst, cp_fe_dev_load
      iff (!ert_sample_valid) {
      ignore_bins falling_dev_load =
      binsof(cp_fe_dev_load.fall_01_00) ||
      binsof(cp_fe_dev_load.fall_10_01) ||
      binsof(cp_fe_dev_load.fall_11_10) ||
      binsof(cp_fe_dev_load.fall_10_00) ||
      binsof(cp_fe_dev_load.fall_11_01) ||
      binsof(cp_fe_dev_load.fall_11_00);
    }
    
    cr_fe_drs_ert_x_nxm_x_poison: cross cp_fe_error_response_type,
    cp_fe_ert_nxm_enable, cp_fe_ert_poison_enable iff (ert_sample_valid);
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
    input bit [1:0]    dev_load,
    input bit ert_sample_valid = 1'b0,
    input bit [1:0] error_resp_type = 0,
    input bit sampled_nxm_enable = 0,
    input bit sampled_poison_enable = 0
  );
    option.per_instance = 1;

    // NDR interface has 6 active channels
    cp_fe_lane: coverpoint lane iff (!ert_sample_valid) {
      bins lanes[] = {[0:5]};
    }

    // NDR Opcode is always Cmp (000) for HDM-H
    cp_fe_opcode: coverpoint opcode iff (!ert_sample_valid) {
      bins cmp         = {3'b000};
      bins unsupported = {[0:$]} with (item != 3'b000);
    }

    // MetaField and MetaValue are always 0
    cp_fe_meta_field: coverpoint meta_field iff (!ert_sample_valid) {
      bins expected_0  = {2'b00};
      bins unsupported = {[0:$]} with (item != 2'b00);
    }
    
    cp_fe_meta_value: coverpoint meta_value iff (!ert_sample_valid) {
      bins expected_0  = {2'b00, 2'b01, 2'b10, 2'b11};
    }

    // ld_id is always 0 for single LD device
    cp_fe_ld_id: coverpoint ld_id iff (!ert_sample_valid) {
      bins expected_0  = {4'h0};
      bins unsupported = {[0:$]} with (item != 4'b0);
    }

    // DevLoad comes from egress queue fill level
    cp_fe_dev_load: coverpoint dev_load iff (!ert_sample_valid) {
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

	  // Rapid increase in dev_load
      bins jump_00_10 = (2'b00 => 2'b10);
      bins jump_00_11 = (2'b00 => 2'b11);
      bins jump_01_11 = (2'b01 => 2'b11);
	}

    cp_fe_tag: coverpoint tag iff (!ert_sample_valid) {
      bins tags[8] = {[16'h0000:16'hFFFF]};
    }

    cp_fe_error_response_type: coverpoint error_resp_type iff (ert_sample_valid) {
      bins no_error = {0};
      bins hdm_miss_err = {1};
      bins cxl_parser_permission = {2};
      bins tag_range_error = {3};
    }
    cp_fe_ert_nxm_enable: coverpoint sampled_nxm_enable iff (ert_sample_valid) {
      bins disabled = {0};
      bins enabled = {1};
    }
    cp_fe_ert_poison_enable: coverpoint sampled_poison_enable iff (ert_sample_valid) {
      bins disabled = {0};
      bins enabled = {1};
    }

    // Cross combinations to ensure no rogue bits appear alongside expected Cmp opcode
    cr_fe_flit_x_opcode: cross flit_mode_inst, cp_fe_opcode iff (!ert_sample_valid);
    cr_fe_flit_x_meta_field: cross flit_mode_inst, cp_fe_meta_field, cp_fe_meta_value iff (!ert_sample_valid);
    cr_fe_flit_x_dev_load: cross flit_mode_inst, cp_fe_dev_load
      iff (!ert_sample_valid) {
      ignore_bins falling_dev_load =
        binsof(cp_fe_dev_load.fall_01_00) ||
        binsof(cp_fe_dev_load.fall_10_01) ||
        binsof(cp_fe_dev_load.fall_11_10) ||
        binsof(cp_fe_dev_load.fall_10_00) ||
        binsof(cp_fe_dev_load.fall_11_01) ||
        binsof(cp_fe_dev_load.fall_11_00);
    }
    cr_fe_ndr_ert_x_nxm_x_poison: cross cp_fe_error_response_type,
      cp_fe_ert_nxm_enable, cp_fe_ert_poison_enable iff (ert_sample_valid);
  endgroup : cg_fe_cxl_encap_ndr

  // -------------------------------------------------------------------------
  // Combining-eligibility input coverage
  // -------------------------------------------------------------------------
  // Lane order follows the driver's round-robin allocation, synchronized on reset.
  bit req_order_known;
  int unsigned req_next_lane;
  int unsigned req_cycle_start;
  bit rwd_order_known;
  int unsigned rwd_next_lane;
  int unsigned rwd_cycle_start;

  covergroup cg_fe_combining_eligibility with function sample(
    input bit is_write,
    input bit combining_enable,
    input bit [2:0] pair_id,
    input bit first_valid,
    input bit second_valid,
    input bit [45:0] first_hpa,
    input bit [45:0] second_hpa,
    input bit sampled_flit_mode,
    input bit [1:0] start_lane,
    input bit [3:0] valid_mask,
    input bit order_sample_valid
  );
    option.per_instance = 1;

    cp_fe_direction: coverpoint is_write {
      bins req_read = {0};
      bins rwd_write = {1};
    }
    cp_fe_combining_enable: coverpoint combining_enable {
      bins disabled = {0};
      bins enabled = {1};
    }
    cp_fe_pair_valids: coverpoint {first_valid, second_valid} {
      bins neither_valid = {2'b00};
      bins first_only = {2'b10};
      bins second_only = {2'b01};
      bins both_valid = {2'b11};
    }
    cp_fe_address_contiguous: coverpoint
      ((first_hpa != 46'h3FFF_FFFF_FFFF) &&
       (second_hpa == first_hpa + 46'd1))
      iff (first_valid && second_valid) {
      bins noncontiguous = {0};
      bins contiguous = {1};
    }

    cp_fe_flit_0 : coverpoint sampled_flit_mode iff(first_valid) {
      bins flit_256B = {1};
      bins flit_68B  = {0};
    }

    cp_fe_flit_1 : coverpoint sampled_flit_mode iff(second_valid) {
      bins flit_256B = {1};
      bins flit_68B  = {0};
    }

    cp_fe_first_alignment: coverpoint first_hpa[0] iff (first_valid && !sampled_flit_mode) {
      bins aligned_128b = {0};
      bins upper_64b_half = {1};
    }
    cp_fe_second_alignment: coverpoint second_hpa[0] iff (second_valid && !sampled_flit_mode) {
      bins aligned_128b = {0};
      bins upper_64b_half = {1};
    }
    cp_fe_candidate_pair: coverpoint pair_id {
      bins req_0_1 = {0};
      bins req_1_2 = {1};
      bins req_2_3 = {2};
      bins req_3_0 = {3};
      bins rwd_0_1 = {4};
      bins rwd_1_0 = {5};
      bins req_1_0_68b = {6};
    }
    // Input eligibility only; actual DUT merging is checked by the scoreboard.
    cp_fe_256Flit_merge_eligible_pair: coverpoint pair_id
      iff (combining_enable && first_valid && second_valid &&
           !first_hpa[0] && second_hpa[0] &&
           first_hpa[45:1] == second_hpa[45:1] && sampled_flit_mode ) {
      bins req_0_1 = {0};
      bins req_1_2 = {1};
      bins req_2_3 = {2};
      bins req_3_0 = {3};
      bins rwd_0_1 = {4};
      bins rwd_1_0 = {5};
      //bins req_1_0_68b = {6};
    }

    cp_fe_68flit_merge_eligible_pair: coverpoint pair_id
      iff (combining_enable && first_valid && second_valid &&
           !first_hpa[1] && second_hpa[1] &&
           first_hpa[45:1] == second_hpa[45:1] && !sampled_flit_mode) {
      bins req_0_1 = {0};
      //bins req_1_2 = {1};
      //bins req_2_3 = {2};
     // bins req_3_0 = {3};
      //bins rwd_0_1 = {4};
      //bins rwd_1_0 = {5};
      bins req_1_0_68b = {6};
    }


    cp_fe_merge_eligible_pair_flit: coverpoint pair_id
      iff (combining_enable && first_valid && second_valid &&
           !first_hpa[0] && second_hpa[0] &&
           first_hpa[45:1] == second_hpa[45:1]) {
      bins req_0_1 = {0};
      bins req_1_2 = {1};
      bins req_2_3 = {2};
      bins req_3_0 = {3};
      bins rwd_0_1 = {4};
      bins rwd_1_0 = {5};
      bins req_1_0_68b = {6};
    }

    // Invalid input pair: both addresses are 64B aligned but not 128B aligned,
    // and they are noncontiguous. These bins do not observe DUT merge results.
    cp_fe_merge_invalid_pair: coverpoint pair_id
      iff (combining_enable && first_valid && second_valid &&
           first_hpa[0] && !second_hpa[0] &&
           !((first_hpa != 46'h3FFF_FFFF_FFFF) &&
             (second_hpa == first_hpa + 46'd1))) {
      bins req_0_1 = {0};
      bins req_1_2 = {1};
      bins req_2_3 = {2};
      bins req_3_0 = {3};
      bins rwd_0_1 = {4};
      bins rwd_1_0 = {5};
      bins req_1_0_68b = {6};
    }

    cp_fe_merge_invalid_pair_disabled: coverpoint pair_id
      iff (!combining_enable && first_valid && second_valid &&
           first_hpa[0] && !second_hpa[0] &&
           !((first_hpa != 46'h3FFF_FFFF_FFFF) &&
             (second_hpa == first_hpa + 46'd1))) {
      bins req_0_1 = {0};
      bins req_1_2 = {1};
      bins req_2_3 = {2};
      bins req_3_0 = {3};
      bins rwd_0_1 = {4};
      bins rwd_1_0 = {5};
      bins req_1_0_68b = {6};
    }

    cp_fe_merge_eligible_pair_disabled: coverpoint pair_id
      iff (!combining_enable && first_valid && second_valid &&
           !first_hpa[0] && second_hpa[0] &&
           first_hpa[45:1] == second_hpa[45:1]) {
      bins req_0_1 = {0};
      bins req_1_2 = {1};
      bins req_2_3 = {2};
      bins req_3_0 = {3};
      bins rwd_0_1 = {4};
      bins rwd_1_0 = {5};
      bins req_1_0_68b = {6};
    }

    cr_fe_direction_x_enable: cross cp_fe_direction, cp_fe_combining_enable;
    cr_fe_pair_x_valids: cross cp_fe_candidate_pair, cp_fe_pair_valids;
    cr_fe_pair_x_enable: cross cp_fe_candidate_pair, cp_fe_combining_enable;
    cr_fe_pair_x_merge_conditions: cross cp_fe_candidate_pair,
      cp_fe_combining_enable, cp_fe_address_contiguous,
      cp_fe_first_alignment, cp_fe_second_alignment
      iff (first_valid && second_valid) {
      ignore_bins contiguous_same_alignment =
        binsof(cp_fe_address_contiguous.contiguous) &&
        ((binsof(cp_fe_first_alignment.aligned_128b) &&
          binsof(cp_fe_second_alignment.aligned_128b)) ||
         (binsof(cp_fe_first_alignment.upper_64b_half) &&
          binsof(cp_fe_second_alignment.upper_64b_half)));
    }

    // Sample packet order once per nonempty snapshot with combining enabled.
    cp_fe_enabled_start_channel:
      coverpoint {is_write, sampled_flit_mode, start_lane}
      iff (combining_enable && order_sample_valid) {
      bins req_68b_start_ch0 = {4'b0000};
      bins req_68b_start_ch1 = {4'b0001};
      bins req_256b_start_ch0 = {4'b0100};
      bins req_256b_start_ch1 = {4'b0101};
      bins req_256b_start_ch2 = {4'b0110};
      bins req_256b_start_ch3 = {4'b0111};
      bins rwd_256b_start_ch0 = {4'b1100};
      bins rwd_256b_start_ch1 = {4'b1101};
    }

    // Lane presence only; this does not test address eligibility.
    cp_fe_enabled_valid_lanes: coverpoint valid_mask
      iff (combining_enable && order_sample_valid) {
      bins masks[] = {[4'b0001:4'b1111]};
    }

    cr_fe_start_channel_x_valid_lanes:
      cross cp_fe_enabled_start_channel, cp_fe_enabled_valid_lanes {
      ignore_bins upper_lanes_in_two_lane_mode =
        (binsof(cp_fe_enabled_start_channel.req_68b_start_ch0) ||
         binsof(cp_fe_enabled_start_channel.req_68b_start_ch1) ||
         binsof(cp_fe_enabled_start_channel.rwd_256b_start_ch0) ||
         binsof(cp_fe_enabled_start_channel.rwd_256b_start_ch1)) &&
        binsof(cp_fe_enabled_valid_lanes) intersect {[4:15]};
      ignore_bins start_ch0_not_valid =
        (binsof(cp_fe_enabled_start_channel.req_68b_start_ch0) ||
         binsof(cp_fe_enabled_start_channel.req_256b_start_ch0) ||
         binsof(cp_fe_enabled_start_channel.rwd_256b_start_ch0)) &&
        binsof(cp_fe_enabled_valid_lanes) intersect {2, 4, 6, 8, 10, 12, 14};
      ignore_bins start_ch1_not_valid =
        (binsof(cp_fe_enabled_start_channel.req_68b_start_ch1) ||
         binsof(cp_fe_enabled_start_channel.req_256b_start_ch1) ||
         binsof(cp_fe_enabled_start_channel.rwd_256b_start_ch1)) &&
        binsof(cp_fe_enabled_valid_lanes) intersect {1, 4, 5, 8, 9, 12, 13};
      ignore_bins start_ch2_not_valid =
        (binsof(cp_fe_enabled_start_channel.req_256b_start_ch2)) &&
        binsof(cp_fe_enabled_valid_lanes) intersect {1, 2, 3, 8, 9, 10, 11};
      ignore_bins start_ch3_not_valid =
        (binsof(cp_fe_enabled_start_channel.req_256b_start_ch3)) &&
        binsof(cp_fe_enabled_valid_lanes) intersect {1, 2, 3, 4, 5, 6, 7};
    }

    cp_fe_start_x_merge_eligible:
      coverpoint {is_write, sampled_flit_mode, start_lane, pair_id}
      iff (combining_enable && first_valid && second_valid &&
           !first_hpa[0] && second_hpa[0] &&
           first_hpa[45:1] == second_hpa[45:1]) {
      bins req_68b_start0_pair01 = {7'b0_0_00_000};
      bins req_68b_start1_pair10 = {7'b0_0_01_110};
      bins req_256b_start0_pairs[] = {7'b0_1_00_000, 7'b0_1_00_001, 7'b0_1_00_010};
      bins req_256b_start1_pairs[] = {7'b0_1_01_001, 7'b0_1_01_010, 7'b0_1_01_011};
      bins req_256b_start2_pairs[] = {7'b0_1_10_010, 7'b0_1_10_011, 7'b0_1_10_000};
      bins req_256b_start3_pairs[] = {7'b0_1_11_011, 7'b0_1_11_000, 7'b0_1_11_001};
      bins rwd_256b_start0_pair01 = {7'b1_1_00_100};
      bins rwd_256b_start1_pair10 = {7'b1_1_01_101};
    }

  endgroup : cg_fe_combining_eligibility


  //--------------------------------------------------------------------------
  // TAG_FIFO'S CoverGroup
  //--------------------------------------------------------------------------

  // Exact 0%, 25%, 50%, 75%, and 100% occupancy milestones.
  // req_rwd_fifo_c1_arb_fill_level_rdata is excluded.
  covergroup cg_fe_fill_levels with function sample(
    input fe_fill_fifo_id_e fifo_id,
    input bit [10:0] fill_level,
    input bit sample_valid
  );
    option.per_instance = 1;

    cp_fe_req_fifo_0_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_REQ_0) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_req_fifo_1_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_REQ_1) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_req_fifo_2_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_REQ_2) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_req_fifo_3_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_REQ_3) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_rwd_fifo_0_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_RWD_0) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_rwd_fifo_1_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_RWD_1) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_ndr_fifo_0_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_NDR_0) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_ndr_fifo_1_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_NDR_1) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_ndr_fifo_2_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_NDR_2) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_ndr_fifo_3_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_NDR_3) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_ndr_fifo_4_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_NDR_4) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_ndr_fifo_5_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_NDR_5) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_drs_fifo_0_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_DRS_0) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_s2m_drs_fifo_1_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_DRS_1) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(32 * 25) / 100};
      bins fill_level_50_pct = {(32 * 50) / 100};
      bins fill_level_75_pct = {(32 * 75) / 100};
      bins fill_level_100_pct = {32};
    }

    cp_fe_read_tag_fifo_0_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_RD_TAG_0) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_read_tag_fifo_1_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_RD_TAG_1) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_read_tag_fifo_2_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_RD_TAG_2) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_read_tag_fifo_3_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_RD_TAG_3) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_write_tag_fifo_0_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_WR_TAG_0) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_write_tag_fifo_1_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_WR_TAG_1) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_write_tag_fifo_2_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_WR_TAG_2) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_write_tag_fifo_3_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_WR_TAG_3) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(512 * 25) / 100};
      bins fill_level_50_pct = {(512 * 50) / 100};
      bins fill_level_75_pct = {(512 * 75) / 100};
      bins fill_level_100_pct = {512};
    }

    cp_fe_egress_ar_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_EGRESS_AR) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(64 * 25) / 100};
      bins fill_level_50_pct = {(64 * 50) / 100};
      bins fill_level_75_pct = {(64 * 75) / 100};
      bins fill_level_100_pct = {64};
    }

    cp_fe_egress_w_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_EGRESS_W) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(64 * 25) / 100};
      bins fill_level_50_pct = {(64 * 50) / 100};
      bins fill_level_75_pct = {(64 * 75) / 100};
      bins fill_level_100_pct = {64};
    }

    cp_fe_egress_aw_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_EGRESS_AW) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(64 * 25) / 100};
      bins fill_level_50_pct = {(64 * 50) / 100};
      bins fill_level_75_pct = {(64 * 75) / 100};
      bins fill_level_100_pct = {64};
    }

    cp_fe_ingress_b_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_INGRESS_B) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(64 * 25) / 100};
      bins fill_level_50_pct = {(64 * 50) / 100};
      bins fill_level_75_pct = {(64 * 75) / 100};
      bins fill_level_100_pct = {64};
    }

    cp_fe_ingress_rresp_fill_level: coverpoint fill_level
      iff (sample_valid && fifo_id == FE_FILL_INGRESS_RRESP) {
      bins fill_level_0_pct = {0};
      bins fill_level_25_pct = {(64 * 25) / 100};
      bins fill_level_50_pct = {(64 * 50) / 100};
      bins fill_level_75_pct = {(64 * 75) / 100};
      bins fill_level_100_pct = {64};
    }
  endgroup : cg_fe_fill_levels

 covergroup cg_fe_tag_fifo with function sample(
  input bit          is_write,
  input int unsigned axi_id
);
  option.per_instance = 1;

  cp_fe_tagfifo_arid: coverpoint axi_id iff (!is_write) {
    bins rd_fifo0 = {0};
    bins rd_fifo1 = {1};
    bins rd_fifo2 = {2};
    bins rd_fifo3 = {3};
  }

  cp_fe_tagfifo_awid: coverpoint axi_id iff (is_write) {
    bins wr_fifo0 = {0};
    bins wr_fifo1 = {1};
    bins wr_fifo2 = {2};
    bins wr_fifo3 = {3};
  }
endgroup : cg_fe_tag_fifo

  // -------------------------------------------------------------------------
  // APB configuration coverage
  // -------------------------------------------------------------------------
  covergroup cg_fe_apb_registers with function sample(
    input bit config_sample,
    input bit irq_enable_sample,
    input bit error_status_sample
  );
    option.per_instance = 1;

    cp_fe_flit_mode: coverpoint flit_mode_inst iff (config_sample) {
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    cp_fe_combining_rd_enable: coverpoint combining_rd_enable_inst iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_combining_wr_enable: coverpoint combining_wr_enable_inst iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_shared_opcode_check_enable: coverpoint unsupported_opcode_check_enable_inst iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_shared_field_check_enable: coverpoint unsupported_field_check_enable_inst iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_crc_invert_enable: coverpoint poison_crc_invert_enable_inst iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_mem_app_pending: coverpoint mem_app_pending_enable iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_nxm_enable: coverpoint nxm_enable iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_poison_enable: coverpoint poison_enable iff (config_sample) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    // -------------------------------------------------------------------------
    // HDM Decoder Coverpoints (Conditioned on is_hdm_update)
    // -------------------------------------------------------------------------
    cp_fe_hdm_idx: coverpoint current_hdm_idx iff (config_sample && is_hdm_update) {
      bins decoders[] = {[0:9]};
    }

    cp_fe_hdm_hpa_base: coverpoint current_hpa_base iff (config_sample && is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }
    
    cp_fe_hdm_hpa_top: coverpoint current_hpa_top iff (config_sample && is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }
    
    cp_fe_hdm_dpa_base: coverpoint current_dpa_base iff (config_sample && is_hdm_update) {
      //bins unconfigured = {24'h0};
      bins configured[12]   = {[24'h0:24'hFF_FFFF]};
    }

    // -------------------------------------------------------------------------
    // Interrupt Enables Coverpoints
    // -------------------------------------------------------------------------
    cp_fe_hdm_miss_rd      : coverpoint interrupt_enables_inst[0] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_hdm_miss_wr      : coverpoint interrupt_enables_inst[1] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_perm_err_rd      : coverpoint interrupt_enables_inst[2] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_perm_err_wr      : coverpoint interrupt_enables_inst[3] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_tag_range_rd     : coverpoint interrupt_enables_inst[4] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_tag_range_wr     : coverpoint interrupt_enables_inst[5] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_unsupported_req  : coverpoint interrupt_enables_inst[6] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_unsupported_rwd  : coverpoint interrupt_enables_inst[7] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_poison_recv      : coverpoint interrupt_enables_inst[8] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_rd_err    : coverpoint interrupt_enables_inst[9] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_wr_err    : coverpoint interrupt_enables_inst[10] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_rd_chk    : coverpoint interrupt_enables_inst[11] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_parity_wr_chk    : coverpoint interrupt_enables_inst[12] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_egress_rd_thresh : coverpoint interrupt_enables_inst[13] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_egress_wr_thresh : coverpoint interrupt_enables_inst[14] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_ndr_credit_ovf   : coverpoint interrupt_enables_inst[15] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_drs_credit_ovf   : coverpoint interrupt_enables_inst[16] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_dcd_ded          : coverpoint interrupt_enables_inst[17] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }
    cp_fe_irq_global_en    : coverpoint interrupt_enables_inst[18] iff (irq_enable_sample) { bins disabled = {0}; bins enabled = {1}; }

    // -------------------------------------------------------------------------
    // WR_Token Bucket / WR_Rate Limiter Coverpoints
    // Base address 'h80c00
    // -------------------------------------------------------------------------
    cp_fe_wr_refill_period: coverpoint wr_refill_period iff (config_sample) {
      bins periods[4] = {[16'h0000:16'hFFFF]}; 
    }

   cp_fe_wr_capacity: coverpoint wr_capacity iff (config_sample) {
     bins capacities[4] = {[16'h0000:16'hFFFF]}; 
   }

   cp_fe_wr_refill_rate: coverpoint wr_refill_rate iff (config_sample) {
     bins rates[4] = {[5'h00:5'h1F]}; // 5-bit width
   }

   cp_fe_wr_reset_token: coverpoint wr_reset_token iff (config_sample) {
     bins deasserted = {1'b0};
     bins asserted   = {1'b1};
   }

    // -------------------------------------------------------------------------
    // RD_Token Bucket / RD_Rate Limiter Coverpoints
    // Base address 'h80d00
    // -------------------------------------------------------------------------
    cp_fe_rd_refill_period: coverpoint rd_refill_period iff (config_sample) {
      bins periods[4] = {[16'h0000:16'hFFFF]}; 
    }

   cp_fe_rd_capacity: coverpoint rd_capacity iff (config_sample) {
     bins capacities[4] = {[16'h0000:16'hFFFF]}; 
   }

   cp_fe_rd_refill_rate: coverpoint rd_refill_rate iff (config_sample) {
     bins rates[4] = {[5'h00:5'h1F]}; // 5-bit width
   }

   cp_fe_rd_reset_token: coverpoint rd_reset_token iff (config_sample) {
     bins deasserted = {1'b0};
     bins asserted   = {1'b1};
   }
    
    // -------------------------------------------------------------------------
    // FE Error Status Register Coverpoints
    // -------------------------------------------------------------------------
    cp_fe_hdm_miss_rd_status      : coverpoint fe_error_status_inst[0] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_hdm_miss_wr_status      : coverpoint fe_error_status_inst[1] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_perm_error_rd_status    : coverpoint fe_error_status_inst[2] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_perm_error_wr_status    : coverpoint fe_error_status_inst[3] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_tag_range_rd_status     : coverpoint fe_error_status_inst[4] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_tag_range_wr_status     : coverpoint fe_error_status_inst[5] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_unsupported_req_status  : coverpoint fe_error_status_inst[6] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_unsupported_rwd_status  : coverpoint fe_error_status_inst[7] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_poison_received_status  : coverpoint fe_error_status_inst[8] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_rd_err_status    : coverpoint fe_error_status_inst[9] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_wr_err_status    : coverpoint fe_error_status_inst[10] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_rd_chk_status    : coverpoint fe_error_status_inst[11] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_parity_wr_chk_status    : coverpoint fe_error_status_inst[12] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_egress_rd_thresh_status : coverpoint fe_error_status_inst[13] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_egress_wr_thresh_status : coverpoint (|fe_error_status_inst[15:14]) iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_ndr_credit_ovf_status   : coverpoint fe_error_status_inst[16] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_drs_credit_ovf_status   : coverpoint fe_error_status_inst[17] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }
    cp_fe_dcd_ded_status          : coverpoint fe_error_status_inst[18] iff (error_status_sample) { bins clean = {0}; bins error = {1}; }


    // Cross Coverage: Verify the reset token triggers across various capacities
    cr_fe_wr_capacity_reset: cross cp_fe_wr_capacity, cp_fe_wr_reset_token iff (config_sample);
    cr_fe_rd_capacity_reset: cross cp_fe_rd_capacity, cp_fe_rd_reset_token iff (config_sample);

    cr_fe_parser_configuration: cross
      cp_fe_flit_mode,
      cp_fe_combining_rd_enable,
      cp_fe_combining_wr_enable iff (config_sample);

    cr_fe_error_configuration: cross
      cp_fe_shared_opcode_check_enable,
      cp_fe_shared_field_check_enable,
      cp_fe_crc_invert_enable iff (config_sample);

    // Cross the index with the base to ensure every individual decoder (0-9) gets a valid HPA configuration
    cr_fe_idx_hpa_base: cross cp_fe_hdm_idx, cp_fe_hdm_hpa_base iff (config_sample);
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
  // Channel selector: AW=0, AR=1, W=2, B=3, R=4.
  covergroup cg_fe_axi_user with function sample(
    input bit [2:0] channel,
    input bit [31:0] user_value,
    input bit [7:0] paired_request_user = 8'h0,
    input bit [7:0] paired_buser = 8'h0
  );
    option.per_instance = 1;
    cp_fe_aw_user: coverpoint ((channel == 3'd5) ? paired_request_user : user_value[7:0]) iff (channel inside {3'd0, 3'd5}) {
      bins user_80 = {32'h80};
      bins user_0 = {32'h0};
      bins other = default;
    }
    cp_fe_ar_user: coverpoint ((channel == 3'd6) ? paired_request_user : user_value[7:0]) iff (channel inside {3'd1, 3'd6}) {
      bins user_80 = {32'h80};
      bins user_0 = {32'h0};
      bins other = default;
    }
    cp_fe_w_user: coverpoint user_value iff (channel == 3'd2) {
      bins user_80 = {32'h80};
      bins user_0 = {32'h0};
      bins other = default;
    }
    cp_fe_b_user: coverpoint ((channel == 3'd7) ? paired_buser : user_value[7:0]) iff (channel inside {3'd3, 3'd5, 3'd7}) {
      bins user_80 = {32'h80};
      bins user_0 = {32'h0};
      bins other = default;
    }
    cp_fe_r_user: coverpoint user_value iff (channel inside {3'd4, 3'd6, 3'd7}) {
      bins user_80 = {32'h80};
      bins user_0 = {32'h0};
      bins other = default;
    }
    // sample_pending_response_priority() supplies this cross because it matches
    // AW and B transactions by AXI ID and order within that ID. Channel 5 samples
    // the saved AWUSER and BUSER together, even when they arrive at different times.
    aw_user_x_b_user: cross cp_fe_aw_user, cp_fe_b_user iff (channel == 3'd5) {
      bins user_80_x_0 = binsof(cp_fe_aw_user.user_80) && binsof(cp_fe_b_user.user_0);
      bins user_0_x_80 = binsof(cp_fe_aw_user.user_0) && binsof(cp_fe_b_user.user_80);
      bins user_80_x_80 = binsof(cp_fe_aw_user.user_80) && binsof(cp_fe_b_user.user_80);
      bins user_0_x_0 = binsof(cp_fe_aw_user.user_0) && binsof(cp_fe_b_user.user_0);
    }
    // sample_pending_response_priority() likewise supplies matched ARUSER and
    // RUSER with channel 6. It retains ARUSER until RLAST so each response beat
    // is paired with its own request, rather than the latest observed ARUSER.
    ar_user_x_r_user: cross cp_fe_ar_user, cp_fe_r_user iff (channel == 3'd6) {
      bins user_80_x_0 = binsof(cp_fe_ar_user.user_80) && binsof(cp_fe_r_user.user_0);
      bins user_0_x_80 = binsof(cp_fe_ar_user.user_0) && binsof(cp_fe_r_user.user_80);
      bins user_80_x_80 = binsof(cp_fe_ar_user.user_80) && binsof(cp_fe_r_user.user_80);
      bins user_0_x_0 = binsof(cp_fe_ar_user.user_0) && binsof(cp_fe_r_user.user_0);
    }
    // Channel 7 pairs the first observed B response with the first observed R
    // beat, then the second with the second, independently of their AXI IDs.
    b_user_x_r_user: cross cp_fe_b_user, cp_fe_r_user iff (channel == 3'd7) {
      bins user_0_x_0 = binsof(cp_fe_b_user.user_0) && binsof(cp_fe_r_user.user_0);
      bins user_80_x_0 = binsof(cp_fe_b_user.user_80) && binsof(cp_fe_r_user.user_0);
      bins user_0_x_80 = binsof(cp_fe_b_user.user_0) && binsof(cp_fe_r_user.user_80);
      bins user_80_x_80 = binsof(cp_fe_b_user.user_80) && binsof(cp_fe_r_user.user_80);
    }
  endgroup : cg_fe_axi_user

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
  covergroup cg_fe_axi_requestor_rd_parity with function sample(
    input bit is_ingress, input logic parity_error
  );
    option.per_instance = 1;
    cp_fe_axi_egress_parity: coverpoint parity_error iff (!is_ingress) {
      bins egress_req_parity_uncorrupted = {1'b0};
      bins egress_req_parity_corrupted   = {1'b1};
    }
    cp_fe_axi_ingress_parity: coverpoint parity_error iff (is_ingress) {
      bins ingress_rd_parity_uncorrupted = {1'b0};
      bins ingress_rd_parity_corrupted   = {1'b1};
    }
  endgroup : cg_fe_axi_requestor_rd_parity

  covergroup cg_fe_axi_requestor_wr_parity with function sample(
    input bit is_ingress, input logic parity_error
  );
    option.per_instance = 1;
    cp_fe_axi_egress_parity: coverpoint parity_error iff (!is_ingress) {
      bins egress_rwd_parity_uncorrupted = {1'b0};
      bins egress_rwd_parity_corrupted   = {1'b1};
    }
    cp_fe_axi_ingress_parity: coverpoint parity_error iff (is_ingress) {
      bins ingress_wr_parity_uncorrupted = {1'b0};
      bins ingress_wr_parity_corrupted   = {1'b1};
    }
  endgroup : cg_fe_axi_requestor_wr_parity

  // Matched scoreboard error type and observed AXI USER[7].
  covergroup cg_fe_axi_requestor_error with function sample(
    input bit [1:0] err_resp_type,
    input logic    erruser
  );
    option.per_instance = 1;
    cp_fe_err_response_type: coverpoint err_resp_type {
      bins no_error = {2'b00};
      bins error    = {2'b01, 2'b10, 2'b11};
    }

    cp_fe_erruser: coverpoint erruser {
      bins clear = {1'b0};
      bins set   = {1'b1};
    }

    cr_fe_erruser_x_ert:
      cross cp_fe_err_response_type, cp_fe_erruser {
        bins no_error_user_clear =
          binsof(cp_fe_err_response_type.no_error) &&
          binsof(cp_fe_erruser.clear);
        bins error_user_set =
          binsof(cp_fe_err_response_type.error) &&
          binsof(cp_fe_erruser.set);
        illegal_bins no_error_user_set =
          binsof(cp_fe_err_response_type.no_error) &&
          binsof(cp_fe_erruser.set);
        illegal_bins error_user_clear =
          binsof(cp_fe_err_response_type.error) &&
          binsof(cp_fe_erruser.clear);
      }
  endgroup : cg_fe_axi_requestor_error

    // Sample the local per-lane scoreboard error-response shadow.
  covergroup cg_fe_hdm_decoder_rd with function sample(input hdm_cov_event_t e);
    option.per_instance = 1;

    cp_fe_dcd_enable: coverpoint dcd_enable iff (e.packet_valid) {
      bins enable_patterns[] = {[5'd0:5'd31]};
    }

    cp_fe_hdm_region_0_programmed:
      coverpoint e.programmed_regions[0]
      iff (e.programming_sample_valid && e.programmed_regions[0]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_1_programmed:
      coverpoint e.programmed_regions[1]
      iff (e.programming_sample_valid && e.programmed_regions[1]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_2_programmed:
      coverpoint e.programmed_regions[2]
      iff (e.programming_sample_valid && e.programmed_regions[2]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_3_programmed:
      coverpoint e.programmed_regions[3]
      iff (e.programming_sample_valid && e.programmed_regions[3]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_4_programmed:
      coverpoint e.programmed_regions[4]
      iff (e.programming_sample_valid && e.programmed_regions[4]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_5_programmed:
      coverpoint e.programmed_regions[5]
      iff (e.programming_sample_valid && e.programmed_regions[5]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_6_programmed:
      coverpoint e.programmed_regions[6]
      iff (e.programming_sample_valid && e.programmed_regions[6]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_7_programmed:
      coverpoint e.programmed_regions[7]
      iff (e.programming_sample_valid && e.programmed_regions[7]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_8_programmed:
      coverpoint e.programmed_regions[8]
      iff (e.programming_sample_valid && e.programmed_regions[8]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_9_programmed:
      coverpoint e.programmed_regions[9]
      iff (e.programming_sample_valid && e.programmed_regions[9]) {
      bins programmed = {1'b1};
    }

    cp_fe_programmed_region_a: coverpoint e.programmed_region_a
      iff (e.programmed_pair_valid) {
      bins regions[] = {[0:9]};
    }
    cp_fe_programmed_region_b: coverpoint e.programmed_region_b
      iff (e.programmed_pair_valid) {
      bins regions[] = {[0:9]};
    }
    cr_fe_programmed_region_pairs:
      cross cp_fe_programmed_region_a, cp_fe_programmed_region_b
      iff (e.programmed_pair_valid);

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

    cp_fe_tag_range: coverpoint {e.tag_position, e.tag_range_passed}
      iff (e.packet_valid && e.tag_bounds_valid && e.tag_range_checked) {
      wildcard bins tag_with_in_range = {4'b???1};
      wildcard bins tag_out_of_range  = {4'b???0};
      wildcard bins tag_at_low         = {4'b1???};
      wildcard bins tag_at_high        = {4'b?1??};
      wildcard bins tag_between_bounds = {4'b??1?};
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

    cp_fe_dcd_enable: coverpoint dcd_enable iff (e.packet_valid) {
      bins enable_patterns[] = {[5'd0:5'd31]};
    }

    cp_fe_hdm_region_0_programmed:
      coverpoint e.programmed_regions[0]
      iff (e.programming_sample_valid && e.programmed_regions[0]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_1_programmed:
      coverpoint e.programmed_regions[1]
      iff (e.programming_sample_valid && e.programmed_regions[1]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_2_programmed:
      coverpoint e.programmed_regions[2]
      iff (e.programming_sample_valid && e.programmed_regions[2]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_3_programmed:
      coverpoint e.programmed_regions[3]
      iff (e.programming_sample_valid && e.programmed_regions[3]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_4_programmed:
      coverpoint e.programmed_regions[4]
      iff (e.programming_sample_valid && e.programmed_regions[4]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_5_programmed:
      coverpoint e.programmed_regions[5]
      iff (e.programming_sample_valid && e.programmed_regions[5]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_6_programmed:
      coverpoint e.programmed_regions[6]
      iff (e.programming_sample_valid && e.programmed_regions[6]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_7_programmed:
      coverpoint e.programmed_regions[7]
      iff (e.programming_sample_valid && e.programmed_regions[7]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_8_programmed:
      coverpoint e.programmed_regions[8]
      iff (e.programming_sample_valid && e.programmed_regions[8]) {
      bins programmed = {1'b1};
    }

    cp_fe_hdm_region_9_programmed:
      coverpoint e.programmed_regions[9]
      iff (e.programming_sample_valid && e.programmed_regions[9]) {
      bins programmed = {1'b1};
    }

    cp_fe_programmed_region_a: coverpoint e.programmed_region_a
      iff (e.programmed_pair_valid) {
      bins regions[] = {[0:9]};
    }
    cp_fe_programmed_region_b: coverpoint e.programmed_region_b
      iff (e.programmed_pair_valid) {
      bins regions[] = {[0:9]};
    }
    cr_fe_programmed_region_pairs:
      cross cp_fe_programmed_region_a, cp_fe_programmed_region_b
      iff (e.programmed_pair_valid);

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

    cp_fe_tag_range: coverpoint {e.tag_position, e.tag_range_passed}
      iff (e.packet_valid && e.tag_bounds_valid && e.tag_range_checked) {
      wildcard bins tag_with_in_range = {4'b???1};
      wildcard bins tag_out_of_range  = {4'b???0};
      wildcard bins tag_at_low         = {4'b1???};
      wildcard bins tag_at_high        = {4'b?1??};
      wildcard bins tag_between_bounds = {4'b??1?};
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
    input bit       response_user7,
    input bit       priority_sample = 1'b0,
    input logic     request_user7 = 1'b0
  );
    option.per_instance = 1;

    cp_fe_bresp: coverpoint response iff (!response_is_read) {
      bins okay   = {2'b01};
      bins slverr = {2'b11};
      illegal_bins unsupported = {2'b00, 2'b10};
    }

    cp_fe_bid: coverpoint response_id iff (!response_is_read) {
      bins id_0 = {8'd0};
      bins id_1 = {8'd1};
      bins id_2 = {8'd2};
      bins id_3 = {8'd3};
      illegal_bins unsupported_id = default;
    }

    cp_fe_rresp: coverpoint response iff (response_is_read) {
      bins okay   = {2'b01};
      bins slverr = {2'b11};
      illegal_bins unsupported = {2'b00, 2'b10};
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
      iff (response == 2'b01) {
      bins buser7_0 = {2'b00};
      bins buser7_1 = {2'b01};
      bins ruser7_0 = {2'b10};
      bins ruser7_1 = {2'b11};
    }
    cp_fe_priority_awuser7: coverpoint request_user7
      iff (priority_sample && !response_is_read) {
      bins clear = {0};
      bins set = {1};
    }
    cp_fe_priority_aruser7: coverpoint request_user7
      iff (priority_sample && response_is_read) {
      bins clear = {0};
      bins set = {1};
    }
    cr_fe_nonokay_wr_priority: cross cp_fe_priority_awuser7, cp_fe_bresp
      iff (priority_sample && !response_is_read) {
      ignore_bins okay_response = binsof(cp_fe_bresp.okay);
    }
    cr_fe_nonokay_rd_priority: cross cp_fe_priority_aruser7, cp_fe_rresp
      iff (priority_sample && response_is_read) {
      ignore_bins okay_response = binsof(cp_fe_rresp.okay);
    }
  endgroup : cg_fe_axi_responder

  // -------------------------------------------------------------------------
  // FE error and interrupt coverage
  // -------------------------------------------------------------------------
  covergroup cg_fe_wr_rate_limiter with function sample(
    input bit [15:0] refill_period,
    input bit [15:0] capacity,
    input bit [4:0]  refill_rate,
    input bit       reset_token
  );
    option.per_instance = 1;
    cp_fe_wr_refill_period: coverpoint refill_period {
      bins periods[4] = {[16'h0000:16'hFFFF]};
    }
    cp_fe_wr_capacity: coverpoint capacity {
      bins capacities[4] = {[16'h0000:16'hFFFF]};
    }
    cp_fe_wr_refill_rate: coverpoint refill_rate {
      bins rates[4] = {[5'h00:5'h1F]};
    }
    cp_fe_wr_reset_token: coverpoint reset_token {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
    }
  endgroup : cg_fe_wr_rate_limiter

  covergroup cg_fe_rd_rate_limiter with function sample(
    input bit [15:0] refill_period,
    input bit [15:0] capacity,
    input bit [4:0]  refill_rate,
    input bit       reset_token
  );
    option.per_instance = 1;
    cp_fe_rd_refill_period: coverpoint refill_period {
      bins periods[4] = {[16'h0000:16'hFFFF]};
    }
    cp_fe_rd_capacity: coverpoint capacity {
      bins capacities[4] = {[16'h0000:16'hFFFF]};
    }
    cp_fe_rd_refill_rate: coverpoint refill_rate {
      bins rates[4] = {[5'h00:5'h1F]};
    }
    cp_fe_rd_reset_token: coverpoint reset_token {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
    }
  endgroup : cg_fe_rd_rate_limiter

  // Each physical lane owns a separate instance and transition history.
  cg_fe_tag_toggle req_tag_toggle_cg[4];
  cg_fe_tag_toggle rwd_tag_toggle_cg[2];

  covergroup cg_fe_error_interrupt with function sample(
    input bit       source_valid,
    input bit [4:0] error_source,
    input bit       source_irq_enable,
    input bit       irq_global_enable,
    input bit [1:0] multi_error_event,
    input bit       source_irq_valid,
    input bit       irq_line,
    input bit       irq_line_valid
  );
    option.per_instance = 1;

    cp_fe_error_source: coverpoint error_source iff (source_valid) {
      bins hdm_miss_rd = {5'd0};
      bins hdm_miss_wr = {5'd1};
      bins permission_error_rd = {5'd2};
      bins permission_error_wr = {5'd3};
      bins tag_range_error_rd = {5'd4};
      bins tag_range_error_wr = {5'd5};
      bins unsupported_req = {5'd6};
      bins unsupported_rwd = {5'd7};
      bins poison_received = {5'd8};
      bins parity_rd_error = {5'd9};
      bins parity_wr_error = {5'd10};
      bins parity_rd_chk = {5'd11};
      bins parity_wr_chk = {5'd12};
      bins egress_rd_threshold = {5'd13};
      bins egress_aw_threshold = {5'd14};
      bins egress_w_threshold = {5'd15};
      bins ndr_credit_ovf = {5'd16};
      bins drs_credit_ovf = {5'd17};
      bins dcd_ded = {5'd18};
      bins axi_rresp_rlast_0 = {5'd19};
    }

    //To track the flit_mode that is used in cr_flit_x_error_src
    cp_fe_error_flit_mode: coverpoint flit_mode_inst
      iff (source_valid) {
      bins mode_68b  = {1'b0};
      bins mode_256b = {1'b1};
    }

    // Event encoding is generated by sample_error_interrupt():
    //   1 = at least three error-status bits active together
    //   2 = exactly one previously-active bit cleared while others remain
    cp_fe_multi_error: coverpoint multi_error_event
      iff (multi_error_event != 2'd0) {
      bins three_or_more_simultaneous = {2'd1};
      bins cleared_one_at_a_time      = {2'd2};
    }

    cp_fe_source_irq_enable: coverpoint source_irq_enable iff (source_valid && source_irq_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_global_irq_enable: coverpoint irq_global_enable iff (source_valid && source_irq_valid) {
      bins disabled = {1'b0};
      bins enabled  = {1'b1};
    }

    cp_fe_irq_line: coverpoint irq_line
      iff (source_valid && source_irq_valid && irq_line_valid) {
      bins deasserted = {1'b0};
      bins asserted   = {1'b1};
    }

    // IRQ is shared: another enabled source may assert it for a masked source.
    // Cross each asserted status source with its mapped enable and observed IRQ.
    // AW/W threshold sources share enable bit 14, as defined by the RDL.
    cr_fe_error_status_x_irq_enable:
      cross flit_mode_inst, cp_fe_error_source, cp_fe_source_irq_enable, cp_fe_irq_line
      iff (source_valid && source_irq_valid && irq_line_valid) {
      ignore_bins no_irq_enable = binsof(cp_fe_error_source.axi_rresp_rlast_0);
    }
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
  extern task sample_irq_status_from_fifo();
  //extern function void sample_all_credits();
  extern function void sample_combining_eligibility(
    kb_cxl_m2s_snap snap, bit is_write, int unsigned first_lane
  );
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
  extern task apb_configure(kb_apb3_vendor_txn_t txn);
  extern function void convert_to_aw(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_ar(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_w(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_b(kb_axi4_vendor_txn_t txn);
  extern function void convert_to_r(kb_axi4_vendor_txn_t txn);
  extern function void sample_error_interrupt(
    bit [19:0] status_value, logic irq_line, bit irq_line_valid);
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
  extern task sample_fill_levels_from_regblock();
  extern task peek_and_sample_fill_register(
    input uvm_reg occupancy_reg,
    input fe_fill_fifo_id_e first_fifo_id,
    input int unsigned field_width,
    input int unsigned field_count
  );
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
  extern function void sample_pending_axi_errors(bit is_write);
  extern function void clear_pending_axi_errors();
  extern function bit [2:0] classify_tag_position(
    bit [15:0] tag_value, bit [15:0] tag_low, bit [15:0] tag_high
  );
  extern function void sample_hdm_event(input hdm_cov_event_t sample_data);
  extern function void sample_hdm_region_programming();
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

  // IRQ error-status FIFO
  irq_fifo         = new("h_irq_fifo", this);

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
  cg_fe_combining_eligibility              = new();
  cg_fe_apb_registers             = new();
  cg_fe_credit_manager                 = new();
  cg_fe_axi_user = new();
  cg_fe_axi_requestor_aw                 = new();
  cg_fe_axi_requestor_w                  = new();
  cg_fe_axi_requestor_rd_parity   = new();
  cg_fe_axi_requestor_wr_parity   = new();
  cg_fe_axi_requestor_error       = new();
  cg_fe_hdm_decoder_rd            = new();
  cg_fe_hdm_decoder_wr            = new();
  cg_fe_axi_responder                    = new();
  cg_fe_error_interrupt                  = new();
  cg_fe_axi_requestor_ar                 = new();
  cg_fe_tag_fifo                         = new();
  cg_fe_fill_levels                      = new();
  cg_fe_egress_queue                     = new();
  cg_fe_wr_rate_limiter                  = new();
  cg_fe_rd_rate_limiter                  = new();
  foreach (req_tag_toggle_cg[i])
    req_tag_toggle_cg[i] = new();
  foreach (rwd_tag_toggle_cg[i])
    rwd_tag_toggle_cg[i] = new();

  reset_seen = 1'b0;
  fe_error_status_prev       = '0;
  fe_error_status_prev_valid = 1'b0;
  credit_egress_state        = 3'd0;
  credit_ingress_state       = 3'd0;
  reset_config_shadow();

  // Configuration coverage starts with the first valid CXL packet.

  
endfunction : new

function void kb_fwd_eng_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);
  void'(uvm_config_db#(bit)::get(this, "", "allow_extended_read_response",
                               allow_extended_read_response));

  if (!uvm_config_db#(kb_fwd_eng_env_cfg)::get(this, "", "env_cfg", h_env_cfg))
    `uvm_fatal(get_type_name(), "Missing env_cfg; cannot sample credit counters from the RAL model")

  if (!h_env_cfg.has_regblock_en || h_env_cfg.h_regblock == null)
    `uvm_fatal(get_type_name(), "RAL model is disabled or h_regblock is null")
endfunction : build_phase

function void kb_fwd_eng_coverage::reset_config_shadow();
  hdm_config_pending = '0;
  is_hdm_update = 1'b0;
  wr_refill_period = 16'h0001;
  rd_refill_period = 16'h0001;
  wr_refill_rate = 5'h01;
  rd_refill_rate = 5'h01;
  wr_capacity = '0;
  rd_capacity = '0;
  wr_reset_token = 1'b0;
  rd_reset_token = 1'b0;
  wr_rate_reset_pending = 1'b0;
  rd_rate_reset_pending = 1'b0;
  
  br_buser_q.delete();
  br_ruser_q.delete();
  reset_hdm_tag_queues();
  foreach (priority_aw_q[i]) begin
    priority_aw_q[i].delete();
    priority_ar_q[i].delete();
    priority_b_q[i].delete();
    priority_r_q[i].delete();
  end
  encap_rd_ert_q.delete();
  encap_wr_ert_q.delete();
  encap_drs_config_q.delete();
  encap_ndr_config_q.delete();
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
  flit_mode_inst                       = 1'b1;
  combining_rd_enable_inst             = 1'b1;
  combining_wr_enable_inst             = 1'b1;
  unsupported_opcode_check_enable_inst = 1'b1;
  unsupported_field_check_enable_inst  = 1'b1;
  tag_range_check                     = 1'b0;
  dcd_enable                          = 5'b00000;
  poison_crc_invert_enable_inst        = 1'b1;
  nxm_enable                           = 1'b0;
  poison_enable                        = 1'b0;
  fe_irq_line_inst                     = 1'b0;
  fe_irq_line_valid                    = 1'b0;
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

    sample_irq_status_from_fifo();
  join_none
endtask : run_phase

// The IRQ FIFO carries status only. Use the latest IRQ line observation from
// the CXL monitor for the other two sample arguments.
task kb_fwd_eng_coverage::sample_irq_status_from_fifo();
  logic [19:0] status_from_irq;

  forever begin
    irq_fifo.get(status_from_irq);

    if (reset_seen) continue;

    sample_error_interrupt(
      status_from_irq,
      fe_irq_line_inst,
      fe_irq_line_valid
    );
    cg_fe_apb_registers.sample(1'b0, 1'b0, 1'b1);
  end
endtask : sample_irq_status_from_fifo

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
    bit req_present;
    bit rwd_present;
    bit cxl_packet_present;

    cxl_m2s_bus_fifo.get(h_cxl_m2s_items);
    cxl_s2m_bus_fifo.get(h_cxl_s2m_items);

    // Capture idle cycles too. The monitor must populate the IRQ field.
    fe_irq_line_inst = h_cxl_s2m_items.irq_line;
    fe_irq_line_valid = (h_cxl_s2m_items.rst_n === 1'b1) &&
                       (h_cxl_m2s_items.rst_n === 1'b1) &&
                       !$isunknown(h_cxl_s2m_items.irq_line);

    sample_credit_manager_fsm(
      h_cxl_m2s_items.rst_n,
      h_cxl_m2s_items.mst_req,
      h_cxl_m2s_items.mst_ack,
      h_cxl_s2m_items.slv_req,
      h_cxl_s2m_items.slv_ack
    );

    if (!h_cxl_m2s_items.rst_n) begin
      clear_pending_axi_errors();
      if (!reset_seen) begin
        reset_config_shadow();

        
        reset_seen = 1'b1;
      end
      // Synchronize rotation pointers on reset; both helpers return without
      // sampling packet or combining coverpoints while rst_n is low.
      sample_req_inputs(h_cxl_m2s_items);
      sample_rwd_inputs(h_cxl_m2s_items);
      continue;
    end

    reset_seen = 1'b0;
    req_present = 1'b0;
    rwd_present = 1'b0;
    for (int i = 0; i < (flit_mode_inst ? 4 : 2); i++)
      req_present |= h_cxl_m2s_items.req_items[i].valid;
    for (int i = 0; i < (flit_mode_inst ? 2 : 1); i++)
      rwd_present |= h_cxl_m2s_items.rwd_items[i].valid;

    cxl_packet_present = req_present || rwd_present;
    foreach (h_cxl_s2m_items.ndr_items[i])
      cxl_packet_present |= h_cxl_s2m_items.ndr_items[i].valid;
    foreach (h_cxl_s2m_items.drc_items[i])
      cxl_packet_present |= h_cxl_s2m_items.drc_items[i].valid;

    if (cxl_packet_present) begin
      // Sample each region updated since the previous packet using its latest shadows.
      if (|hdm_config_pending) begin
        for (int idx = 0; idx < 10; idx++) begin
          if (hdm_config_pending[idx]) begin
            is_hdm_update = 1'b1;
            current_hdm_idx = idx;
            current_hpa_base = reg_hpa_base[idx];
            current_hpa_top = reg_hpa_top[idx];
            current_dpa_base = reg_dpa_base[idx];
            cg_fe_apb_registers.sample(1'b1, 1'b0, 1'b0);
          end
        end
      end else begin
        is_hdm_update = 1'b0;
        cg_fe_apb_registers.sample(1'b1, 1'b0, 1'b0);
      end
      is_hdm_update = 1'b0;
      hdm_config_pending = '0;
      wr_reset_token = 1'b0;
      rd_reset_token = 1'b0;
      sample_egress_backpressure_from_regblock();
    end

    if (req_present) begin
      cg_fe_rd_rate_limiter.sample(
        rd_refill_period, rd_capacity, rd_refill_rate, rd_rate_reset_pending
      );
      rd_rate_reset_pending = 1'b0;
    end
    if (rwd_present) begin
      cg_fe_wr_rate_limiter.sample(
        wr_refill_period, wr_capacity, wr_refill_rate, wr_rate_reset_pending
      );
      wr_rate_reset_pending = 1'b0;
    end
    sample_credit_counters_from_regblock();
    sample_fill_levels_from_regblock();
    sample_hdm_region_counters_from_regblock();
    sample_hdm_region_programming();
    sample_dcd_ecc_counters_from_regblock();
    sample_req_inputs(h_cxl_m2s_items);
    sample_rwd_inputs(h_cxl_m2s_items);
    sample_ndr_outputs(h_cxl_s2m_items);
    sample_drc_outputs(h_cxl_s2m_items);
  end
endtask : cxl_configure


task kb_fwd_eng_coverage::peek_and_sample_fill_register(
  input uvm_reg occupancy_reg,
  input fe_fill_fifo_id_e first_fifo_id,
  input int unsigned field_width,
  input int unsigned field_count
);
  uvm_status_e status;
  uvm_reg_data_t register_value;

  if (occupancy_reg == null) begin
    `uvm_error("FILL_LEVEL_NULL_REG", "FIFO occupancy register handle is null")
    return;
  end
  if (field_width == 0 || field_width > 11 || field_count == 0 ||
      field_width * field_count > occupancy_reg.get_n_bits()) begin
    `uvm_error("FILL_LEVEL_LAYOUT", "Invalid FIFO occupancy field layout")
    return;
  end

  occupancy_reg.peek(status, register_value);
  if (status != UVM_IS_OK) begin
    `uvm_warning("FILL_LEVEL_PEEK_FAILED",
      $sformatf("Skipping failed peek: %s", occupancy_reg.get_full_name()))
    return;
  end

  for (int unsigned field_idx = 0; field_idx < field_count; field_idx++) begin
    logic [10:0] field_value;
    fe_fill_fifo_id_e sampled_fifo_id;
    field_value = '0;
    for (int unsigned bit_idx = 0; bit_idx < field_width; bit_idx++)
      field_value[bit_idx] =
        register_value[field_idx * field_width + bit_idx];

    if ($isunknown(field_value)) begin
      `uvm_warning("FILL_LEVEL_UNKNOWN",
        $sformatf("Skipping unknown occupancy: %s field %0d",
                  occupancy_reg.get_full_name(), field_idx))
      continue;
    end
    sampled_fifo_id = fe_fill_fifo_id_e'(int'(first_fifo_id) + field_idx);
    cg_fe_fill_levels.sample(sampled_fifo_id, field_value, 1'b1);
  end
endtask : peek_and_sample_fill_register

task kb_fwd_eng_coverage::sample_fill_levels_from_regblock();
  if (reset_seen || h_env_cfg == null) return;
  if (!h_env_cfg.has_regblock_en || h_env_cfg.h_regblock == null) return;
  if (h_env_cfg.h_regblock.fifo_occupancy_register == null) begin
    `uvm_error("FILL_LEVEL_NULL_BLOCK", "FIFO occupancy register block is null")
    return;
  end

  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.req_fifo_fill_level,
    FE_FILL_REQ_0, 7, 4
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.rwd_fifo_fill_level,
    FE_FILL_RWD_0, 7, 2
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.s2m_ndr_fifo_0to2_fill_level,
    FE_FILL_NDR_0, 7, 3
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.s2m_ndr_fifo_3to5_fill_level,
    FE_FILL_NDR_3, 7, 3
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.s2m_drs_fifo_0to1_fill_level,
    FE_FILL_DRS_0, 7, 2
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.read_tag_fifo_0to1_fill_level,
    FE_FILL_RD_TAG_0, 11, 2
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.read_tag_fifo_2to3_fill_level,
    FE_FILL_RD_TAG_2, 11, 2
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.write_tag_fifo_0to1_fill_level,
    FE_FILL_WR_TAG_0, 11, 2
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.write_tag_fifo_2to3_fill_level,
    FE_FILL_WR_TAG_2, 11, 2
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.egress_ar_w_aw_fill_level,
    FE_FILL_EGRESS_AR, 8, 3
  );
  peek_and_sample_fill_register(
    h_env_cfg.h_regblock.fifo_occupancy_register.ingress_b_rresp_fill_level,
    FE_FILL_INGRESS_B, 8, 2
  );
endtask : sample_fill_levels_from_regblock

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
      h_env_cfg.h_regblock.hdm_decoder[i].rd_region_hit_count_msb,
      h_env_cfg.h_regblock.hdm_decoder[i].rd_region_hit_count_lsb,
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
      h_env_cfg.h_regblock.hdm_decoder[i].wr_region_hit_count_msb,
      h_env_cfg.h_regblock.hdm_decoder[i].wr_region_hit_count_lsb,
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



// Classify one accepted CXL address against the programmed HDM regions.
// The comparison intentionally uses only HPA[51:28]. The REQ caller removes
// normalized Address[5] before passing the 46-bit HPA[51:6] value here.
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

// Attribute an excluded address to the nearest lower programmed region.
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

function void kb_fwd_eng_coverage::sample_combining_eligibility(
  kb_cxl_m2s_snap snap,
  bit is_write,
  int unsigned first_lane
);
  int unsigned lane_count;
  bit [3:0] valid_mask;
  if (!snap.rst_n) return;
  lane_count = is_write ? (flit_mode_inst ? 2 : 1) :
                         (flit_mode_inst ? 4 : 2);
  if (lane_count < 2 || first_lane >= lane_count) return;
  valid_mask = '0;
  for (int lane = 0; lane < lane_count; lane++) begin
    if (is_write) valid_mask[lane] = snap.rwd_items[lane].valid;
    else          valid_mask[lane] = snap.req_items[lane].valid;
  end
  if (valid_mask == '0) return;

  // Only consecutive physical lanes within this snapshot's packet-order window.
  // Do not pair the final position back to the first position.
  for (int k = 0; k < lane_count - 1; k++) begin
    int unsigned first;
    int unsigned second;
    first = (first_lane + k) % lane_count;
    second = (first + 1) % lane_count;
    // REQ 1->0 is a valid candidate order in 68B mode.

    if (is_write)
      cg_fe_combining_eligibility.sample(
        1'b1, combining_wr_enable_inst, (first == 0) ? 3'd4 : 3'd5,
        snap.rwd_items[first].valid, snap.rwd_items[second].valid,
        snap.rwd_items[first].hpa, snap.rwd_items[second].hpa,
        flit_mode_inst, first_lane[1:0], valid_mask, (k == 0)
      );
    else
      cg_fe_combining_eligibility.sample(
        1'b0, combining_rd_enable_inst,
        (lane_count == 2 && first == 1) ? 3'd6 : 3'(first),
        snap.req_items[first].valid, snap.req_items[second].valid,
        snap.req_items[first].hpa, snap.req_items[second].hpa,
        flit_mode_inst, first_lane[1:0], valid_mask, (k == 0)
      );
  end
endfunction : sample_combining_eligibility

function void kb_fwd_eng_coverage::sample_req_inputs(
  kb_cxl_m2s_snap snap
);
  int unsigned max_req_lanes;
  bit [3:0] current_mask;
  int unsigned ordered_lanes[4];
  int unsigned packet_count;
  int unsigned lane_base;

  // rst_n is active low. Discard partial gap history while reset is asserted.
  if (!snap.rst_n) begin
    req_order_known = 1'b1;
    req_next_lane = 0;
    foreach (req_seen_valid[i]) begin
      req_seen_valid[i] = 1'b0;
      req_gap_cycles[i] = 0;
    end
    return;
  end

  max_req_lanes = flit_mode_inst ? 4 : 2;

  // Preserve all physical valid bits. In 68B mode, an asserted upper-lane
  // valid must remain visible so lane-by-mode illegal bins can detect it.
  current_mask = '0;
  for (int i = 0; i < KB_CXL_MAX_NUM_REQ; i++) begin
    req_valid[i] = snap.m2s_req[i*KB_CXL_REQ_SIZE];
    if (i < 4) current_mask[i] = req_valid[i];
  end

  for (int i = 0; i < KB_CXL_MAX_NUM_REQ; i++) begin
    bit gap_available;
    int unsigned gap_class;
    int unsigned req_concurrency = 0;

    gap_available = 1'b0;
    gap_class = 0;

    if (req_valid[i]) begin
      cg_fe_axi_requestor_rd_parity.sample(1'b0, calculate_req_parity_error(snap, i));
      gap_available = req_seen_valid[i];
      gap_class = req_gap_cycles[i];
      req_concurrency++;

      // 1. Populate the local arrays for the active lane
      
      if (flit_mode_inst) begin
        req_opcode[i]     = snap.req_items[i].opcode;
        req_snp_type[i]   = snap.req_items[i].snp_type;
        req_meta_field[i] = snap.req_items[i].meta_field;
        req_meta_value[i] = snap.req_items[i].meta_value;
        req_tag[i]        = snap.req_items[i].tag;
        req_hpa[i]        = snap.req_items[i].hpa;
        req_ld_id[i]      = snap.req_items[i].ld_id;
      end else begin
        // 68B REQ inserts Address[5] at HPA_OFF. HPA[51:6], poison,
        // and LD-ID are shifted up one bit in the raw lane header.
        req_opcode[i] = snap.m2s_req[
          i*KB_CXL_REQ_SIZE + 1 + KB_CXL_OPCODE_OFF +: KB_CXL_OPCODE_W
        ];
        req_snp_type[i] = snap.m2s_req[
          i*KB_CXL_REQ_SIZE + 1 + KB_CXL_SNP_OFF +: KB_CXL_SNP_W
        ];
        req_meta_field[i] = snap.m2s_req[
          i*KB_CXL_REQ_SIZE + 1 + KB_CXL_META_FLD_OFF +: KB_CXL_META_FLD_W
        ];
        req_meta_value[i] = snap.m2s_req[
          i*KB_CXL_REQ_SIZE + 1 + KB_CXL_META_VAL_OFF +: KB_CXL_META_VAL_W
        ];
        req_tag[i] = snap.m2s_req[
          i*KB_CXL_REQ_SIZE + 1 + KB_CXL_TAG_OFF +: KB_CXL_TAG_WIDTH
        ];
        // Skip the separate Address[5] bit and keep only HPA[51:6].
        req_hpa[i] = snap.m2s_req[
          i*KB_CXL_REQ_SIZE + 1 + KB_CXL_HPA_OFF + 1
          +: KB_CXL_ADDR_BW
        ];
        req_ld_id[i] = snap.m2s_req[
          i*KB_CXL_REQ_SIZE + 1 + KB_CXL_LDID_OFF + 1
          +: KB_CXL_LDID_W
        ];
      end
      req_tag_toggle_cg[i].sample(req_tag[i]);

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
      sample_combining_eligibility(snap, 1'b0, req_cycle_start);
    end
  end
endfunction : sample_req_inputs

function void kb_fwd_eng_coverage::sample_rwd_inputs(
  kb_cxl_m2s_snap snap
);
  int unsigned max_rwd_lanes;
  int unsigned packet_count;
  int unsigned lane_base;

  // rst_n is active low. Discard partial gap history while reset is asserted.
  if (!snap.rst_n) begin
    rwd_order_known = 1'b1;
    rwd_next_lane = 0;
    foreach (rwd_seen_valid[i]) begin
      rwd_seen_valid[i] = 1'b0;
      rwd_gap_cycles[i] = 0;
    end
    return;
  end

  max_rwd_lanes = flit_mode_inst ? 2 : 1;

  // Keep an illegal lane-1 valid visible in 68B mode for the mode cross.
  for (int i = 0; i < KB_CXL_MAX_NUM_RWD; i++)
    rwd_valid[i] = snap.rwd_items[i].valid;

  for (int i = 0; i < KB_CXL_MAX_NUM_RWD; i++) begin

    bit rwd_gap_available;
    int unsigned rwd_gap_class;
    int unsigned rwd_concurrency = 0;

    rwd_gap_available = 1'b0;
    rwd_gap_class = 0;

    if (rwd_valid[i]) begin
      cg_fe_axi_requestor_wr_parity.sample(1'b0, calculate_rwd_parity_error(snap, i));
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
      rwd_tag_toggle_cg[i].sample(rwd_tag[i]);
      rwd_hpa[i]        = snap.rwd_items[i].hpa;
      rwd_ld_id[i]      = snap.rwd_items[i].ld_id;
      rwd_poison[i]     = snap.rwd_items[i].poison;

      sample_hdm_boundary(1'b1, rwd_hpa[i]);
      
      // Preserve RWD data and byte-enable values for future coverage. 
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

    if (packet_count != 0)
      sample_combining_eligibility(snap, 1'b1, rwd_cycle_start);
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
      // 1. Populate the local arrays for the active NDR lane
      encap_ndr_config_q.push_back({nxm_enable, poison_enable});
      sample_pending_encap_errors(1'b1);
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
      // 1. Populate the local arrays for the active DRC lane
      encap_drs_config_q.push_back({nxm_enable, poison_enable});
      sample_pending_encap_errors(1'b0);
      drc_opcode[i]     = snap.drc_items[i].s2m_drc_opcode;
      drc_meta_field[i] = snap.drc_items[i].s2m_meta_field;
      drc_meta_value[i] = snap.drc_items[i].s2m_meta_value;
      drc_tag[i]        = snap.drc_items[i].s2m_tag;
      drc_poison[i]     = snap.drc_items[i].s2m_poison;
      drc_ld_id[i]      = snap.drc_items[i].s2m_ld_id;
      drc_dev_load[i]   = snap.drc_items[i].s2m_dev_load;
      drc_data[i]       = snap.drc_items[i].s2m_data;

      // 2. Sample the covergroup using the local array variables, 
      // explicitly passing the lane index 'i' as the first argument
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
  bit [19:0] status_value,
  logic irq_line,
  bit irq_line_valid
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
    5'd0,
    1'b0,
    interrupt_enables_inst[18],
    multi_error_event,
    1'b0,
    irq_line,
    irq_line_valid
  );

  // Source encoding equals the physical fe_error_status bit index.
  for (int unsigned i = 0; i < 20; i++) begin
    bit source_irq_valid;
    bit source_irq_enable;
    int unsigned irq_idx;

    source_irq_valid = (i < 19);
    irq_idx = 0;
    case (i)
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13: irq_idx = i;
      14, 15: irq_idx = 14; // AW and W share the write-threshold enable.
      16: irq_idx = 15;     // NDR credit overflow.
      17: irq_idx = 16;     // DRS credit overflow.
      18: irq_idx = 17;     // DCD DED.
      default: source_irq_valid = 1'b0;
    endcase
    source_irq_enable = source_irq_valid ? interrupt_enables_inst[irq_idx] : 1'b0;
    if (status_value[i]) begin
      cg_fe_error_interrupt.sample(
        1'b1,
        5'(i),
        source_irq_enable,
        interrupt_enables_inst[18],
        2'd0,
        source_irq_valid,
        irq_line,
        irq_line_valid
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

  // APB updates configuration shadows; CXL packet arrivals sample them.

  if (txn.Direction == DENALI_CDN_APB_DIRECTION_READ) begin
    case (txn.Addr)
      'h81028: begin
      write_egress_queue_devload = txn.Data[3:2];
      read_egress_queue_devload  = txn.Data[1:0];


    end

      'h80a00: begin // fe_error_status: coverage samples status from irq_fifo
        // This register is write-on-clear now. An APB read neither supplies
        // the status coverage event nor clears the local status shadow.
      end
      'h80600: begin // cxl_mem_mst_req: software read-only
        mst_req = txn.Data[0];

        
      end
      'h80604: begin // cxl_mem_mst_ack: hardware/software writable
        mst_ack = txn.Data[0];

        
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

    hdm_config_pending[idx] = 1'b1;
    return;
  end

  case (txn.Addr)
    'h80100: tag_range_check = txn.Data[0]; // dcd_control.tag_enable
    'h80104: dcd_enable = txn.Data[4:0]; // address_range_check_enable

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

    'h80b00: begin
      interrupt_enables_inst = txn.Data[18:0];
      cg_fe_apb_registers.sample(1'b0, 1'b1, 1'b0);
    end

    // Each token-bucket field occupies a separate register.
    'h80c00: wr_refill_period = txn.Data[15:0];
    'h80c04: wr_refill_rate   = txn.Data[4:0];
    'h80c08: wr_capacity      = txn.Data[15:0];
    'h80c0c: begin
      wr_reset_token |= txn.Data[0];
      wr_rate_reset_pending |= txn.Data[0];
    end

    'h80d00: rd_refill_period = txn.Data[15:0];
    'h80d04: rd_refill_rate   = txn.Data[4:0];
    'h80d08: rd_capacity      = txn.Data[15:0];
    'h80d0c: begin
      rd_reset_token |= txn.Data[0];
      rd_rate_reset_pending |= txn.Data[0];
    end

    'h80e00: begin // cxl_encap_control
      mem_app_pending_enable = txn.Data[0];
      nxm_enable             = txn.Data[1];
      poison_enable          = txn.Data[2];
    end

    default: return; // No existing shadow coverage for this address
  endcase


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
      if (i == 0) aw.user = txn.Auser[i][7:0];
    end
    
    if (!reset_seen && aw.valid) cg_fe_axi_user.sample(3'd0, aw.user);
    cg_fe_axi_requestor_aw.sample();
    if (!reset_seen && aw.valid) begin
      priority_aw_q[aw.id].push_back(aw.user);
      sample_pending_response_priority(1'b0, aw.id);
    end

    // SB: enqueue once per observed AXI address transaction.
    wr_erruser_q.push_back('{erruser: aw.user[7],
                              size: aw.size, len: aw.len});
    sample_pending_axi_errors(1'b1);

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
      if (i == 0) ar.user = txn.Auser[i][7:0];
    end
    
    if (!reset_seen && ar.valid) cg_fe_axi_user.sample(3'd1, ar.user);
    cg_fe_axi_requestor_ar.sample();
    if (!reset_seen && ar.valid) begin
      priority_ar_q[ar.id].push_back(ar.user);
      sample_pending_response_priority(1'b1, ar.id);
    end

    // SB: enqueue once per observed AXI address transaction.
    rd_erruser_q.push_back('{erruser: ar.user[7],
                              size: ar.size, len: ar.len});
    sample_pending_axi_errors(1'b0);

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
      if (i == 0) w.user = txn.User[i][31:0];
    end
    
    if (!reset_seen && w.valid) cg_fe_axi_user.sample(3'd2, w.user);
    cg_fe_axi_requestor_w.sample();
  end
endfunction : convert_to_w

function void kb_fwd_eng_coverage::sample_pending_br_users();
  bit [7:0] buser_value;
  bit [31:0] ruser_value;
  if (reset_seen) return;
  while (br_buser_q.size() && br_ruser_q.size()) begin
    buser_value = br_buser_q.pop_front();
    ruser_value = br_ruser_q.pop_front();
    cg_fe_axi_user.sample(3'd7, ruser_value, 8'h0, buser_value);
  end
endfunction : sample_pending_br_users

function void kb_fwd_eng_coverage::sample_pending_response_priority(
  bit is_read, bit [7:0] id
);
  logic [7:0] request_user;
  priority_response_t item;
  if (reset_seen) return;
  if (is_read) begin
    while (priority_ar_q[id].size() && priority_r_q[id].size()) begin
      item = priority_r_q[id].pop_front();
      request_user = priority_ar_q[id][0];
      if (item.last) request_user = priority_ar_q[id].pop_front();
      cg_fe_axi_user.sample(3'd6, item.user_value, request_user);
      cg_fe_axi_responder.sample(1'b1, id, item.resp, item.last, item.user7, 1'b1, request_user[7]);
    end
  end else begin
    while (priority_aw_q[id].size() && priority_b_q[id].size()) begin
      item = priority_b_q[id].pop_front();
      request_user = priority_aw_q[id].pop_front();
      cg_fe_axi_user.sample(3'd5, item.user_value, request_user);
      cg_fe_axi_responder.sample(1'b0, id, item.resp, 1'b0, item.user7, 1'b1, request_user[7]);
    end
  end
endfunction : sample_pending_response_priority

function void kb_fwd_eng_coverage::convert_to_b(kb_axi4_vendor_txn_t txn);
  if (txn.Direction == DENALI_CDN_AXI_DIRECTION_WRITE) begin
    b.valid = 1'b1;
    b.id    = txn.IdTag;
    b.resp  = txn.Resp; // Preserve VIP encoding: OKAY=01, SLVERR=11.
    
    b.user = '0;
    foreach (txn.Buser[i]) begin
      if (i == 0) b.user = txn.Buser[i][7:0];
    end
    if (!reset_seen && b.valid) begin
      cg_fe_axi_user.sample(3'd3, b.user);
      br_buser_q.push_back(b.user);
      sample_pending_br_users();
      priority_b_q[b.id].push_back('{resp: b.resp, last: 1'b1, user7: b.user[7], user_value: b.user});
      sample_pending_response_priority(1'b0, b.id);
    end
    if (!reset_seen && b.valid)
      cg_fe_axi_requestor_wr_parity.sample(1'b1, b.user[7]);
    
  end
endfunction : convert_to_b

function void kb_fwd_eng_coverage::convert_to_r(kb_axi4_vendor_txn_t txn);
  if (txn.Direction == DENALI_CDN_AXI_DIRECTION_READ) begin
    r.valid = 1'b1;
    r.id    = txn.IdTag;
    r.resp  = txn.Resp; // Preserve VIP encoding: OKAY=01, SLVERR=11.
    r.last  = txn.Last;
    
    r.user  = '0;
    r.data  = '0;
    foreach (txn.PhysicalData[i]) begin
      r.data[(i * 32) +: 32] = txn.PhysicalData[i];
    end
    // FE read requests are single-beat; use the burst-level RUSER entry,
    // matching the scoreboard's convert_denali_to_r().
    if (txn.UserSignalArray.size() == 0) begin
      r.valid = 1'b0;
      `uvm_warning("COV_RUSER_MISSING", "Read response has no UserSignalArray entry; skipping coverage sample")
      return;
    end
    r.user = txn.UserSignalArray[0];
    if (!reset_seen && r.valid) begin
      cg_fe_axi_user.sample(3'd4, r.user);
      br_ruser_q.push_back(r.user);
      sample_pending_br_users();
      priority_r_q[r.id].push_back('{resp: r.resp, last: r.last, user7: r.user[7], user_value: r.user});
      sample_pending_response_priority(1'b1, r.id);
    end
    if (!reset_seen && r.valid)
      cg_fe_axi_requestor_rd_parity.sample(1'b1, r.user[7]);
    
  end
endfunction : convert_to_r

// Route each event to exactly one direction's embedded covergroup.
function bit [2:0] kb_fwd_eng_coverage::classify_tag_position(
  bit [15:0] tag_value, bit [15:0] tag_low, bit [15:0] tag_high
);
  bit [2:0] position;
  position = '0;
  if (tag_low <= tag_value && tag_value <= tag_high) begin
    position[2] = (tag_value == tag_low);
    position[1] = (tag_value == tag_high);
    position[0] = (tag_low < tag_value && tag_value < tag_high);
  end
  return position;
endfunction : classify_tag_position

function void kb_fwd_eng_coverage::sample_hdm_region_programming();
  hdm_cov_event_t region_event;
  bit [9:0] programmed;

  if (reset_seen) return;
  for (int i = 0; i < 10; i++)
    programmed[i] = (reg_hpa_base[i] != 0) || (reg_hpa_top[i] != 0);

  // Both groups observe the same shared HDM configuration.
  for (int direction = 0; direction < 2; direction++) begin
    region_event = '0;
    region_event.is_write = (direction == 1);
    region_event.programming_sample_valid = 1'b1;
    region_event.programmed_regions = programmed;
    sample_hdm_event(region_event);

    // Ordered coexistence pairs, including self-pairs: 10 x 10 bins.
    region_event.programming_sample_valid = 1'b0;
    region_event.programmed_pair_valid = 1'b1;
    for (int i = 0; i < 10; i++) begin
      if (!programmed[i]) continue;
      for (int j = 0; j < 10; j++) begin
        if (!programmed[j]) continue;
        region_event.programmed_region_a = 4'(i);
        region_event.programmed_region_b = 4'(j);
        sample_hdm_event(region_event);
      end
    end
  end
endfunction : sample_hdm_region_programming

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

// Match queued scoreboard and AXI observations when both are available.
function void kb_fwd_eng_coverage::clear_pending_axi_errors();
  rd_ert_q.delete();
  wr_ert_q.delete();
  rd_erruser_q.delete();
  wr_erruser_q.delete();
endfunction : clear_pending_axi_errors

function void kb_fwd_eng_coverage::sample_pending_axi_errors(bit is_write);
  axi_error_observation_t observation;
  bit [1:0] final_ert;
  int unsigned required_entries;

  forever begin
    if (is_write) begin
      if (wr_erruser_q.size() == 0) return;
      observation = wr_erruser_q[0];
    end else begin
      if (rd_erruser_q.size() == 0) return;
      observation = rd_erruser_q[0];
    end

    // Response-length injection preserves the original 64B/128B request pairing.
    if (((observation.len !== 8'd0) &&
         (is_write || !allow_extended_read_response || $isunknown(observation.len))) ||
        !((observation.size === 3'd6) ||
          (observation.size === 3'd7))) begin
      `uvm_fatal("SB_AXI_ERROR_SIZE",
        $sformatf("Unsupported AXI error pairing: write=%0b size=%0h len=%0h",
                  is_write, observation.size, observation.len))
      return;
    end
    required_entries = (observation.size == 3'd7) ? 2 : 1;

    if (is_write) begin
      if (wr_ert_q.size() < required_entries) return;
      observation = wr_erruser_q.pop_front();
    end else begin
      if (rd_ert_q.size() < required_entries) return;
      observation = rd_erruser_q.pop_front();
    end

    // A merged request uses the same actual USER bit for both lane results.
    repeat (required_entries) begin
      if (is_write) final_ert = wr_ert_q.pop_front();
      else          final_ert = rd_ert_q.pop_front();
      cg_fe_axi_requestor_error.sample(final_ert, observation.erruser);
    end
  end
endfunction : sample_pending_axi_errors

function void kb_fwd_eng_coverage::sample_pending_encap_errors(bit is_write);
  bit [1:0] ert;
  bit [1:0] cfg;
  if (reset_seen) return;
  if (is_write) begin
    while (encap_wr_ert_q.size() && encap_ndr_config_q.size()) begin
      ert = encap_wr_ert_q.pop_front();
      cfg = encap_ndr_config_q.pop_front();
      cg_fe_cxl_encap_ndr.sample(0, 0, 0, 0, 0, 0, 0,
                                1'b1, ert, cfg[1], cfg[0]);
    end
  end else begin
    while (encap_rd_ert_q.size() && encap_drs_config_q.size()) begin
      ert = encap_rd_ert_q.pop_front();
      cfg = encap_drs_config_q.pop_front();
      cg_fe_cxl_encap_drs.sample(0, 0, 0, 0, 0, 0, 0, 0, 0,
                                1'b1, ert, cfg[1], cfg[0]);
    end
  end
endfunction : sample_pending_encap_errors

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
        if (h_txn.is_write)
          encap_wr_ert_q.push_back(err_resp_type[i]);
        else
          encap_rd_ert_q.push_back(err_resp_type[i]);
        hdm_sample = '0;
        hdm_sample.error_valid       = 1'b1;
        hdm_sample.packet_valid      = 1'b1;
        hdm_sample.tag_bounds_valid  = tag_bounds_valid[i];
        hdm_sample.tag_check_enabled = tag_range_check;
        hdm_sample.tag_range_checked = tag_range_checked[i];
        hdm_sample.tag_range_passed  = tag_range_passed[i];
        hdm_sample.tag_position = classify_tag_position(
          h_txn.tag_value[i], h_txn.tag_low[i], h_txn.tag_high[i]
        );
        hdm_sample.error_type        = err_resp_type[i];
        hdm_sample.nxm_enabled       = nxm_enable;
        hdm_sample.poison_enabled    = poison_enable;
        hdm_sample.is_write          = h_txn.is_write;
        hdm_sample.permission_valid  = h_txn.permission_checked[i];
        hdm_sample.permission_passed = h_txn.permission_passed[i];
        sample_hdm_event(hdm_sample);
        // valid entries in this iteration order are in
        // AXI request order within this direction. A merged request supplies
        // two consecutive original-tag entries, each with its own result.
        // Enqueue even if checking was skipped: every packet occupies a slot.
        queue_hdm_tag(h_txn.is_write, '{
          tag_bounds_valid: tag_bounds_valid[i],
          tag_range_checked: tag_range_checked[i],
          tag_range_passed: tag_range_passed[i]
        });
        // Requires scoreboard lane results in AXI request order per direction.
        if (h_txn.is_write)
          wr_ert_q.push_back(err_resp_type[i]);
        else
          rd_ert_q.push_back(err_resp_type[i]);
      end
    end
    sample_pending_axi_errors(h_txn.is_write);
    sample_pending_encap_errors(h_txn.is_write);

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
  `uvm_info(get_type_name(), $sformatf("  REQ Parity Coverage    : %0.2f%%", cg_fe_axi_requestor_rd_parity.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  RwD Parity Coverage    : %0.2f%%", cg_fe_axi_requestor_wr_parity.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Scoreboard Error Cov   : %0.2f%%", cg_fe_axi_requestor_error.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Combining Coverage     : %0.2f%%", cg_fe_combining_eligibility.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  AXI Responder Coverage : %0.2f%%", cg_fe_axi_responder.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Error/IRQ Coverage     : %0.2f%%", cg_fe_error_interrupt.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  APB Config Coverage    : %0.2f%%", cg_fe_apb_registers.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), $sformatf("  Credit Manager Coverage: %0.2f%%", cg_fe_credit_manager.get_coverage()), UVM_LOW)
  `uvm_info(get_type_name(), "=====================================", UVM_LOW)
endfunction : report_phase

`endif // KB_FWD_ENG_COVERAGE_SV




