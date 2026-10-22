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
      cg_fe_cxl_parser_combining.sample(
        1'b0,
        combining_rd_enable_inst,
        combining_wr_enable_inst,
        i,
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
      cg_fe_cxl_parser_combining.sample(
        1'b1,
        combining_rd_enable_inst,
        combining_wr_enable_inst,
        3'd3,
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
      cg_fe_cxl_encap_ndr.sample(
        i,
        snap.ndr_items[i].s2m_ndr_opcode,
