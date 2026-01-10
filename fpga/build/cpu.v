module cpu (
	clk,
	rst,
	bmem_addr,
	bmem_read,
	bmem_write,
	bmem_wdata,
	bmem_ready,
	bmem_raddr,
	bmem_rdata,
	bmem_rvalid
);
	input wire clk;
	input wire rst;
	output wire [31:0] bmem_addr;
	output wire bmem_read;
	output wire bmem_write;
	output wire [63:0] bmem_wdata;
	input wire bmem_ready;
	input wire [31:0] bmem_raddr;
	input wire [63:0] bmem_rdata;
	input wire bmem_rvalid;
	generate
		if (1) begin : icache_itf_i
			wire [31:0] addr;
			wire read;
			wire write;
			wire [255:0] wdata;
			reg ready;
			reg [31:0] raddr;
			reg [255:0] rdata;
			reg rvalid;
		end
		if (1) begin : dcache_itf_i
			wire [31:0] addr;
			wire read;
			wire write;
			wire [255:0] wdata;
			reg ready;
			reg [31:0] raddr;
			reg [255:0] rdata;
			reg rvalid;
		end
		if (1) begin : adapter_itf_i
			reg [31:0] addr;
			reg read;
			reg write;
			reg [255:0] wdata;
			reg ready;
			wire [31:0] raddr;
			reg [255:0] rdata;
			reg rvalid;
		end
		if (1) begin : frontend_fifo_itf_i
			wire valid;
			wire ready;
			localparam cpu_params_IF_WIDTH = 2;
			reg [(((((cpu_params_IF_WIDTH * 32) + cpu_params_IF_WIDTH) + (cpu_params_IF_WIDTH * 32)) + 32) + cpu_params_IF_WIDTH) - 1:0] packet;
		end
		if (1) begin : fifo_backend_itf_i
			wire valid;
			reg ready;
			localparam cpu_params_IF_WIDTH = 2;
			wire [(((((cpu_params_IF_WIDTH * 32) + cpu_params_IF_WIDTH) + (cpu_params_IF_WIDTH * 32)) + 32) + cpu_params_IF_WIDTH) - 1:0] packet;
		end
		if (1) begin : cb_bp_itf_i
			wire update_en;
			wire [31:0] pc;
			wire [3:0] fu_opcode;
			wire branch_taken;
			wire [31:0] target_address;
		end
	endgenerate
	wire backend_flush;
	wire [31:0] backend_redirect_pc;
	generate
		if (1) begin : frontend_i
			reg _sv2v_0;
			wire clk;
			wire rst;
			wire backend_flush;
			wire [31:0] backend_redirect_pc;
			localparam cpu_params_IF_WIDTH = 2;
			localparam IF_BLK_SIZE = cpu_params_IF_WIDTH * 4;
			localparam IF_WIDTH_IDX = $clog2(1'd0);
			wire if1_valid;
			wire if1_ready;
			reg [31:0] pc_next;
			wire [31:0] pc;
			wire [31:0] blk_pc;
			wire [(cpu_params_IF_WIDTH * 32) - 1:0] insts;
			reg prev_rst;
			wire [cpu_params_IF_WIDTH - 1:0] predict_taken;
			wire [cpu_params_IF_WIDTH - 1:0] predict_taken_gshare;
			wire [(cpu_params_IF_WIDTH * 32) - 1:0] predict_target;
			reg predict_taken_en;
			reg [IF_WIDTH_IDX - 1:0] predict_taken_idx;
			always @(posedge clk) prev_rst <= rst;
			always @(*) begin
				if (_sv2v_0)
					;
				if (prev_rst)
					pc_next = 32'haaaaa000;
				else if (backend_flush)
					pc_next = backend_redirect_pc;
				else if (predict_taken_en)
					pc_next = predict_target[predict_taken_idx * 32+:32];
				else
					pc_next = (pc + IF_BLK_SIZE) & ~$unsigned(IF_BLK_SIZE - 1);
			end
			always @(*) begin : sv2v_autoblock_1
				reg [0:1] _sv2v_jump;
				_sv2v_jump = 2'b00;
				if (_sv2v_0)
					;
				predict_taken_en = 1'sb0;
				predict_taken_idx = 1'sb0;
				begin : sv2v_autoblock_2
					reg signed [31:0] i;
					begin : sv2v_autoblock_3
						reg signed [31:0] _sv2v_value_on_break;
						for (i = 0; i < cpu_params_IF_WIDTH; i = i + 1)
							if (_sv2v_jump < 2'b10) begin
								_sv2v_jump = 2'b00;
								if (($unsigned(i) >= ((pc % IF_BLK_SIZE) / 4)) & predict_taken[i]) begin
									predict_taken_en = 1'b1;
									begin : sv2v_autoblock_4
										reg [IF_WIDTH_IDX - 1:0] sv2v_tmp_cast;
										sv2v_tmp_cast = $unsigned(i);
										predict_taken_idx = sv2v_tmp_cast;
									end
									_sv2v_jump = 2'b10;
								end
								_sv2v_value_on_break = i;
							end
						if (!(_sv2v_jump < 2'b10))
							i = _sv2v_value_on_break;
						if (_sv2v_jump != 2'b11)
							_sv2v_jump = 2'b00;
					end
				end
			end
			if (1) begin : if1_stage_i
				wire clk;
				wire rst;
				wire flush;
				wire prv_valid;
				wire prv_ready;
				wire nxt_valid;
				wire nxt_ready;
				wire [31:0] pc_next;
				reg [31:0] pc;
				localparam cpu_params_IF_WIDTH = 2;
				wire [(cpu_params_IF_WIDTH * 32) - 1:0] insts;
				localparam IF_BLK_SIZE = cpu_params_IF_WIDTH * 4;
				wire [31:0] blk_pc_next;
				reg icache_valid;
				wire icache_resp;
				reg icache_pending;
				wire [(cpu_params_IF_WIDTH * 32) - 1:0] icache_rdata;
				wire icache_unresponsive;
				assign prv_ready = (~icache_valid || (nxt_valid && nxt_ready)) || flush;
				assign blk_pc_next = pc_next & ~$unsigned(IF_BLK_SIZE - 1);
				always @(posedge clk)
					if (rst)
						pc <= 1'sb0;
					else if (prv_ready && prv_valid)
						pc <= pc_next;
				always @(posedge clk)
					if (rst)
						icache_pending <= 1'sb0;
					else if (prv_ready && prv_valid)
						icache_pending <= 1'sb1;
					else if (icache_resp)
						icache_pending <= 1'sb0;
				always @(posedge clk)
					if (rst)
						icache_valid <= 1'sb0;
					else if (prv_ready)
						icache_valid <= prv_valid;
				assign icache_unresponsive = icache_pending && ~icache_resp;
				localparam _param_AA4CD_IF_WIDTH = cpu_params_IF_WIDTH;
				if (1) begin : icache_i
					reg _sv2v_0;
					localparam IF_WIDTH = _param_AA4CD_IF_WIDTH;
					localparam OFFSET_IDX = 5;
					localparam SET_IDX = 4;
					localparam TAG_IDX = 23;
					localparam NUM_WAYS = 4;
					wire clk;
					wire rst;
					wire [31:0] ufp_addr;
					wire ufp_read;
					wire [(IF_WIDTH * 32) - 1:0] ufp_rdata;
					wire ufp_resp;
					wire kill;
					localparam PLRU_BITS = 3;
					localparam WAY_BITS = 2;
					reg data_csb0 [0:3];
					reg tag_csb0 [0:3];
					reg valid_csb0 [0:3];
					wire plru_csb0;
					wire plru_csb1;
					reg data_web0 [0:3];
					reg tag_web0 [0:3];
					reg valid_web0 [0:3];
					wire plru_web1;
					reg [31:0] data_wmask0;
					reg [255:0] data_din0;
					wire [TAG_IDX:0] tag_din0;
					wire valid_din0;
					wire [2:0] plru_din1;
					wire [255:0] data_dout0 [0:3];
					wire [95:0] tag_dout0;
					wire [0:3] valid_dout0;
					wire [2:0] plru_dout0;
					wire [4:0] ufp_offset;
					wire [3:0] ufp_set;
					wire [22:0] ufp_tag;
					wire [3:0] next_set;
					wire [3:0] sram_operating_set;
					reg [32:0] stage_reg;
					wire hit;
					wire [1:0] hit_way;
					wire [1:0] replace_way;
					wire stall;
					wire allocate_done;
					assign ufp_offset = ufp_addr[4:0];
					assign ufp_set = ufp_addr[8:OFFSET_IDX];
					assign ufp_tag = ufp_addr[31:9];
					assign sram_operating_set = (~stall || kill ? ufp_set : stage_reg[26-:4]);
					genvar _gv_i_37;
					for (_gv_i_37 = 0; _gv_i_37 < NUM_WAYS; _gv_i_37 = _gv_i_37 + 1) begin : arrays
						localparam i = _gv_i_37;
						icache_data_array data_array(
							.clk0(clk),
							.csb0(data_csb0[i]),
							.web0(data_web0[i]),
							.wmask0(data_wmask0),
							.addr0(sram_operating_set),
							.din0(data_din0),
							.dout0(data_dout0[i])
						);
						icache_tag_array tag_array(
							.clk0(clk),
							.csb0(tag_csb0[i]),
							.web0(tag_web0[i]),
							.addr0(sram_operating_set),
							.din0(tag_din0),
							.dout0(tag_dout0[0 + ((3 - i) * 24)+:24])
						);
						valid_array #(
							.S_INDEX(SET_IDX),
							.WIDTH(1)
						) valid_array(
							.clk0(clk),
							.rst0(rst),
							.csb0(valid_csb0[i]),
							.web0(valid_web0[i]),
							.addr0(sram_operating_set),
							.din0(valid_din0),
							.dout0(valid_dout0[i])
						);
					end
					localparam sv2v_uu_lru_array_WIDTH = PLRU_BITS;
					localparam [2:0] sv2v_uu_lru_array_ext_din0_x = 1'sbx;
					lru_array #(
						.S_INDEX(SET_IDX),
						.WIDTH(PLRU_BITS)
					) lru_array(
						.clk0(clk),
						.rst0(rst),
						.csb0(plru_csb0),
						.addr0(ufp_set),
						.din0(sv2v_uu_lru_array_ext_din0_x),
						.dout0(plru_dout0),
						.csb1(plru_csb1),
						.web1(plru_web1),
						.addr1(stage_reg[26-:4]),
						.din1(plru_din1)
					);
					always @(posedge clk)
						if (rst)
							stage_reg[32] <= 1'sb0;
						else if (~stall || kill) begin
							stage_reg[32] <= ufp_read;
							stage_reg[31-:5] <= ufp_offset;
							stage_reg[26-:4] <= ufp_set;
							stage_reg[22-:23] <= ufp_tag;
						end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_5
							reg signed [31:0] i;
							for (i = 0; i < NUM_WAYS; i = i + 1)
								begin
									data_csb0[i] = 1'b1;
									tag_csb0[i] = 1'b1;
									valid_csb0[i] = 1'b1;
								end
						end
						if (~stall || kill) begin : sv2v_autoblock_6
							reg signed [31:0] i;
							for (i = 0; i < NUM_WAYS; i = i + 1)
								begin
									data_csb0[i] = 1'b0;
									tag_csb0[i] = 1'b0;
									valid_csb0[i] = 1'b0;
								end
						end
						if (allocate_done) begin
							data_csb0[replace_way] = 1'b0;
							tag_csb0[replace_way] = 1'b0;
							valid_csb0[replace_way] = 1'b0;
						end
					end
					assign plru_csb0 = stall;
					assign plru_csb1 = ~ufp_resp;
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_7
							reg signed [31:0] i;
							for (i = 0; i < NUM_WAYS; i = i + 1)
								begin
									data_web0[i] = 1'b1;
									tag_web0[i] = 1'b1;
									valid_web0[i] = 1'b1;
								end
						end
						if (allocate_done) begin
							data_web0[replace_way] = 1'b0;
							tag_web0[replace_way] = 1'b0;
							valid_web0[replace_way] = 1'b0;
						end
					end
					assign plru_web1 = plru_csb1;
					always @(*) begin
						if (_sv2v_0)
							;
						if (allocate_done) begin
							data_wmask0 = 1'sb1;
							data_din0 = cpu.icache_itf_i.rdata;
						end
						else begin
							data_wmask0 = 1'sbx;
							data_din0 = 1'sbx;
						end
					end
					assign tag_din0 = {1'b0, stage_reg[22-:23]};
					assign valid_din0 = 1'b1;
					assign cpu.icache_itf_i.wdata = 1'sbx;
					genvar _gv_i_38;
					for (_gv_i_38 = 0; _gv_i_38 < IF_WIDTH; _gv_i_38 = _gv_i_38 + 1) begin : ufp_rdata_assign
						localparam i = _gv_i_38;
						assign ufp_rdata[i * 32+:32] = data_dout0[hit_way][(8 * stage_reg[31-:5]) + $unsigned(32 * i)+:32];
					end
					assign ufp_resp = stage_reg[32] && ~stall;
					icache_ctrl #(
						.TAG_IDX(TAG_IDX),
						.NUM_WAYS(NUM_WAYS),
						.WAY_BITS(WAY_BITS),
						.OFFSET_IDX(OFFSET_IDX),
						.SET_IDX(SET_IDX)
					) icache_ctrl_i(
						.clk(clk),
						.rst(rst),
						.kill(kill),
						.read(stage_reg[32]),
						.tag(stage_reg[22-:23]),
						.set(stage_reg[26-:4]),
						.tag_arr_out(tag_dout0),
						.valid_arr_out(valid_dout0),
						.stall(stall),
						.allocate_done(allocate_done),
						.hit_way(hit_way),
						.dfp_addr(cpu.icache_itf_i.addr),
						.dfp_read(cpu.icache_itf_i.read),
						.dfp_write(cpu.icache_itf_i.write),
						.dfp_ready(cpu.icache_itf_i.ready),
						.dfp_raddr(cpu.icache_itf_i.raddr),
						.dfp_rvalid(cpu.icache_itf_i.rvalid)
					);
					plru_update #(
						.NUM_WAYS(NUM_WAYS),
						.PLRU_BITS(PLRU_BITS),
						.WAY_BITS(WAY_BITS)
					) plru_update_i(
						.current_plru(plru_dout0),
						.next_plru(plru_din1),
						.hit_way(hit_way),
						.replace_way(replace_way)
					);
					initial _sv2v_0 = 0;
				end
				assign icache_i.clk = clk;
				assign icache_i.rst = rst;
				assign icache_i.ufp_addr = blk_pc_next;
				assign icache_i.ufp_read = prv_ready && prv_valid;
				assign icache_rdata = icache_i.ufp_rdata;
				assign icache_resp = icache_i.ufp_resp;
				assign icache_i.kill = flush;
				reg [(cpu_params_IF_WIDTH * 32) - 1:0] temp_icache_rdata;
				always @(posedge clk)
					if (icache_resp)
						temp_icache_rdata <= icache_rdata;
				assign insts = (icache_resp ? icache_rdata : temp_icache_rdata);
				assign nxt_valid = icache_valid && ~icache_unresponsive;
			end
			assign if1_stage_i.clk = clk;
			assign if1_stage_i.rst = rst;
			assign if1_stage_i.flush = backend_flush;
			assign if1_stage_i.prv_valid = 1'sb1;
			assign if1_valid = if1_stage_i.nxt_valid;
			assign if1_stage_i.nxt_ready = if1_ready;
			assign if1_stage_i.pc_next = pc_next;
			assign pc = if1_stage_i.pc;
			assign insts = if1_stage_i.insts;
			if (1) begin : gshare_i
				wire clk;
				wire rst;
				wire [31:0] blk_pc;
				localparam cpu_params_IF_WIDTH = 2;
				wire [cpu_params_IF_WIDTH - 1:0] predict_taken;
				localparam IF_BLK_SIZE = cpu_params_IF_WIDTH * 4;
				localparam cpu_params_PHT_DEPTH = 512;
				localparam cpu_params_PHT_IDX = $clog2(1'd0);
				reg [cpu_params_PHT_IDX - 1:0] ghr;
				reg [1:0] pht [0:cpu_params_PHT_DEPTH - 1];
				always @(posedge clk)
					if (rst) begin
						ghr <= 1'sb0;
						begin : sv2v_autoblock_8
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_PHT_DEPTH; i = i + 1)
								pht[i] = 2'b01;
						end
					end
					else if (cpu.cb_bp_itf_i.update_en) begin
						ghr <= {ghr[cpu_params_PHT_IDX - 2:0], cpu.cb_bp_itf_i.branch_taken};
						if (cpu.cb_bp_itf_i.branch_taken)
							pht[ghr ^ cpu.cb_bp_itf_i.pc[cpu_params_PHT_IDX + 1:2]] <= (pht[ghr ^ cpu.cb_bp_itf_i.pc[cpu_params_PHT_IDX + 1:2]] == 2'b11 ? 2'b11 : pht[ghr ^ cpu.cb_bp_itf_i.pc[cpu_params_PHT_IDX + 1:2]] + 2'd1);
						else
							pht[ghr ^ cpu.cb_bp_itf_i.pc[cpu_params_PHT_IDX + 1:2]] <= (pht[ghr ^ cpu.cb_bp_itf_i.pc[cpu_params_PHT_IDX + 1:2]] == 2'b00 ? 2'b00 : pht[ghr ^ cpu.cb_bp_itf_i.pc[cpu_params_PHT_IDX + 1:2]] - 2'd1);
					end
				wire [(cpu_params_IF_WIDTH * 32) - 1:0] pc_in;
				genvar _gv_i_40;
				for (_gv_i_40 = 0; _gv_i_40 < cpu_params_IF_WIDTH; _gv_i_40 = _gv_i_40 + 1) begin : genblk1
					localparam i = _gv_i_40;
					assign pc_in[i * 32+:32] = blk_pc + ($unsigned(i) * 4);
					assign predict_taken[i] = pht[ghr ^ pc_in[(i * 32) + ((cpu_params_PHT_IDX + 1) >= 2 ? cpu_params_PHT_IDX + 1 : ((cpu_params_PHT_IDX + 1) + ((cpu_params_PHT_IDX + 1) >= 2 ? cpu_params_PHT_IDX + 0 : 3 - (cpu_params_PHT_IDX + 1))) - 1)-:((cpu_params_PHT_IDX + 1) >= 2 ? cpu_params_PHT_IDX + 0 : 3 - (cpu_params_PHT_IDX + 1))]] >= 2'b10;
				end
			end
			assign gshare_i.clk = clk;
			assign gshare_i.rst = rst;
			assign gshare_i.blk_pc = blk_pc;
			assign predict_taken_gshare = gshare_i.predict_taken;
			if (1) begin : ubtb_i
				reg _sv2v_0;
				wire clk;
				wire rst;
				localparam cpu_params_IF_WIDTH = 2;
				wire [cpu_params_IF_WIDTH - 1:0] predict_taken_gshare;
				wire [31:0] blk_pc;
				reg [(cpu_params_IF_WIDTH * 32) - 1:0] predict_target;
				reg [cpu_params_IF_WIDTH - 1:0] predict_taken;
				localparam IF_BLK_SIZE = cpu_params_IF_WIDTH * 4;
				localparam cpu_params_UBTB_TAG_IDX = 20;
				localparam cpu_params_UBTB_DEPTH = 8;
				reg [(33 + cpu_params_UBTB_TAG_IDX) - 1:0] br_ubtb [0:cpu_params_UBTB_DEPTH - 1];
				reg [2:0] br_ubtb_update;
				localparam cpu_params_UBTB_IDX = $clog2(1'd0);
				reg [cpu_params_UBTB_IDX - 1:0] br_update_idx;
				reg [cpu_params_UBTB_IDX - 1:0] br_insert_idx;
				reg [cpu_params_UBTB_IDX - 1:0] br_ubtb_head;
				always @(posedge clk)
					if (rst) begin
						br_ubtb_head <= 1'sb0;
						begin : sv2v_autoblock_9
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_UBTB_DEPTH; i = i + 1)
								br_ubtb[i][cpu_params_UBTB_TAG_IDX + 32] <= 1'sb0;
						end
					end
					else if ((cpu.cb_bp_itf_i.update_en && cpu.cb_bp_itf_i.branch_taken) && ~cpu.cb_bp_itf_i.fu_opcode[3])
						(* full_case, parallel_case *)
						case (br_ubtb_update)
							3'b001: begin
								br_ubtb[br_insert_idx][cpu_params_UBTB_TAG_IDX + 32] <= 1'sb1;
								br_ubtb[br_insert_idx][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] <= cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2];
								br_ubtb[br_insert_idx][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)] <= cpu.cb_bp_itf_i.target_address;
							end
							3'b010: begin
								br_ubtb[br_update_idx][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] <= cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2];
								br_ubtb[br_update_idx][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)] <= cpu.cb_bp_itf_i.target_address;
							end
							3'b100: begin
								br_ubtb[br_ubtb_head][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] <= cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2];
								br_ubtb[br_ubtb_head][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)] <= cpu.cb_bp_itf_i.target_address;
								br_ubtb_head <= br_ubtb_head + 1'b1;
							end
							default:
								;
						endcase
				always @(*) begin
					if (_sv2v_0)
						;
					br_ubtb_update = 3'b100;
					br_update_idx = 1'sbx;
					br_insert_idx = 1'sbx;
					begin : sv2v_autoblock_10
						reg [31:0] i;
						for (i = 0; i < cpu_params_UBTB_DEPTH; i = i + 1)
							if (~cpu.cb_bp_itf_i.fu_opcode[3]) begin
								if (!br_ubtb[i][cpu_params_UBTB_TAG_IDX + 32]) begin
									br_ubtb_update = 3'b001;
									begin : sv2v_autoblock_11
										reg [cpu_params_UBTB_IDX - 1:0] sv2v_tmp_cast;
										sv2v_tmp_cast = i;
										br_insert_idx = sv2v_tmp_cast;
									end
								end
								else if (br_ubtb[i][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] == cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2]) begin
									br_ubtb_update = 3'b010;
									begin : sv2v_autoblock_12
										reg [cpu_params_UBTB_IDX - 1:0] sv2v_tmp_cast;
										sv2v_tmp_cast = i;
										br_update_idx = sv2v_tmp_cast;
									end
								end
							end
					end
				end
				reg [(33 + cpu_params_UBTB_TAG_IDX) - 1:0] j_ubtb [0:cpu_params_UBTB_DEPTH - 1];
				reg [2:0] j_ubtb_update;
				reg [cpu_params_UBTB_IDX - 1:0] j_update_idx;
				reg [cpu_params_UBTB_IDX - 1:0] j_insert_idx;
				reg [cpu_params_UBTB_IDX - 1:0] j_ubtb_head;
				always @(posedge clk)
					if (rst) begin
						j_ubtb_head <= 1'sb0;
						begin : sv2v_autoblock_13
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_UBTB_DEPTH; i = i + 1)
								j_ubtb[i][cpu_params_UBTB_TAG_IDX + 32] <= 1'sb0;
						end
					end
					else if ((cpu.cb_bp_itf_i.update_en && cpu.cb_bp_itf_i.branch_taken) && cpu.cb_bp_itf_i.fu_opcode[3])
						(* full_case, parallel_case *)
						case (j_ubtb_update)
							3'b001: begin
								j_ubtb[j_insert_idx][cpu_params_UBTB_TAG_IDX + 32] <= 1'sb1;
								j_ubtb[j_insert_idx][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] <= cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2];
								j_ubtb[j_insert_idx][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)] <= cpu.cb_bp_itf_i.target_address;
							end
							3'b010: begin
								j_ubtb[j_update_idx][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] <= cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2];
								j_ubtb[j_update_idx][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)] <= cpu.cb_bp_itf_i.target_address;
							end
							3'b100: begin
								j_ubtb[j_ubtb_head][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] <= cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2];
								j_ubtb[j_ubtb_head][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)] <= cpu.cb_bp_itf_i.target_address;
								j_ubtb_head <= j_ubtb_head + 1'b1;
							end
							default:
								;
						endcase
				always @(*) begin
					if (_sv2v_0)
						;
					j_ubtb_update = 3'b100;
					j_update_idx = 1'sbx;
					j_insert_idx = 1'sbx;
					begin : sv2v_autoblock_14
						reg [31:0] i;
						for (i = 0; i < cpu_params_UBTB_DEPTH; i = i + 1)
							if (cpu.cb_bp_itf_i.fu_opcode[3]) begin
								if (!j_ubtb[i][cpu_params_UBTB_TAG_IDX + 32]) begin
									j_ubtb_update = 3'b001;
									begin : sv2v_autoblock_15
										reg [cpu_params_UBTB_IDX - 1:0] sv2v_tmp_cast;
										sv2v_tmp_cast = i;
										j_insert_idx = sv2v_tmp_cast;
									end
								end
								else if (j_ubtb[i][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] == cpu.cb_bp_itf_i.pc[cpu_params_UBTB_TAG_IDX + 1:2]) begin
									j_ubtb_update = 3'b010;
									begin : sv2v_autoblock_16
										reg [cpu_params_UBTB_IDX - 1:0] sv2v_tmp_cast;
										sv2v_tmp_cast = i;
										j_update_idx = sv2v_tmp_cast;
									end
								end
							end
					end
				end
				reg [(cpu_params_IF_WIDTH * 32) - 1:0] pc_in;
				genvar _gv_w_1;
				for (_gv_w_1 = 0; _gv_w_1 < cpu_params_IF_WIDTH; _gv_w_1 = _gv_w_1 + 1) begin : genblk1
					localparam w = _gv_w_1;
					always @(*) begin : sv2v_autoblock_17
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						predict_taken[w] = 1'b0;
						pc_in[w * 32+:32] = blk_pc + ($unsigned(w) * 4);
						predict_target[w * 32+:32] = (blk_pc + ($unsigned(w) * 4)) + 4;
						begin : sv2v_autoblock_18
							reg signed [31:0] i;
							begin : sv2v_autoblock_19
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_UBTB_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if ((predict_taken_gshare[w] && br_ubtb[i][cpu_params_UBTB_TAG_IDX + 32]) && (br_ubtb[i][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] == pc_in[(w * 32) + ((cpu_params_UBTB_TAG_IDX + 1) >= 2 ? cpu_params_UBTB_TAG_IDX + 1 : ((cpu_params_UBTB_TAG_IDX + 1) + ((cpu_params_UBTB_TAG_IDX + 1) >= 2 ? cpu_params_UBTB_TAG_IDX + 0 : 3 - (cpu_params_UBTB_TAG_IDX + 1))) - 1)-:((cpu_params_UBTB_TAG_IDX + 1) >= 2 ? cpu_params_UBTB_TAG_IDX + 0 : 3 - (cpu_params_UBTB_TAG_IDX + 1))])) begin
											predict_target[w * 32+:32] = br_ubtb[i][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)];
											predict_taken[w] = 1'b1;
											_sv2v_jump = 2'b10;
										end
										if (_sv2v_jump == 2'b00) begin
											if (j_ubtb[i][cpu_params_UBTB_TAG_IDX + 32] && (j_ubtb[i][cpu_params_UBTB_TAG_IDX - 1-:cpu_params_UBTB_TAG_IDX] == pc_in[(w * 32) + ((cpu_params_UBTB_TAG_IDX + 1) >= 2 ? cpu_params_UBTB_TAG_IDX + 1 : ((cpu_params_UBTB_TAG_IDX + 1) + ((cpu_params_UBTB_TAG_IDX + 1) >= 2 ? cpu_params_UBTB_TAG_IDX + 0 : 3 - (cpu_params_UBTB_TAG_IDX + 1))) - 1)-:((cpu_params_UBTB_TAG_IDX + 1) >= 2 ? cpu_params_UBTB_TAG_IDX + 0 : 3 - (cpu_params_UBTB_TAG_IDX + 1))])) begin
												predict_target[w * 32+:32] = j_ubtb[i][cpu_params_UBTB_TAG_IDX + 31-:((cpu_params_UBTB_TAG_IDX + 31) >= (cpu_params_UBTB_TAG_IDX + 0) ? ((cpu_params_UBTB_TAG_IDX + 31) - (cpu_params_UBTB_TAG_IDX + 0)) + 1 : ((cpu_params_UBTB_TAG_IDX + 0) - (cpu_params_UBTB_TAG_IDX + 31)) + 1)];
												predict_taken[w] = 1'b1;
												_sv2v_jump = 2'b10;
											end
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
				end
				initial _sv2v_0 = 0;
			end
			assign ubtb_i.clk = clk;
			assign ubtb_i.rst = rst;
			assign ubtb_i.predict_taken_gshare = predict_taken_gshare;
			assign ubtb_i.blk_pc = blk_pc;
			assign predict_target = ubtb_i.predict_target;
			assign predict_taken = ubtb_i.predict_taken;
			assign if1_ready = cpu.frontend_fifo_itf_i.ready;
			assign cpu.frontend_fifo_itf_i.valid = if1_valid;
			wire [(((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31)))) >= (1'd0 + ((1'd0 * 32) + ((32 + 1'd0) + 0))) ? (((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31)))) - (1'd0 + ((1'd0 * 32) + ((32 + 1'd0) + 0)))) + 1 : ((1'd0 + ((1'd0 * 32) + ((32 + 1'd0) + 0))) - ((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31))))) + 1) * 1:1] sv2v_tmp_2FCCD;
			assign sv2v_tmp_2FCCD = insts;
			always @(*) cpu.frontend_fifo_itf_i.packet[(1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31)))-:(((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31)))) >= (1'd0 + ((1'd0 * 32) + ((32 + 1'd0) + 0))) ? (((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31)))) - (1'd0 + ((1'd0 * 32) + ((32 + 1'd0) + 0)))) + 1 : ((1'd0 + ((1'd0 * 32) + ((32 + 1'd0) + 0))) - ((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31))))) + 1)] = sv2v_tmp_2FCCD;
			assign blk_pc = pc & ~$unsigned(IF_BLK_SIZE - 1);
			genvar _gv_i_39;
			for (_gv_i_39 = 0; _gv_i_39 < cpu_params_IF_WIDTH; _gv_i_39 = _gv_i_39 + 1) begin : genblk1
				localparam i = _gv_i_39;
				wire [1:1] sv2v_tmp_86D38;
				assign sv2v_tmp_86D38 = predict_taken[i];
				always @(*) cpu.frontend_fifo_itf_i.packet[(1'd0 + ((1'd0 * 32) + (1'd0 + 31))) - ((1'd0 - 1) - i)] = sv2v_tmp_86D38;
				wire [32:1] sv2v_tmp_DB50B;
				assign sv2v_tmp_DB50B = predict_target[i * 32+:32];
				always @(*) cpu.frontend_fifo_itf_i.packet[((1'd0 * 32) + (1'd0 + 31)) - (((1'd0 * 32) - 1) - (i * 32))+:32] = sv2v_tmp_DB50B;
			end
			wire [((1'd0 + 31) >= (1'd0 + 0) ? ((1'd0 + 31) - (1'd0 + 0)) + 1 : ((1'd0 + 0) - (1'd0 + 31)) + 1) * 1:1] sv2v_tmp_DD487;
			assign sv2v_tmp_DD487 = blk_pc;
			always @(*) cpu.frontend_fifo_itf_i.packet[1'd0 + 31-:((1'd0 + 31) >= (1'd0 + 0) ? ((1'd0 + 31) - (1'd0 + 0)) + 1 : ((1'd0 + 0) - (1'd0 + 31)) + 1)] = sv2v_tmp_DD487;
			localparam cpu_params_ID_WIDTH = 2;
			if (cpu_params_ID_WIDTH == 1) begin : genblk2
				wire [1:1] sv2v_tmp_71357;
				assign sv2v_tmp_71357 = 1'b1;
				always @(*) cpu.frontend_fifo_itf_i.packet[(1'd0 - 1) - (1'd0 - 1)] = sv2v_tmp_71357;
			end
			if (cpu_params_ID_WIDTH > 1) begin : genblk3
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_20
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							begin : sv2v_autoblock_21
								reg [IF_WIDTH_IDX - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = $unsigned(i);
								cpu.frontend_fifo_itf_i.packet[(1'd0 - 1) - ((1'd0 - 1) - i)] = ~(predict_taken_en & (sv2v_tmp_cast > predict_taken_idx)) & ($unsigned(i) >= ((pc % IF_BLK_SIZE) / 4));
							end
					end
				end
			end
			initial _sv2v_0 = 0;
		end
	endgenerate
	assign frontend_i.clk = clk;
	assign frontend_i.rst = rst;
	assign frontend_i.backend_flush = backend_flush;
	assign frontend_i.backend_redirect_pc = backend_redirect_pc;
	generate
		if (1) begin : bmem_arbiter_i
			reg _sv2v_0;
			wire clk;
			wire rst;
			reg [31:0] addr_buf;
			reg [255:0] data_buf;
			always @(posedge clk)
				if (rst) begin
					addr_buf <= 1'sb0;
					data_buf <= 1'sb0;
				end
				else if (cpu.dcache_itf_i.write) begin
					addr_buf <= cpu.dcache_itf_i.addr;
					data_buf <= cpu.dcache_itf_i.wdata;
				end
			reg curr_state;
			reg next_state;
			always @(posedge clk)
				if (rst)
					curr_state <= 1'b0;
				else
					curr_state <= next_state;
			always @(*) begin
				if (_sv2v_0)
					;
				cpu.icache_itf_i.ready = 1'sb0;
				cpu.dcache_itf_i.ready = 1'sb0;
				cpu.adapter_itf_i.read = 1'sb0;
				cpu.adapter_itf_i.write = 1'sb0;
				cpu.adapter_itf_i.addr = 1'sbx;
				cpu.adapter_itf_i.wdata = 1'sbx;
				(* full_case, parallel_case *)
				case (curr_state)
					1'b0:
						if (cpu.dcache_itf_i.read || cpu.dcache_itf_i.write) begin
							cpu.adapter_itf_i.read = cpu.dcache_itf_i.read;
							cpu.adapter_itf_i.write = cpu.dcache_itf_i.write;
							cpu.adapter_itf_i.addr = cpu.dcache_itf_i.addr;
							cpu.adapter_itf_i.wdata = cpu.dcache_itf_i.wdata;
							if (cpu.adapter_itf_i.ready)
								cpu.dcache_itf_i.ready = 1'sb1;
						end
						else if (cpu.icache_itf_i.read) begin
							cpu.adapter_itf_i.read = 1'sb1;
							cpu.adapter_itf_i.addr = cpu.icache_itf_i.addr;
							cpu.adapter_itf_i.wdata = cpu.icache_itf_i.wdata;
							if (cpu.adapter_itf_i.ready)
								cpu.icache_itf_i.ready = 1'sb1;
						end
					1'b1: begin
						cpu.adapter_itf_i.write = 1'sb1;
						cpu.adapter_itf_i.addr = addr_buf;
						cpu.adapter_itf_i.wdata = data_buf;
						if (cpu.adapter_itf_i.ready)
							cpu.dcache_itf_i.ready = 1'sb1;
					end
					default:
						;
				endcase
			end
			always @(*) begin
				if (_sv2v_0)
					;
				next_state = curr_state;
				(* full_case, parallel_case *)
				case (curr_state)
					1'b0:
						if (cpu.dcache_itf_i.write)
							next_state = 1'b1;
					1'b1:
						if (cpu.adapter_itf_i.ready)
							next_state = 1'b0;
					default:
						;
				endcase
			end
			always @(*) begin
				if (_sv2v_0)
					;
				cpu.icache_itf_i.rdata = cpu.adapter_itf_i.rdata;
				cpu.dcache_itf_i.rdata = cpu.adapter_itf_i.rdata;
				cpu.icache_itf_i.rvalid = cpu.adapter_itf_i.rvalid;
				cpu.dcache_itf_i.rvalid = cpu.adapter_itf_i.rvalid;
				cpu.icache_itf_i.raddr = cpu.adapter_itf_i.raddr;
				cpu.dcache_itf_i.raddr = cpu.adapter_itf_i.raddr;
			end
			initial _sv2v_0 = 0;
		end
	endgenerate
	assign bmem_arbiter_i.clk = clk;
	assign bmem_arbiter_i.rst = rst;
	generate
		if (1) begin : cache_adapter_i
			reg _sv2v_0;
			wire clk;
			wire rst;
			wire [31:0] dfp_addr;
			wire dfp_read;
			wire dfp_write;
			reg [63:0] dfp_wdata;
			wire dfp_ready;
			wire [31:0] dfp_raddr;
			wire [63:0] dfp_rdata;
			wire dfp_rvalid;
			reg [1:0] wdata_state;
			reg [1:0] next_wdata_state;
			always @(posedge clk)
				if (rst)
					wdata_state <= 2'd0;
				else
					wdata_state <= next_wdata_state;
			always @(*) begin
				if (_sv2v_0)
					;
				next_wdata_state = wdata_state;
				dfp_wdata = 1'sbx;
				cpu.adapter_itf_i.ready = 1'b0;
				(* full_case, parallel_case *)
				case (wdata_state)
					2'd0: begin
						cpu.adapter_itf_i.ready = dfp_ready;
						if (cpu.adapter_itf_i.write) begin
							cpu.adapter_itf_i.ready = 1'b0;
							dfp_wdata = cpu.adapter_itf_i.wdata[0+:64];
							if (dfp_ready)
								next_wdata_state = 2'd1;
						end
					end
					2'd1: begin
						cpu.adapter_itf_i.ready = 1'b0;
						dfp_wdata = cpu.adapter_itf_i.wdata[64+:64];
						if (dfp_ready)
							next_wdata_state = 2'd2;
					end
					2'd2: begin
						cpu.adapter_itf_i.ready = 1'b0;
						dfp_wdata = cpu.adapter_itf_i.wdata[128+:64];
						if (dfp_ready)
							next_wdata_state = 2'd3;
					end
					2'd3: begin
						cpu.adapter_itf_i.ready = 1'b0;
						dfp_wdata = cpu.adapter_itf_i.wdata[192+:64];
						if (dfp_ready) begin
							cpu.adapter_itf_i.ready = 1'b1;
							next_wdata_state = 2'd0;
						end
					end
					default:
						;
				endcase
			end
			reg [1:0] rdata_state;
			reg [1:0] next_rdata_state;
			reg [63:0] cached_rdata [0:2];
			reg cache_rdata [0:2];
			always @(posedge clk)
				if (rst)
					rdata_state <= 2'd0;
				else
					rdata_state <= next_rdata_state;
			always @(posedge clk) begin : sv2v_autoblock_22
				reg signed [31:0] i;
				for (i = 0; i < 3; i = i + 1)
					if (cache_rdata[i])
						cached_rdata[i] <= dfp_rdata;
			end
			always @(*) begin
				if (_sv2v_0)
					;
				next_rdata_state = rdata_state;
				cpu.adapter_itf_i.rdata = 1'sbx;
				cpu.adapter_itf_i.rvalid = 1'b0;
				begin : sv2v_autoblock_23
					reg signed [31:0] i;
					for (i = 0; i < 3; i = i + 1)
						cache_rdata[i] = 1'b0;
				end
				(* full_case, parallel_case *)
				case (rdata_state)
					2'd0: begin
						if (dfp_rvalid)
							next_rdata_state = 2'd1;
						cache_rdata[0] = 1'b1;
					end
					2'd1: begin
						next_rdata_state = 2'd2;
						cache_rdata[1] = 1'b1;
					end
					2'd2: begin
						next_rdata_state = 2'd3;
						cache_rdata[2] = 1'b1;
					end
					2'd3: begin
						next_rdata_state = 2'd0;
						cpu.adapter_itf_i.rvalid = 1'b1;
						cpu.adapter_itf_i.rdata = {dfp_rdata, cached_rdata[2], cached_rdata[1], cached_rdata[0]};
					end
					default:
						;
				endcase
			end
			assign dfp_addr = cpu.adapter_itf_i.addr;
			assign dfp_read = cpu.adapter_itf_i.read;
			assign dfp_write = cpu.adapter_itf_i.write;
			assign cpu.adapter_itf_i.raddr = dfp_raddr;
			initial _sv2v_0 = 0;
		end
	endgenerate
	assign cache_adapter_i.clk = clk;
	assign cache_adapter_i.rst = rst;
	assign bmem_addr = cache_adapter_i.dfp_addr;
	assign bmem_read = cache_adapter_i.dfp_read;
	assign bmem_write = cache_adapter_i.dfp_write;
	assign bmem_wdata = cache_adapter_i.dfp_wdata;
	assign cache_adapter_i.dfp_ready = bmem_ready;
	assign cache_adapter_i.dfp_raddr = bmem_raddr;
	assign cache_adapter_i.dfp_rdata = bmem_rdata;
	assign cache_adapter_i.dfp_rvalid = bmem_rvalid;
	localparam _param_425F7_DEPTH = 8;
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	generate
		if (1) begin : inst_queue_i
			reg _sv2v_0;
			localparam DEPTH = _param_425F7_DEPTH;
			wire clk;
			wire rst;
			localparam ADDR_IDX = 3;
			localparam cpu_params_IF_WIDTH = 2;
			reg [(((((cpu_params_IF_WIDTH * 32) + cpu_params_IF_WIDTH) + (cpu_params_IF_WIDTH * 32)) + 32) + cpu_params_IF_WIDTH) - 1:0] fifo [0:7];
			wire enq_en;
			wire full;
			wire [(((((cpu_params_IF_WIDTH * 32) + cpu_params_IF_WIDTH) + (cpu_params_IF_WIDTH * 32)) + 32) + cpu_params_IF_WIDTH) - 1:0] enq_data;
			wire deq_en;
			wire empty;
			wire [(((((cpu_params_IF_WIDTH * 32) + cpu_params_IF_WIDTH) + (cpu_params_IF_WIDTH * 32)) + 32) + cpu_params_IF_WIDTH) - 1:0] deq_data;
			assign enq_en = cpu.frontend_fifo_itf_i.valid;
			assign cpu.frontend_fifo_itf_i.ready = ~full;
			assign enq_data = cpu.frontend_fifo_itf_i.packet;
			assign deq_en = cpu.fifo_backend_itf_i.ready;
			assign cpu.fifo_backend_itf_i.valid = ~empty;
			assign cpu.fifo_backend_itf_i.packet = deq_data;
			reg [ADDR_IDX:0] wr_ptr;
			wire [2:0] wr_ptr_actual;
			wire wr_ptr_flag;
			reg [ADDR_IDX:0] rd_ptr;
			wire [2:0] rd_ptr_actual;
			wire rd_ptr_flag;
			assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
			assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;
			always @(posedge clk)
				if (rst) begin
					wr_ptr <= 1'sb0;
					rd_ptr <= 1'sb0;
				end
				else begin
					if (enq_en && ~full) begin
						fifo[wr_ptr_actual] <= enq_data;
						wr_ptr <= sv2v_cast_4(wr_ptr + 1);
					end
					if (deq_en && ~empty)
						rd_ptr <= sv2v_cast_4(rd_ptr + 1);
				end
			assign empty = wr_ptr == rd_ptr;
			assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
			assign deq_data = fifo[rd_ptr_actual];
			reg [2:0] perf_n_elem;
			reg [2:0] perf_n_elem_nxt;
			always @(posedge clk)
				if (rst)
					perf_n_elem <= 1'sb0;
				else
					perf_n_elem <= perf_n_elem_nxt;
			always @(*) begin
				if (_sv2v_0)
					;
				perf_n_elem_nxt = perf_n_elem;
				if (enq_en && ~full)
					perf_n_elem_nxt = sv2v_cast_3(perf_n_elem_nxt + 1);
				if (deq_en && ~empty)
					perf_n_elem_nxt = sv2v_cast_3(perf_n_elem_nxt - 1);
			end
			initial _sv2v_0 = 0;
		end
	endgenerate
	assign inst_queue_i.clk = clk;
	assign inst_queue_i.rst = rst || backend_flush;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [1'd1 - 1:0] sv2v_cast_1;
		input reg [1'd1 - 1:0] inp;
		sv2v_cast_1 = inp;
	endfunction
	generate
		if (1) begin : backend_i
			wire clk;
			wire rst;
			wire backend_flush;
			wire [31:0] backend_redirect_pc;
			if (1) begin : id_rat_itf_i
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_ID_WIDTH = 2;
				wire [cpu_params_ARF_IDX - 1:0] rs1_arch [0:cpu_params_ID_WIDTH - 1];
				wire [cpu_params_ARF_IDX - 1:0] rs2_arch [0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				reg [cpu_params_PRF_IDX - 1:0] rs1_phy [0:cpu_params_ID_WIDTH - 1];
				reg [cpu_params_PRF_IDX - 1:0] rs2_phy [0:cpu_params_ID_WIDTH - 1];
				reg rs1_valid [0:cpu_params_ID_WIDTH - 1];
				reg rs2_valid [0:cpu_params_ID_WIDTH - 1];
				wire write_en [0:cpu_params_ID_WIDTH - 1];
				wire [cpu_params_ARF_IDX - 1:0] rd_arch [0:cpu_params_ID_WIDTH - 1];
				wire [cpu_params_PRF_IDX - 1:0] rd_phy [0:cpu_params_ID_WIDTH - 1];
			end
			if (1) begin : id_fl_itf_i
				localparam cpu_params_ID_WIDTH = 2;
				wire valid [0:cpu_params_ID_WIDTH - 1];
				wire ready;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [cpu_params_PRF_IDX - 1:0] free_idx [0:cpu_params_ID_WIDTH - 1];
			end
			if (1) begin : id_rob_itf_i
				wire valid;
				wire ready;
				localparam cpu_params_ID_WIDTH = 2;
				wire inst_valid [0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [cpu_params_ROB_IDX - 1:0] rob_id [0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [cpu_params_PRF_IDX - 1:0] rd_phy [0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				wire [cpu_params_ARF_IDX - 1:0] rd_arch [0:cpu_params_ID_WIDTH - 1];
				wire is_store [0:cpu_params_ID_WIDTH - 1];
				wire [412:0] rvfi_dbg [0:cpu_params_ID_WIDTH - 1];
			end
			if (1) begin : ds_int_rs_itf_i
				localparam cpu_params_ID_WIDTH = 2;
				reg valid [0:cpu_params_ID_WIDTH - 1];
				wire ready;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				reg [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop [0:cpu_params_ID_WIDTH - 1];
			end
			if (1) begin : ds_intm_rs_itf_i
				localparam cpu_params_ID_WIDTH = 2;
				reg valid [0:cpu_params_ID_WIDTH - 1];
				wire ready;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				reg [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop [0:cpu_params_ID_WIDTH - 1];
			end
			if (1) begin : ds_branch_itf_i
				reg valid;
				wire ready;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				reg [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop;
			end
			if (1) begin : ds_lsu_itf_i
				reg valid;
				wire ready;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				reg [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop;
			end
			if (1) begin : rob_rrf_itf_i
				localparam cpu_params_ID_WIDTH = 2;
				wire valid [0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [cpu_params_PRF_IDX - 1:0] rd_phy [0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				wire [cpu_params_ARF_IDX - 1:0] rd_arch [0:cpu_params_ID_WIDTH - 1];
			end
			if (1) begin : rrf_fl_itf_i
				localparam cpu_params_ID_WIDTH = 2;
				reg valid [0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				reg [cpu_params_PRF_IDX - 1:0] stale_idx [0:cpu_params_ID_WIDTH - 1];
			end
			localparam cpu_params_CDB_WIDTH = 5;
			genvar _arr_5BD2B;
			for (_arr_5BD2B = 0; _arr_5BD2B <= (cpu_params_CDB_WIDTH - 1); _arr_5BD2B = _arr_5BD2B + 1) begin : cdb_itfs
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [cpu_params_ROB_IDX - 1:0] rob_id;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [cpu_params_PRF_IDX - 1:0] rd_phy;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				wire [cpu_params_ARF_IDX - 1:0] rd_arch;
				wire [31:0] rd_value;
				wire [31:0] rs1_value_dbg;
				wire [31:0] rs2_value_dbg;
				wire valid;
			end
			if (1) begin : cb_rob_itf_i
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [cpu_params_ROB_IDX - 1:0] rob_id;
				wire miss_predict;
				wire [31:0] target_address;
				wire ready;
				wire dequeue;
			end
			if (1) begin : ldq_rob_itf
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [cpu_params_ROB_IDX - 1:0] rob_id;
				wire [31:0] addr_dbg;
				wire [3:0] rmask_dbg;
				wire [31:0] rdata_dbg;
				wire valid;
			end
			if (1) begin : stq_rob_itf
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [cpu_params_ROB_IDX - 1:0] rob_id;
				wire [31:0] addr_dbg;
				wire [3:0] wmask_dbg;
				wire [31:0] wdata_dbg;
				wire [31:0] rs1_value_dbg;
				wire [31:0] rs2_value_dbg;
				wire valid;
				wire ready;
			end
			genvar _arr_55461;
			for (_arr_55461 = 0; _arr_55461 <= (cpu_params_CDB_WIDTH - 1); _arr_55461 = _arr_55461 + 1) begin : rs_prf_itfs
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [cpu_params_PRF_IDX - 1:0] rs1_phy;
				wire [cpu_params_PRF_IDX - 1:0] rs2_phy;
				wire [31:0] rs1_value;
				wire [31:0] rs2_value;
				localparam cpu_params_CDB_WIDTH = 5;
				localparam cpu_params_INT_ISSUE_WIDTH = 2;
				localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
				wire [((((1'd1 + 1) + (1'd1 + 1)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) - 1:0] rs_bypass;
			end
			wire dispatch_valid;
			wire dispatch_ready;
			localparam cpu_params_ID_WIDTH = 2;
			wire [0:cpu_params_ID_WIDTH - 1] uops_valid;
			wire [(cpu_params_ID_WIDTH * 2) - 1:0] rs_type;
			localparam cpu_params_ARF_DEPTH = 32;
			localparam cpu_params_ARF_IDX = $clog2(1'd0);
			localparam cpu_params_PRF_DEPTH = 64;
			localparam cpu_params_PRF_IDX = $clog2(1'd0);
			localparam cpu_params_ROB_DEPTH = 32;
			localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
			wire [((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (cpu_params_ID_WIDTH * (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33)) - 1 : (cpu_params_ID_WIDTH * (1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 31)):((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 0 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32)] uops;
			wire [(cpu_params_ARF_DEPTH * cpu_params_PRF_IDX) - 1:0] rrf_mem;
			if (1) begin : id_stage_i
				reg _sv2v_0;
				wire clk;
				wire rst;
				wire nxt_valid;
				wire nxt_ready;
				localparam cpu_params_ID_WIDTH = 2;
				reg [0:cpu_params_ID_WIDTH - 1] uops_valid;
				wire [(cpu_params_ID_WIDTH * 2) - 1:0] rs_type;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (cpu_params_ID_WIDTH * (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33)) - 1 : (cpu_params_ID_WIDTH * (1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 31)):((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 0 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32)] uops;
				wire uops_raw_valid [0:cpu_params_ID_WIDTH - 1];
				wire [1:0] fu_type [0:cpu_params_ID_WIDTH - 1];
				wire [3:0] fu_opcode [0:cpu_params_ID_WIDTH - 1];
				wire [0:0] op1_sel [0:cpu_params_ID_WIDTH - 1];
				wire [0:0] op2_sel [0:cpu_params_ID_WIDTH - 1];
				wire [31:0] imm [0:cpu_params_ID_WIDTH - 1];
				wire [cpu_params_ARF_IDX - 1:0] rd_arch [0:cpu_params_ID_WIDTH - 1];
				wire rd_en [0:cpu_params_ID_WIDTH - 1];
				wire [cpu_params_ARF_IDX - 1:0] rs1_arch [0:cpu_params_ID_WIDTH - 1];
				wire [cpu_params_ARF_IDX - 1:0] rs2_arch [0:cpu_params_ID_WIDTH - 1];
				wire is_store [0:cpu_params_ID_WIDTH - 1];
				genvar _gv_i_26;
				for (_gv_i_26 = 0; _gv_i_26 < cpu_params_ID_WIDTH; _gv_i_26 = _gv_i_26 + 1) begin : decoders
					localparam i = _gv_i_26;
					decoder decoder_i(
						.inst(cpu.fifo_backend_itf_i.packet[((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31)))) - (((1'd0 * 32) - 1) - (i * 32))+:32]),
						.rs_type(rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2]),
						.fu_type(fu_type[i]),
						.fu_opcode(fu_opcode[i]),
						.op1_sel(op1_sel[i]),
						.op2_sel(op2_sel[i]),
						.imm(imm[i]),
						.rd_arch(rd_arch[i]),
						.rd_en(rd_en[i]),
						.rs1_arch(rs1_arch[i]),
						.rs2_arch(rs2_arch[i]),
						.is_store(is_store[i])
					);
					assign uops_raw_valid[i] = cpu.fifo_backend_itf_i.packet[(1'd0 - 1) - ((1'd0 - 1) - i)];
					assign uops[(((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 75 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (75 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))] = uops_valid[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)] = cpu.fifo_backend_itf_i.packet[1'd0 + 31-:((1'd0 + 31) >= (1'd0 + 0) ? ((1'd0 + 31) - (1'd0 + 0)) + 1 : ((1'd0 + 0) - (1'd0 + 31)) + 1)] + ($unsigned(i) * 4);
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)] = cpu.fifo_backend_itf_i.packet[((1'd0 * 32) + (1'd0 + ((1'd0 * 32) + (1'd0 + 31)))) - (((1'd0 * 32) - 1) - (i * 32))+:32];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)] = rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)] = fu_type[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (6 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)] = fu_opcode[i];
					assign uops[(((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (2 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))] = op1_sel[i];
					assign uops[(((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 1 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (1 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))] = op2_sel[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) + ((32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) >= (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))) ? ((32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))) + 1 : ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))) - (32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) + 1)) - 1)-:((32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) >= (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))) ? ((32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))) + 1 : ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))) - (32 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) + 1)] = imm[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) + ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) >= (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)) ? ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) + 1)) - 1)-:((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) >= (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)) ? ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) + 1)] = rd_arch[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) + ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)) >= (cpu_params_ARF_IDX + 33) ? ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)) - (cpu_params_ARF_IDX + 33)) + 1 : ((cpu_params_ARF_IDX + 33) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) + 1)) - 1)-:((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)) >= (cpu_params_ARF_IDX + 33) ? ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)) - (cpu_params_ARF_IDX + 33)) + 1 : ((cpu_params_ARF_IDX + 33) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) + 1)] = rs1_arch[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ARF_IDX + 32 : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ARF_IDX + 32)) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ARF_IDX + 32 : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ARF_IDX + 32))) + ((cpu_params_ARF_IDX + 32) >= 33 ? cpu_params_ARF_IDX + 0 : 34 - (cpu_params_ARF_IDX + 32))) - 1)-:((cpu_params_ARF_IDX + 32) >= 33 ? cpu_params_ARF_IDX + 0 : 34 - (cpu_params_ARF_IDX + 32))] = rs2_arch[i];
					assign uops[(((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 32 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 0)] = cpu.fifo_backend_itf_i.packet[(1'd0 + ((1'd0 * 32) + (1'd0 + 31))) - ((1'd0 - 1) - i)];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 31 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 1) : ((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 31 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 1)) + 31)-:32] = cpu.fifo_backend_itf_i.packet[((1'd0 * 32) + (1'd0 + 31)) - (((1'd0 * 32) - 1) - (i * 32))+:32];
				end
				if (cpu_params_ID_WIDTH == 2) begin : filter_2way
					reg dispatch_stalled;
					reg [1:0] uops_is_br;
					reg [1:0] uops_is_mem;
					reg [1:0] dispatch_mask;
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_24
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								begin
									uops_is_br[i] = ((rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2] == 2'b10) && uops_raw_valid[i]) && cpu.fifo_backend_itf_i.valid;
									uops_is_mem[i] = ((rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2] == 2'b11) && uops_raw_valid[i]) && cpu.fifo_backend_itf_i.valid;
								end
						end
					end
					always @(posedge clk)
						if (rst)
							dispatch_stalled <= 1'b0;
						else if (uops_is_br[0] || (uops_is_mem[0] && uops_is_mem[1])) begin
							if ((((dispatch_stalled == 1'b0) && cpu.backend_i.id_fl_itf_i.ready) && cpu.backend_i.id_rob_itf_i.ready) && nxt_ready)
								dispatch_stalled <= 1'b1;
							else if ((((dispatch_stalled == 1'b1) && cpu.backend_i.id_fl_itf_i.ready) && cpu.backend_i.id_rob_itf_i.ready) && nxt_ready)
								dispatch_stalled <= 1'b0;
						end
						else
							dispatch_stalled <= 1'b0;
					always @(*) begin
						if (_sv2v_0)
							;
						dispatch_mask = 2'b11;
						if (uops_is_br[0]) begin
							if (dispatch_stalled == 1'b0)
								dispatch_mask = 2'b01;
							else
								dispatch_mask = 2'b10;
						end
						if (uops_is_mem[0] && uops_is_mem[1]) begin
							if (dispatch_stalled == 1'b0)
								dispatch_mask = 2'b01;
							else
								dispatch_mask = 2'b10;
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_25
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								uops_valid[i] = uops_raw_valid[i] && dispatch_mask[i];
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						cpu.fifo_backend_itf_i.ready = 1'b0;
						if (uops_is_br[0] || (uops_is_mem[0] && uops_is_mem[1]))
							cpu.fifo_backend_itf_i.ready = (((dispatch_stalled == 1'b1) && cpu.backend_i.id_fl_itf_i.ready) && cpu.backend_i.id_rob_itf_i.ready) && nxt_ready;
						else
							cpu.fifo_backend_itf_i.ready = (cpu.backend_i.id_fl_itf_i.ready && cpu.backend_i.id_rob_itf_i.ready) && nxt_ready;
					end
				end
				if (cpu_params_ID_WIDTH == 1) begin : filter_1way
					wire garbage_clk;
					wire garbage_rst;
					assign garbage_clk = clk;
					assign garbage_rst = rst;
					wire [1:1] sv2v_tmp_74E12;
					assign sv2v_tmp_74E12 = uops_raw_valid[0];
					always @(*) uops_valid[0] = sv2v_tmp_74E12;
					wire [1:1] sv2v_tmp_033A9;
					assign sv2v_tmp_033A9 = (cpu.backend_i.id_fl_itf_i.ready && cpu.backend_i.id_rob_itf_i.ready) && nxt_ready;
					always @(*) cpu.fifo_backend_itf_i.ready = sv2v_tmp_033A9;
				end
				genvar _gv_i_27;
				for (_gv_i_27 = 0; _gv_i_27 < cpu_params_ID_WIDTH; _gv_i_27 = _gv_i_27 + 1) begin : genblk4
					localparam i = _gv_i_27;
					assign cpu.backend_i.id_fl_itf_i.valid[i] = (((cpu.fifo_backend_itf_i.valid && uops_valid[i]) && cpu.backend_i.id_rob_itf_i.ready) && nxt_ready) && (rd_arch[i] != {cpu_params_ARF_IDX {1'sb0}});
				end
				genvar _gv_i_28;
				for (_gv_i_28 = 0; _gv_i_28 < cpu_params_ID_WIDTH; _gv_i_28 = _gv_i_28 + 1) begin : genblk5
					localparam i = _gv_i_28;
					assign cpu.backend_i.id_rat_itf_i.rs1_arch[i] = rs1_arch[i];
					assign cpu.backend_i.id_rat_itf_i.rs2_arch[i] = rs2_arch[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) + ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) >= (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) - (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) + 1 : ((cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) >= (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) - (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) + 1 : ((cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) + 1)] = cpu.backend_i.id_rat_itf_i.rs1_phy[i];
					assign uops[(((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))] = cpu.backend_i.id_rat_itf_i.rs1_valid[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) + ((cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) >= (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))) ? ((cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) - (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))) + 1 : ((34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))) - (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) >= (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))) ? ((cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) - (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))) + 1 : ((34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))) - (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) + 1)] = cpu.backend_i.id_rat_itf_i.rs2_phy[i];
					assign uops[(((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 33 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (33 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))] = cpu.backend_i.id_rat_itf_i.rs2_valid[i];
				end
				genvar _gv_i_29;
				for (_gv_i_29 = 0; _gv_i_29 < cpu_params_ID_WIDTH; _gv_i_29 = _gv_i_29 + 1) begin : genblk6
					localparam i = _gv_i_29;
					assign cpu.backend_i.id_rat_itf_i.write_en[i] = ((((cpu.fifo_backend_itf_i.valid && uops_valid[i]) && cpu.backend_i.id_fl_itf_i.ready) && cpu.backend_i.id_rob_itf_i.ready) && nxt_ready) && (rd_arch[i] != {cpu_params_ARF_IDX {1'sb0}});
					assign cpu.backend_i.id_rat_itf_i.rd_arch[i] = rd_arch[i];
					assign cpu.backend_i.id_rat_itf_i.rd_phy[i] = cpu.backend_i.id_fl_itf_i.free_idx[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) >= (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) >= (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) + 1)] = (rd_arch[i] != {cpu_params_ARF_IDX {1'sb0}} ? cpu.backend_i.id_fl_itf_i.free_idx[i] : {((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) >= (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) + 1) * 1 {1'sb0}});
				end
				assign cpu.backend_i.id_rob_itf_i.valid = (cpu.fifo_backend_itf_i.valid && cpu.backend_i.id_fl_itf_i.ready) && nxt_ready;
				genvar _gv_i_30;
				for (_gv_i_30 = 0; _gv_i_30 < cpu_params_ID_WIDTH; _gv_i_30 = _gv_i_30 + 1) begin : genblk7
					localparam i = _gv_i_30;
					assign cpu.backend_i.id_rob_itf_i.inst_valid[i] = uops_valid[i];
					assign cpu.backend_i.id_rob_itf_i.rd_phy[i] = uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) >= (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) >= (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) + 1)];
					assign cpu.backend_i.id_rob_itf_i.rd_arch[i] = rd_arch[i];
					assign cpu.backend_i.id_rob_itf_i.is_store[i] = is_store[i];
					assign uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))) + ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) >= (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) + 1)) - 1)-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) >= (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))) - (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))) + 1)] = cpu.backend_i.id_rob_itf_i.rob_id[i];
				end
				assign nxt_valid = (cpu.fifo_backend_itf_i.valid && cpu.backend_i.id_fl_itf_i.ready) && cpu.backend_i.id_rob_itf_i.ready;
				genvar _gv_i_31;
				for (_gv_i_31 = 0; _gv_i_31 < cpu_params_ID_WIDTH; _gv_i_31 = _gv_i_31 + 1) begin : genblk8
					localparam i = _gv_i_31;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][411-:64] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][347-:32] = uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)];
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][315-:5] = rs1_arch[i];
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][310-:5] = rs2_arch[i];
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][305-:32] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][273-:32] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][241-:5] = rd_arch[i];
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][236-:32] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][204-:5] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][199-:32] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][167-:32] = uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((42 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (74 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)];
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][135-:32] = cpu.fifo_backend_itf_i.packet[((1'd0 * 32) + (1'd0 + 31)) - (((1'd0 * 32) - 1) - (i * 32))+:32];
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][103-:32] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][71-:4] = 1'sb0;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][67-:4] = 1'sb0;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][63-:32] = 1'sbx;
					assign cpu.backend_i.id_rob_itf_i.rvfi_dbg[i][31-:32] = 1'sbx;
				end
				initial _sv2v_0 = 0;
			end
			assign id_stage_i.clk = clk;
			assign id_stage_i.rst = rst;
			assign dispatch_valid = id_stage_i.nxt_valid;
			assign id_stage_i.nxt_ready = dispatch_ready;
			assign uops_valid = id_stage_i.uops_valid;
			assign rs_type = id_stage_i.rs_type;
			assign uops = id_stage_i.uops;
			localparam _bbase_BE127_cdb = 0;
			if (1) begin : rat_i
				reg _sv2v_0;
				wire clk;
				wire rst;
				wire backend_flush;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [(cpu_params_ARF_DEPTH * cpu_params_PRF_IDX) - 1:0] rrf_mem;
				localparam cpu_params_CDB_WIDTH = 5;
				localparam _mbase_cdb = 0;
				reg [cpu_params_PRF_IDX:0] mem [0:cpu_params_ARF_DEPTH - 1];
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				wire [(cpu_params_PRF_IDX + cpu_params_ARF_IDX) + 0:0] cdb_local [0:cpu_params_CDB_WIDTH - 1];
				genvar _gv_i_7;
				for (_gv_i_7 = 0; _gv_i_7 < cpu_params_CDB_WIDTH; _gv_i_7 = _gv_i_7 + 1) begin : genblk1
					localparam i = _gv_i_7;
					assign cdb_local[i][cpu_params_ARF_IDX + 0-:((cpu_params_ARF_IDX + 0) >= 1 ? cpu_params_ARF_IDX + 0 : 2 - (cpu_params_ARF_IDX + 0))] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].rd_arch;
					assign cdb_local[i][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) >= (cpu_params_ARF_IDX + 1) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) - (cpu_params_ARF_IDX + 1)) + 1 : ((cpu_params_ARF_IDX + 1) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))) + 1)] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].rd_phy;
					assign cdb_local[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].valid;
				end
				localparam cpu_params_ID_WIDTH = 2;
				always @(posedge clk)
					if (rst) begin : sv2v_autoblock_26
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ARF_DEPTH; i = i + 1)
							begin
								mem[i][cpu_params_PRF_IDX] <= 1'b1;
								begin : sv2v_autoblock_27
									reg signed [cpu_params_ARF_IDX - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = i;
									mem[i][cpu_params_PRF_IDX - 1:0] <= {1'b0, sv2v_tmp_cast};
								end
							end
					end
					else if (backend_flush) begin : sv2v_autoblock_28
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ARF_DEPTH; i = i + 1)
							begin
								mem[i][cpu_params_PRF_IDX] <= 1'b1;
								mem[i][cpu_params_PRF_IDX - 1:0] <= rrf_mem[((cpu_params_ARF_DEPTH - 1) - i) * cpu_params_PRF_IDX+:cpu_params_PRF_IDX];
							end
					end
					else begin
						begin : sv2v_autoblock_29
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_CDB_WIDTH; i = i + 1)
								if (cdb_local[i][0] && (mem[cdb_local[i][cpu_params_ARF_IDX + 0-:((cpu_params_ARF_IDX + 0) >= 1 ? cpu_params_ARF_IDX + 0 : 2 - (cpu_params_ARF_IDX + 0))]][cpu_params_PRF_IDX - 1:0] == cdb_local[i][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) >= (cpu_params_ARF_IDX + 1) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) - (cpu_params_ARF_IDX + 1)) + 1 : ((cpu_params_ARF_IDX + 1) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))) + 1)]))
									mem[cdb_local[i][cpu_params_ARF_IDX + 0-:((cpu_params_ARF_IDX + 0) >= 1 ? cpu_params_ARF_IDX + 0 : 2 - (cpu_params_ARF_IDX + 0))]][cpu_params_PRF_IDX] <= 1'b1;
						end
						begin : sv2v_autoblock_30
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								if (cpu.backend_i.id_rat_itf_i.write_en[i]) begin
									mem[cpu.backend_i.id_rat_itf_i.rd_arch[i]][cpu_params_PRF_IDX] <= 1'b0;
									mem[cpu.backend_i.id_rat_itf_i.rd_arch[i]][cpu_params_PRF_IDX - 1:0] <= cpu.backend_i.id_rat_itf_i.rd_phy[i];
								end
						end
					end
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_31
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							begin
								cpu.backend_i.id_rat_itf_i.rs1_phy[i] = mem[cpu.backend_i.id_rat_itf_i.rs1_arch[i]][cpu_params_PRF_IDX - 1:0];
								cpu.backend_i.id_rat_itf_i.rs2_phy[i] = mem[cpu.backend_i.id_rat_itf_i.rs2_arch[i]][cpu_params_PRF_IDX - 1:0];
								cpu.backend_i.id_rat_itf_i.rs1_valid[i] = mem[cpu.backend_i.id_rat_itf_i.rs1_arch[i]][cpu_params_PRF_IDX];
								cpu.backend_i.id_rat_itf_i.rs2_valid[i] = mem[cpu.backend_i.id_rat_itf_i.rs2_arch[i]][cpu_params_PRF_IDX];
								begin : sv2v_autoblock_32
									reg signed [31:0] j;
									for (j = 0; j < i; j = j + 1)
										begin
											if (cpu.backend_i.id_rat_itf_i.write_en[j] && (cpu.backend_i.id_rat_itf_i.rd_arch[j] == cpu.backend_i.id_rat_itf_i.rs1_arch[i])) begin
												cpu.backend_i.id_rat_itf_i.rs1_phy[i] = cpu.backend_i.id_rat_itf_i.rd_phy[j];
												cpu.backend_i.id_rat_itf_i.rs1_valid[i] = 1'b0;
											end
											if (cpu.backend_i.id_rat_itf_i.write_en[j] && (cpu.backend_i.id_rat_itf_i.rd_arch[j] == cpu.backend_i.id_rat_itf_i.rs2_arch[i])) begin
												cpu.backend_i.id_rat_itf_i.rs2_phy[i] = cpu.backend_i.id_rat_itf_i.rd_phy[j];
												cpu.backend_i.id_rat_itf_i.rs2_valid[i] = 1'b0;
											end
										end
								end
								begin : sv2v_autoblock_33
									reg signed [31:0] j;
									for (j = 0; j < cpu_params_CDB_WIDTH; j = j + 1)
										if (cdb_local[j][0]) begin
											if (cdb_local[j][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) >= (cpu_params_ARF_IDX + 1) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) - (cpu_params_ARF_IDX + 1)) + 1 : ((cpu_params_ARF_IDX + 1) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))) + 1)] == cpu.backend_i.id_rat_itf_i.rs1_phy[i])
												cpu.backend_i.id_rat_itf_i.rs1_valid[i] = 1'b1;
											if (cdb_local[j][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) >= (cpu_params_ARF_IDX + 1) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) - (cpu_params_ARF_IDX + 1)) + 1 : ((cpu_params_ARF_IDX + 1) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))) + 1)] == cpu.backend_i.id_rat_itf_i.rs2_phy[i])
												cpu.backend_i.id_rat_itf_i.rs2_valid[i] = 1'b1;
										end
								end
								if (cpu.backend_i.id_rat_itf_i.rs1_arch[i] == {sv2v_cast_1($clog2(1'd0)) {1'sb0}}) begin
									cpu.backend_i.id_rat_itf_i.rs1_phy[i] = 1'sb0;
									cpu.backend_i.id_rat_itf_i.rs1_valid[i] = 1'b1;
								end
								if (cpu.backend_i.id_rat_itf_i.rs2_arch[i] == {sv2v_cast_1($clog2(1'd0)) {1'sb0}}) begin
									cpu.backend_i.id_rat_itf_i.rs2_phy[i] = 1'sb0;
									cpu.backend_i.id_rat_itf_i.rs2_valid[i] = 1'b1;
								end
							end
					end
				end
				initial _sv2v_0 = 0;
			end
			assign rat_i.clk = clk;
			assign rat_i.rst = rst;
			assign rat_i.backend_flush = backend_flush;
			assign rat_i.rrf_mem = rrf_mem;
			if (1) begin : free_list_i
				reg _sv2v_0;
				wire clk;
				wire rst;
				wire backend_flush;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam FREELIST_DEPTH = cpu_params_PRF_DEPTH - cpu_params_ARF_DEPTH;
				localparam FREELIST_IDX = $clog2(FREELIST_DEPTH);
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				reg [cpu_params_PRF_IDX - 1:0] free_list [0:FREELIST_DEPTH - 1];
				reg [FREELIST_IDX - 1:0] wr_ptr;
				reg [FREELIST_IDX - 1:0] rd_ptr;
				localparam cpu_params_ID_WIDTH = 2;
				reg [FREELIST_IDX - 1:0] wr_ptrs [0:cpu_params_ID_WIDTH - 1];
				reg [FREELIST_IDX - 1:0] rd_ptrs [0:cpu_params_ID_WIDTH - 1];
				reg [FREELIST_IDX:0] counter;
				wire [FREELIST_IDX:0] counter_nxt;
				localparam cpu_params_ID_WIDTH_IDX = $clog2(1'd0);
				reg [cpu_params_ID_WIDTH_IDX:0] n_valids_id;
				reg [cpu_params_ID_WIDTH_IDX:0] n_valids_rrf;
				always @(posedge clk)
					if (rst) begin
						wr_ptr <= 1'sb0;
						rd_ptr <= 1'sb0;
						begin : sv2v_autoblock_34
							reg [((FREELIST_IDX + 0) >= 0 ? FREELIST_IDX + 1 : 1 - (FREELIST_IDX + 0)) - 1:0] sv2v_tmp_cast;
							sv2v_tmp_cast = $unsigned(FREELIST_DEPTH);
							counter <= sv2v_tmp_cast;
						end
					end
					else if (backend_flush) begin
						wr_ptr <= 1'sb0;
						rd_ptr <= 1'sb0;
						begin : sv2v_autoblock_35
							reg [((FREELIST_IDX + 0) >= 0 ? FREELIST_IDX + 1 : 1 - (FREELIST_IDX + 0)) - 1:0] sv2v_tmp_cast;
							sv2v_tmp_cast = $unsigned(FREELIST_DEPTH);
							counter <= sv2v_tmp_cast;
						end
					end
					else begin
						begin : sv2v_autoblock_36
							reg [FREELIST_IDX - 1:0] sv2v_tmp_cast;
							sv2v_tmp_cast = wr_ptr + n_valids_rrf;
							wr_ptr <= sv2v_tmp_cast;
						end
						if (cpu.backend_i.id_fl_itf_i.ready) begin : sv2v_autoblock_37
							reg [FREELIST_IDX - 1:0] sv2v_tmp_cast_1;
							sv2v_tmp_cast_1 = rd_ptr + n_valids_id;
							rd_ptr <= sv2v_tmp_cast_1;
						end
						counter <= counter_nxt;
					end
				function automatic [((FREELIST_IDX + 0) >= 0 ? FREELIST_IDX + 1 : 1 - (FREELIST_IDX + 0)) - 1:0] sv2v_cast_70C2D;
					input reg [((FREELIST_IDX + 0) >= 0 ? FREELIST_IDX + 1 : 1 - (FREELIST_IDX + 0)) - 1:0] inp;
					sv2v_cast_70C2D = inp;
				endfunction
				assign counter_nxt = (cpu.backend_i.id_fl_itf_i.ready ? (counter + sv2v_cast_70C2D(n_valids_rrf)) - sv2v_cast_70C2D(n_valids_id) : counter + sv2v_cast_70C2D(n_valids_rrf));
				always @(posedge clk)
					if (rst) begin : sv2v_autoblock_38
						reg signed [31:0] i;
						for (i = 0; i < FREELIST_DEPTH; i = i + 1)
							begin : sv2v_autoblock_39
								reg [cpu_params_PRF_IDX - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = cpu_params_ARF_DEPTH + $unsigned(i);
								free_list[i] <= sv2v_tmp_cast;
							end
					end
					else if (backend_flush) begin : sv2v_autoblock_40
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							if (cpu.backend_i.rrf_fl_itf_i.valid[i]) begin : sv2v_autoblock_41
								reg [FREELIST_IDX - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = wr_ptrs[i];
								free_list[sv2v_tmp_cast] <= cpu.backend_i.rrf_fl_itf_i.stale_idx[i];
							end
					end
					else begin : sv2v_autoblock_42
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							if (cpu.backend_i.rrf_fl_itf_i.valid[i]) begin : sv2v_autoblock_43
								reg [FREELIST_IDX - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = wr_ptrs[i];
								free_list[sv2v_tmp_cast] <= cpu.backend_i.rrf_fl_itf_i.stale_idx[i];
							end
					end
				always @(*) begin
					if (_sv2v_0)
						;
					n_valids_id = 1'sb0;
					begin : sv2v_autoblock_44
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							begin
								begin : sv2v_autoblock_45
									reg [FREELIST_IDX - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = n_valids_id;
									rd_ptrs[i] = rd_ptr + sv2v_tmp_cast;
								end
								if (cpu.backend_i.id_fl_itf_i.valid[i]) begin : sv2v_autoblock_46
									reg [((cpu_params_ID_WIDTH_IDX + 0) >= 0 ? cpu_params_ID_WIDTH_IDX + 1 : 1 - (cpu_params_ID_WIDTH_IDX + 0)) - 1:0] sv2v_tmp_cast_1;
									sv2v_tmp_cast_1 = n_valids_id + 1;
									n_valids_id = sv2v_tmp_cast_1;
								end
							end
					end
				end
				always @(*) begin
					if (_sv2v_0)
						;
					n_valids_rrf = 1'sb0;
					begin : sv2v_autoblock_47
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							begin
								begin : sv2v_autoblock_48
									reg [FREELIST_IDX - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = n_valids_rrf;
									wr_ptrs[i] = wr_ptr + sv2v_tmp_cast;
								end
								if (cpu.backend_i.rrf_fl_itf_i.valid[i]) begin : sv2v_autoblock_49
									reg [((cpu_params_ID_WIDTH_IDX + 0) >= 0 ? cpu_params_ID_WIDTH_IDX + 1 : 1 - (cpu_params_ID_WIDTH_IDX + 0)) - 1:0] sv2v_tmp_cast_1;
									sv2v_tmp_cast_1 = n_valids_rrf + 1;
									n_valids_rrf = sv2v_tmp_cast_1;
								end
							end
					end
				end
				genvar _gv_i_8;
				for (_gv_i_8 = 0; _gv_i_8 < cpu_params_ID_WIDTH; _gv_i_8 = _gv_i_8 + 1) begin : genblk1
					localparam i = _gv_i_8;
					function automatic [FREELIST_IDX - 1:0] sv2v_cast_CD795;
						input reg [FREELIST_IDX - 1:0] inp;
						sv2v_cast_CD795 = inp;
					endfunction
					assign cpu.backend_i.id_fl_itf_i.free_idx[i] = free_list[sv2v_cast_CD795(rd_ptrs[i])];
				end
				assign cpu.backend_i.id_fl_itf_i.ready = counter >= sv2v_cast_70C2D(cpu_params_ID_WIDTH);
				initial _sv2v_0 = 0;
			end
			assign free_list_i.clk = clk;
			assign free_list_i.rst = rst;
			assign free_list_i.backend_flush = backend_flush;
			localparam _bbase_D4947_cdb = 0;
			if (1) begin : rob_i
				reg _sv2v_0;
				wire clk;
				wire rst;
				wire backend_flush;
				wire [31:0] backend_redirect_pc;
				localparam cpu_params_CDB_WIDTH = 5;
				localparam _mbase_cdb = 0;
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				reg [((2 + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 0:0] rob_arr [0:cpu_params_ROB_DEPTH - 1][0:cpu_params_ID_WIDTH - 1];
				localparam cpu_params_ROB_PTR_IDX = $clog2(1'd0);
				reg [cpu_params_ROB_PTR_IDX:0] head_ptr_reg;
				reg [cpu_params_ROB_PTR_IDX:0] tail_ptr_reg;
				wire [cpu_params_ROB_PTR_IDX - 1:0] head_ptr;
				wire head_ptr_flag;
				wire [cpu_params_ROB_PTR_IDX - 1:0] tail_ptr;
				wire tail_ptr_flag;
				wire full;
				wire empty;
				reg pop;
				reg [cpu_params_ID_WIDTH - 1:0] commit_instr;
				wire [cpu_params_ROB_IDX + 96:0] cdb_rob [0:cpu_params_CDB_WIDTH - 1];
				wire dequeue;
				reg [412:0] rvfi_itf [0:cpu_params_ID_WIDTH - 1];
				reg [412:0] rvfi_array [0:cpu_params_ROB_DEPTH - 1][0:cpu_params_ID_WIDTH - 1];
				reg [63:0] rvfi_order;
				reg [63:0] commit_instrs;
				assign {head_ptr_flag, head_ptr} = head_ptr_reg;
				assign {tail_ptr_flag, tail_ptr} = tail_ptr_reg;
				assign full = (tail_ptr == head_ptr) && (tail_ptr_flag != head_ptr_flag);
				assign empty = (tail_ptr == head_ptr) && (tail_ptr_flag == head_ptr_flag);
				always @(*) begin
					if (_sv2v_0)
						;
					if (empty)
						pop = 1'b0;
					else if (cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready)
						pop = 1'b1;
					else begin
						pop = 1'b1;
						begin : sv2v_autoblock_50
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								if (rob_arr[head_ptr][i][2 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))] && ~rob_arr[head_ptr][i][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))])
									pop = 1'b0;
						end
					end
				end
				genvar _gv_k_1;
				for (_gv_k_1 = 0; _gv_k_1 < cpu_params_CDB_WIDTH; _gv_k_1 = _gv_k_1 + 1) begin : cdb_assign
					localparam k = _gv_k_1;
					assign cdb_rob[k][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] = cpu.backend_i.cdb_itfs[k + _mbase_cdb].rob_id;
					assign cdb_rob[k][96] = cpu.backend_i.cdb_itfs[k + _mbase_cdb].valid;
					assign cdb_rob[k][95-:32] = cpu.backend_i.cdb_itfs[k + _mbase_cdb].rd_value;
					assign cdb_rob[k][63-:32] = cpu.backend_i.cdb_itfs[k + _mbase_cdb].rs1_value_dbg;
					assign cdb_rob[k][31-:32] = cpu.backend_i.cdb_itfs[k + _mbase_cdb].rs2_value_dbg;
				end
				always @(posedge clk)
					if (rst || backend_flush) begin
						begin : sv2v_autoblock_51
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_ROB_DEPTH; i = i + 1)
								begin : sv2v_autoblock_52
									reg signed [31:0] j;
									for (j = 0; j < cpu_params_ID_WIDTH; j = j + 1)
										begin
											rob_arr[i][j][2 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))] <= 1'b0;
											rob_arr[i][j][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))] <= 1'b0;
										end
								end
						end
						head_ptr_reg <= 1'sb0;
						tail_ptr_reg <= 1'sb0;
					end
					else begin
						if (cpu.backend_i.id_rob_itf_i.valid && cpu.backend_i.id_rob_itf_i.ready) begin
							begin : sv2v_autoblock_53
								reg [((cpu_params_ROB_PTR_IDX + 0) >= 0 ? cpu_params_ROB_PTR_IDX + 1 : 1 - (cpu_params_ROB_PTR_IDX + 0)) - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = tail_ptr_reg + 1;
								tail_ptr_reg <= sv2v_tmp_cast;
							end
							begin : sv2v_autoblock_54
								reg signed [31:0] i;
								for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
									begin
										rob_arr[tail_ptr][i][2 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))] <= cpu.backend_i.id_rob_itf_i.inst_valid[i];
										rob_arr[tail_ptr][i][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))] <= 1'b0;
										rob_arr[tail_ptr][i][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) >= (cpu_params_ARF_IDX + 1) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) - (cpu_params_ARF_IDX + 1)) + 1 : ((cpu_params_ARF_IDX + 1) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))) + 1)] <= cpu.backend_i.id_rob_itf_i.rd_phy[i];
										rob_arr[tail_ptr][i][cpu_params_ARF_IDX + 0-:((cpu_params_ARF_IDX + 0) >= 1 ? cpu_params_ARF_IDX + 0 : 2 - (cpu_params_ARF_IDX + 0))] <= cpu.backend_i.id_rob_itf_i.rd_arch[i];
										rob_arr[tail_ptr][i][0] <= cpu.backend_i.id_rob_itf_i.is_store[i];
										rvfi_array[tail_ptr][i] <= cpu.backend_i.id_rob_itf_i.rvfi_dbg[i];
									end
							end
						end
						if (pop) begin : sv2v_autoblock_55
							reg [((cpu_params_ROB_PTR_IDX + 0) >= 0 ? cpu_params_ROB_PTR_IDX + 1 : 1 - (cpu_params_ROB_PTR_IDX + 0)) - 1:0] sv2v_tmp_cast;
							sv2v_tmp_cast = head_ptr_reg + 1;
							head_ptr_reg <= sv2v_tmp_cast;
						end
						begin : sv2v_autoblock_56
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_CDB_WIDTH; i = i + 1)
								if (cdb_rob[i][96]) begin
									rob_arr[cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] / cpu_params_ID_WIDTH][cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] % cpu_params_ID_WIDTH][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))] <= 1'b1;
									rvfi_array[cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] / cpu_params_ID_WIDTH][cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] % cpu_params_ID_WIDTH][236-:32] <= cdb_rob[i][95-:32];
									rvfi_array[cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] / cpu_params_ID_WIDTH][cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] % cpu_params_ID_WIDTH][305-:32] <= cdb_rob[i][63-:32];
									rvfi_array[cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] / cpu_params_ID_WIDTH][cdb_rob[i][cpu_params_ROB_IDX + 96-:((cpu_params_ROB_IDX + 96) >= 97 ? cpu_params_ROB_IDX + 0 : 98 - (cpu_params_ROB_IDX + 96))] % cpu_params_ID_WIDTH][273-:32] <= cdb_rob[i][31-:32];
								end
						end
						if (cpu.backend_i.ldq_rob_itf.valid) begin
							rvfi_array[cpu.backend_i.ldq_rob_itf.rob_id / cpu_params_ID_WIDTH][cpu.backend_i.ldq_rob_itf.rob_id % cpu_params_ID_WIDTH][103-:32] <= cpu.backend_i.ldq_rob_itf.addr_dbg;
							rvfi_array[cpu.backend_i.ldq_rob_itf.rob_id / cpu_params_ID_WIDTH][cpu.backend_i.ldq_rob_itf.rob_id % cpu_params_ID_WIDTH][71-:4] <= cpu.backend_i.ldq_rob_itf.rmask_dbg;
							rvfi_array[cpu.backend_i.ldq_rob_itf.rob_id / cpu_params_ID_WIDTH][cpu.backend_i.ldq_rob_itf.rob_id % cpu_params_ID_WIDTH][67-:4] <= 1'sb0;
							rvfi_array[cpu.backend_i.ldq_rob_itf.rob_id / cpu_params_ID_WIDTH][cpu.backend_i.ldq_rob_itf.rob_id % cpu_params_ID_WIDTH][63-:32] <= cpu.backend_i.ldq_rob_itf.rdata_dbg;
							rvfi_array[cpu.backend_i.ldq_rob_itf.rob_id / cpu_params_ID_WIDTH][cpu.backend_i.ldq_rob_itf.rob_id % cpu_params_ID_WIDTH][31-:32] <= 1'sb0;
						end
					end
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_57
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							commit_instr[i] = pop && rob_arr[head_ptr][i][2 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))];
					end
				end
				assign cpu.backend_i.id_rob_itf_i.ready = ~full;
				genvar _gv_i_9;
				for (_gv_i_9 = 0; _gv_i_9 < cpu_params_ID_WIDTH; _gv_i_9 = _gv_i_9 + 1) begin : genblk2
					localparam i = _gv_i_9;
					function automatic [cpu_params_ROB_IDX - 1:0] sv2v_cast_7DAD8;
						input reg [cpu_params_ROB_IDX - 1:0] inp;
						sv2v_cast_7DAD8 = inp;
					endfunction
					assign cpu.backend_i.id_rob_itf_i.rob_id[i] = sv2v_cast_7DAD8((tail_ptr * cpu_params_ID_WIDTH) + i);
				end
				genvar _gv_i_10;
				for (_gv_i_10 = 0; _gv_i_10 < cpu_params_ID_WIDTH; _gv_i_10 = _gv_i_10 + 1) begin : genblk3
					localparam i = _gv_i_10;
					assign cpu.backend_i.rob_rrf_itf_i.valid[i] = commit_instr[i];
					assign cpu.backend_i.rob_rrf_itf_i.rd_phy[i] = rob_arr[head_ptr][i][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) >= (cpu_params_ARF_IDX + 1) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0)) - (cpu_params_ARF_IDX + 1)) + 1 : ((cpu_params_ARF_IDX + 1) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))) + 1)];
					assign cpu.backend_i.rob_rrf_itf_i.rd_arch[i] = rob_arr[head_ptr][i][cpu_params_ARF_IDX + 0-:((cpu_params_ARF_IDX + 0) >= 1 ? cpu_params_ARF_IDX + 0 : 2 - (cpu_params_ARF_IDX + 0))];
				end
				function automatic [cpu_params_ROB_PTR_IDX - 1:0] sv2v_cast_25975;
					input reg [cpu_params_ROB_PTR_IDX - 1:0] inp;
					sv2v_cast_25975 = inp;
				endfunction
				assign dequeue = (cpu.backend_i.cb_rob_itf_i.ready ? pop && (sv2v_cast_25975(cpu.backend_i.cb_rob_itf_i.rob_id / cpu_params_ID_WIDTH) == head_ptr) : 1'b0);
				assign cpu.backend_i.cb_rob_itf_i.dequeue = dequeue;
				assign backend_flush = dequeue && cpu.backend_i.cb_rob_itf_i.miss_predict;
				assign backend_redirect_pc = cpu.backend_i.cb_rob_itf_i.target_address;
				reg stq_ready;
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_58
						reg [cpu_params_ROB_PTR_IDX - 1:0] sv2v_tmp_cast;
						sv2v_tmp_cast = cpu.backend_i.stq_rob_itf.rob_id / cpu_params_ID_WIDTH;
						stq_ready = sv2v_tmp_cast == head_ptr;
					end
					begin : sv2v_autoblock_59
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							if ((rob_arr[head_ptr][i][2 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))] && !rob_arr[head_ptr][i][0]) && !rob_arr[head_ptr][i][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 0))])
								stq_ready = 1'b0;
					end
				end
				assign cpu.backend_i.stq_rob_itf.ready = stq_ready;
				wire [412:0] rvfi_head [0:cpu_params_ID_WIDTH - 1];
				genvar _gv_i_11;
				for (_gv_i_11 = 0; _gv_i_11 < cpu_params_ID_WIDTH; _gv_i_11 = _gv_i_11 + 1) begin : genblk4
					localparam i = _gv_i_11;
					assign rvfi_head[i] = rvfi_array[head_ptr][i];
					wire [1:1] sv2v_tmp_4EBA8;
					assign sv2v_tmp_4EBA8 = commit_instr[i];
					always @(*) rvfi_itf[i][412] = sv2v_tmp_4EBA8;
					wire [32:1] sv2v_tmp_48047;
					assign sv2v_tmp_48047 = rvfi_head[i][347-:32];
					always @(*) rvfi_itf[i][347-:32] = sv2v_tmp_48047;
					wire [5:1] sv2v_tmp_61CA1;
					assign sv2v_tmp_61CA1 = rvfi_head[i][315-:5];
					always @(*) rvfi_itf[i][315-:5] = sv2v_tmp_61CA1;
					wire [5:1] sv2v_tmp_BF831;
					assign sv2v_tmp_BF831 = rvfi_head[i][310-:5];
					always @(*) rvfi_itf[i][310-:5] = sv2v_tmp_BF831;
					wire [32:1] sv2v_tmp_55A3D;
					assign sv2v_tmp_55A3D = ((cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready) && (sv2v_cast_32(cpu.backend_i.stq_rob_itf.rob_id % cpu_params_ID_WIDTH) == i) ? cpu.backend_i.stq_rob_itf.rs1_value_dbg : rvfi_head[i][305-:32]);
					always @(*) rvfi_itf[i][305-:32] = sv2v_tmp_55A3D;
					wire [32:1] sv2v_tmp_3290E;
					assign sv2v_tmp_3290E = ((cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready) && (sv2v_cast_32(cpu.backend_i.stq_rob_itf.rob_id % cpu_params_ID_WIDTH) == i) ? cpu.backend_i.stq_rob_itf.rs2_value_dbg : rvfi_head[i][273-:32]);
					always @(*) rvfi_itf[i][273-:32] = sv2v_tmp_3290E;
					wire [5:1] sv2v_tmp_48BC1;
					assign sv2v_tmp_48BC1 = rvfi_head[i][241-:5];
					always @(*) rvfi_itf[i][241-:5] = sv2v_tmp_48BC1;
					wire [32:1] sv2v_tmp_C52C7;
					assign sv2v_tmp_C52C7 = rvfi_head[i][236-:32];
					always @(*) rvfi_itf[i][236-:32] = sv2v_tmp_C52C7;
					wire [5:1] sv2v_tmp_37A31;
					assign sv2v_tmp_37A31 = rvfi_head[i][204-:5];
					always @(*) rvfi_itf[i][204-:5] = sv2v_tmp_37A31;
					wire [32:1] sv2v_tmp_E33C7;
					assign sv2v_tmp_E33C7 = rvfi_head[i][199-:32];
					always @(*) rvfi_itf[i][199-:32] = sv2v_tmp_E33C7;
					wire [32:1] sv2v_tmp_6A907;
					assign sv2v_tmp_6A907 = rvfi_head[i][167-:32];
					always @(*) rvfi_itf[i][167-:32] = sv2v_tmp_6A907;
					wire [32:1] sv2v_tmp_3A9EA;
					assign sv2v_tmp_3A9EA = (backend_flush && (sv2v_cast_32(cpu.backend_i.cb_rob_itf_i.rob_id % cpu_params_ID_WIDTH) == i) ? backend_redirect_pc : rvfi_head[i][135-:32]);
					always @(*) rvfi_itf[i][135-:32] = sv2v_tmp_3A9EA;
					wire [32:1] sv2v_tmp_89DAD;
					assign sv2v_tmp_89DAD = ((cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready) && (sv2v_cast_32(cpu.backend_i.stq_rob_itf.rob_id % cpu_params_ID_WIDTH) == i) ? cpu.backend_i.stq_rob_itf.addr_dbg : rvfi_head[i][103-:32]);
					always @(*) rvfi_itf[i][103-:32] = sv2v_tmp_89DAD;
					wire [4:1] sv2v_tmp_8B45A;
					assign sv2v_tmp_8B45A = ((cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready) && (sv2v_cast_32(cpu.backend_i.stq_rob_itf.rob_id % cpu_params_ID_WIDTH) == i) ? {4 {1'sb0}} : rvfi_head[i][71-:4]);
					always @(*) rvfi_itf[i][71-:4] = sv2v_tmp_8B45A;
					wire [4:1] sv2v_tmp_52C02;
					assign sv2v_tmp_52C02 = ((cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready) && (sv2v_cast_32(cpu.backend_i.stq_rob_itf.rob_id % cpu_params_ID_WIDTH) == i) ? cpu.backend_i.stq_rob_itf.wmask_dbg : rvfi_head[i][67-:4]);
					always @(*) rvfi_itf[i][67-:4] = sv2v_tmp_52C02;
					wire [32:1] sv2v_tmp_412A3;
					assign sv2v_tmp_412A3 = ((cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready) && (sv2v_cast_32(cpu.backend_i.stq_rob_itf.rob_id % cpu_params_ID_WIDTH) == i) ? {32 {1'sb0}} : rvfi_head[i][63-:32]);
					always @(*) rvfi_itf[i][63-:32] = sv2v_tmp_412A3;
					wire [32:1] sv2v_tmp_51DF8;
					assign sv2v_tmp_51DF8 = ((cpu.backend_i.stq_rob_itf.valid && cpu.backend_i.stq_rob_itf.ready) && (sv2v_cast_32(cpu.backend_i.stq_rob_itf.rob_id % cpu_params_ID_WIDTH) == i) ? cpu.backend_i.stq_rob_itf.wdata_dbg : rvfi_head[i][31-:32]);
					always @(*) rvfi_itf[i][31-:32] = sv2v_tmp_51DF8;
				end
				always @(posedge clk)
					if (rst)
						rvfi_order <= 64'h0000000000000000;
					else if (pop)
						rvfi_order <= rvfi_order + commit_instrs;
				always @(*) begin
					if (_sv2v_0)
						;
					commit_instrs = 1'sb0;
					begin : sv2v_autoblock_60
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							begin
								rvfi_itf[i][411-:64] = rvfi_order + commit_instrs;
								if (commit_instr[i])
									commit_instrs = commit_instrs + 1;
							end
					end
				end
				initial _sv2v_0 = 0;
			end
			assign rob_i.clk = clk;
			assign rob_i.rst = rst;
			assign backend_flush = rob_i.backend_flush;
			assign backend_redirect_pc = rob_i.backend_redirect_pc;
			if (1) begin : rrf_i
				reg _sv2v_0;
				wire clk;
				wire rst;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				reg [(cpu_params_ARF_DEPTH * cpu_params_PRF_IDX) - 1:0] rrf_mem;
				reg [(cpu_params_ARF_DEPTH * cpu_params_PRF_IDX) - 1:0] mem;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_ID_WIDTH = 2;
				always @(posedge clk)
					if (rst) begin : sv2v_autoblock_61
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ARF_DEPTH; i = i + 1)
							begin : sv2v_autoblock_62
								reg signed [cpu_params_ARF_IDX - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = i;
								mem[((cpu_params_ARF_DEPTH - 1) - i) * cpu_params_PRF_IDX+:cpu_params_PRF_IDX] <= {1'b0, sv2v_tmp_cast};
							end
					end
					else begin : sv2v_autoblock_63
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							if (cpu.backend_i.rob_rrf_itf_i.valid[i] && (cpu.backend_i.rob_rrf_itf_i.rd_arch[i] != {sv2v_cast_1($clog2(1'd0)) {1'sb0}}))
								mem[((cpu_params_ARF_DEPTH - 1) - cpu.backend_i.rob_rrf_itf_i.rd_arch[i]) * cpu_params_PRF_IDX+:cpu_params_PRF_IDX] <= cpu.backend_i.rob_rrf_itf_i.rd_phy[i];
					end
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_64
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							begin
								cpu.backend_i.rrf_fl_itf_i.valid[i] = 1'sb0;
								cpu.backend_i.rrf_fl_itf_i.stale_idx[i] = 1'sbx;
								if (cpu.backend_i.rob_rrf_itf_i.valid[i] && (cpu.backend_i.rob_rrf_itf_i.rd_arch[i] != {sv2v_cast_1($clog2(1'd0)) {1'sb0}})) begin
									cpu.backend_i.rrf_fl_itf_i.valid[i] = 1'sb1;
									cpu.backend_i.rrf_fl_itf_i.stale_idx[i] = mem[((cpu_params_ARF_DEPTH - 1) - cpu.backend_i.rob_rrf_itf_i.rd_arch[i]) * cpu_params_PRF_IDX+:cpu_params_PRF_IDX];
									begin : sv2v_autoblock_65
										reg signed [31:0] j;
										for (j = 0; j < i; j = j + 1)
											if (cpu.backend_i.rob_rrf_itf_i.valid[j] && (cpu.backend_i.rob_rrf_itf_i.rd_arch[j] == cpu.backend_i.rob_rrf_itf_i.rd_arch[i]))
												cpu.backend_i.rrf_fl_itf_i.stale_idx[i] = cpu.backend_i.rob_rrf_itf_i.rd_phy[j];
									end
								end
							end
					end
				end
				always @(*) begin
					if (_sv2v_0)
						;
					rrf_mem = mem;
					begin : sv2v_autoblock_66
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							if (cpu.backend_i.rob_rrf_itf_i.valid[i] && (cpu.backend_i.rob_rrf_itf_i.rd_arch[i] != {sv2v_cast_1($clog2(1'd0)) {1'sb0}}))
								rrf_mem[((cpu_params_ARF_DEPTH - 1) - cpu.backend_i.rob_rrf_itf_i.rd_arch[i]) * cpu_params_PRF_IDX+:cpu_params_PRF_IDX] = cpu.backend_i.rob_rrf_itf_i.rd_phy[i];
					end
				end
				initial _sv2v_0 = 0;
			end
			assign rrf_i.clk = clk;
			assign rrf_i.rst = rst;
			assign rrf_mem = rrf_i.rrf_mem;
			if (1) begin : ds_stage_i
				reg _sv2v_0;
				wire clk;
				wire rst;
				wire prv_valid;
				reg prv_ready;
				localparam cpu_params_ID_WIDTH = 2;
				wire [0:cpu_params_ID_WIDTH - 1] uops_valid;
				wire [(cpu_params_ID_WIDTH * 2) - 1:0] rs_type;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (cpu_params_ID_WIDTH * (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33)) - 1 : (cpu_params_ID_WIDTH * (1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 31)):((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 0 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32)] uops;
				wire dispatch_valid [0:cpu_params_ID_WIDTH - 1];
				reg dispatch_ready [0:cpu_params_ID_WIDTH - 1];
				genvar _gv_i_32;
				for (_gv_i_32 = 0; _gv_i_32 < cpu_params_ID_WIDTH; _gv_i_32 = _gv_i_32 + 1) begin : dispatch_valids
					localparam i = _gv_i_32;
					assign dispatch_valid[i] = prv_valid && uops_valid[i];
				end
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_67
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							begin
								cpu.backend_i.ds_int_rs_itf_i.valid[i] = 1'sb0;
								begin : sv2v_autoblock_68
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_1;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_2;
									reg [sv2v_cast_1($clog2(1'd0 * 1'd0)) - 1:0] sv2v_tmp_cast_3;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_4;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_5;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_6;
									sv2v_tmp_cast = 1'sbx;
									sv2v_tmp_cast_1 = 1'sbx;
									sv2v_tmp_cast_2 = 1'sbx;
									sv2v_tmp_cast_3 = 1'sbx;
									sv2v_tmp_cast_4 = 1'sbx;
									sv2v_tmp_cast_5 = 1'sbx;
									sv2v_tmp_cast_6 = 1'sbx;
									cpu.backend_i.ds_int_rs_itf_i.uop[i] = {75'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast, sv2v_tmp_cast_1, sv2v_tmp_cast_2, 34'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast_3, sv2v_tmp_cast_4, sv2v_tmp_cast_5, sv2v_tmp_cast_6, 33'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
								end
								cpu.backend_i.ds_intm_rs_itf_i.valid[i] = 1'sb0;
								begin : sv2v_autoblock_69
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_7;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_8;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_9;
									reg [sv2v_cast_1($clog2(1'd0 * 1'd0)) - 1:0] sv2v_tmp_cast_10;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_11;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_12;
									reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_13;
									sv2v_tmp_cast_7 = 1'sbx;
									sv2v_tmp_cast_8 = 1'sbx;
									sv2v_tmp_cast_9 = 1'sbx;
									sv2v_tmp_cast_10 = 1'sbx;
									sv2v_tmp_cast_11 = 1'sbx;
									sv2v_tmp_cast_12 = 1'sbx;
									sv2v_tmp_cast_13 = 1'sbx;
									cpu.backend_i.ds_intm_rs_itf_i.uop[i] = {75'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast_7, sv2v_tmp_cast_8, sv2v_tmp_cast_9, 34'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast_10, sv2v_tmp_cast_11, sv2v_tmp_cast_12, sv2v_tmp_cast_13, 33'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
								end
							end
					end
					begin : sv2v_autoblock_70
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							(* full_case, parallel_case *)
							case (rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2])
								2'b00: begin
									cpu.backend_i.ds_int_rs_itf_i.valid[i] = dispatch_valid[i] && prv_ready;
									cpu.backend_i.ds_int_rs_itf_i.uop[i] = uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 0 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) + (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32)))+:((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))];
								end
								2'b01: begin
									cpu.backend_i.ds_intm_rs_itf_i.valid[i] = dispatch_valid[i] && prv_ready;
									cpu.backend_i.ds_intm_rs_itf_i.uop[i] = uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 0 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) + (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32)))+:((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))];
								end
								default:
									;
							endcase
					end
				end
				always @(*) begin : sv2v_autoblock_71
					reg [0:1] _sv2v_jump;
					_sv2v_jump = 2'b00;
					if (_sv2v_0)
						;
					cpu.backend_i.ds_branch_itf_i.valid = 1'sb0;
					begin : sv2v_autoblock_72
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_1;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_2;
						reg [sv2v_cast_1($clog2(1'd0 * 1'd0)) - 1:0] sv2v_tmp_cast_3;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_4;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_5;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_6;
						sv2v_tmp_cast = 1'sbx;
						sv2v_tmp_cast_1 = 1'sbx;
						sv2v_tmp_cast_2 = 1'sbx;
						sv2v_tmp_cast_3 = 1'sbx;
						sv2v_tmp_cast_4 = 1'sbx;
						sv2v_tmp_cast_5 = 1'sbx;
						sv2v_tmp_cast_6 = 1'sbx;
						cpu.backend_i.ds_branch_itf_i.uop = {75'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast, sv2v_tmp_cast_1, sv2v_tmp_cast_2, 34'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast_3, sv2v_tmp_cast_4, sv2v_tmp_cast_5, sv2v_tmp_cast_6, 33'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
					end
					cpu.backend_i.ds_lsu_itf_i.valid = 1'sb0;
					begin : sv2v_autoblock_73
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_7;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_8;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_9;
						reg [sv2v_cast_1($clog2(1'd0 * 1'd0)) - 1:0] sv2v_tmp_cast_10;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_11;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_12;
						reg [sv2v_cast_1($clog2(1'd0)) - 1:0] sv2v_tmp_cast_13;
						sv2v_tmp_cast_7 = 1'sbx;
						sv2v_tmp_cast_8 = 1'sbx;
						sv2v_tmp_cast_9 = 1'sbx;
						sv2v_tmp_cast_10 = 1'sbx;
						sv2v_tmp_cast_11 = 1'sbx;
						sv2v_tmp_cast_12 = 1'sbx;
						sv2v_tmp_cast_13 = 1'sbx;
						cpu.backend_i.ds_lsu_itf_i.uop = {75'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast_7, sv2v_tmp_cast_8, sv2v_tmp_cast_9, 34'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, sv2v_tmp_cast_10, sv2v_tmp_cast_11, sv2v_tmp_cast_12, sv2v_tmp_cast_13, 33'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
					end
					begin : sv2v_autoblock_74
						reg signed [31:0] i;
						begin : sv2v_autoblock_75
							reg signed [31:0] _sv2v_value_on_break;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								if (_sv2v_jump < 2'b10) begin
									_sv2v_jump = 2'b00;
									if ((rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2] == 2'b10) && dispatch_valid[i]) begin
										cpu.backend_i.ds_branch_itf_i.valid = prv_ready;
										cpu.backend_i.ds_branch_itf_i.uop = uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 0 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) + (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32)))+:((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))];
										_sv2v_jump = 2'b10;
									end
									_sv2v_value_on_break = i;
								end
							if (!(_sv2v_jump < 2'b10))
								i = _sv2v_value_on_break;
							if (_sv2v_jump != 2'b11)
								_sv2v_jump = 2'b00;
						end
					end
					if (_sv2v_jump == 2'b00) begin : sv2v_autoblock_76
						reg signed [31:0] i;
						begin : sv2v_autoblock_77
							reg signed [31:0] _sv2v_value_on_break;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								if (_sv2v_jump < 2'b10) begin
									_sv2v_jump = 2'b00;
									if ((rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2] == 2'b11) && dispatch_valid[i]) begin
										cpu.backend_i.ds_lsu_itf_i.valid = prv_ready;
										cpu.backend_i.ds_lsu_itf_i.uop = uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 0 : ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) + (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32)))+:((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))];
										_sv2v_jump = 2'b10;
									end
									_sv2v_value_on_break = i;
								end
							if (!(_sv2v_jump < 2'b10))
								i = _sv2v_value_on_break;
							if (_sv2v_jump != 2'b11)
								_sv2v_jump = 2'b00;
						end
					end
				end
				genvar _gv_i_33;
				for (_gv_i_33 = 0; _gv_i_33 < cpu_params_ID_WIDTH; _gv_i_33 = _gv_i_33 + 1) begin : genblk2
					localparam i = _gv_i_33;
					always @(*) begin
						if (_sv2v_0)
							;
						(* full_case, parallel_case *)
						case (rs_type[((cpu_params_ID_WIDTH - 1) - i) * 2+:2])
							2'b00: dispatch_ready[i] = cpu.backend_i.ds_int_rs_itf_i.ready;
							2'b01: dispatch_ready[i] = cpu.backend_i.ds_intm_rs_itf_i.ready;
							2'b10: dispatch_ready[i] = cpu.backend_i.ds_branch_itf_i.ready;
							2'b11: dispatch_ready[i] = cpu.backend_i.ds_lsu_itf_i.ready;
							default: dispatch_ready[i] = 1'sb0;
						endcase
					end
				end
				always @(*) begin
					if (_sv2v_0)
						;
					prv_ready = 1'b1;
					begin : sv2v_autoblock_78
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							prv_ready = prv_ready && dispatch_ready[i];
					end
				end
				reg [31:0] perf_int_rs_block;
				reg [31:0] perf_intm_rs_block;
				reg [31:0] perf_br_rs_block;
				reg [31:0] perf_mem_rs_block;
				always @(posedge clk)
					if (rst) begin
						perf_int_rs_block <= 1'sb0;
						perf_intm_rs_block <= 1'sb0;
						perf_br_rs_block <= 1'sb0;
						perf_mem_rs_block <= 1'sb0;
					end
					else begin : sv2v_autoblock_79
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
							if (!dispatch_ready[i] && dispatch_valid[i])
								(* full_case, parallel_case *)
								case (uops[((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? (((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) : (((((cpu_params_ID_WIDTH - 1) - i) * ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? ((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 33 : 1 - (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32))) + ((((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) >= 0 ? 10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))) : (((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))))) + ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)) - 1)-:((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) >= (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) ? ((10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32))))))))) - (8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33)))))))))) + 1 : ((8 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 33))))))))) - (10 + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (34 + (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + (cpu_params_ARF_IDX + 32)))))))))) + 1)])
									2'b00: perf_int_rs_block <= perf_int_rs_block + 1;
									2'b01: perf_intm_rs_block <= perf_intm_rs_block + 1;
									2'b10: perf_br_rs_block <= perf_br_rs_block + 1;
									2'b11: perf_mem_rs_block <= perf_mem_rs_block + 1;
									default:
										;
								endcase
					end
				initial _sv2v_0 = 0;
			end
			assign ds_stage_i.clk = clk;
			assign ds_stage_i.rst = rst;
			assign ds_stage_i.prv_valid = dispatch_valid;
			assign dispatch_ready = ds_stage_i.prv_ready;
			assign ds_stage_i.uops_valid = uops_valid;
			assign ds_stage_i.rs_type = rs_type;
			assign ds_stage_i.uops = uops;
			localparam cpu_params_NUM_FAST_BYPASS = 2;
			wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
			localparam cpu_params_MAX_ISSUE_WIDTH = 2;
			localparam signed [(cpu_params_MAX_ISSUE_WIDTH * 32) - 1:0] subset_indices = 64'h0000000000000004;
			localparam cpu_params_INT_ISSUE_WIDTH = 2;
			genvar _arr_DF347;
			for (_arr_DF347 = 0; _arr_DF347 <= (cpu_params_INT_ISSUE_WIDTH - 1); _arr_DF347 = _arr_DF347 + 1) begin : int_to_prf
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [cpu_params_PRF_IDX - 1:0] rs1_phy;
				wire [cpu_params_PRF_IDX - 1:0] rs2_phy;
				wire [31:0] rs1_value;
				wire [31:0] rs2_value;
				localparam cpu_params_CDB_WIDTH = 5;
				localparam cpu_params_INT_ISSUE_WIDTH = 2;
				localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
				wire [((((1'd1 + 1) + (1'd1 + 1)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) - 1:0] rs_bypass;
			end
			genvar _arr_AEFA7;
			for (_arr_AEFA7 = 0; _arr_AEFA7 <= (cpu_params_INT_ISSUE_WIDTH - 1); _arr_AEFA7 = _arr_AEFA7 + 1) begin : int_fu_cdb_out
				localparam cpu_params_ID_WIDTH = 2;
				localparam cpu_params_ROB_DEPTH = 32;
				localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
				wire [cpu_params_ROB_IDX - 1:0] rob_id;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [cpu_params_PRF_IDX - 1:0] rd_phy;
				localparam cpu_params_ARF_DEPTH = 32;
				localparam cpu_params_ARF_IDX = $clog2(1'd0);
				wire [cpu_params_ARF_IDX - 1:0] rd_arch;
				wire [31:0] rd_value;
				wire [31:0] rs1_value_dbg;
				wire [31:0] rs2_value_dbg;
				wire valid;
			end
			genvar _gv_i_34;
			for (_gv_i_34 = 0; _gv_i_34 < cpu_params_INT_ISSUE_WIDTH; _gv_i_34 = _gv_i_34 + 1) begin : genblk1
				localparam i = _gv_i_34;
				assign cdb_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rob_id = int_fu_cdb_out[i].rob_id;
				assign cdb_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rd_phy = int_fu_cdb_out[i].rd_phy;
				assign cdb_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rd_arch = int_fu_cdb_out[i].rd_arch;
				assign cdb_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rd_value = int_fu_cdb_out[i].rd_value;
				assign cdb_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].valid = int_fu_cdb_out[i].valid;
				assign cdb_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rs1_value_dbg = int_fu_cdb_out[i].rs1_value_dbg;
				assign cdb_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rs2_value_dbg = int_fu_cdb_out[i].rs2_value_dbg;
				assign rs_prf_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rs1_phy = int_to_prf[i].rs1_phy;
				assign rs_prf_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rs2_phy = int_to_prf[i].rs2_phy;
				assign rs_prf_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rs_bypass = int_to_prf[i].rs_bypass;
				assign int_to_prf[i].rs1_value = rs_prf_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rs1_value;
				assign int_to_prf[i].rs2_value = rs_prf_itfs[subset_indices[((cpu_params_MAX_ISSUE_WIDTH - 1) - i) * 32+:32]].rs2_value;
			end
			localparam cpu_params_INT_RS_TYPE = 1;
			if (cpu_params_INT_RS_TYPE == 1) begin : genblk2
				localparam _bbase_04678_to_prf = 0;
				localparam _bbase_04678_cdb = 0;
				localparam _bbase_04678_fu_cdb_out = 0;
				if (1) begin : int_rs_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam cpu_params_INT_ISSUE_WIDTH = 2;
					localparam _mbase_to_prf = 0;
					localparam cpu_params_CDB_WIDTH = 5;
					localparam _mbase_cdb = 0;
					localparam _mbase_fu_cdb_out = 0;
					localparam cpu_params_NUM_FAST_BYPASS = 2;
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
					localparam cpu_params_INTRS_DEPTH = 8;
					wire [cpu_params_INTRS_DEPTH - 1:0] rs_valid;
					wire [cpu_params_INTRS_DEPTH - 1:0] rs_request;
					reg [cpu_params_INTRS_DEPTH - 1:0] rs_grant;
					reg [cpu_params_INTRS_DEPTH - 1:0] rs_push_en;
					reg [cpu_params_INTRS_DEPTH - 1:0] rs_clear;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (cpu_params_INTRS_DEPTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38)) - 1 : (cpu_params_INTRS_DEPTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 36)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)] rs_entry;
					reg [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37:0] rs_entry_in [0:cpu_params_INTRS_DEPTH - 1];
					wire [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37:0] rs_entry_out [0:cpu_params_INTRS_DEPTH - 1];
					reg [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (cpu_params_ID_WIDTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38)) - 1 : (cpu_params_ID_WIDTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 36)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)] from_ds_entry;
					localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
					wire [(cpu_params_INTRS_DEPTH * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)) - 1:0] rs_bypass;
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_80
							reg signed [31:0] w;
							for (w = 0; w < cpu_params_ID_WIDTH; w = w + 1)
								begin
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))))) + ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + 1)) - 1)-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) >= (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))] = cpu.backend_i.ds_int_rs_itf_i.uop[w][34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) + ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))-:((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) >= (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) ? ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) - (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) + 1 : ((34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))] = cpu.backend_i.ds_int_rs_itf_i.uop[w][33 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) + ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) >= (cpu_params_ARF_IDX + 38) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) - (cpu_params_ARF_IDX + 38)) + 1 : ((cpu_params_ARF_IDX + 38) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) + 1)) - 1)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) >= (cpu_params_ARF_IDX + 38) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) - (cpu_params_ARF_IDX + 38)) + 1 : ((cpu_params_ARF_IDX + 38) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ARF_IDX + 37 : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ARF_IDX + 37)) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ARF_IDX + 37 : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ARF_IDX + 37))) + ((cpu_params_ARF_IDX + 37) >= 38 ? cpu_params_ARF_IDX + 0 : 39 - (cpu_params_ARF_IDX + 37))) - 1)-:((cpu_params_ARF_IDX + 37) >= 38 ? cpu_params_ARF_IDX + 0 : 39 - (cpu_params_ARF_IDX + 37))] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 37 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 0)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 36 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 35 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 2) : ((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 35 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 2)) + 31)-:32] = cpu.backend_i.ds_int_rs_itf_i.uop[w][32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))-:((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) >= (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) ? ((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) + 1 : ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) - (32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 3 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 34) : ((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 3 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 34)) + 3)-:4] = cpu.backend_i.ds_int_rs_itf_i.uop[w][6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
								end
						end
					end
					genvar _gv_i_14;
					for (_gv_i_14 = 0; _gv_i_14 < cpu_params_INTRS_DEPTH; _gv_i_14 = _gv_i_14 + 1) begin : rs_array
						localparam i = _gv_i_14;
						localparam _bbase_8D758_wakeup_cdb = 0;
						if (1) begin : int_rs_entry_i
							reg _sv2v_0;
							localparam cpu_params_ARF_DEPTH = 32;
							localparam cpu_params_ARF_IDX = $clog2(1'd0);
							localparam cpu_params_PRF_DEPTH = 64;
							localparam cpu_params_PRF_IDX = $clog2(1'd0);
							localparam cpu_params_ID_WIDTH = 2;
							localparam cpu_params_ROB_DEPTH = 32;
							localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
							wire clk;
							wire rst;
							wire valid;
							wire request;
							wire grant;
							wire push_en;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry_in;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry_out;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry;
							wire clear;
							localparam cpu_params_NUM_FAST_BYPASS = 2;
							wire [(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + sv2v_cast_1($clog2(1'd0))) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + ((1 + sv2v_cast_1($clog2(1'd0))) + 30)):(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 0 : (1 + sv2v_cast_1($clog2(1'd0))) + 31)] fast_bypass;
							localparam cpu_params_CDB_WIDTH = 5;
							localparam cpu_params_INT_ISSUE_WIDTH = 2;
							localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
							reg [((((1'd1 + 1) + (1'd1 + 1)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) - 1:0] rs_bypass;
							localparam _mbase_wakeup_cdb = 0;
							wire [(32 + sv2v_cast_1($clog2(1'd0))) + 0:0] cdb_rs [0:cpu_params_CDB_WIDTH - 1];
							genvar _gv_i_5;
							for (_gv_i_5 = 0; _gv_i_5 < cpu_params_CDB_WIDTH; _gv_i_5 = _gv_i_5 + 1) begin : genblk1
								localparam i = _gv_i_5;
								assign cdb_rs[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].valid;
								assign cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].rd_phy;
							end
							reg entry_valid;
							reg next_valid;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry_reg;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] next_entry;
							always @(posedge clk)
								if (rst || clear)
									entry_valid <= 1'b0;
								else
									entry_valid <= next_valid;
							always @(*) begin
								if (_sv2v_0)
									;
								next_valid = entry_valid;
								if (push_en)
									next_valid = 1'b1;
								else if (grant)
									next_valid = 1'b0;
							end
							always @(posedge clk) entry_reg <= next_entry;
							always @(*) begin
								if (_sv2v_0)
									;
								next_entry = entry_reg;
								if (push_en)
									next_entry = entry_in;
								else begin : sv2v_autoblock_81
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))] = 1'b1;
										end
								end
							end
							always @(*) begin
								if (_sv2v_0)
									;
								entry_out = entry_reg;
								begin : sv2v_autoblock_82
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))] = 1'b1;
										end
								end
							end
							wire src1_ready;
							wire src2_ready;
							genvar _gv_i_6;
							for (_gv_i_6 = 0; _gv_i_6 < cpu_params_CDB_WIDTH; _gv_i_6 = _gv_i_6 + 1) begin : genblk2
								localparam i = _gv_i_6;
								wire [1:1] sv2v_tmp_9F982;
								assign sv2v_tmp_9F982 = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - i)] = sv2v_tmp_9F982;
								wire [1:1] sv2v_tmp_60EC8;
								assign sv2v_tmp_60EC8 = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - i)] = sv2v_tmp_60EC8;
							end
							always @(*) begin : sv2v_autoblock_83
								reg [0:1] _sv2v_jump;
								_sv2v_jump = 2'b00;
								if (_sv2v_0)
									;
								rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = 1'sbx;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = 1'sbx;
								begin : sv2v_autoblock_84
									reg signed [31:0] i;
									begin : sv2v_autoblock_85
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_86
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
								if (_sv2v_jump == 2'b00) begin : sv2v_autoblock_87
									reg signed [31:0] i;
									begin : sv2v_autoblock_88
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_89
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
							end
							assign src1_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))] || |rs_bypass[(1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))-:(((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) >= ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) ? (((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)))) + 1 : (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) - ((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))))) + 1)];
							assign src2_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))] || |rs_bypass[(1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))-:(((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) ? (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) + 1)];
							assign request = (entry_valid && src1_ready) && src2_ready;
							assign valid = entry_valid;
							assign entry = entry_reg;
							initial _sv2v_0 = 0;
						end
						assign int_rs_entry_i.clk = clk;
						assign int_rs_entry_i.rst = rst;
						assign rs_valid[i] = int_rs_entry_i.valid;
						assign rs_request[i] = int_rs_entry_i.request;
						assign int_rs_entry_i.grant = rs_grant[i];
						assign int_rs_entry_i.push_en = rs_push_en[i];
						assign int_rs_entry_i.entry_in = rs_entry_in[i];
						assign rs_entry_out[i] = int_rs_entry_i.entry_out;
						assign rs_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))] = int_rs_entry_i.entry;
						assign int_rs_entry_i.clear = rs_clear[i];
						assign int_rs_entry_i.fast_bypass = alu_bypass;
						assign rs_bypass[i * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)+:(((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX] = int_rs_entry_i.rs_bypass;
					end
					localparam cpu_params_INTRS_IDX = $clog2(1'd0);
					reg [cpu_params_INTRS_IDX - 1:0] int_rs_top;
					reg [cpu_params_INTRS_IDX - 1:0] rs_top_next;
					wire alu_ready [0:cpu_params_INT_ISSUE_WIDTH - 1];
					reg [cpu_params_ID_WIDTH - 1:0] rs_push [0:cpu_params_INTRS_DEPTH - 1];
					wire [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37:0] rs_push_entry [0:cpu_params_INTRS_DEPTH - 1];
					wire [0:cpu_params_INT_ISSUE_WIDTH - 1] int_rs_valid;
					wire [(cpu_params_INT_ISSUE_WIDTH * cpu_params_INTRS_DEPTH) - 1:0] fu_issue;
					wire [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37:0] issued_entry [0:cpu_params_INT_ISSUE_WIDTH - 1];
					reg [1:0] rs_update_sel [0:cpu_params_INTRS_DEPTH - 1];
					wire [(cpu_params_INTRS_DEPTH * cpu_params_INT_ISSUE_WIDTH) - 1:0] rs_compress;
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_90
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
								begin
									rs_update_sel[i] = 2'b10;
									if (rs_valid[i] & |rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH])
										rs_update_sel[i] = 2'b00;
									if (|rs_push[i])
										rs_update_sel[i] = 2'b11;
								end
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_91
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
								(* full_case, parallel_case *)
								case (rs_update_sel[i])
									2'b00:
										if (($unsigned(i) + {30'b000000000000000000000000000000, rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH]}) < cpu_params_INTRS_DEPTH) begin
											rs_push_en[i] = rs_valid[$unsigned(i) + {30'b000000000000000000000000000000, rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH]}];
											rs_clear[i] = ~rs_valid[$unsigned(i) + {30'b000000000000000000000000000000, rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH]}];
											rs_entry_in[i] = rs_entry_out[$unsigned(i) + {30'b000000000000000000000000000000, rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH]}];
										end
										else begin
											rs_push_en[i] = 1'b0;
											rs_clear[i] = 1'b1;
											rs_entry_in[i] = 1'sbx;
										end
									2'b10: begin
										rs_push_en[i] = 1'b0;
										rs_clear[i] = 1'b0;
										rs_entry_in[i] = 1'sbx;
									end
									2'b11: begin
										rs_push_en[i] = 1'b1;
										rs_clear[i] = 1'b0;
										rs_entry_in[i] = rs_push_entry[i];
									end
									default: begin
										rs_push_en[i] = 1'bx;
										rs_clear[i] = 1'bx;
										rs_entry_in[i] = 1'sbx;
									end
								endcase
						end
					end
					always @(posedge clk)
						if (rst)
							int_rs_top <= 1'sb0;
						else
							int_rs_top <= rs_top_next;
					always @(*) begin
						if (_sv2v_0)
							;
						rs_top_next = int_rs_top;
						begin : sv2v_autoblock_92
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INT_ISSUE_WIDTH; i = i + 1)
								if (int_rs_valid[i] & alu_ready[i]) begin : sv2v_autoblock_93
									reg [cpu_params_INTRS_IDX - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = rs_top_next - 1;
									rs_top_next = sv2v_tmp_cast;
								end
						end
						begin : sv2v_autoblock_94
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
								rs_push[i] = 1'sb0;
						end
						begin : sv2v_autoblock_95
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								if (cpu.backend_i.ds_int_rs_itf_i.valid[i] && cpu.backend_i.ds_int_rs_itf_i.ready) begin
									rs_push[rs_top_next][i] = 1'sb1;
									begin : sv2v_autoblock_96
										reg [cpu_params_INTRS_IDX - 1:0] sv2v_tmp_cast;
										sv2v_tmp_cast = rs_top_next + 1;
										rs_top_next = sv2v_tmp_cast;
									end
								end
						end
					end
					genvar _gv_i_15;
					for (_gv_i_15 = 0; _gv_i_15 < cpu_params_INTRS_DEPTH; _gv_i_15 = _gv_i_15 + 1) begin : genblk2
						localparam i = _gv_i_15;
						one_hot_mux_A9A2C_2CF1C #(
							.T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
							.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
							.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
							.NUM_INPUTS(cpu_params_ID_WIDTH)
						) ohm_push(
							.data_in(from_ds_entry),
							.select(rs_push[i]),
							.data_out(rs_push_entry[i])
						);
					end
					wire [cpu_params_INTRS_DEPTH:1] sv2v_tmp_issue_arbiter_i_rs_grant;
					always @(*) rs_grant = sv2v_tmp_issue_arbiter_i_rs_grant;
					issue_arbiter issue_arbiter_i(
						.rs_request(rs_request),
						.rs_grant(sv2v_tmp_issue_arbiter_i_rs_grant),
						.rs_compress(rs_compress),
						.fu_issue(fu_issue)
					);
					genvar _gv_i_16;
					for (_gv_i_16 = 0; _gv_i_16 < cpu_params_INT_ISSUE_WIDTH; _gv_i_16 = _gv_i_16 + 1) begin : genblk3
						localparam i = _gv_i_16;
						one_hot_mux_A9A2C_2CF1C #(
							.T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
							.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
							.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
							.NUM_INPUTS(cpu_params_INTRS_DEPTH)
						) ohm_entry(
							.data_in(rs_entry),
							.select(fu_issue[((cpu_params_INT_ISSUE_WIDTH - 1) - i) * cpu_params_INTRS_DEPTH+:cpu_params_INTRS_DEPTH]),
							.data_out(issued_entry[i])
						);
						one_hot_mux_602F0_CCEF1 #(
							.T_cpu_params_CDB_WIDTH(cpu_params_CDB_WIDTH),
							.T_cpu_params_INT_ISSUE_IDX(cpu_params_INT_ISSUE_IDX),
							.NUM_INPUTS(cpu_params_INTRS_DEPTH)
						) ohm_bypass(
							.data_in(rs_bypass),
							.select(fu_issue[((cpu_params_INT_ISSUE_WIDTH - 1) - i) * cpu_params_INTRS_DEPTH+:cpu_params_INTRS_DEPTH]),
							.data_out(cpu.backend_i.int_to_prf[i + _mbase_to_prf].rs_bypass)
						);
					end
					reg [cpu_params_INTRS_IDX:0] n_available_slots;
					always @(*) begin
						if (_sv2v_0)
							;
						n_available_slots = 1'sb0;
						begin : sv2v_autoblock_97
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
								if (~rs_valid[i]) begin : sv2v_autoblock_98
									reg [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = n_available_slots + 1;
									n_available_slots = sv2v_tmp_cast;
								end
						end
					end
					function automatic [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] sv2v_cast_BC94B;
						input reg [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] inp;
						sv2v_cast_BC94B = inp;
					endfunction
					assign cpu.backend_i.ds_int_rs_itf_i.ready = n_available_slots >= sv2v_cast_BC94B(cpu_params_ID_WIDTH);
					genvar _gv_i_17;
					for (_gv_i_17 = 0; _gv_i_17 < cpu_params_INT_ISSUE_WIDTH; _gv_i_17 = _gv_i_17 + 1) begin : genblk4
						localparam i = _gv_i_17;
						assign cpu.backend_i.int_to_prf[i + _mbase_to_prf].rs1_phy = issued_entry[i][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) + 1)];
						assign cpu.backend_i.int_to_prf[i + _mbase_to_prf].rs2_phy = issued_entry[i][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) + 1)];
					end
					reg [((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (cpu_params_INT_ISSUE_WIDTH * (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102)) - 1 : (cpu_params_INT_ISSUE_WIDTH * (1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 100)):((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 0 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101)] fu_alu_reg_in;
					genvar _gv_i_18;
					for (_gv_i_18 = 0; _gv_i_18 < cpu_params_INT_ISSUE_WIDTH; _gv_i_18 = _gv_i_18 + 1) begin : genblk5
						localparam i = _gv_i_18;
						always @(*) begin
							if (_sv2v_0)
								;
							fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) : (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)))) : (((((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) : (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))))) + ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)))) + 1)) - 1)-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)))) + 1)] = issued_entry[i][cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + 1)];
							fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? cpu_params_PRF_IDX + 101 : (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) - (cpu_params_PRF_IDX + 101)) : (((((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? cpu_params_PRF_IDX + 101 : (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) - (cpu_params_PRF_IDX + 101))) + ((cpu_params_PRF_IDX + 101) >= 102 ? cpu_params_PRF_IDX + 0 : 103 - (cpu_params_PRF_IDX + 101))) - 1)-:((cpu_params_PRF_IDX + 101) >= 102 ? cpu_params_PRF_IDX + 0 : 103 - (cpu_params_PRF_IDX + 101))] = issued_entry[i][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) >= (cpu_params_ARF_IDX + 38) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) - (cpu_params_ARF_IDX + 38)) + 1 : ((cpu_params_ARF_IDX + 38) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) + 1)];
							fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101) : (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) : (((((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101) : (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)))) + ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) >= (cpu_params_PRF_IDX + 102) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) - (cpu_params_PRF_IDX + 102)) + 1 : ((cpu_params_PRF_IDX + 102) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) + 1)) - 1)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) >= (cpu_params_PRF_IDX + 102) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) - (cpu_params_PRF_IDX + 102)) + 1 : ((cpu_params_PRF_IDX + 102) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) + 1)] = issued_entry[i][cpu_params_ARF_IDX + 37-:((cpu_params_ARF_IDX + 37) >= 38 ? cpu_params_ARF_IDX + 0 : 39 - (cpu_params_ARF_IDX + 37))];
							fu_alu_reg_in[(((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 97 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 4)] = issued_entry[i][37];
							fu_alu_reg_in[(((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 96 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 5)] = issued_entry[i][36];
							fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 101 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 0) : ((((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 101 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 0)) + 3)-:4] = issued_entry[i][3-:4];
							fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 95 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 6) : ((((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 95 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 6)) + 31)-:32] = issued_entry[i][35-:32];
							fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 63 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 38) : ((((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 63 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 38)) + 31)-:32] = cpu.backend_i.int_to_prf[i + _mbase_to_prf].rs1_value;
							fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 31 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 70) : ((((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))) + ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 31 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 70)) + 31)-:32] = cpu.backend_i.int_to_prf[i + _mbase_to_prf].rs2_value;
						end
					end
					genvar _gv_i_19;
					for (_gv_i_19 = 0; _gv_i_19 < cpu_params_INT_ISSUE_WIDTH; _gv_i_19 = _gv_i_19 + 1) begin : genblk6
						localparam i = _gv_i_19;
						assign int_rs_valid[i] = |fu_issue[((cpu_params_INT_ISSUE_WIDTH - 1) - i) * cpu_params_INTRS_DEPTH+:cpu_params_INTRS_DEPTH];
					end
					wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_INT_ISSUE_WIDTH * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_INT_ISSUE_WIDTH * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] fu_alu_bypass;
					assign alu_bypass = fu_alu_bypass;
					genvar _gv_i_20;
					for (_gv_i_20 = 0; _gv_i_20 < cpu_params_INT_ISSUE_WIDTH; _gv_i_20 = _gv_i_20 + 1) begin : alu
						localparam i = _gv_i_20;
						localparam _bbase_FBA59_cdb = _gv_i_20 + _mbase_fu_cdb_out;
						if (1) begin : fu_alu_i
							reg _sv2v_0;
							wire clk;
							wire rst;
							wire int_rs_valid;
							wire fu_alu_ready;
							localparam cpu_params_ARF_DEPTH = 32;
							localparam cpu_params_ARF_IDX = $clog2(1'd0);
							localparam cpu_params_PRF_DEPTH = 64;
							localparam cpu_params_PRF_IDX = $clog2(1'd0);
							localparam cpu_params_ID_WIDTH = 2;
							localparam cpu_params_ROB_DEPTH = 32;
							localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
							wire [((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 101:0] fu_alu_reg_in;
							wire [(1 + sv2v_cast_1($clog2(1'd0))) + 31:0] bypass;
							localparam _mbase_cdb = _bbase_FBA59_cdb;
							reg [((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 101:0] fu_alu_reg_out;
							reg fu_alu_valid;
							wire cdb_ready;
							reg cdb_valid;
							reg [((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 95:0] cdb_reg;
							assign fu_alu_ready = 1'b1;
							always @(posedge clk)
								if (rst)
									fu_alu_valid <= 1'sb0;
								else if (fu_alu_ready)
									fu_alu_valid <= int_rs_valid;
							always @(posedge clk)
								if (int_rs_valid && fu_alu_ready)
									fu_alu_reg_out <= fu_alu_reg_in;
							reg [31:0] a;
							reg [31:0] b;
							wire signed [31:0] as;
							wire signed [31:0] bs;
							wire [31:0] au;
							wire [31:0] bu;
							reg [31:0] alu_out;
							always @(*) begin
								if (_sv2v_0)
									;
								(* full_case, parallel_case *)
								case (fu_alu_reg_out[97])
									1'b0: a = fu_alu_reg_out[63-:32];
									1'b1: a = 1'sb0;
									default: a = 1'sb0;
								endcase
								(* full_case, parallel_case *)
								case (fu_alu_reg_out[96])
									1'b0: b = fu_alu_reg_out[31-:32];
									1'b1: b = fu_alu_reg_out[95-:32];
									default: b = 1'sb0;
								endcase
							end
							assign as = $signed(a);
							assign bs = $signed(b);
							assign au = $unsigned(a);
							assign bu = $unsigned(b);
							always @(*) begin
								if (_sv2v_0)
									;
								(* full_case, parallel_case *)
								case (fu_alu_reg_out[101-:4])
									4'b0000: alu_out = au + bu;
									4'b0001: alu_out = au << bu[4:0];
									4'b0010: alu_out = $unsigned(as >>> bu[4:0]);
									4'b0011: alu_out = au - bu;
									4'b0100: alu_out = au ^ bu;
									4'b0101: alu_out = au >> bu[4:0];
									4'b0110: alu_out = au | bu;
									4'b0111: alu_out = au & bu;
									4'b1000: alu_out = {31'd0, as < bs};
									4'b1001: alu_out = {31'd0, au < bu};
									default: alu_out = 1'sbx;
								endcase
							end
							assign bypass[1 + (sv2v_cast_1($clog2(1'd0)) + 31)] = fu_alu_valid;
							assign bypass[sv2v_cast_1($clog2(1'd0)) + 31-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] = fu_alu_reg_out[sv2v_cast_1($clog2(1'd0)) + 101-:((sv2v_cast_1($clog2(1'd0)) + 101) >= 102 ? sv2v_cast_1($clog2(1'd0)) + 0 : 103 - (sv2v_cast_1($clog2(1'd0)) + 101))];
							assign bypass[31-:32] = alu_out;
							assign cdb_ready = 1'b1;
							always @(posedge clk)
								if (rst)
									cdb_valid <= 1'sb0;
								else if (cdb_ready)
									cdb_valid <= fu_alu_valid;
							always @(posedge clk)
								if (rst)
									cdb_reg <= 1'sb0;
								else if (fu_alu_valid && cdb_ready) begin
									cdb_reg[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 96)) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 96))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 96)) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)))) + 1)] <= fu_alu_reg_out[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 102)) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 102))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 102)) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))) + 1)];
									cdb_reg[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)) >= (sv2v_cast_1($clog2(1'd0)) + 96) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)) - (sv2v_cast_1($clog2(1'd0)) + 96)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 96) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))) + 1)] <= fu_alu_reg_out[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)) >= (sv2v_cast_1($clog2(1'd0)) + 102) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)) - (sv2v_cast_1($clog2(1'd0)) + 102)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 102) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) + 1)];
									cdb_reg[sv2v_cast_1($clog2(1'd0)) + 95-:((sv2v_cast_1($clog2(1'd0)) + 95) >= 96 ? sv2v_cast_1($clog2(1'd0)) + 0 : 97 - (sv2v_cast_1($clog2(1'd0)) + 95))] <= fu_alu_reg_out[sv2v_cast_1($clog2(1'd0)) + 101-:((sv2v_cast_1($clog2(1'd0)) + 101) >= 102 ? sv2v_cast_1($clog2(1'd0)) + 0 : 103 - (sv2v_cast_1($clog2(1'd0)) + 101))];
									cdb_reg[95-:32] <= alu_out;
									cdb_reg[63-:32] <= fu_alu_reg_out[63-:32];
									cdb_reg[31-:32] <= fu_alu_reg_out[31-:32];
								end
							assign cpu.backend_i.int_fu_cdb_out[_mbase_cdb].rob_id = cdb_reg[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 96)) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 96))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 96)) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)))) + 1)];
							assign cpu.backend_i.int_fu_cdb_out[_mbase_cdb].rd_phy = cdb_reg[sv2v_cast_1($clog2(1'd0)) + 95-:((sv2v_cast_1($clog2(1'd0)) + 95) >= 96 ? sv2v_cast_1($clog2(1'd0)) + 0 : 97 - (sv2v_cast_1($clog2(1'd0)) + 95))];
							assign cpu.backend_i.int_fu_cdb_out[_mbase_cdb].rd_arch = cdb_reg[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)) >= (sv2v_cast_1($clog2(1'd0)) + 96) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95)) - (sv2v_cast_1($clog2(1'd0)) + 96)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 96) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 95))) + 1)];
							assign cpu.backend_i.int_fu_cdb_out[_mbase_cdb].rd_value = cdb_reg[95-:32];
							assign cpu.backend_i.int_fu_cdb_out[_mbase_cdb].valid = cdb_valid;
							assign cpu.backend_i.int_fu_cdb_out[_mbase_cdb].rs1_value_dbg = cdb_reg[63-:32];
							assign cpu.backend_i.int_fu_cdb_out[_mbase_cdb].rs2_value_dbg = cdb_reg[31-:32];
							initial _sv2v_0 = 0;
						end
						assign fu_alu_i.clk = clk;
						assign fu_alu_i.rst = rst;
						assign fu_alu_i.int_rs_valid = int_rs_valid[i];
						assign alu_ready[i] = fu_alu_i.fu_alu_ready;
						assign fu_alu_i.fu_alu_reg_in = fu_alu_reg_in[((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? 0 : ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) + (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * ((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101)))+:((((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101) >= 0 ? ((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 102 : 1 - (((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101))];
						assign fu_alu_bypass[(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31) + (((cpu_params_INT_ISSUE_WIDTH - 1) - i) * (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (1 + cpu_params_PRF_IDX) + 32 : 1 - ((1 + cpu_params_PRF_IDX) + 31)))+:(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (1 + cpu_params_PRF_IDX) + 32 : 1 - ((1 + cpu_params_PRF_IDX) + 31))] = fu_alu_i.bypass;
					end
					initial _sv2v_0 = 0;
				end
				assign int_rs_i.clk = clk;
				assign int_rs_i.rst = rst || backend_flush;
				assign alu_bypass = int_rs_i.alu_bypass;
			end
			else begin : genblk2
				localparam _bbase_7E465_to_prf = 0;
				localparam _bbase_7E465_cdb = 0;
				localparam _bbase_7E465_fu_cdb_out = 0;
				if (1) begin : int_rs_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam _mbase_to_prf = _bbase_7E465_to_prf;
					localparam cpu_params_CDB_WIDTH = 5;
					localparam _mbase_cdb = 0;
					localparam _mbase_fu_cdb_out = _bbase_7E465_fu_cdb_out;
					localparam cpu_params_INTRS_DEPTH = 8;
					wire [cpu_params_INTRS_DEPTH - 1:0] rs_valid;
					wire [cpu_params_INTRS_DEPTH - 1:0] rs_request;
					reg [cpu_params_INTRS_DEPTH - 1:0] rs_grant;
					reg [cpu_params_INTRS_DEPTH - 1:0] rs_push_en;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (cpu_params_INTRS_DEPTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38)) - 1 : (cpu_params_INTRS_DEPTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 36)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)] rs_entry;
					reg [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (cpu_params_INTRS_DEPTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38)) - 1 : (cpu_params_INTRS_DEPTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 36)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)] rs_entry_in;
					reg [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (cpu_params_ID_WIDTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38)) - 1 : (cpu_params_ID_WIDTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 36)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)] from_ds_entry;
					wire [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37:0] issued_entry;
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_99
							reg signed [31:0] w;
							for (w = 0; w < cpu_params_ID_WIDTH; w = w + 1)
								begin
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))))) + ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + 1)) - 1)-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) >= (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))] = cpu.backend_i.ds_int_rs_itf_i.uop[w][34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) + ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))-:((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) >= (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) ? ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) - (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) + 1 : ((34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))] = cpu.backend_i.ds_int_rs_itf_i.uop[w][33 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) + ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) >= (cpu_params_ARF_IDX + 38) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) - (cpu_params_ARF_IDX + 38)) + 1 : ((cpu_params_ARF_IDX + 38) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) + 1)) - 1)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) >= (cpu_params_ARF_IDX + 38) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) - (cpu_params_ARF_IDX + 38)) + 1 : ((cpu_params_ARF_IDX + 38) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ARF_IDX + 37 : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ARF_IDX + 37)) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? cpu_params_ARF_IDX + 37 : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) - (cpu_params_ARF_IDX + 37))) + ((cpu_params_ARF_IDX + 37) >= 38 ? cpu_params_ARF_IDX + 0 : 39 - (cpu_params_ARF_IDX + 37))) - 1)-:((cpu_params_ARF_IDX + 37) >= 38 ? cpu_params_ARF_IDX + 0 : 39 - (cpu_params_ARF_IDX + 37))] = cpu.backend_i.ds_int_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 37 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 0)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 36 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 1)] = cpu.backend_i.ds_int_rs_itf_i.uop[w][1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 35 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 2) : ((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 35 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 2)) + 31)-:32] = cpu.backend_i.ds_int_rs_itf_i.uop[w][32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))-:((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) >= (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) ? ((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) + 1 : ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) - (32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 3 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 34) : ((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 3 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 34)) + 3)-:4] = cpu.backend_i.ds_int_rs_itf_i.uop[w][6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
								end
						end
					end
					genvar _gv_i_12;
					for (_gv_i_12 = 0; _gv_i_12 < cpu_params_INTRS_DEPTH; _gv_i_12 = _gv_i_12 + 1) begin : rs_array
						localparam i = _gv_i_12;
						localparam _bbase_A0F1E_wakeup_cdb = 0;
						if (1) begin : int_rs_entry_i
							reg _sv2v_0;
							localparam cpu_params_ARF_DEPTH = 32;
							localparam cpu_params_ARF_IDX = $clog2(1'd0);
							localparam cpu_params_PRF_DEPTH = 64;
							localparam cpu_params_PRF_IDX = $clog2(1'd0);
							localparam cpu_params_ID_WIDTH = 2;
							localparam cpu_params_ROB_DEPTH = 32;
							localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
							wire clk;
							wire rst;
							wire valid;
							wire request;
							wire grant;
							wire push_en;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry_in;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry_out;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry;
							wire clear;
							localparam cpu_params_NUM_FAST_BYPASS = 2;
							wire [(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + sv2v_cast_1($clog2(1'd0))) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + ((1 + sv2v_cast_1($clog2(1'd0))) + 30)):(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 0 : (1 + sv2v_cast_1($clog2(1'd0))) + 31)] fast_bypass;
							localparam cpu_params_CDB_WIDTH = 5;
							localparam cpu_params_INT_ISSUE_WIDTH = 2;
							localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
							reg [((((1'd1 + 1) + (1'd1 + 1)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) - 1:0] rs_bypass;
							localparam _mbase_wakeup_cdb = 0;
							wire [(32 + sv2v_cast_1($clog2(1'd0))) + 0:0] cdb_rs [0:cpu_params_CDB_WIDTH - 1];
							genvar _gv_i_5;
							for (_gv_i_5 = 0; _gv_i_5 < cpu_params_CDB_WIDTH; _gv_i_5 = _gv_i_5 + 1) begin : genblk1
								localparam i = _gv_i_5;
								assign cdb_rs[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].valid;
								assign cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].rd_phy;
							end
							reg entry_valid;
							reg next_valid;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] entry_reg;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 37:0] next_entry;
							always @(posedge clk)
								if (rst || clear)
									entry_valid <= 1'b0;
								else
									entry_valid <= next_valid;
							always @(*) begin
								if (_sv2v_0)
									;
								next_valid = entry_valid;
								if (push_en)
									next_valid = 1'b1;
								else if (grant)
									next_valid = 1'b0;
							end
							always @(posedge clk) entry_reg <= next_entry;
							always @(*) begin
								if (_sv2v_0)
									;
								next_entry = entry_reg;
								if (push_en)
									next_entry = entry_in;
								else begin : sv2v_autoblock_100
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))] = 1'b1;
										end
								end
							end
							always @(*) begin
								if (_sv2v_0)
									;
								entry_out = entry_reg;
								begin : sv2v_autoblock_101
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))] = 1'b1;
										end
								end
							end
							wire src1_ready;
							wire src2_ready;
							genvar _gv_i_6;
							for (_gv_i_6 = 0; _gv_i_6 < cpu_params_CDB_WIDTH; _gv_i_6 = _gv_i_6 + 1) begin : genblk2
								localparam i = _gv_i_6;
								wire [1:1] sv2v_tmp_9F982;
								assign sv2v_tmp_9F982 = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - i)] = sv2v_tmp_9F982;
								wire [1:1] sv2v_tmp_60EC8;
								assign sv2v_tmp_60EC8 = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - i)] = sv2v_tmp_60EC8;
							end
							always @(*) begin : sv2v_autoblock_102
								reg [0:1] _sv2v_jump;
								_sv2v_jump = 2'b00;
								if (_sv2v_0)
									;
								rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = 1'sbx;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = 1'sbx;
								begin : sv2v_autoblock_103
									reg signed [31:0] i;
									begin : sv2v_autoblock_104
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_105
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
								if (_sv2v_jump == 2'b00) begin : sv2v_autoblock_106
									reg signed [31:0] i;
									begin : sv2v_autoblock_107
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 38))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_108
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
							end
							assign src1_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))))] || |rs_bypass[(1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))-:(((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) >= ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) ? (((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)))) + 1 : (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) - ((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))))) + 1)];
							assign src2_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 37))] || |rs_bypass[(1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))-:(((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) ? (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) + 1)];
							assign request = (entry_valid && src1_ready) && src2_ready;
							assign valid = entry_valid;
							assign entry = entry_reg;
							initial _sv2v_0 = 0;
						end
						assign int_rs_entry_i.clk = clk;
						assign int_rs_entry_i.rst = rst;
						assign rs_valid[i] = int_rs_entry_i.valid;
						assign rs_request[i] = int_rs_entry_i.request;
						assign int_rs_entry_i.grant = rs_grant[i];
						assign int_rs_entry_i.push_en = rs_push_en[i];
						assign int_rs_entry_i.entry_in = rs_entry_in[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))];
						assign rs_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))] = int_rs_entry_i.entry;
						assign int_rs_entry_i.clear = 1'b0;
					end
					reg [(cpu_params_INTRS_DEPTH * cpu_params_ID_WIDTH) - 1:0] entry_push_en_arr;
					reg [cpu_params_INTRS_DEPTH - 1:0] allocated;
					localparam cpu_params_INTRS_IDX = $clog2(1'd0);
					always @(*) begin : sv2v_autoblock_109
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_110
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
								entry_push_en_arr[i * cpu_params_ID_WIDTH+:cpu_params_ID_WIDTH] = 1'sb0;
						end
						allocated = 1'sb0;
						begin : sv2v_autoblock_111
							reg signed [31:0] w;
							begin : sv2v_autoblock_112
								reg signed [31:0] _sv2v_value_on_break;
								for (w = 0; w < cpu_params_ID_WIDTH; w = w + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (cpu.backend_i.ds_int_rs_itf_i.valid[w] && cpu.backend_i.ds_int_rs_itf_i.ready) begin : sv2v_autoblock_113
											reg signed [31:0] i;
											begin : sv2v_autoblock_114
												reg signed [31:0] _sv2v_value_on_break;
												reg [0:1] _sv2v_jump_1;
												_sv2v_jump_1 = _sv2v_jump;
												for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
													if (_sv2v_jump < 2'b10) begin
														_sv2v_jump = 2'b00;
														begin : sv2v_autoblock_115
															reg [cpu_params_INTRS_IDX - 1:0] sv2v_tmp_cast;
															sv2v_tmp_cast = $unsigned(i);
															if (!rs_valid[sv2v_tmp_cast] && !allocated[i]) begin
																entry_push_en_arr[(i * cpu_params_ID_WIDTH) + w] = 1'b1;
																allocated[i] = 1'b1;
																_sv2v_jump = 2'b10;
															end
														end
														_sv2v_value_on_break = i;
													end
												if (!(_sv2v_jump < 2'b10))
													i = _sv2v_value_on_break;
												if (_sv2v_jump != 2'b11)
													_sv2v_jump = _sv2v_jump_1;
											end
										end
										_sv2v_value_on_break = w;
									end
								if (!(_sv2v_jump < 2'b10))
									w = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_116
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
								rs_push_en[i] = |entry_push_en_arr[i * cpu_params_ID_WIDTH+:cpu_params_ID_WIDTH];
						end
					end
					genvar _gv_i_13;
					for (_gv_i_13 = 0; _gv_i_13 < cpu_params_INTRS_DEPTH; _gv_i_13 = _gv_i_13 + 1) begin : push_muxes
						localparam i = _gv_i_13;
						wire [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)) * 1:1] sv2v_tmp_push_mux_data_out;
						always @(*) rs_entry_in[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 38 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 37))] = sv2v_tmp_push_mux_data_out;
						one_hot_mux_A9A2C_2CF1C #(
							.T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
							.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
							.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
							.NUM_INPUTS(cpu_params_ID_WIDTH)
						) push_mux(
							.data_in(from_ds_entry),
							.select(entry_push_en_arr[i * cpu_params_ID_WIDTH+:cpu_params_ID_WIDTH]),
							.data_out(sv2v_tmp_push_mux_data_out)
						);
					end
					always @(*) begin : sv2v_autoblock_117
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						rs_grant = 1'sb0;
						begin : sv2v_autoblock_118
							reg signed [31:0] i;
							begin : sv2v_autoblock_119
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (rs_request[i]) begin
											rs_grant[i] = 1'b1;
											_sv2v_jump = 2'b10;
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					one_hot_mux_A9A2C_2CF1C #(
						.T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
						.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
						.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
						.NUM_INPUTS(cpu_params_INTRS_DEPTH)
					) ohm(
						.data_in(rs_entry),
						.select(rs_grant),
						.data_out(issued_entry)
					);
					reg [cpu_params_INTRS_IDX:0] n_available_slots;
					always @(*) begin
						if (_sv2v_0)
							;
						n_available_slots = 1'sb0;
						begin : sv2v_autoblock_120
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
								if (~rs_valid[i]) begin : sv2v_autoblock_121
									reg [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = n_available_slots + 1;
									n_available_slots = sv2v_tmp_cast;
								end
						end
					end
					function automatic [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] sv2v_cast_BC94B;
						input reg [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] inp;
						sv2v_cast_BC94B = inp;
					endfunction
					assign cpu.backend_i.ds_int_rs_itf_i.ready = n_available_slots >= sv2v_cast_BC94B(cpu_params_ID_WIDTH);
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_phy = issued_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) + 1)];
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_phy = issued_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))) + 1)];
					wire int_rs_valid;
					wire fu_alu_ready;
					reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101:0] fu_alu_reg_in;
					assign int_rs_valid = |rs_grant;
					always @(*) begin
						if (_sv2v_0)
							;
						fu_alu_reg_in[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)))) + 1)] = issued_entry[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 38)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)))))))) + 1)];
						fu_alu_reg_in[cpu_params_PRF_IDX + 101-:((cpu_params_PRF_IDX + 101) >= 102 ? cpu_params_PRF_IDX + 0 : 103 - (cpu_params_PRF_IDX + 101))] = issued_entry[cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) >= (cpu_params_ARF_IDX + 38) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37)) - (cpu_params_ARF_IDX + 38)) + 1 : ((cpu_params_ARF_IDX + 38) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 37))) + 1)];
						fu_alu_reg_in[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) >= (cpu_params_PRF_IDX + 102) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) - (cpu_params_PRF_IDX + 102)) + 1 : ((cpu_params_PRF_IDX + 102) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) + 1)] = issued_entry[cpu_params_ARF_IDX + 37-:((cpu_params_ARF_IDX + 37) >= 38 ? cpu_params_ARF_IDX + 0 : 39 - (cpu_params_ARF_IDX + 37))];
						fu_alu_reg_in[97] = issued_entry[37];
						fu_alu_reg_in[96] = issued_entry[36];
						fu_alu_reg_in[101-:4] = issued_entry[3-:4];
						fu_alu_reg_in[95-:32] = issued_entry[35-:32];
						fu_alu_reg_in[63-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_value;
						fu_alu_reg_in[31-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_value;
					end
					localparam _bbase_326CE_cdb = 0;
					if (1) begin : fu_alu_i
						reg _sv2v_0;
						wire clk;
						wire rst;
						wire int_rs_valid;
						wire fu_alu_ready;
						localparam cpu_params_ARF_DEPTH = 32;
						localparam cpu_params_ARF_IDX = $clog2(1'd0);
						localparam cpu_params_PRF_DEPTH = 64;
						localparam cpu_params_PRF_IDX = $clog2(1'd0);
						localparam cpu_params_ID_WIDTH = 2;
						localparam cpu_params_ROB_DEPTH = 32;
						localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
						wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101:0] fu_alu_reg_in;
						wire [(1 + cpu_params_PRF_IDX) + 31:0] bypass;
						localparam _mbase_cdb = _bbase_326CE_cdb;
						reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 101:0] fu_alu_reg_out;
						reg fu_alu_valid;
						wire cdb_ready;
						reg cdb_valid;
						reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_reg;
						assign fu_alu_ready = 1'b1;
						always @(posedge clk)
							if (rst)
								fu_alu_valid <= 1'sb0;
							else if (fu_alu_ready)
								fu_alu_valid <= int_rs_valid;
						always @(posedge clk)
							if (int_rs_valid && fu_alu_ready)
								fu_alu_reg_out <= fu_alu_reg_in;
						reg [31:0] a;
						reg [31:0] b;
						wire signed [31:0] as;
						wire signed [31:0] bs;
						wire [31:0] au;
						wire [31:0] bu;
						reg [31:0] alu_out;
						always @(*) begin
							if (_sv2v_0)
								;
							(* full_case, parallel_case *)
							case (fu_alu_reg_out[97])
								1'b0: a = fu_alu_reg_out[63-:32];
								1'b1: a = 1'sb0;
								default: a = 1'sb0;
							endcase
							(* full_case, parallel_case *)
							case (fu_alu_reg_out[96])
								1'b0: b = fu_alu_reg_out[31-:32];
								1'b1: b = fu_alu_reg_out[95-:32];
								default: b = 1'sb0;
							endcase
						end
						assign as = $signed(a);
						assign bs = $signed(b);
						assign au = $unsigned(a);
						assign bu = $unsigned(b);
						always @(*) begin
							if (_sv2v_0)
								;
							(* full_case, parallel_case *)
							case (fu_alu_reg_out[101-:4])
								4'b0000: alu_out = au + bu;
								4'b0001: alu_out = au << bu[4:0];
								4'b0010: alu_out = $unsigned(as >>> bu[4:0]);
								4'b0011: alu_out = au - bu;
								4'b0100: alu_out = au ^ bu;
								4'b0101: alu_out = au >> bu[4:0];
								4'b0110: alu_out = au | bu;
								4'b0111: alu_out = au & bu;
								4'b1000: alu_out = {31'd0, as < bs};
								4'b1001: alu_out = {31'd0, au < bu};
								default: alu_out = 1'sbx;
							endcase
						end
						assign bypass[1 + (cpu_params_PRF_IDX + 31)] = fu_alu_valid;
						assign bypass[cpu_params_PRF_IDX + 31-:((cpu_params_PRF_IDX + 31) >= 32 ? cpu_params_PRF_IDX + 0 : 33 - (cpu_params_PRF_IDX + 31))] = fu_alu_reg_out[cpu_params_PRF_IDX + 101-:((cpu_params_PRF_IDX + 101) >= 102 ? cpu_params_PRF_IDX + 0 : 103 - (cpu_params_PRF_IDX + 101))];
						assign bypass[31-:32] = alu_out;
						assign cdb_ready = 1'b1;
						always @(posedge clk)
							if (rst)
								cdb_valid <= 1'sb0;
							else if (cdb_ready)
								cdb_valid <= fu_alu_valid;
						always @(posedge clk)
							if (rst)
								cdb_reg <= 1'sb0;
							else if (fu_alu_valid && cdb_ready) begin
								cdb_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)] <= fu_alu_reg_out[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 102)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)))) + 1)];
								cdb_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)] <= fu_alu_reg_out[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) >= (cpu_params_PRF_IDX + 102) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101)) - (cpu_params_PRF_IDX + 102)) + 1 : ((cpu_params_PRF_IDX + 102) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 101))) + 1)];
								cdb_reg[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))] <= fu_alu_reg_out[cpu_params_PRF_IDX + 101-:((cpu_params_PRF_IDX + 101) >= 102 ? cpu_params_PRF_IDX + 0 : 103 - (cpu_params_PRF_IDX + 101))];
								cdb_reg[95-:32] <= alu_out;
								cdb_reg[63-:32] <= fu_alu_reg_out[63-:32];
								cdb_reg[31-:32] <= fu_alu_reg_out[31-:32];
							end
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rob_id = cdb_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_phy = cdb_reg[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_arch = cdb_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_value = cdb_reg[95-:32];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].valid = cdb_valid;
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rs1_value_dbg = cdb_reg[63-:32];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rs2_value_dbg = cdb_reg[31-:32];
						initial _sv2v_0 = 0;
					end
					assign fu_alu_i.clk = clk;
					assign fu_alu_i.rst = rst;
					assign fu_alu_i.int_rs_valid = int_rs_valid;
					assign fu_alu_ready = fu_alu_i.fu_alu_ready;
					assign fu_alu_i.fu_alu_reg_in = fu_alu_reg_in;
					initial _sv2v_0 = 0;
				end
				assign int_rs_i.clk = clk;
				assign int_rs_i.rst = rst || backend_flush;
			end
			localparam cpu_params_INTM_RS_TYPE = 0;
			if (cpu_params_INTM_RS_TYPE == 1) begin : genblk3
				localparam _bbase_300BB_to_prf = 1;
				localparam _bbase_300BB_cdb = 0;
				localparam _bbase_300BB_fu_cdb_out = 1;
				if (1) begin : intm_rs_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam _mbase_to_prf = _bbase_300BB_to_prf;
					localparam cpu_params_CDB_WIDTH = 5;
					localparam _mbase_cdb = 0;
					localparam _mbase_fu_cdb_out = _bbase_300BB_fu_cdb_out;
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					wire [(32 + cpu_params_PRF_IDX) + 0:0] cdb_rs [0:cpu_params_CDB_WIDTH - 1];
					genvar _gv_i_24;
					for (_gv_i_24 = 0; _gv_i_24 < cpu_params_CDB_WIDTH; _gv_i_24 = _gv_i_24 + 1) begin : genblk1
						localparam i = _gv_i_24;
						assign cdb_rs[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].valid;
						assign cdb_rs[i][cpu_params_PRF_IDX + 0-:((cpu_params_PRF_IDX + 0) >= 1 ? cpu_params_PRF_IDX + 0 : 2 - (cpu_params_PRF_IDX + 0))] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].rd_phy;
					end
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					localparam cpu_params_INTMRS_DEPTH = 4;
					reg [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3:0] intm_rs_array [0:cpu_params_INTMRS_DEPTH - 1];
					reg [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3:0] rs_array_next [0:cpu_params_INTMRS_DEPTH - 1];
					reg intm_rs_available [0:cpu_params_INTMRS_DEPTH - 1];
					reg rs_available_next [0:cpu_params_INTMRS_DEPTH - 1];
					localparam cpu_params_INTMRS_IDX = $clog2(1'd0);
					reg [cpu_params_INTMRS_IDX - 1:0] intm_rs_top;
					reg [cpu_params_INTMRS_IDX - 1:0] rs_top_next;
					reg intm_rs_pop_en;
					reg intm_rs_push_en [0:cpu_params_ID_WIDTH - 1];
					reg [cpu_params_INTMRS_IDX - 1:0] intm_rs_push_idx [0:cpu_params_ID_WIDTH - 1];
					reg intm_rs_issue_en;
					reg [cpu_params_INTMRS_IDX - 1:0] intm_rs_issue_idx;
					wire fu_md_ready;
					wire fu_md_valid;
					reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] intm_rs_in;
					reg intm_rs_in_valid;
					reg [1:0] rs_update_sel [0:cpu_params_INTMRS_DEPTH - 1];
					localparam cpu_params_ID_WIDTH_IDX = $clog2(1'd0);
					reg [cpu_params_ID_WIDTH_IDX - 1:0] rs_push_sel [0:cpu_params_INTMRS_DEPTH - 1];
					always @(posedge clk)
						if (rst) begin
							intm_rs_top <= 1'sb0;
							begin : sv2v_autoblock_122
								reg signed [31:0] i;
								for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
									intm_rs_available[i] <= 1'b1;
							end
						end
						else begin
							begin : sv2v_autoblock_123
								reg signed [31:0] i;
								for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
									begin
										intm_rs_array[i] <= rs_array_next[i];
										intm_rs_available[i] <= rs_available_next[i];
									end
							end
							intm_rs_top <= rs_top_next;
						end
					always @(*) begin : compress_control
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_124
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
								begin
									rs_push_sel[i] = 1'sb0;
									rs_update_sel[i] = 2'b10;
									if (intm_rs_pop_en) begin : sv2v_autoblock_125
										reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast;
										sv2v_tmp_cast = $unsigned(i);
										if (sv2v_tmp_cast >= intm_rs_issue_idx)
											rs_update_sel[i] = 2'b00;
									end
									begin : sv2v_autoblock_126
										reg signed [31:0] j;
										for (j = 0; j < cpu_params_ID_WIDTH; j = j + 1)
											begin : sv2v_autoblock_127
												reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast_1;
												sv2v_tmp_cast_1 = $unsigned(i);
												if (intm_rs_push_en[j] && (sv2v_tmp_cast_1 == intm_rs_push_idx[j])) begin
													rs_update_sel[i] = 2'b11;
													begin : sv2v_autoblock_128
														reg [cpu_params_ID_WIDTH_IDX - 1:0] sv2v_tmp_cast_2;
														sv2v_tmp_cast_2 = $unsigned(j);
														rs_push_sel[i] = sv2v_tmp_cast_2;
													end
												end
											end
									end
								end
						end
					end
					always @(*) begin : compress_mux
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_129
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
								begin
									rs_array_next[i] = 1'sbx;
									rs_available_next[i] = 1'b1;
									(* full_case, parallel_case *)
									case (rs_update_sel[i])
										2'b00:
											if (i < (cpu_params_INTMRS_DEPTH - 1)) begin
												rs_array_next[i] = intm_rs_array[i + 1];
												rs_available_next[i] = intm_rs_available[i + 1];
											end
										2'b10: begin
											rs_array_next[i] = intm_rs_array[i];
											rs_available_next[i] = intm_rs_available[i];
										end
										2'b11: begin
											rs_available_next[i] = 1'b0;
											rs_array_next[i][cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
											rs_array_next[i][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) >= (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) + 1)];
											rs_array_next[i][1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
											rs_array_next[i][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))-:((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) >= (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) ? ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) - (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) + 1 : ((34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) + 1)];
											rs_array_next[i][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][33 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
											rs_array_next[i][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) >= (cpu_params_ARF_IDX + 4) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) - (cpu_params_ARF_IDX + 4)) + 1 : ((cpu_params_ARF_IDX + 4) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) + 1)];
											rs_array_next[i][cpu_params_ARF_IDX + 3-:((cpu_params_ARF_IDX + 3) >= 4 ? cpu_params_ARF_IDX + 0 : 5 - (cpu_params_ARF_IDX + 3))] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) + 1)];
											rs_array_next[i][3-:4] = cpu.backend_i.ds_intm_rs_itf_i.uop[rs_push_sel[i]][6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
										end
										default:
											;
									endcase
									begin : sv2v_autoblock_130
										reg signed [31:0] k;
										for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
											if (cdb_rs[k][0] && !intm_rs_available[i]) begin
												if (intm_rs_array[i][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) + 1)] == cdb_rs[k][cpu_params_PRF_IDX + 0-:((cpu_params_PRF_IDX + 0) >= 1 ? cpu_params_PRF_IDX + 0 : 2 - (cpu_params_PRF_IDX + 0))]) begin
													if (rs_update_sel[i] == 2'b10)
														rs_array_next[i][1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))] = 1'b1;
													else if (i > 0) begin
														if (rs_update_sel[i - 1] == 2'b00)
															rs_array_next[i - 1][1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))] = 1'b1;
													end
												end
												if (intm_rs_array[i][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) + 1)] == cdb_rs[k][cpu_params_PRF_IDX + 0-:((cpu_params_PRF_IDX + 0) >= 1 ? cpu_params_PRF_IDX + 0 : 2 - (cpu_params_PRF_IDX + 0))]) begin
													if (rs_update_sel[i] == 2'b10)
														rs_array_next[i][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))] = 1'b1;
													else if (i > 0) begin
														if (rs_update_sel[i - 1] == 2'b00)
															rs_array_next[i - 1][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))] = 1'b1;
													end
												end
											end
									end
								end
						end
					end
					reg src1_valid;
					reg src2_valid;
					always @(*) begin : sv2v_autoblock_131
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						intm_rs_issue_en = 1'sb0;
						intm_rs_issue_idx = 1'sb0;
						src1_valid = 1'sb0;
						src2_valid = 1'sb0;
						begin : sv2v_autoblock_132
							reg signed [31:0] i;
							begin : sv2v_autoblock_133
								reg signed [31:0] _sv2v_value_on_break;
								begin : sv2v_autoblock_134
									reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = $unsigned(i);
									for (i = 0; sv2v_tmp_cast < intm_rs_top; i = i + 1)
										if (_sv2v_jump < 2'b10) begin
											_sv2v_jump = 2'b00;
											begin : sv2v_autoblock_135
												reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast_1;
												sv2v_tmp_cast_1 = $unsigned(i);
												src1_valid = intm_rs_array[sv2v_tmp_cast_1][1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))];
											end
											begin : sv2v_autoblock_136
												reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast_2;
												sv2v_tmp_cast_2 = $unsigned(i);
												src2_valid = intm_rs_array[sv2v_tmp_cast_2][1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))];
											end
											begin : sv2v_autoblock_137
												reg signed [31:0] k;
												for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
													begin
														begin : sv2v_autoblock_138
															reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast_3;
															sv2v_tmp_cast_3 = $unsigned(i);
															if (cdb_rs[k][0] && (cdb_rs[k][cpu_params_PRF_IDX + 0-:((cpu_params_PRF_IDX + 0) >= 1 ? cpu_params_PRF_IDX + 0 : 2 - (cpu_params_PRF_IDX + 0))] == intm_rs_array[sv2v_tmp_cast_3][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) + 1)]))
																src1_valid = 1'b1;
														end
														begin : sv2v_autoblock_139
															reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast_4;
															sv2v_tmp_cast_4 = $unsigned(i);
															if (cdb_rs[k][0] && (cdb_rs[k][cpu_params_PRF_IDX + 0-:((cpu_params_PRF_IDX + 0) >= 1 ? cpu_params_PRF_IDX + 0 : 2 - (cpu_params_PRF_IDX + 0))] == intm_rs_array[sv2v_tmp_cast_4][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) + 1)]))
																src2_valid = 1'b1;
														end
													end
											end
											if (src1_valid && src2_valid) begin
												intm_rs_issue_en = 1'sb1;
												begin : sv2v_autoblock_140
													reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast_3;
													sv2v_tmp_cast_3 = $unsigned(i);
													intm_rs_issue_idx = sv2v_tmp_cast_3;
												end
												_sv2v_jump = 2'b10;
											end
											_sv2v_value_on_break = i;
										end
								end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						rs_top_next = intm_rs_top;
						intm_rs_pop_en = 1'sb0;
						if (intm_rs_in_valid && fu_md_ready) begin
							intm_rs_pop_en = 1'sb1;
							begin : sv2v_autoblock_141
								reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = rs_top_next - 1;
								rs_top_next = sv2v_tmp_cast;
							end
						end
						begin : sv2v_autoblock_142
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_ID_WIDTH; i = i + 1)
								begin
									intm_rs_push_en[i] = 1'sb0;
									intm_rs_push_idx[i] = 1'sbx;
									if (cpu.backend_i.ds_intm_rs_itf_i.valid[i] && cpu.backend_i.ds_intm_rs_itf_i.ready) begin
										intm_rs_push_en[i] = 1'sb1;
										intm_rs_push_idx[i] = rs_top_next;
										begin : sv2v_autoblock_143
											reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast;
											sv2v_tmp_cast = rs_top_next + 1;
											rs_top_next = sv2v_tmp_cast;
										end
									end
								end
						end
					end
					reg [cpu_params_INTMRS_IDX:0] n_available_slots;
					localparam cpu_params_INTRS_DEPTH = 8;
					localparam cpu_params_INTRS_IDX = $clog2(1'd0);
					always @(*) begin
						if (_sv2v_0)
							;
						n_available_slots = 1'sb0;
						begin : sv2v_autoblock_144
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
								if (intm_rs_available[i]) begin : sv2v_autoblock_145
									reg [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = n_available_slots + 1;
									n_available_slots = sv2v_tmp_cast;
								end
						end
					end
					function automatic [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] sv2v_cast_BC94B;
						input reg [((cpu_params_INTRS_IDX + 0) >= 0 ? cpu_params_INTRS_IDX + 1 : 1 - (cpu_params_INTRS_IDX + 0)) - 1:0] inp;
						sv2v_cast_BC94B = inp;
					endfunction
					assign cpu.backend_i.ds_intm_rs_itf_i.ready = n_available_slots >= sv2v_cast_BC94B(cpu_params_ID_WIDTH);
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_phy = intm_rs_array[intm_rs_issue_idx][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) + 1)];
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_phy = intm_rs_array[intm_rs_issue_idx][cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) + 1)];
					always @(*) begin
						if (_sv2v_0)
							;
						intm_rs_in = 1'sb0;
						intm_rs_in_valid = intm_rs_issue_en;
						if (intm_rs_issue_en) begin
							intm_rs_in[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)))) + 1)] = intm_rs_array[intm_rs_issue_idx][cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))))) + 1)];
							intm_rs_in[cpu_params_PRF_IDX + 67-:((cpu_params_PRF_IDX + 67) >= 68 ? cpu_params_PRF_IDX + 0 : 69 - (cpu_params_PRF_IDX + 67))] = intm_rs_array[intm_rs_issue_idx][cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) >= (cpu_params_ARF_IDX + 4) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) - (cpu_params_ARF_IDX + 4)) + 1 : ((cpu_params_ARF_IDX + 4) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) + 1)];
							intm_rs_in[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) >= (cpu_params_PRF_IDX + 68) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) - (cpu_params_PRF_IDX + 68)) + 1 : ((cpu_params_PRF_IDX + 68) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) + 1)] = intm_rs_array[intm_rs_issue_idx][cpu_params_ARF_IDX + 3-:((cpu_params_ARF_IDX + 3) >= 4 ? cpu_params_ARF_IDX + 0 : 5 - (cpu_params_ARF_IDX + 3))];
							intm_rs_in[67-:4] = intm_rs_array[intm_rs_issue_idx][3-:4];
							intm_rs_in[63-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_value;
							intm_rs_in[31-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_value;
						end
					end
					localparam _bbase_9E4A1_cdb = 1;
					if (1) begin : fu_md_i
						reg _sv2v_0;
						wire clk;
						wire rst;
						wire flush;
						wire prv_valid;
						wire prv_ready;
						wire nxt_valid;
						wire nxt_ready;
						localparam cpu_params_ARF_DEPTH = 32;
						localparam cpu_params_ARF_IDX = $clog2(1'd0);
						localparam cpu_params_PRF_DEPTH = 64;
						localparam cpu_params_PRF_IDX = $clog2(1'd0);
						localparam cpu_params_ID_WIDTH = 2;
						localparam cpu_params_ROB_DEPTH = 32;
						localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
						wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] intm_rs_in;
						localparam _mbase_cdb = _bbase_9E4A1_cdb;
						localparam DATA_WIDTH = 32;
						localparam A_WIDTH = 33;
						localparam B_WIDTH = 33;
						wire mul_start;
						wire div_start;
						reg [32:0] a;
						reg [32:0] b;
						wire mul_complete;
						wire [65:0] product;
						wire div_complete;
						wire org_complete;
						wire [32:0] quotient;
						wire [32:0] remainder;
						wire divide_by_0;
						wire is_multiply;
						wire complete;
						reg [31:0] outcome;
						reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] intm_rs_reg;
						wire [DATA_WIDTH:0] au;
						wire [DATA_WIDTH:0] bu;
						wire [DATA_WIDTH:0] as;
						wire [DATA_WIDTH:0] bs;
						reg reg_valid;
						reg reg_start;
						assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);
						always @(posedge clk)
							if (rst || flush)
								reg_valid <= 1'sb0;
							else if (prv_ready)
								reg_valid <= prv_valid;
						always @(posedge clk)
							if (rst)
								intm_rs_reg <= 1'sb0;
							else if (prv_ready && prv_valid)
								intm_rs_reg <= intm_rs_in;
						always @(posedge clk)
							if (rst)
								reg_start <= 1'sb0;
							else if (reg_start)
								reg_start <= 1'sb0;
							else if (prv_ready && prv_valid)
								reg_start <= 1'sb1;
						assign is_multiply = ~intm_rs_reg[66];
						assign complete = (is_multiply ? mul_complete : div_complete);
						assign div_complete = org_complete && ~div_start;
						assign mul_start = reg_start && is_multiply;
						assign div_start = reg_start && ~is_multiply;
						assign au = {1'b0, intm_rs_reg[63-:32]};
						assign bu = {1'b0, intm_rs_reg[31-:32]};
						assign as = {intm_rs_reg[63], intm_rs_reg[63-:32]};
						assign bs = {intm_rs_reg[31], intm_rs_reg[31-:32]};
						always @(*) begin
							if (_sv2v_0)
								;
							a = 1'sb0;
							b = 1'sb0;
							outcome = 1'sbx;
							(* full_case, parallel_case *)
							case (intm_rs_reg[67-:4])
								4'b0000: begin
									a = as;
									b = bs;
									outcome = product[31:0];
								end
								4'b0001: begin
									a = as;
									b = bs;
									outcome = product[63:DATA_WIDTH];
								end
								4'b0010: begin
									a = as;
									b = bu;
									outcome = product[63:DATA_WIDTH];
								end
								4'b0011: begin
									a = au;
									b = bu;
									outcome = product[63:DATA_WIDTH];
								end
								4'b0100: begin
									a = as;
									b = bs;
									outcome = quotient[31:0];
									if (divide_by_0)
										outcome = 1'sb1;
								end
								4'b0101: begin
									a = au;
									b = bu;
									outcome = quotient[31:0];
									if (divide_by_0)
										outcome = 1'sb1;
								end
								4'b0110: begin
									a = as;
									b = bs;
									outcome = remainder[31:0];
									if (divide_by_0)
										outcome = intm_rs_reg[63-:32];
								end
								4'b0111: begin
									a = au;
									b = bu;
									outcome = remainder[31:0];
									if (divide_by_0)
										outcome = intm_rs_reg[63-:32];
								end
								default:
									;
							endcase
						end
						localparam NUM_CYC_DIV = 12;
						localparam NUM_CYC_MUL = 3;
						localparam TC_MODE = 1;
						localparam RST_MODE = 1;
						localparam INPUT_MODE = 0;
						localparam OUTPUT_MODE = 0;
						localparam EARLY_START = 0;
						DW_mult_seq #(
							A_WIDTH,
							B_WIDTH,
							TC_MODE,
							NUM_CYC_MUL,
							RST_MODE,
							INPUT_MODE,
							OUTPUT_MODE,
							EARLY_START
						) signed_mul(
							.clk(clk),
							.rst_n(~rst),
							.hold(1'sb0),
							.start(mul_start),
							.a(a),
							.b(b),
							.complete(mul_complete),
							.product(product)
						);
						DW_div_seq #(
							A_WIDTH,
							B_WIDTH,
							TC_MODE,
							NUM_CYC_DIV,
							RST_MODE,
							INPUT_MODE,
							OUTPUT_MODE,
							EARLY_START
						) divider(
							.clk(clk),
							.rst_n(~rst),
							.hold(1'sb0),
							.start(div_start),
							.a(a),
							.b(b),
							.complete(org_complete),
							.divide_by_0(divide_by_0),
							.quotient(quotient),
							.remainder(remainder)
						);
						reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] fu_md_reg;
						reg cdb_valid;
						wire cdb_ready;
						assign cdb_ready = 1'b1;
						assign nxt_valid = reg_valid && complete;
						always @(posedge clk)
							if (rst)
								cdb_valid <= 1'b0;
							else begin
								cdb_valid <= nxt_valid && cdb_ready;
								if (nxt_valid && cdb_ready) begin
									fu_md_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)] <= intm_rs_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)))) + 1)];
									fu_md_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)] <= intm_rs_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) >= (cpu_params_PRF_IDX + 68) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) - (cpu_params_PRF_IDX + 68)) + 1 : ((cpu_params_PRF_IDX + 68) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) + 1)];
									fu_md_reg[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))] <= intm_rs_reg[cpu_params_PRF_IDX + 67-:((cpu_params_PRF_IDX + 67) >= 68 ? cpu_params_PRF_IDX + 0 : 69 - (cpu_params_PRF_IDX + 67))];
									fu_md_reg[95-:32] <= outcome;
									fu_md_reg[63-:32] <= intm_rs_reg[63-:32];
									fu_md_reg[31-:32] <= intm_rs_reg[31-:32];
								end
							end
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].valid = cdb_valid;
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rob_id = fu_md_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_phy = fu_md_reg[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_arch = fu_md_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_value = fu_md_reg[95-:32];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rs1_value_dbg = fu_md_reg[63-:32];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rs2_value_dbg = fu_md_reg[31-:32];
						initial _sv2v_0 = 0;
					end
					assign fu_md_i.clk = clk;
					assign fu_md_i.rst = rst;
					assign fu_md_i.flush = 1'sb0;
					assign fu_md_i.prv_valid = intm_rs_in_valid;
					assign fu_md_ready = fu_md_i.prv_ready;
					assign fu_md_valid = fu_md_i.nxt_valid;
					assign fu_md_i.nxt_ready = 1'sb1;
					assign fu_md_i.intm_rs_in = intm_rs_in;
					initial _sv2v_0 = 0;
				end
				assign intm_rs_i.clk = clk;
				assign intm_rs_i.rst = rst || backend_flush;
			end
			else begin : genblk3
				localparam _bbase_DAED6_to_prf = 1;
				localparam _bbase_DAED6_cdb = 0;
				localparam _bbase_DAED6_fu_cdb_out = 1;
				if (1) begin : intm_rs_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam _mbase_to_prf = _bbase_DAED6_to_prf;
					localparam cpu_params_CDB_WIDTH = 5;
					localparam _mbase_cdb = 0;
					localparam _mbase_fu_cdb_out = _bbase_DAED6_fu_cdb_out;
					localparam cpu_params_NUM_FAST_BYPASS = 2;
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
					localparam cpu_params_INTMRS_DEPTH = 4;
					wire [cpu_params_INTMRS_DEPTH - 1:0] rs_valid;
					wire [cpu_params_INTMRS_DEPTH - 1:0] rs_request;
					wire [cpu_params_INTMRS_DEPTH - 1:0] rs_grant;
					reg [cpu_params_INTMRS_DEPTH - 1:0] rs_push_en;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (cpu_params_INTMRS_DEPTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4)) - 1 : (cpu_params_INTMRS_DEPTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 2)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3)] rs_entry;
					wire [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (cpu_params_INTMRS_DEPTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4)) - 1 : (cpu_params_INTMRS_DEPTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 2)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3)] rs_entry_in;
					reg [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (cpu_params_ID_WIDTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4)) - 1 : (cpu_params_ID_WIDTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 2)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3)] from_ds_entry;
					wire [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3:0] issued_entry;
					localparam cpu_params_INT_ISSUE_WIDTH = 2;
					localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
					wire [(cpu_params_INTMRS_DEPTH * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)) - 1:0] rs_bypass;
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_146
							reg signed [31:0] w;
							for (w = 0; w < cpu_params_ID_WIDTH; w = w + 1)
								begin
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))))) + ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))))) + 1)) - 1)-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))))) + ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) >= (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) + ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) + 1)) - 1)-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))-:((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) >= (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) ? ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) - (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) + 1 : ((34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) + 1)];
									from_ds_entry[(w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][33 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3) : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) + ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) >= (cpu_params_ARF_IDX + 4) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) - (cpu_params_ARF_IDX + 4)) + 1 : ((cpu_params_ARF_IDX + 4) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) + 1)) - 1)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) >= (cpu_params_ARF_IDX + 4) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) - (cpu_params_ARF_IDX + 4)) + 1 : ((cpu_params_ARF_IDX + 4) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) + 1)] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_ARF_IDX + 3 : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_ARF_IDX + 3)) : (((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? cpu_params_ARF_IDX + 3 : (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) - (cpu_params_ARF_IDX + 3))) + ((cpu_params_ARF_IDX + 3) >= 4 ? cpu_params_ARF_IDX + 0 : 5 - (cpu_params_ARF_IDX + 3))) - 1)-:((cpu_params_ARF_IDX + 3) >= 4 ? cpu_params_ARF_IDX + 0 : 5 - (cpu_params_ARF_IDX + 3))] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) + 1)];
									from_ds_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? (w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 3 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 0) : ((w * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 3 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 0)) + 3)-:4] = cpu.backend_i.ds_intm_rs_itf_i.uop[w][6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
								end
						end
					end
					genvar _gv_i_21;
					for (_gv_i_21 = 0; _gv_i_21 < cpu_params_INTMRS_DEPTH; _gv_i_21 = _gv_i_21 + 1) begin : rs_array
						localparam i = _gv_i_21;
						localparam _bbase_7979D_wakeup_cdb = 0;
						if (1) begin : intm_rs_entry_i
							reg _sv2v_0;
							localparam cpu_params_ARF_DEPTH = 32;
							localparam cpu_params_ARF_IDX = $clog2(1'd0);
							localparam cpu_params_PRF_DEPTH = 64;
							localparam cpu_params_PRF_IDX = $clog2(1'd0);
							localparam cpu_params_ID_WIDTH = 2;
							localparam cpu_params_ROB_DEPTH = 32;
							localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
							wire clk;
							wire rst;
							wire valid;
							wire request;
							wire grant;
							wire push_en;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 3:0] entry_in;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 3:0] entry_out;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 3:0] entry;
							wire clear;
							localparam cpu_params_NUM_FAST_BYPASS = 2;
							wire [(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + sv2v_cast_1($clog2(1'd0))) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + ((1 + sv2v_cast_1($clog2(1'd0))) + 30)):(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 0 : (1 + sv2v_cast_1($clog2(1'd0))) + 31)] fast_bypass;
							localparam cpu_params_CDB_WIDTH = 5;
							localparam cpu_params_INT_ISSUE_WIDTH = 2;
							localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
							reg [((((1'd1 + 1) + (1'd1 + 1)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) - 1:0] rs_bypass;
							localparam _mbase_wakeup_cdb = 0;
							wire [(32 + sv2v_cast_1($clog2(1'd0))) + 0:0] cdb_rs [0:cpu_params_CDB_WIDTH - 1];
							genvar _gv_i_5;
							for (_gv_i_5 = 0; _gv_i_5 < cpu_params_CDB_WIDTH; _gv_i_5 = _gv_i_5 + 1) begin : genblk1
								localparam i = _gv_i_5;
								assign cdb_rs[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].valid;
								assign cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].rd_phy;
							end
							reg entry_valid;
							reg next_valid;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 3:0] entry_reg;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 3:0] next_entry;
							always @(posedge clk)
								if (rst || clear)
									entry_valid <= 1'b0;
								else
									entry_valid <= next_valid;
							always @(*) begin
								if (_sv2v_0)
									;
								next_valid = entry_valid;
								if (push_en)
									next_valid = 1'b1;
								else if (grant)
									next_valid = 1'b0;
							end
							always @(posedge clk) entry_reg <= next_entry;
							always @(*) begin
								if (_sv2v_0)
									;
								next_entry = entry_reg;
								if (push_en)
									next_entry = entry_in;
								else begin : sv2v_autoblock_147
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))] = 1'b1;
										end
								end
							end
							always @(*) begin
								if (_sv2v_0)
									;
								entry_out = entry_reg;
								begin : sv2v_autoblock_148
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))] = 1'b1;
										end
								end
							end
							wire src1_ready;
							wire src2_ready;
							genvar _gv_i_6;
							for (_gv_i_6 = 0; _gv_i_6 < cpu_params_CDB_WIDTH; _gv_i_6 = _gv_i_6 + 1) begin : genblk2
								localparam i = _gv_i_6;
								wire [1:1] sv2v_tmp_F2424;
								assign sv2v_tmp_F2424 = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - i)] = sv2v_tmp_F2424;
								wire [1:1] sv2v_tmp_AEA9E;
								assign sv2v_tmp_AEA9E = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - i)] = sv2v_tmp_AEA9E;
							end
							always @(*) begin : sv2v_autoblock_149
								reg [0:1] _sv2v_jump;
								_sv2v_jump = 2'b00;
								if (_sv2v_0)
									;
								rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = 1'sbx;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = 1'sbx;
								begin : sv2v_autoblock_150
									reg signed [31:0] i;
									begin : sv2v_autoblock_151
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_152
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
								if (_sv2v_jump == 2'b00) begin : sv2v_autoblock_153
									reg signed [31:0] i;
									begin : sv2v_autoblock_154
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 4))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_155
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
							end
							assign src1_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))))] || |rs_bypass[(1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))-:(((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) >= ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) ? (((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)))) + 1 : (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) - ((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))))) + 1)];
							assign src2_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 3))] || |rs_bypass[(1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))-:(((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) ? (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) + 1)];
							assign request = (entry_valid && src1_ready) && src2_ready;
							assign valid = entry_valid;
							assign entry = entry_reg;
							initial _sv2v_0 = 0;
						end
						assign intm_rs_entry_i.clk = clk;
						assign intm_rs_entry_i.rst = rst;
						assign rs_valid[i] = intm_rs_entry_i.valid;
						assign rs_request[i] = intm_rs_entry_i.request;
						assign intm_rs_entry_i.grant = rs_grant[i];
						assign intm_rs_entry_i.push_en = rs_push_en[i];
						assign intm_rs_entry_i.entry_in = rs_entry_in[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))];
						assign rs_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))] = intm_rs_entry_i.entry;
						assign intm_rs_entry_i.clear = 1'b0;
						assign intm_rs_entry_i.fast_bypass = alu_bypass;
						assign rs_bypass[i * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)+:(((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX] = intm_rs_entry_i.rs_bypass;
					end
					reg [(cpu_params_INTMRS_DEPTH * cpu_params_ID_WIDTH) - 1:0] entry_push_en_arr;
					reg [cpu_params_INTMRS_DEPTH - 1:0] allocated;
					localparam cpu_params_INTMRS_IDX = $clog2(1'd0);
					always @(*) begin : sv2v_autoblock_156
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_157
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
								entry_push_en_arr[i * cpu_params_ID_WIDTH+:cpu_params_ID_WIDTH] = 1'sb0;
						end
						allocated = 1'sb0;
						begin : sv2v_autoblock_158
							reg signed [31:0] w;
							begin : sv2v_autoblock_159
								reg signed [31:0] _sv2v_value_on_break;
								for (w = 0; w < cpu_params_ID_WIDTH; w = w + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (cpu.backend_i.ds_intm_rs_itf_i.valid[w] && cpu.backend_i.ds_intm_rs_itf_i.ready) begin : sv2v_autoblock_160
											reg signed [31:0] i;
											begin : sv2v_autoblock_161
												reg signed [31:0] _sv2v_value_on_break;
												reg [0:1] _sv2v_jump_1;
												_sv2v_jump_1 = _sv2v_jump;
												for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
													if (_sv2v_jump < 2'b10) begin
														_sv2v_jump = 2'b00;
														begin : sv2v_autoblock_162
															reg [cpu_params_INTMRS_IDX - 1:0] sv2v_tmp_cast;
															sv2v_tmp_cast = $unsigned(i);
															if (!rs_valid[sv2v_tmp_cast] && !allocated[i]) begin
																entry_push_en_arr[(i * cpu_params_ID_WIDTH) + w] = 1'b1;
																allocated[i] = 1'b1;
																_sv2v_jump = 2'b10;
															end
														end
														_sv2v_value_on_break = i;
													end
												if (!(_sv2v_jump < 2'b10))
													i = _sv2v_value_on_break;
												if (_sv2v_jump != 2'b11)
													_sv2v_jump = _sv2v_jump_1;
											end
										end
										_sv2v_value_on_break = w;
									end
								if (!(_sv2v_jump < 2'b10))
									w = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_163
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
								rs_push_en[i] = |entry_push_en_arr[i * cpu_params_ID_WIDTH+:cpu_params_ID_WIDTH];
						end
					end
					genvar _gv_i_22;
					for (_gv_i_22 = 0; _gv_i_22 < cpu_params_INTMRS_DEPTH; _gv_i_22 = _gv_i_22 + 1) begin : push_muxes
						localparam i = _gv_i_22;
						one_hot_mux_6420F_858A2 #(
							.T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
							.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
							.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
							.NUM_INPUTS(cpu_params_ID_WIDTH)
						) push_mux(
							.data_in(from_ds_entry),
							.select(entry_push_en_arr[i * cpu_params_ID_WIDTH+:cpu_params_ID_WIDTH]),
							.data_out(rs_entry_in[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))])
						);
					end
					wire fu_mul_ready;
					wire fu_div_ready;
					reg [cpu_params_INTMRS_DEPTH - 1:0] rs_mul_request;
					reg [cpu_params_INTMRS_DEPTH - 1:0] rs_div_request;
					reg [cpu_params_INTMRS_DEPTH - 1:0] rs_mul_grant;
					reg [cpu_params_INTMRS_DEPTH - 1:0] rs_div_grant;
					genvar _gv_i_23;
					for (_gv_i_23 = 0; _gv_i_23 < cpu_params_INTMRS_DEPTH; _gv_i_23 = _gv_i_23 + 1) begin : issue_logic
						localparam i = _gv_i_23;
						always @(*) begin
							if (_sv2v_0)
								;
							rs_mul_request[i] = rs_request[i] && ~rs_entry[(i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 2 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 1)];
							rs_div_request[i] = rs_request[i] && rs_entry[(i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 4 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3))) + ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 3) >= 0 ? 2 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 1)];
						end
					end
					always @(*) begin : sv2v_autoblock_164
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						rs_mul_grant = 1'sb0;
						begin : sv2v_autoblock_165
							reg signed [31:0] i;
							begin : sv2v_autoblock_166
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (rs_mul_request[i] && fu_mul_ready) begin
											rs_mul_grant[i] = 1'b1;
											_sv2v_jump = 2'b10;
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					always @(*) begin : sv2v_autoblock_167
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						rs_div_grant = 1'sb0;
						begin : sv2v_autoblock_168
							reg signed [31:0] i;
							begin : sv2v_autoblock_169
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (rs_div_request[i] && fu_div_ready) begin
											rs_div_grant[i] = 1'b1;
											_sv2v_jump = 2'b10;
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					assign rs_grant = (|rs_div_grant ? rs_div_grant : rs_mul_grant);
					one_hot_mux_6420F_858A2 #(
						.T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
						.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
						.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
						.NUM_INPUTS(cpu_params_INTMRS_DEPTH)
					) ohm(
						.data_in(rs_entry),
						.select(rs_grant),
						.data_out(issued_entry)
					);
					one_hot_mux_602F0_CCEF1 #(
						.T_cpu_params_CDB_WIDTH(cpu_params_CDB_WIDTH),
						.T_cpu_params_INT_ISSUE_IDX(cpu_params_INT_ISSUE_IDX),
						.NUM_INPUTS(cpu_params_INTMRS_DEPTH)
					) ohm_rs1(
						.data_in(rs_bypass),
						.select(rs_grant),
						.data_out(cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs_bypass)
					);
					reg [cpu_params_INTMRS_IDX:0] n_available_slots;
					always @(*) begin
						if (_sv2v_0)
							;
						n_available_slots = 1'sb0;
						begin : sv2v_autoblock_170
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_INTMRS_DEPTH; i = i + 1)
								if (~rs_valid[i]) begin : sv2v_autoblock_171
									reg [((cpu_params_INTMRS_IDX + 0) >= 0 ? cpu_params_INTMRS_IDX + 1 : 1 - (cpu_params_INTMRS_IDX + 0)) - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = n_available_slots + 1;
									n_available_slots = sv2v_tmp_cast;
								end
						end
					end
					function automatic [((cpu_params_INTMRS_IDX + 0) >= 0 ? cpu_params_INTMRS_IDX + 1 : 1 - (cpu_params_INTMRS_IDX + 0)) - 1:0] sv2v_cast_54ECB;
						input reg [((cpu_params_INTMRS_IDX + 0) >= 0 ? cpu_params_INTMRS_IDX + 1 : 1 - (cpu_params_INTMRS_IDX + 0)) - 1:0] inp;
						sv2v_cast_54ECB = inp;
					endfunction
					assign cpu.backend_i.ds_intm_rs_itf_i.ready = n_available_slots >= sv2v_cast_54ECB(cpu_params_ID_WIDTH);
					reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] intm_rs_in;
					wire fu_mul_valid;
					wire fu_div_valid;
					wire cdb_mul_ready;
					wire cdb_div_ready;
					wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] fu_mul_cdb_out;
					wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] fu_div_cdb_out;
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_phy = issued_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) + 1)];
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_phy = issued_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))) + 1)];
					always @(*) begin
						if (_sv2v_0)
							;
						intm_rs_in[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)))) + 1)] = issued_entry[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 4)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)))))))) + 1)];
						intm_rs_in[cpu_params_PRF_IDX + 67-:((cpu_params_PRF_IDX + 67) >= 68 ? cpu_params_PRF_IDX + 0 : 69 - (cpu_params_PRF_IDX + 67))] = issued_entry[cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) >= (cpu_params_ARF_IDX + 4) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3)) - (cpu_params_ARF_IDX + 4)) + 1 : ((cpu_params_ARF_IDX + 4) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 3))) + 1)];
						intm_rs_in[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) >= (cpu_params_PRF_IDX + 68) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) - (cpu_params_PRF_IDX + 68)) + 1 : ((cpu_params_PRF_IDX + 68) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) + 1)] = issued_entry[cpu_params_ARF_IDX + 3-:((cpu_params_ARF_IDX + 3) >= 4 ? cpu_params_ARF_IDX + 0 : 5 - (cpu_params_ARF_IDX + 3))];
						intm_rs_in[67-:4] = issued_entry[3-:4];
						intm_rs_in[63-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_value;
						intm_rs_in[31-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_value;
					end
					localparam [0:0] sv2v_uu_fu_mul_i_ext_prv_valid_0 = 1'sb0;
					fu_mul fu_mul_i(
						.clk(clk),
						.rst(rst),
						.prv_valid((|rs_div_grant ? sv2v_uu_fu_mul_i_ext_prv_valid_0 : |rs_mul_request)),
						.prv_ready(fu_mul_ready),
						.nxt_valid(fu_mul_valid),
						.nxt_ready(cdb_mul_ready),
						.iss_in(intm_rs_in),
						.cdb_out(fu_mul_cdb_out)
					);
					fu_div_dual fu_div_i(
						.clk(clk),
						.rst(rst),
						.prv_valid(|rs_div_request),
						.prv_ready(fu_div_ready),
						.nxt_valid(fu_div_valid),
						.iss_in(intm_rs_in),
						.cdb_out(fu_div_cdb_out)
					);
					wire cdb_valid;
					wire cdb_out_valid;
					wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_reg_in;
					wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_reg_out;
					assign cdb_valid = fu_mul_valid || fu_div_valid;
					assign cdb_mul_ready = ~fu_div_valid;
					assign cdb_div_ready = 1'b1;
					assign cdb_reg_in = (fu_div_valid ? fu_div_cdb_out : fu_mul_cdb_out);
					pipeline_reg_E6238_A4C6B #(
						.DATA_T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
						.DATA_T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
						.DATA_T_cpu_params_ROB_IDX(cpu_params_ROB_IDX)
					) cdb_reg(
						.clk(clk),
						.rst(rst),
						.flush(1'b0),
						.prv_valid(cdb_valid),
						.prv_ready(),
						.nxt_valid(cdb_out_valid),
						.nxt_ready(1'b1),
						.prv_data(cdb_reg_in),
						.nxt_data(cdb_reg_out)
					);
					assign cpu.backend_i.cdb_itfs[_mbase_fu_cdb_out].valid = cdb_out_valid;
					assign cpu.backend_i.cdb_itfs[_mbase_fu_cdb_out].rob_id = cdb_reg_out[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)];
					assign cpu.backend_i.cdb_itfs[_mbase_fu_cdb_out].rd_phy = cdb_reg_out[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))];
					assign cpu.backend_i.cdb_itfs[_mbase_fu_cdb_out].rd_arch = cdb_reg_out[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)];
					assign cpu.backend_i.cdb_itfs[_mbase_fu_cdb_out].rd_value = cdb_reg_out[95-:32];
					assign cpu.backend_i.cdb_itfs[_mbase_fu_cdb_out].rs1_value_dbg = cdb_reg_out[63-:32];
					assign cpu.backend_i.cdb_itfs[_mbase_fu_cdb_out].rs2_value_dbg = cdb_reg_out[31-:32];
					initial _sv2v_0 = 0;
				end
				assign intm_rs_i.clk = clk;
				assign intm_rs_i.rst = rst || backend_flush;
				assign intm_rs_i.alu_bypass = alu_bypass;
			end
			localparam _bbase_23545_to_prf = 2;
			localparam _bbase_23545_cdb = 0;
			localparam _bbase_23545_fu_cdb_out = 2;
			if (1) begin : branch_i
				wire clk;
				wire rst;
				wire backend_flush;
				localparam _mbase_to_prf = _bbase_23545_to_prf;
				localparam cpu_params_CDB_WIDTH = 5;
				localparam _mbase_cdb = 0;
				localparam _mbase_fu_cdb_out = _bbase_23545_fu_cdb_out;
				localparam cpu_params_NUM_FAST_BYPASS = 2;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
				if (1) begin : br_cdb_itf_i
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [cpu_params_ROB_IDX - 1:0] rob_id;
					wire miss_predict;
					wire [31:0] target_address;
					wire valid;
					wire branch_taken;
				end
				if (1) begin : ds_br_rs_itf_i
					wire valid;
					wire ready;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop;
				end
				if (1) begin : ds_cb_itf_i
					wire valid;
					wire ready;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop;
				end
				assign ds_br_rs_itf_i.valid = cpu.backend_i.ds_branch_itf_i.valid;
				assign ds_br_rs_itf_i.uop = cpu.backend_i.ds_branch_itf_i.uop;
				assign ds_cb_itf_i.valid = cpu.backend_i.ds_branch_itf_i.valid;
				assign ds_cb_itf_i.uop = cpu.backend_i.ds_branch_itf_i.uop;
				assign cpu.backend_i.ds_branch_itf_i.ready = ds_br_rs_itf_i.ready && ds_cb_itf_i.ready;
				if (1) begin : control_buffer_i
					wire clk;
					wire rst;
					wire branch_ready;
					localparam cpu_params_CB_DEPTH = 8;
					localparam CB_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					reg [cpu_params_ROB_IDX + 69:0] fifo [0:cpu_params_CB_DEPTH - 1];
					wire enqueue;
					wire full;
					wire dequeue;
					wire empty;
					reg [CB_IDX:0] wr_ptr;
					wire [CB_IDX - 1:0] wr_ptr_actual;
					wire wr_ptr_flag;
					reg [CB_IDX:0] rd_ptr;
					wire [CB_IDX - 1:0] rd_ptr_actual;
					wire rd_ptr_flag;
					assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
					assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;
					always @(posedge clk)
						if (rst) begin
							wr_ptr <= 1'sb0;
							rd_ptr <= 1'sb0;
						end
						else begin
							if (enqueue && ~full) begin
								fifo[wr_ptr_actual][cpu_params_ROB_IDX + 69-:((cpu_params_ROB_IDX + 69) >= 70 ? cpu_params_ROB_IDX + 0 : 71 - (cpu_params_ROB_IDX + 69))] <= cpu.backend_i.branch_i.ds_cb_itf_i.uop[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
								fifo[wr_ptr_actual][35-:32] <= cpu.backend_i.branch_i.ds_cb_itf_i.uop[74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (42 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (42 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((42 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
								fifo[wr_ptr_actual][3-:4] <= cpu.backend_i.branch_i.ds_cb_itf_i.uop[6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
								begin : sv2v_autoblock_172
									reg [((CB_IDX + 0) >= 0 ? CB_IDX + 1 : 1 - (CB_IDX + 0)) - 1:0] sv2v_tmp_cast;
									sv2v_tmp_cast = wr_ptr + 1;
									wr_ptr <= sv2v_tmp_cast;
								end
							end
							if (cpu.backend_i.branch_i.br_cdb_itf_i.valid) begin : sv2v_autoblock_173
								reg signed [31:0] i;
								for (i = 0; i < cpu_params_CB_DEPTH; i = i + 1)
									if (fifo[i][cpu_params_ROB_IDX + 69-:((cpu_params_ROB_IDX + 69) >= 70 ? cpu_params_ROB_IDX + 0 : 71 - (cpu_params_ROB_IDX + 69))] == cpu.backend_i.branch_i.br_cdb_itf_i.rob_id) begin
										fifo[i][69] <= cpu.backend_i.branch_i.br_cdb_itf_i.miss_predict;
										fifo[i][68-:32] <= cpu.backend_i.branch_i.br_cdb_itf_i.target_address;
										fifo[i][36] <= cpu.backend_i.branch_i.br_cdb_itf_i.branch_taken;
									end
							end
							if (dequeue) begin : sv2v_autoblock_174
								reg [((CB_IDX + 0) >= 0 ? CB_IDX + 1 : 1 - (CB_IDX + 0)) - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = rd_ptr + 1;
								rd_ptr <= sv2v_tmp_cast;
							end
						end
					assign empty = wr_ptr == rd_ptr;
					assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
					assign cpu.backend_i.branch_i.ds_cb_itf_i.ready = ~full;
					assign enqueue = (cpu.backend_i.branch_i.ds_cb_itf_i.valid && branch_ready) && ~(cpu.backend_i.branch_i.ds_cb_itf_i.uop[6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)] == 4'b1111);
					assign dequeue = cpu.backend_i.cb_rob_itf_i.dequeue;
					assign cpu.backend_i.cb_rob_itf_i.rob_id = fifo[rd_ptr_actual][cpu_params_ROB_IDX + 69-:((cpu_params_ROB_IDX + 69) >= 70 ? cpu_params_ROB_IDX + 0 : 71 - (cpu_params_ROB_IDX + 69))];
					assign cpu.backend_i.cb_rob_itf_i.miss_predict = fifo[rd_ptr_actual][69];
					assign cpu.backend_i.cb_rob_itf_i.target_address = fifo[rd_ptr_actual][68-:32];
					assign cpu.backend_i.cb_rob_itf_i.ready = ~empty;
					assign cpu.cb_bp_itf_i.update_en = dequeue;
					assign cpu.cb_bp_itf_i.pc = fifo[rd_ptr_actual][35-:32];
					assign cpu.cb_bp_itf_i.fu_opcode = fifo[rd_ptr_actual][3-:4];
					assign cpu.cb_bp_itf_i.branch_taken = fifo[rd_ptr_actual][36];
					assign cpu.cb_bp_itf_i.target_address = fifo[rd_ptr_actual][68-:32];
				end
				assign control_buffer_i.clk = clk;
				assign control_buffer_i.rst = rst || backend_flush;
				assign control_buffer_i.branch_ready = cpu.backend_i.ds_branch_itf_i.ready;
				localparam _bbase_F5238_to_prf = 2;
				localparam _bbase_F5238_cdb = 0;
				localparam _bbase_F5238_fu_cdb_out = 2;
				if (1) begin : br_rs_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam _mbase_to_prf = _bbase_F5238_to_prf;
					localparam cpu_params_CDB_WIDTH = 5;
					localparam _mbase_cdb = 0;
					localparam _mbase_fu_cdb_out = _bbase_F5238_fu_cdb_out;
					wire branch_ready;
					localparam cpu_params_NUM_FAST_BYPASS = 2;
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
					localparam cpu_params_BRRS_DEPTH = 4;
					wire [cpu_params_BRRS_DEPTH - 1:0] rs_valid;
					wire [cpu_params_BRRS_DEPTH - 1:0] rs_request;
					reg [cpu_params_BRRS_DEPTH - 1:0] rs_grant;
					reg [cpu_params_BRRS_DEPTH - 1:0] rs_push_en;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? (cpu_params_BRRS_DEPTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101)) - 1 : (cpu_params_BRRS_DEPTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 99)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100)] rs_entry;
					wire [((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? (cpu_params_BRRS_DEPTH * (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101)) - 1 : (cpu_params_BRRS_DEPTH * (1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100))) + (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 99)):((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100)] rs_entry_in;
					wire [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100:0] from_ds_entry;
					wire [((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100:0] issued_entry;
					localparam cpu_params_INT_ISSUE_WIDTH = 2;
					localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
					wire [(cpu_params_BRRS_DEPTH * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)) - 1:0] rs_bypass;
					assign from_ds_entry[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))))) + 1)] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
					assign from_ds_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))) + 1)] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) >= (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) + 1)];
					assign from_ds_entry[1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
					assign from_ds_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))) + 1)] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))-:((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) >= (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) ? ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) - (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) + 1 : ((34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) + 1)];
					assign from_ds_entry[1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[33 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
					assign from_ds_entry[cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)) >= (cpu_params_ARF_IDX + 101) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)) - (cpu_params_ARF_IDX + 101)) + 1 : ((cpu_params_ARF_IDX + 101) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))) + 1)] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) + 1)];
					assign from_ds_entry[cpu_params_ARF_IDX + 100-:((cpu_params_ARF_IDX + 100) >= 101 ? cpu_params_ARF_IDX + 0 : 102 - (cpu_params_ARF_IDX + 100))] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) + 1)];
					assign from_ds_entry[100-:32] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))-:((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) >= (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) ? ((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) + 1 : ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) - (32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) + 1)];
					assign from_ds_entry[68-:32] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (42 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (42 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((42 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (74 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
					assign from_ds_entry[36-:4] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
					assign from_ds_entry[32] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[32];
					assign from_ds_entry[31-:32] = cpu.backend_i.branch_i.ds_br_rs_itf_i.uop[31-:32];
					genvar _gv_i_35;
					for (_gv_i_35 = 0; _gv_i_35 < cpu_params_BRRS_DEPTH; _gv_i_35 = _gv_i_35 + 1) begin : rs_array
						localparam i = _gv_i_35;
						localparam _bbase_40F63_wakeup_cdb = 0;
						if (1) begin : br_rs_entry_i
							reg _sv2v_0;
							localparam cpu_params_ARF_DEPTH = 32;
							localparam cpu_params_ARF_IDX = $clog2(1'd0);
							localparam cpu_params_PRF_DEPTH = 64;
							localparam cpu_params_PRF_IDX = $clog2(1'd0);
							localparam cpu_params_ID_WIDTH = 2;
							localparam cpu_params_ROB_DEPTH = 32;
							localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
							wire clk;
							wire rst;
							wire valid;
							wire request;
							wire grant;
							wire push_en;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 100:0] entry_in;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 100:0] entry_out;
							wire [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 100:0] entry;
							wire clear;
							localparam cpu_params_NUM_FAST_BYPASS = 2;
							wire [(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + sv2v_cast_1($clog2(1'd0))) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + ((1 + sv2v_cast_1($clog2(1'd0))) + 30)):(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 0 : (1 + sv2v_cast_1($clog2(1'd0))) + 31)] fast_bypass;
							localparam cpu_params_CDB_WIDTH = 5;
							localparam cpu_params_INT_ISSUE_WIDTH = 2;
							localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
							reg [((((1'd1 + 1) + (1'd1 + 1)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) - 1:0] rs_bypass;
							localparam _mbase_wakeup_cdb = 0;
							wire [(32 + sv2v_cast_1($clog2(1'd0))) + 0:0] cdb_rs [0:cpu_params_CDB_WIDTH - 1];
							genvar _gv_i_5;
							for (_gv_i_5 = 0; _gv_i_5 < cpu_params_CDB_WIDTH; _gv_i_5 = _gv_i_5 + 1) begin : genblk1
								localparam i = _gv_i_5;
								assign cdb_rs[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].valid;
								assign cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].rd_phy;
							end
							reg entry_valid;
							reg next_valid;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 100:0] entry_reg;
							reg [((((((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) + 100:0] next_entry;
							always @(posedge clk)
								if (rst || clear)
									entry_valid <= 1'b0;
								else
									entry_valid <= next_valid;
							always @(*) begin
								if (_sv2v_0)
									;
								next_valid = entry_valid;
								if (push_en)
									next_valid = 1'b1;
								else if (grant)
									next_valid = 1'b0;
							end
							always @(posedge clk) entry_reg <= next_entry;
							always @(*) begin
								if (_sv2v_0)
									;
								next_entry = entry_reg;
								if (push_en)
									next_entry = entry_in;
								else begin : sv2v_autoblock_175
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))] = 1'b1;
										end
								end
							end
							always @(*) begin
								if (_sv2v_0)
									;
								entry_out = entry_reg;
								begin : sv2v_autoblock_176
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))] = 1'b1;
										end
								end
							end
							wire src1_ready;
							wire src2_ready;
							genvar _gv_i_6;
							for (_gv_i_6 = 0; _gv_i_6 < cpu_params_CDB_WIDTH; _gv_i_6 = _gv_i_6 + 1) begin : genblk2
								localparam i = _gv_i_6;
								wire [1:1] sv2v_tmp_CDA8E;
								assign sv2v_tmp_CDA8E = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - i)] = sv2v_tmp_CDA8E;
								wire [1:1] sv2v_tmp_E6924;
								assign sv2v_tmp_E6924 = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - i)] = sv2v_tmp_E6924;
							end
							always @(*) begin : sv2v_autoblock_177
								reg [0:1] _sv2v_jump;
								_sv2v_jump = 2'b00;
								if (_sv2v_0)
									;
								rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = 1'sbx;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = 1'sbx;
								begin : sv2v_autoblock_178
									reg signed [31:0] i;
									begin : sv2v_autoblock_179
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_180
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
								if (_sv2v_jump == 2'b00) begin : sv2v_autoblock_181
									reg signed [31:0] i;
									begin : sv2v_autoblock_182
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100)))) - (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101)))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 101))) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_183
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
							end
							assign src1_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))))] || |rs_bypass[(1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))-:(((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) >= ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) ? (((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)))) + 1 : (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) - ((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))))) + 1)];
							assign src2_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 100))] || |rs_bypass[(1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))-:(((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) ? (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) + 1)];
							assign request = (entry_valid && src1_ready) && src2_ready;
							assign valid = entry_valid;
							assign entry = entry_reg;
							initial _sv2v_0 = 0;
						end
						assign br_rs_entry_i.clk = clk;
						assign br_rs_entry_i.rst = rst;
						assign rs_valid[i] = br_rs_entry_i.valid;
						assign rs_request[i] = br_rs_entry_i.request;
						assign br_rs_entry_i.grant = rs_grant[i];
						assign br_rs_entry_i.push_en = rs_push_en[i];
						assign br_rs_entry_i.entry_in = rs_entry_in[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100))];
						assign rs_entry[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100))] = br_rs_entry_i.entry;
						assign br_rs_entry_i.clear = 1'b0;
						assign br_rs_entry_i.fast_bypass = alu_bypass;
						assign rs_bypass[i * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)+:(((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX] = br_rs_entry_i.rs_bypass;
					end
					wire [cpu_params_BRRS_DEPTH - 1:0] entry_push_en_arr;
					localparam cpu_params_BRRS_IDX = $clog2(1'd0);
					always @(*) begin : sv2v_autoblock_184
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						rs_push_en = 1'sb0;
						if (cpu.backend_i.branch_i.ds_br_rs_itf_i.valid && branch_ready) begin : sv2v_autoblock_185
							reg signed [31:0] i;
							begin : sv2v_autoblock_186
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_BRRS_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										begin : sv2v_autoblock_187
											reg [cpu_params_BRRS_IDX - 1:0] sv2v_tmp_cast;
											sv2v_tmp_cast = $unsigned(i);
											if (!rs_valid[sv2v_tmp_cast]) begin
												rs_push_en[i] = 1'b1;
												_sv2v_jump = 2'b10;
											end
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					genvar _gv_i_36;
					for (_gv_i_36 = 0; _gv_i_36 < cpu_params_BRRS_DEPTH; _gv_i_36 = _gv_i_36 + 1) begin : push_muxes
						localparam i = _gv_i_36;
						assign rs_entry_in[((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? 0 : ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) + (i * ((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100)))+:((((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100) >= 0 ? ((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 101 : 1 - (((((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 100))] = from_ds_entry;
					end
					always @(*) begin : sv2v_autoblock_188
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						rs_grant = 1'sb0;
						begin : sv2v_autoblock_189
							reg signed [31:0] i;
							begin : sv2v_autoblock_190
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_BRRS_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (rs_request[i]) begin
											rs_grant[i] = 1'b1;
											_sv2v_jump = 2'b10;
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					one_hot_mux_3CA04_C50D1 #(
						.T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
						.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
						.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
						.NUM_INPUTS(cpu_params_BRRS_DEPTH)
					) ohm(
						.data_in(rs_entry),
						.select(rs_grant),
						.data_out(issued_entry)
					);
					one_hot_mux_602F0_CCEF1 #(
						.T_cpu_params_CDB_WIDTH(cpu_params_CDB_WIDTH),
						.T_cpu_params_INT_ISSUE_IDX(cpu_params_INT_ISSUE_IDX),
						.NUM_INPUTS(cpu_params_BRRS_DEPTH)
					) ohm_rs1(
						.data_in(rs_bypass),
						.select(rs_grant),
						.data_out(cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs_bypass)
					);
					assign cpu.backend_i.branch_i.ds_br_rs_itf_i.ready = |(~rs_valid);
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_phy = issued_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))) >= (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))) - (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))))) + 1 : ((1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))) + 1)];
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_phy = issued_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))) >= (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))) - (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))) + 1 : ((1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))) + 1)];
					wire br_rs_valid;
					wire fu_br_ready;
					wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 164:0] fu_br_reg_in;
					assign br_rs_valid = |rs_request;
					assign fu_br_reg_in[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 165)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 165))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 165)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)))) + 1)] = issued_entry[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))))))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101))))))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 101)))))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)))))))) + 1)];
					assign fu_br_reg_in[cpu_params_PRF_IDX + 164-:((cpu_params_PRF_IDX + 164) >= 165 ? cpu_params_PRF_IDX + 0 : 166 - (cpu_params_PRF_IDX + 164))] = issued_entry[cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)) >= (cpu_params_ARF_IDX + 101) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100)) - (cpu_params_ARF_IDX + 101)) + 1 : ((cpu_params_ARF_IDX + 101) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 100))) + 1)];
					assign fu_br_reg_in[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)) >= (cpu_params_PRF_IDX + 165) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)) - (cpu_params_PRF_IDX + 165)) + 1 : ((cpu_params_PRF_IDX + 165) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))) + 1)] = issued_entry[cpu_params_ARF_IDX + 100-:((cpu_params_ARF_IDX + 100) >= 101 ? cpu_params_ARF_IDX + 0 : 102 - (cpu_params_ARF_IDX + 100))];
					assign fu_br_reg_in[164-:4] = issued_entry[36-:4];
					assign fu_br_reg_in[128-:32] = issued_entry[100-:32];
					assign fu_br_reg_in[160-:32] = issued_entry[68-:32];
					assign fu_br_reg_in[32] = issued_entry[32];
					assign fu_br_reg_in[31-:32] = issued_entry[31-:32];
					assign fu_br_reg_in[96-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_value;
					assign fu_br_reg_in[64-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_value;
					localparam _bbase_3CD46_cdb = 2;
					if (1) begin : fu_br_i
						reg _sv2v_0;
						wire clk;
						wire rst;
						wire br_rs_valid;
						wire fu_br_ready;
						localparam cpu_params_ARF_DEPTH = 32;
						localparam cpu_params_ARF_IDX = $clog2(1'd0);
						localparam cpu_params_PRF_DEPTH = 64;
						localparam cpu_params_PRF_IDX = $clog2(1'd0);
						localparam cpu_params_ID_WIDTH = 2;
						localparam cpu_params_ROB_DEPTH = 32;
						localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
						wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 164:0] fu_br_reg_in;
						localparam _mbase_cdb = _bbase_3CD46_cdb;
						reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 164:0] fu_br_reg_out;
						reg fu_br_valid;
						wire cdb_ready;
						reg cdb_valid;
						reg br_cdb_valid;
						reg [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_reg;
						assign fu_br_ready = 1'b1;
						always @(posedge clk)
							if (rst)
								fu_br_valid <= 1'sb0;
							else if (fu_br_ready)
								fu_br_valid <= br_rs_valid;
						always @(posedge clk)
							if (br_rs_valid && fu_br_ready)
								fu_br_reg_out <= fu_br_reg_in;
						reg [31:0] target_address;
						wire [31:0] a;
						wire [31:0] b;
						reg branch_taken;
						wire miss_predict;
						wire signed [31:0] as;
						wire signed [31:0] bs;
						wire [31:0] au;
						wire [31:0] bu;
						assign a = fu_br_reg_out[96-:32];
						assign b = fu_br_reg_out[64-:32];
						assign as = $signed(a);
						assign bs = $signed(b);
						assign au = $unsigned(a);
						assign bu = $unsigned(b);
						always @(*) begin
							if (_sv2v_0)
								;
							(* full_case, parallel_case *)
							case (fu_br_reg_out[164-:4])
								4'b0000: branch_taken = au == bu;
								4'b0001: branch_taken = au != bu;
								4'b0100: branch_taken = as < bs;
								4'b0101: branch_taken = as >= bs;
								4'b0110: branch_taken = au < bu;
								4'b0111: branch_taken = au >= bu;
								4'b1000: branch_taken = 1'b1;
								4'b1001: branch_taken = 1'b1;
								default: branch_taken = 1'sbx;
							endcase
						end
						always @(*) begin
							if (_sv2v_0)
								;
							if (branch_taken)
								target_address = (fu_br_reg_out[164-:4] == 4'b1001 ? (fu_br_reg_out[96-:32] + fu_br_reg_out[128-:32]) & 32'hfffffffe : fu_br_reg_out[160-:32] + fu_br_reg_out[128-:32]);
							else
								target_address = fu_br_reg_out[160-:32] + 32'd4;
						end
						assign miss_predict = (branch_taken != fu_br_reg_out[32]) || (target_address != fu_br_reg_out[31-:32]);
						reg [31:0] rd_value;
						always @(*) begin
							if (_sv2v_0)
								;
							if (fu_br_reg_out[164-:4] == 4'b1111)
								rd_value = fu_br_reg_out[160-:32] + fu_br_reg_out[128-:32];
							else
								rd_value = fu_br_reg_out[160-:32] + 32'd4;
						end
						assign cdb_ready = 1'b1;
						always @(posedge clk)
							if (rst) begin
								cdb_valid <= 1'sb0;
								br_cdb_valid <= 1'sb0;
							end
							else if (cdb_ready) begin
								cdb_valid <= fu_br_valid;
								br_cdb_valid <= fu_br_valid && ~(fu_br_reg_out[164-:4] == 4'b1111);
							end
						reg cdb_reg_branch_taken;
						reg cdb_reg_miss_predict;
						reg [31:0] cdb_reg_target_address;
						always @(posedge clk)
							if (fu_br_valid && cdb_ready) begin
								cdb_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)] <= fu_br_reg_out[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 165)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 165))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 165)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)))) + 1)];
								cdb_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)] <= fu_br_reg_out[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)) >= (cpu_params_PRF_IDX + 165) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164)) - (cpu_params_PRF_IDX + 165)) + 1 : ((cpu_params_PRF_IDX + 165) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 164))) + 1)];
								cdb_reg[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))] <= fu_br_reg_out[cpu_params_PRF_IDX + 164-:((cpu_params_PRF_IDX + 164) >= 165 ? cpu_params_PRF_IDX + 0 : 166 - (cpu_params_PRF_IDX + 164))];
								cdb_reg[95-:32] <= rd_value;
								cdb_reg[63-:32] <= fu_br_reg_out[96-:32];
								cdb_reg[31-:32] <= fu_br_reg_out[64-:32];
								cdb_reg_miss_predict <= miss_predict;
								cdb_reg_target_address <= target_address;
								cdb_reg_branch_taken <= branch_taken;
							end
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rob_id = cdb_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_phy = cdb_reg[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_arch = cdb_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rd_value = cdb_reg[95-:32];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].valid = cdb_valid;
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rs1_value_dbg = cdb_reg[63-:32];
						assign cpu.backend_i.cdb_itfs[_mbase_cdb].rs2_value_dbg = cdb_reg[31-:32];
						assign cpu.backend_i.branch_i.br_cdb_itf_i.rob_id = cdb_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)];
						assign cpu.backend_i.branch_i.br_cdb_itf_i.miss_predict = cdb_reg_miss_predict;
						assign cpu.backend_i.branch_i.br_cdb_itf_i.target_address = cdb_reg_target_address;
						assign cpu.backend_i.branch_i.br_cdb_itf_i.branch_taken = cdb_reg_branch_taken;
						assign cpu.backend_i.branch_i.br_cdb_itf_i.valid = br_cdb_valid;
						initial _sv2v_0 = 0;
					end
					assign fu_br_i.clk = clk;
					assign fu_br_i.rst = rst;
					assign fu_br_i.br_rs_valid = br_rs_valid;
					assign fu_br_ready = fu_br_i.fu_br_ready;
					assign fu_br_i.fu_br_reg_in = fu_br_reg_in;
					initial _sv2v_0 = 0;
				end
				assign br_rs_i.clk = clk;
				assign br_rs_i.rst = rst || backend_flush;
				assign br_rs_i.branch_ready = cpu.backend_i.ds_branch_itf_i.ready;
				assign br_rs_i.alu_bypass = alu_bypass;
			end
			assign branch_i.clk = clk;
			assign branch_i.rst = rst;
			assign branch_i.backend_flush = backend_flush;
			assign branch_i.alu_bypass = alu_bypass;
			localparam _bbase_581EF_to_prf = 3;
			localparam _bbase_581EF_cdb = 0;
			localparam _bbase_581EF_fu_cdb_out = 3;
			if (1) begin : lsu_i
				wire clk;
				wire rst;
				localparam _mbase_to_prf = _bbase_581EF_to_prf;
				localparam cpu_params_CDB_WIDTH = 5;
				localparam _mbase_cdb = 0;
				localparam _mbase_fu_cdb_out = _bbase_581EF_fu_cdb_out;
				localparam cpu_params_NUM_FAST_BYPASS = 2;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
				wire backend_flush;
				if (1) begin : ds_mem_rs_i
					wire valid;
					wire ready;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop;
				end
				if (1) begin : ds_ldq_i
					wire valid;
					reg ready;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop;
				end
				if (1) begin : ds_stq_i
					wire valid;
					wire ready;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [((((((((75 + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + cpu_params_PRF_IDX) + 34) + cpu_params_ROB_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + cpu_params_ARF_IDX) + 32:0] uop;
				end
				if (1) begin : agu_lsq_i
					wire valid;
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [cpu_params_ROB_IDX + 131:0] data;
				end
				if (1) begin : lsu_adapter_i
					assign cpu.backend_i.lsu_i.ds_mem_rs_i.valid = (cpu.backend_i.ds_lsu_itf_i.valid && cpu.backend_i.lsu_i.ds_ldq_i.ready) && cpu.backend_i.lsu_i.ds_stq_i.ready;
					assign cpu.backend_i.lsu_i.ds_mem_rs_i.uop = cpu.backend_i.ds_lsu_itf_i.uop;
					assign cpu.backend_i.lsu_i.ds_stq_i.valid = (cpu.backend_i.ds_lsu_itf_i.valid && cpu.backend_i.lsu_i.ds_mem_rs_i.ready) && cpu.backend_i.lsu_i.ds_ldq_i.ready;
					assign cpu.backend_i.lsu_i.ds_stq_i.uop = cpu.backend_i.ds_lsu_itf_i.uop;
					assign cpu.backend_i.lsu_i.ds_ldq_i.valid = (cpu.backend_i.ds_lsu_itf_i.valid && cpu.backend_i.lsu_i.ds_mem_rs_i.ready) && cpu.backend_i.lsu_i.ds_stq_i.ready;
					assign cpu.backend_i.lsu_i.ds_ldq_i.uop = cpu.backend_i.ds_lsu_itf_i.uop;
					assign cpu.backend_i.ds_lsu_itf_i.ready = (cpu.backend_i.lsu_i.ds_mem_rs_i.ready && cpu.backend_i.lsu_i.ds_ldq_i.ready) && cpu.backend_i.lsu_i.ds_stq_i.ready;
				end
				localparam _bbase_87EB1_to_prf = 3;
				localparam _bbase_87EB1_cdb = 0;
				if (1) begin : mem_rs_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam _mbase_to_prf = _bbase_87EB1_to_prf;
					localparam cpu_params_CDB_WIDTH = 5;
					localparam _mbase_cdb = 0;
					localparam cpu_params_NUM_FAST_BYPASS = 2;
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
					localparam cpu_params_MEMRS_DEPTH = 8;
					wire [cpu_params_MEMRS_DEPTH - 1:0] rs_valid;
					wire [cpu_params_MEMRS_DEPTH - 1:0] rs_request;
					reg [cpu_params_MEMRS_DEPTH - 1:0] rs_grant;
					reg [cpu_params_MEMRS_DEPTH - 1:0] rs_push_en;
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					wire [(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (cpu_params_MEMRS_DEPTH * ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37)) - 1 : (cpu_params_MEMRS_DEPTH * (1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36))) + ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 35)):(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? 0 : (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36)] rs_entry;
					wire [(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (cpu_params_MEMRS_DEPTH * ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37)) - 1 : (cpu_params_MEMRS_DEPTH * (1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36))) + ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 35)):(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? 0 : (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36)] rs_entry_in;
					reg [(((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36:0] from_ds_entry;
					wire [(((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36:0] issued_entry;
					localparam cpu_params_INT_ISSUE_WIDTH = 2;
					localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
					wire [(cpu_params_MEMRS_DEPTH * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)) - 1:0] rs_bypass;
					always @(*) begin
						if (_sv2v_0)
							;
						from_ds_entry[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 37))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 37)))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 37))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))))) + 1)] = cpu.backend_i.lsu_i.ds_mem_rs_i.uop[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
						from_ds_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))) >= (1 + (cpu_params_PRF_IDX + 37)) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))) - (1 + (cpu_params_PRF_IDX + 37))) + 1 : ((1 + (cpu_params_PRF_IDX + 37)) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))) + 1)] = cpu.backend_i.lsu_i.ds_mem_rs_i.uop[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) >= (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) + 1)];
						from_ds_entry[1 + (cpu_params_PRF_IDX + 36)] = cpu.backend_i.lsu_i.ds_mem_rs_i.uop[34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
						from_ds_entry[cpu_params_PRF_IDX + 36-:((cpu_params_PRF_IDX + 36) >= 37 ? cpu_params_PRF_IDX + 0 : 38 - (cpu_params_PRF_IDX + 36))] = cpu.backend_i.lsu_i.ds_mem_rs_i.uop[sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))-:((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) >= (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) ? ((sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) - (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))) + 1 : ((34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) - (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))) + 1)];
						from_ds_entry[36] = cpu.backend_i.lsu_i.ds_mem_rs_i.uop[33 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))];
						from_ds_entry[35-:32] = cpu.backend_i.lsu_i.ds_mem_rs_i.uop[32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))-:((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) >= (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) ? ((32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))) + 1 : ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) - (32 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))) + 1)];
						from_ds_entry[3-:4] = cpu.backend_i.lsu_i.ds_mem_rs_i.uop[6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
					end
					genvar _gv_i_3;
					for (_gv_i_3 = 0; _gv_i_3 < cpu_params_MEMRS_DEPTH; _gv_i_3 = _gv_i_3 + 1) begin : rs_array
						localparam i = _gv_i_3;
						localparam _bbase_16EA6_wakeup_cdb = 0;
						if (1) begin : mem_rs_entry_i
							reg _sv2v_0;
							localparam cpu_params_ARF_DEPTH = 32;
							localparam cpu_params_ARF_IDX = $clog2(1'd0);
							localparam cpu_params_PRF_DEPTH = 64;
							localparam cpu_params_PRF_IDX = $clog2(1'd0);
							localparam cpu_params_ID_WIDTH = 2;
							localparam cpu_params_ROB_DEPTH = 32;
							localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
							wire clk;
							wire rst;
							wire valid;
							wire request;
							wire grant;
							wire push_en;
							wire [(((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 36:0] entry_in;
							reg [(((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 36:0] entry_out;
							wire [(((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 36:0] entry;
							wire clear;
							localparam cpu_params_NUM_FAST_BYPASS = 2;
							wire [(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + sv2v_cast_1($clog2(1'd0))) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + ((1 + sv2v_cast_1($clog2(1'd0))) + 30)):(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 0 : (1 + sv2v_cast_1($clog2(1'd0))) + 31)] fast_bypass;
							localparam cpu_params_CDB_WIDTH = 5;
							localparam cpu_params_INT_ISSUE_WIDTH = 2;
							localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
							reg [((((1'd1 + 1) + (1'd1 + 1)) + sv2v_cast_1($clog2(1'd0))) + sv2v_cast_1($clog2(1'd0))) - 1:0] rs_bypass;
							localparam _mbase_wakeup_cdb = 0;
							wire [(32 + sv2v_cast_1($clog2(1'd0))) + 0:0] cdb_rs [0:cpu_params_CDB_WIDTH - 1];
							genvar _gv_i_5;
							for (_gv_i_5 = 0; _gv_i_5 < cpu_params_CDB_WIDTH; _gv_i_5 = _gv_i_5 + 1) begin : genblk1
								localparam i = _gv_i_5;
								assign cdb_rs[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].valid;
								assign cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] = cpu.backend_i.cdb_itfs[i + _mbase_wakeup_cdb].rd_phy;
							end
							reg entry_valid;
							reg next_valid;
							reg [(((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 36:0] entry_reg;
							reg [(((sv2v_cast_1($clog2(1'd0 * 1'd0)) + sv2v_cast_1($clog2(1'd0))) + 1) + sv2v_cast_1($clog2(1'd0))) + 36:0] next_entry;
							always @(posedge clk)
								if (rst || clear)
									entry_valid <= 1'b0;
								else
									entry_valid <= next_valid;
							always @(*) begin
								if (_sv2v_0)
									;
								next_valid = entry_valid;
								if (push_en)
									next_valid = 1'b1;
								else if (grant)
									next_valid = 1'b0;
							end
							always @(posedge clk) entry_reg <= next_entry;
							always @(*) begin
								if (_sv2v_0)
									;
								next_entry = entry_reg;
								if (push_en)
									next_entry = entry_in;
								else begin : sv2v_autoblock_191
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + 37)) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) - (1 + (sv2v_cast_1($clog2(1'd0)) + 37))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + 37)) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36)))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[1 + (sv2v_cast_1($clog2(1'd0)) + 36)] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + 36-:((sv2v_cast_1($clog2(1'd0)) + 36) >= 37 ? sv2v_cast_1($clog2(1'd0)) + 0 : 38 - (sv2v_cast_1($clog2(1'd0)) + 36))] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												next_entry[36] = 1'b1;
										end
								end
							end
							always @(*) begin
								if (_sv2v_0)
									;
								entry_out = entry_reg;
								begin : sv2v_autoblock_192
									reg signed [31:0] k;
									for (k = 0; k < cpu_params_CDB_WIDTH; k = k + 1)
										if (cdb_rs[k][0]) begin
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + 37)) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) - (1 + (sv2v_cast_1($clog2(1'd0)) + 37))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + 37)) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36)))) + 1)] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[1 + (sv2v_cast_1($clog2(1'd0)) + 36)] = 1'b1;
											if (entry_reg[sv2v_cast_1($clog2(1'd0)) + 36-:((sv2v_cast_1($clog2(1'd0)) + 36) >= 37 ? sv2v_cast_1($clog2(1'd0)) + 0 : 38 - (sv2v_cast_1($clog2(1'd0)) + 36))] == cdb_rs[k][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))])
												entry_out[36] = 1'b1;
										end
								end
							end
							wire src1_ready;
							wire src2_ready;
							genvar _gv_i_6;
							for (_gv_i_6 = 0; _gv_i_6 < cpu_params_CDB_WIDTH; _gv_i_6 = _gv_i_6 + 1) begin : genblk2
								localparam i = _gv_i_6;
								wire [1:1] sv2v_tmp_8109C;
								assign sv2v_tmp_8109C = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + 37)) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) - (1 + (sv2v_cast_1($clog2(1'd0)) + 37))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + 37)) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36)))) + 1)] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - i)] = sv2v_tmp_8109C;
								wire [1:1] sv2v_tmp_0E998;
								assign sv2v_tmp_0E998 = (cdb_rs[i][0] && (cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))] != {((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + 36-:((sv2v_cast_1($clog2(1'd0)) + 36) >= 37 ? sv2v_cast_1($clog2(1'd0)) + 0 : 38 - (sv2v_cast_1($clog2(1'd0)) + 36))] == cdb_rs[i][sv2v_cast_1($clog2(1'd0)) + 0-:((sv2v_cast_1($clog2(1'd0)) + 0) >= 1 ? sv2v_cast_1($clog2(1'd0)) + 0 : 2 - (sv2v_cast_1($clog2(1'd0)) + 0))]);
								always @(*) rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - i)] = sv2v_tmp_0E998;
							end
							always @(*) begin : sv2v_autoblock_193
								reg [0:1] _sv2v_jump;
								_sv2v_jump = 2'b00;
								if (_sv2v_0)
									;
								rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb0;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = 1'sbx;
								rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = 1'sbx;
								begin : sv2v_autoblock_194
									reg signed [31:0] i;
									begin : sv2v_autoblock_195
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))-:((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) >= (1 + (sv2v_cast_1($clog2(1'd0)) + 37)) ? ((sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36))) - (1 + (sv2v_cast_1($clog2(1'd0)) + 37))) + 1 : ((1 + (sv2v_cast_1($clog2(1'd0)) + 37)) - (sv2v_cast_1($clog2(1'd0)) + (1 + (sv2v_cast_1($clog2(1'd0)) + 36)))) + 1)] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_196
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) >= (sv2v_cast_1($clog2(1'd0)) + 0) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)) - (sv2v_cast_1($clog2(1'd0)) + 0)) + 1 : ((sv2v_cast_1($clog2(1'd0)) + 0) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) + 1)] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
								if (_sv2v_jump == 2'b00) begin : sv2v_autoblock_197
									reg signed [31:0] i;
									begin : sv2v_autoblock_198
										reg signed [31:0] _sv2v_value_on_break;
										for (i = 0; i < cpu_params_NUM_FAST_BYPASS; i = i + 1)
											if (_sv2v_jump < 2'b10) begin
												_sv2v_jump = 2'b00;
												if ((fast_bypass[(((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? 1 + (sv2v_cast_1($clog2(1'd0)) + 31) : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (1 + (sv2v_cast_1($clog2(1'd0)) + 31)))] && (fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))] != {((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31)) * 1 {1'sb0}})) && (entry_reg[sv2v_cast_1($clog2(1'd0)) + 36-:((sv2v_cast_1($clog2(1'd0)) + 36) >= 37 ? sv2v_cast_1($clog2(1'd0)) + 0 : 38 - (sv2v_cast_1($clog2(1'd0)) + 36))] == fast_bypass[(((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31)) : (((((1'd0 - 1) - i) * (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? (1 + sv2v_cast_1($clog2(1'd0))) + 32 : 1 - ((1 + sv2v_cast_1($clog2(1'd0))) + 31))) + (((1 + sv2v_cast_1($clog2(1'd0))) + 31) >= 0 ? sv2v_cast_1($clog2(1'd0)) + 31 : ((1 + sv2v_cast_1($clog2(1'd0))) + 31) - (sv2v_cast_1($clog2(1'd0)) + 31))) + ((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))) - 1)-:((sv2v_cast_1($clog2(1'd0)) + 31) >= 32 ? sv2v_cast_1($clog2(1'd0)) + 0 : 33 - (sv2v_cast_1($clog2(1'd0)) + 31))])) begin
													rs_bypass[((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (1'd1 - cpu_params_CDB_WIDTH)] = 1'sb1;
													begin : sv2v_autoblock_199
														reg [cpu_params_INT_ISSUE_IDX - 1:0] sv2v_tmp_cast;
														sv2v_tmp_cast = $unsigned(i);
														rs_bypass[sv2v_cast_1($clog2(1'd0)) - 1-:sv2v_cast_1($clog2(1'd0))] = sv2v_tmp_cast;
													end
													_sv2v_jump = 2'b10;
												end
												_sv2v_value_on_break = i;
											end
										if (!(_sv2v_jump < 2'b10))
											i = _sv2v_value_on_break;
										if (_sv2v_jump != 2'b11)
											_sv2v_jump = 2'b00;
									end
								end
							end
							assign src1_ready = entry_reg[1 + (sv2v_cast_1($clog2(1'd0)) + 36)] || |rs_bypass[(1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))-:(((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) >= ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) ? (((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)))) + 1 : (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) - ((1'd1 + 1) + ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))))) + 1)];
							assign src2_ready = entry_reg[36] || |rs_bypass[(1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))-:(((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) ? (((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 0)) - ((1'd1 + 1) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) - 1)))) + 1)];
							assign request = (entry_valid && src1_ready) && src2_ready;
							assign valid = entry_valid;
							assign entry = entry_reg;
							initial _sv2v_0 = 0;
						end
						assign mem_rs_entry_i.clk = clk;
						assign mem_rs_entry_i.rst = rst;
						assign rs_valid[i] = mem_rs_entry_i.valid;
						assign rs_request[i] = mem_rs_entry_i.request;
						assign mem_rs_entry_i.grant = rs_grant[i];
						assign mem_rs_entry_i.push_en = rs_push_en[i];
						assign mem_rs_entry_i.entry_in = rs_entry_in[(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? 0 : (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) + (i * (((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37 : 1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36)))+:(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37 : 1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36))];
						assign rs_entry[(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? 0 : (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) + (i * (((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37 : 1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36)))+:(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37 : 1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36))] = mem_rs_entry_i.entry;
						assign mem_rs_entry_i.clear = 1'b0;
						assign mem_rs_entry_i.fast_bypass = alu_bypass;
						assign rs_bypass[i * ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)+:(((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX] = mem_rs_entry_i.rs_bypass;
					end
					wire [cpu_params_MEMRS_DEPTH - 1:0] entry_push_en_arr;
					localparam cpu_params_MEMRS_IDX = $clog2(1'd0);
					always @(*) begin : sv2v_autoblock_200
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						rs_push_en = 1'sb0;
						if (cpu.backend_i.lsu_i.ds_mem_rs_i.valid && cpu.backend_i.lsu_i.ds_mem_rs_i.ready) begin : sv2v_autoblock_201
							reg signed [31:0] i;
							begin : sv2v_autoblock_202
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_MEMRS_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										begin : sv2v_autoblock_203
											reg [cpu_params_MEMRS_IDX - 1:0] sv2v_tmp_cast;
											sv2v_tmp_cast = $unsigned(i);
											if (!rs_valid[sv2v_tmp_cast]) begin
												rs_push_en[i] = 1'b1;
												_sv2v_jump = 2'b10;
											end
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					genvar _gv_i_4;
					for (_gv_i_4 = 0; _gv_i_4 < cpu_params_MEMRS_DEPTH; _gv_i_4 = _gv_i_4 + 1) begin : push_muxes
						localparam i = _gv_i_4;
						assign rs_entry_in[(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? 0 : (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) + (i * (((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37 : 1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36)))+:(((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36) >= 0 ? (((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 37 : 1 - ((((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + 1) + cpu_params_PRF_IDX) + 36))] = from_ds_entry;
					end
					always @(*) begin : sv2v_autoblock_204
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						rs_grant = 1'sb0;
						begin : sv2v_autoblock_205
							reg signed [31:0] i;
							begin : sv2v_autoblock_206
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_MEMRS_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (rs_request[i]) begin
											rs_grant[i] = 1'b1;
											_sv2v_jump = 2'b10;
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					one_hot_mux_921A8_BE200 #(
						.T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
						.T_cpu_params_ROB_IDX(cpu_params_ROB_IDX),
						.NUM_INPUTS(cpu_params_MEMRS_DEPTH)
					) ohm(
						.data_in(rs_entry),
						.select(rs_grant),
						.data_out(issued_entry)
					);
					one_hot_mux_602F0_CCEF1 #(
						.T_cpu_params_CDB_WIDTH(cpu_params_CDB_WIDTH),
						.T_cpu_params_INT_ISSUE_IDX(cpu_params_INT_ISSUE_IDX),
						.NUM_INPUTS(cpu_params_MEMRS_DEPTH)
					) ohm_rs1(
						.data_in(rs_bypass),
						.select(rs_grant),
						.data_out(cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs_bypass)
					);
					assign cpu.backend_i.lsu_i.ds_mem_rs_i.ready = |(~rs_valid);
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_phy = issued_entry[cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))-:((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))) >= (1 + (cpu_params_PRF_IDX + 37)) ? ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))) - (1 + (cpu_params_PRF_IDX + 37))) + 1 : ((1 + (cpu_params_PRF_IDX + 37)) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))) + 1)];
					assign cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_phy = issued_entry[cpu_params_PRF_IDX + 36-:((cpu_params_PRF_IDX + 36) >= 37 ? cpu_params_PRF_IDX + 0 : 38 - (cpu_params_PRF_IDX + 36))];
					wire [cpu_params_ROB_IDX + 99:0] agu_reg_in;
					wire [cpu_params_ROB_IDX + 131:0] agu_lsq;
					assign agu_reg_in[cpu_params_ROB_IDX + 99-:((cpu_params_ROB_IDX + 99) >= 100 ? cpu_params_ROB_IDX + 0 : 101 - (cpu_params_ROB_IDX + 99))] = issued_entry[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))) >= (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 37))) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36)))) - (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 37)))) + 1 : ((cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 37))) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (1 + (cpu_params_PRF_IDX + 36))))) + 1)];
					assign agu_reg_in[99-:4] = issued_entry[3-:4];
					assign agu_reg_in[95-:32] = issued_entry[35-:32];
					assign agu_reg_in[63-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs1_value;
					assign agu_reg_in[31-:32] = cpu.backend_i.rs_prf_itfs[_mbase_to_prf].rs2_value;
					fu_agu fu_agu_i(
						.clk(clk),
						.rst(rst),
						.prv_valid(|rs_request),
						.prv_ready(),
						.agu_reg_in(agu_reg_in),
						.nxt_valid(cpu.backend_i.lsu_i.agu_lsq_i.valid),
						.to_lsq(cpu.backend_i.lsu_i.agu_lsq_i.data)
					);
					initial _sv2v_0 = 0;
				end
				assign mem_rs_i.clk = clk;
				assign mem_rs_i.rst = rst || backend_flush;
				assign mem_rs_i.alu_bypass = alu_bypass;
				if (1) begin : dmem_itf_i
					reg [31:0] addr;
					wire [3:0] rmask;
					wire [3:0] wmask;
					wire [31:0] rdata;
					wire [31:0] wdata;
					wire resp;
				end
				if (1) begin : ld_dmem_itf_i
					wire valid;
					wire ready;
					wire [31:0] addr;
					wire [3:0] rmask;
					wire resp;
					wire [31:0] rdata;
				end
				if (1) begin : stq_stb_i
					wire valid;
					wire ready;
					wire [31:0] addr;
					wire [3:0] wmask;
					wire [31:0] wdata;
				end
				if (1) begin : st_dmem_itf_i
					wire valid;
					wire ready;
					wire [31:0] addr;
					wire [3:0] wmask;
					wire [31:0] wdata;
				end
				if (1) begin : ldq_stq_i
					localparam cpu_params_STQ_DEPTH = 8;
					localparam cpu_params_STQ_IDX = $clog2(1'd0);
					wire [cpu_params_STQ_IDX:0] stq_tail;
					wire stq_deq;
					localparam cpu_params_LDQ_DEPTH = 8;
					wire [cpu_params_STQ_IDX:0] ldq_tracker [0:cpu_params_LDQ_DEPTH - 1];
					wire [31:0] ldq_addr [0:cpu_params_LDQ_DEPTH - 1];
					wire [3:0] ldq_rmask [0:cpu_params_LDQ_DEPTH - 1];
					reg has_conflicting_store [0:cpu_params_LDQ_DEPTH - 1];
				end
				if (1) begin : ldq_stb_i
					localparam cpu_params_LDQ_DEPTH = 8;
					wire [31:0] ldq_addr [0:cpu_params_LDQ_DEPTH - 1];
					wire [3:0] ldq_rmask [0:cpu_params_LDQ_DEPTH - 1];
					reg has_conflicting_store [0:cpu_params_LDQ_DEPTH - 1];
				end
				localparam _bbase_68837_cdb_out = 3;
				if (1) begin : ldq_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					wire backend_flush;
					localparam _mbase_cdb_out = _bbase_68837_cdb_out;
					localparam cpu_params_LDQ_DEPTH = 8;
					localparam cpu_params_ARF_DEPTH = 32;
					localparam cpu_params_ARF_IDX = $clog2(1'd0);
					localparam cpu_params_PRF_DEPTH = 64;
					localparam cpu_params_PRF_IDX = $clog2(1'd0);
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					localparam cpu_params_STQ_DEPTH = 8;
					localparam cpu_params_STQ_IDX = $clog2(1'd0);
					reg [(((((2 + (cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX)) + cpu_params_ROB_IDX) + 40) + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 63:0] ldq_arr [0:cpu_params_LDQ_DEPTH - 1];
					reg [(((((2 + (cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX)) + cpu_params_ROB_IDX) + 40) + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 63:0] ldq_arr_nxt [0:cpu_params_LDQ_DEPTH - 1];
					reg push_en;
					localparam cpu_params_LDQ_IDX = $clog2(1'd0);
					reg [cpu_params_LDQ_IDX - 1:0] push_idx;
					reg issue_en;
					reg [cpu_params_LDQ_IDX - 1:0] issue_idx;
					always @(posedge clk)
						if (rst || backend_flush) begin : sv2v_autoblock_207
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								ldq_arr[i][2 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))] <= 1'b0;
						end
						else begin : sv2v_autoblock_208
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								ldq_arr[i] <= ldq_arr_nxt[i];
						end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_209
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								ldq_arr_nxt[i] = ldq_arr[i];
						end
						if (cpu.backend_i.lsu_i.ldq_stq_i.stq_deq) begin : sv2v_autoblock_210
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								ldq_arr_nxt[i][(cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))-:(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1)] = (ldq_arr[i][(cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))-:(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1)] == {(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1) * 1 {1'sb0}} ? {(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1) * 1 {1'sb0}} : ldq_arr[i][(cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))-:(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1)] - 1);
						end
						if (cpu.backend_i.lsu_i.agu_lsq_i.valid) begin : sv2v_autoblock_211
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								if (ldq_arr[i][cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))-:((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) >= (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) - (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) + 1)] == cpu.backend_i.lsu_i.agu_lsq_i.data[sv2v_cast_1($clog2(1'd0 * 1'd0)) + 131-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + 131) >= 132 ? sv2v_cast_1($clog2(1'd0 * 1'd0)) + 0 : 133 - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + 131))]) begin
									ldq_arr_nxt[i][1 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))] = 1'b1;
									ldq_arr_nxt[i][36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)] = cpu.backend_i.lsu_i.agu_lsq_i.data[131-:32];
									ldq_arr_nxt[i][4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) ? ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)] = cpu.backend_i.lsu_i.agu_lsq_i.data[67-:4];
									ldq_arr_nxt[i][63-:32] = cpu.backend_i.lsu_i.agu_lsq_i.data[63-:32];
									ldq_arr_nxt[i][31-:32] = cpu.backend_i.lsu_i.agu_lsq_i.data[31-:32];
								end
						end
						if (push_en) begin
							ldq_arr_nxt[push_idx][2 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))] = 1'b1;
							ldq_arr_nxt[push_idx][1 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))] = 1'b0;
							ldq_arr_nxt[push_idx][(cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))-:(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1)] = (cpu.backend_i.lsu_i.ldq_stq_i.stq_deq ? cpu.backend_i.lsu_i.ldq_stq_i.stq_tail - 1 : cpu.backend_i.lsu_i.ldq_stq_i.stq_tail);
							ldq_arr_nxt[push_idx][cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))-:((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) >= (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) - (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) + 1)] = cpu.backend_i.lsu_i.ds_ldq_i.uop[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
							ldq_arr_nxt[push_idx][40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)] = cpu.backend_i.lsu_i.ds_ldq_i.uop[6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))-:((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) >= (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) ? ((6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) - (2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))))) + 1 : ((2 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))))) - (6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))))) + 1)];
							ldq_arr_nxt[push_idx][cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)) >= (cpu_params_PRF_IDX + 64) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)) - (cpu_params_PRF_IDX + 64)) + 1 : ((cpu_params_PRF_IDX + 64) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) + 1)] = cpu.backend_i.lsu_i.ds_ldq_i.uop[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) + 1)];
							ldq_arr_nxt[push_idx][cpu_params_PRF_IDX + 63-:((cpu_params_PRF_IDX + 63) >= 64 ? cpu_params_PRF_IDX + 0 : 65 - (cpu_params_PRF_IDX + 63))] = cpu.backend_i.lsu_i.ds_ldq_i.uop[sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))-:((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) ? ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))))))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))))))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))) + 1)];
						end
						if (issue_en && cpu.backend_i.lsu_i.ld_dmem_itf_i.ready)
							ldq_arr_nxt[issue_idx][2 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))] = 1'b0;
					end
					always @(*) begin : sv2v_autoblock_212
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						push_en = 1'sb0;
						push_idx = 1'sb0;
						if ((cpu.backend_i.lsu_i.ds_ldq_i.valid && cpu.backend_i.lsu_i.ds_ldq_i.ready) && ~cpu.backend_i.lsu_i.ds_ldq_i.uop[6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))]) begin : sv2v_autoblock_213
							reg signed [31:0] i;
							begin : sv2v_autoblock_214
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										begin : sv2v_autoblock_215
											reg [cpu_params_LDQ_IDX - 1:0] sv2v_tmp_cast;
											sv2v_tmp_cast = $unsigned(i);
											if (~ldq_arr[sv2v_tmp_cast][2 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))]) begin
												push_en = 1'b1;
												begin : sv2v_autoblock_216
													reg [cpu_params_LDQ_IDX - 1:0] sv2v_tmp_cast_1;
													sv2v_tmp_cast_1 = $unsigned(i);
													push_idx = sv2v_tmp_cast_1;
												end
												_sv2v_jump = 2'b10;
											end
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					always @(*) begin : sv2v_autoblock_217
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						cpu.backend_i.lsu_i.ds_ldq_i.ready = 1'sb0;
						begin : sv2v_autoblock_218
							reg signed [31:0] i;
							begin : sv2v_autoblock_219
								reg signed [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (~ldq_arr[i][2 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))]) begin
											cpu.backend_i.lsu_i.ds_ldq_i.ready = 1'sb1;
											_sv2v_jump = 2'b10;
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					genvar _gv_i_2;
					for (_gv_i_2 = 0; _gv_i_2 < cpu_params_LDQ_DEPTH; _gv_i_2 = _gv_i_2 + 1) begin : genblk1
						localparam i = _gv_i_2;
						assign cpu.backend_i.lsu_i.ldq_stq_i.ldq_tracker[i] = ldq_arr[i][(cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))-:(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1)];
						assign cpu.backend_i.lsu_i.ldq_stq_i.ldq_addr[i] = ldq_arr[i][36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)];
						assign cpu.backend_i.lsu_i.ldq_stq_i.ldq_rmask[i] = ldq_arr[i][4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) ? ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)];
						assign cpu.backend_i.lsu_i.ldq_stb_i.ldq_addr[i] = ldq_arr[i][36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)];
						assign cpu.backend_i.lsu_i.ldq_stb_i.ldq_rmask[i] = ldq_arr[i][4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) ? ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)];
					end
					always @(*) begin : sv2v_autoblock_220
						reg [0:1] _sv2v_jump;
						_sv2v_jump = 2'b00;
						if (_sv2v_0)
							;
						issue_en = 1'sb0;
						issue_idx = 1'sb0;
						begin : sv2v_autoblock_221
							reg [31:0] i;
							begin : sv2v_autoblock_222
								reg [31:0] _sv2v_value_on_break;
								for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
									if (_sv2v_jump < 2'b10) begin
										_sv2v_jump = 2'b00;
										if (ldq_arr[i][2 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))] && ldq_arr[i][1 + ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))]) begin
											if (((ldq_arr[i][(cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))-:(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1)] == {(((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) >= (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) ? (((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))))) + 1 : ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) - ((cpu_params_STQ_IDX >= 0 ? cpu_params_STQ_IDX + 1 : 1 - cpu_params_STQ_IDX) + (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))))) + 1) * 1 {1'sb0}}) || !cpu.backend_i.lsu_i.ldq_stq_i.has_conflicting_store[i]) && !cpu.backend_i.lsu_i.ldq_stb_i.has_conflicting_store[i]) begin
												issue_en = 1'b1;
												begin : sv2v_autoblock_223
													reg [cpu_params_LDQ_IDX - 1:0] sv2v_tmp_cast;
													sv2v_tmp_cast = i;
													issue_idx = sv2v_tmp_cast;
												end
												_sv2v_jump = 2'b10;
											end
										end
										_sv2v_value_on_break = i;
									end
								if (!(_sv2v_jump < 2'b10))
									i = _sv2v_value_on_break;
								if (_sv2v_jump != 2'b11)
									_sv2v_jump = 2'b00;
							end
						end
					end
					assign cpu.backend_i.lsu_i.ld_dmem_itf_i.valid = issue_en && ~backend_flush;
					reg [(((cpu_params_ROB_IDX + 2) + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 103:0] load_stage_reg;
					always @(posedge clk)
						if (cpu.backend_i.lsu_i.ld_dmem_itf_i.valid && cpu.backend_i.lsu_i.ld_dmem_itf_i.ready) begin
							load_stage_reg[cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))-:((cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))) >= (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104))) ? ((cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))) - (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104)))) + 1 : ((2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104))) - (cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))))) + 1)] <= ldq_arr[issue_idx][cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))-:((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) >= (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) - (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (cpu_params_ROB_IDX + (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))))) + 1)];
							load_stage_reg[2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))-:((2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104)) ? ((2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104)) - (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))) + 1)] <= ldq_arr[issue_idx][(36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - 30:(36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - 31];
							load_stage_reg[103-:4] <= ldq_arr[issue_idx][40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) ? ((40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)))) + 1 : ((36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) - (40 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)];
							load_stage_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)) >= (cpu_params_PRF_IDX + 104) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)) - (cpu_params_PRF_IDX + 104)) + 1 : ((cpu_params_PRF_IDX + 104) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))) + 1)] <= ldq_arr[issue_idx][cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)) >= (cpu_params_PRF_IDX + 64) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)) - (cpu_params_PRF_IDX + 64)) + 1 : ((cpu_params_PRF_IDX + 64) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) + 1)];
							load_stage_reg[cpu_params_PRF_IDX + 103-:((cpu_params_PRF_IDX + 103) >= 104 ? cpu_params_PRF_IDX + 0 : 105 - (cpu_params_PRF_IDX + 103))] <= ldq_arr[issue_idx][cpu_params_PRF_IDX + 63-:((cpu_params_PRF_IDX + 63) >= 64 ? cpu_params_PRF_IDX + 0 : 65 - (cpu_params_PRF_IDX + 63))];
							load_stage_reg[99-:32] <= cpu.backend_i.lsu_i.ld_dmem_itf_i.addr;
							load_stage_reg[67-:4] <= ldq_arr[issue_idx][4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) ? ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)];
							load_stage_reg[63-:32] <= ldq_arr[issue_idx][63-:32];
							load_stage_reg[31-:32] <= ldq_arr[issue_idx][31-:32];
						end
					assign cpu.backend_i.lsu_i.ld_dmem_itf_i.rmask = ldq_arr[issue_idx][4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))-:((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) ? ((4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 64)) - (4 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)))) + 1)];
					assign cpu.backend_i.lsu_i.ld_dmem_itf_i.addr = {ldq_arr[issue_idx][36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63)):(36 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 63))) - 29], 2'b00};
					wire [1:0] addr_2;
					assign addr_2 = load_stage_reg[2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))-:((2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104)) ? ((2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104)) - (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))) + 1)];
					wire [31:0] dmem_rdata;
					reg [31:0] dmem_rdata_wb;
					assign dmem_rdata = cpu.backend_i.lsu_i.ld_dmem_itf_i.rdata;
					always @(*) begin
						if (_sv2v_0)
							;
						(* full_case, parallel_case *)
						case (load_stage_reg[103-:4])
							4'b0000: dmem_rdata_wb = {{24 {dmem_rdata[7 + (8 * addr_2[1:0])]}}, dmem_rdata[8 * addr_2[1:0]+:8]};
							4'b0100: dmem_rdata_wb = {{24 {1'b0}}, dmem_rdata[8 * addr_2[1:0]+:8]};
							4'b0001: dmem_rdata_wb = {{16 {dmem_rdata[15 + (16 * addr_2[1])]}}, dmem_rdata[16 * addr_2[1]+:16]};
							4'b0101: dmem_rdata_wb = {{16 {1'b0}}, dmem_rdata[16 * addr_2[1]+:16]};
							4'b0010: dmem_rdata_wb = dmem_rdata;
							default: dmem_rdata_wb = 1'sbx;
						endcase
					end
					wire [((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 31:0] cdb_reg_in;
					wire [((cpu_params_ROB_IDX + cpu_params_PRF_IDX) + cpu_params_ARF_IDX) + 31:0] cdb_reg_out;
					wire [131:0] rvfi_reg_in;
					wire [131:0] rvfi_reg_out;
					wire cdb_out_valid;
					wire rvfi_out_valid;
					assign cdb_reg_in[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) >= (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32)) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32)) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)))) + 1)] = load_stage_reg[cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))-:((cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))) >= (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104))) ? ((cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)))) - (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104)))) + 1 : ((2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 104))) - (cpu_params_ROB_IDX + (2 + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))))) + 1)];
					assign cdb_reg_in[cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)) >= (cpu_params_ARF_IDX + 32) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)) - (cpu_params_ARF_IDX + 32)) + 1 : ((cpu_params_ARF_IDX + 32) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) + 1)] = load_stage_reg[cpu_params_PRF_IDX + 103-:((cpu_params_PRF_IDX + 103) >= 104 ? cpu_params_PRF_IDX + 0 : 105 - (cpu_params_PRF_IDX + 103))];
					assign cdb_reg_in[cpu_params_ARF_IDX + 31-:((cpu_params_ARF_IDX + 31) >= 32 ? cpu_params_ARF_IDX + 0 : 33 - (cpu_params_ARF_IDX + 31))] = load_stage_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)) >= (cpu_params_PRF_IDX + 104) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103)) - (cpu_params_PRF_IDX + 104)) + 1 : ((cpu_params_PRF_IDX + 104) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 103))) + 1)];
					assign cdb_reg_in[31-:32] = dmem_rdata_wb;
					assign rvfi_reg_in[131-:32] = load_stage_reg[63-:32];
					assign rvfi_reg_in[99-:32] = load_stage_reg[31-:32];
					assign rvfi_reg_in[67-:32] = load_stage_reg[99-:32];
					assign rvfi_reg_in[35-:4] = load_stage_reg[67-:4];
					assign rvfi_reg_in[31-:32] = dmem_rdata;
					pipeline_reg_A3B61_DD976 #(
						.DATA_T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
						.DATA_T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
						.DATA_T_cpu_params_ROB_IDX(cpu_params_ROB_IDX)
					) cdb_reg(
						.clk(clk),
						.rst(rst),
						.flush(backend_flush),
						.prv_valid(cpu.backend_i.lsu_i.ld_dmem_itf_i.resp),
						.prv_ready(),
						.nxt_valid(cdb_out_valid),
						.nxt_ready(1'b1),
						.prv_data(cdb_reg_in),
						.nxt_data(cdb_reg_out)
					);
					pipeline_reg_DE194 rvfi_reg(
						.clk(clk),
						.rst(rst),
						.flush(backend_flush),
						.prv_valid(cpu.backend_i.lsu_i.ld_dmem_itf_i.resp),
						.prv_ready(),
						.nxt_valid(rvfi_out_valid),
						.nxt_ready(1'b1),
						.prv_data(rvfi_reg_in),
						.nxt_data(rvfi_reg_out)
					);
					assign cpu.backend_i.cdb_itfs[_mbase_cdb_out].valid = cdb_out_valid;
					assign cpu.backend_i.cdb_itfs[_mbase_cdb_out].rob_id = cdb_reg_out[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) >= (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32)) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32)) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)))) + 1)];
					assign cpu.backend_i.cdb_itfs[_mbase_cdb_out].rd_phy = cdb_reg_out[cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)-:((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)) >= (cpu_params_ARF_IDX + 32) ? ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)) - (cpu_params_ARF_IDX + 32)) + 1 : ((cpu_params_ARF_IDX + 32) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) + 1)];
					assign cpu.backend_i.cdb_itfs[_mbase_cdb_out].rd_arch = cdb_reg_out[cpu_params_ARF_IDX + 31-:((cpu_params_ARF_IDX + 31) >= 32 ? cpu_params_ARF_IDX + 0 : 33 - (cpu_params_ARF_IDX + 31))];
					assign cpu.backend_i.cdb_itfs[_mbase_cdb_out].rd_value = cdb_reg_out[31-:32];
					assign cpu.backend_i.cdb_itfs[_mbase_cdb_out].rs1_value_dbg = rvfi_reg_out[131-:32];
					assign cpu.backend_i.cdb_itfs[_mbase_cdb_out].rs2_value_dbg = rvfi_reg_out[99-:32];
					assign cpu.backend_i.ldq_rob_itf.valid = rvfi_out_valid;
					assign cpu.backend_i.ldq_rob_itf.rob_id = cdb_reg_out[cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))-:((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) >= (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32)) ? ((cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31))) - (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32))) + 1 : ((cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 32)) - (cpu_params_ROB_IDX + (cpu_params_PRF_IDX + (cpu_params_ARF_IDX + 31)))) + 1)];
					assign cpu.backend_i.ldq_rob_itf.addr_dbg = rvfi_reg_out[67-:32];
					assign cpu.backend_i.ldq_rob_itf.rmask_dbg = rvfi_reg_out[35-:4];
					assign cpu.backend_i.ldq_rob_itf.rdata_dbg = rvfi_reg_out[31-:32];
					initial _sv2v_0 = 0;
				end
				assign ldq_i.clk = clk;
				assign ldq_i.rst = rst;
				assign ldq_i.backend_flush = backend_flush;
				if (1) begin : stq_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					wire backend_flush;
					localparam cpu_params_STQ_DEPTH = 8;
					localparam cpu_params_ID_WIDTH = 2;
					localparam cpu_params_ROB_DEPTH = 32;
					localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
					reg [cpu_params_ROB_IDX + 132:0] fifo [0:cpu_params_STQ_DEPTH - 1];
					localparam cpu_params_STQ_IDX = $clog2(1'd0);
					reg [cpu_params_STQ_IDX:0] wr_ptr;
					wire [cpu_params_STQ_IDX - 1:0] wr_ptr_actual;
					wire wr_ptr_flag;
					reg [cpu_params_STQ_IDX:0] rd_ptr;
					wire [cpu_params_STQ_IDX - 1:0] rd_ptr_actual;
					wire rd_ptr_flag;
					reg [cpu_params_STQ_IDX:0] counter;
					reg [cpu_params_STQ_IDX:0] counter_nxt;
					assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
					assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;
					wire enqueue;
					wire dequeue;
					always @(posedge clk)
						if (rst || backend_flush) begin
							wr_ptr <= 1'sb0;
							rd_ptr <= 1'sb0;
							counter <= 1'sb0;
						end
						else begin
							if (enqueue) begin : sv2v_autoblock_224
								reg [((cpu_params_STQ_IDX + 0) >= 0 ? cpu_params_STQ_IDX + 1 : 1 - (cpu_params_STQ_IDX + 0)) - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = wr_ptr + 1;
								wr_ptr <= sv2v_tmp_cast;
							end
							if (dequeue) begin : sv2v_autoblock_225
								reg [((cpu_params_STQ_IDX + 0) >= 0 ? cpu_params_STQ_IDX + 1 : 1 - (cpu_params_STQ_IDX + 0)) - 1:0] sv2v_tmp_cast_1;
								sv2v_tmp_cast_1 = rd_ptr + 1;
								rd_ptr <= sv2v_tmp_cast_1;
							end
							counter <= counter_nxt;
						end
					always @(*) begin
						if (_sv2v_0)
							;
						counter_nxt = counter;
						if (enqueue) begin : sv2v_autoblock_226
							reg [((cpu_params_STQ_IDX + 0) >= 0 ? cpu_params_STQ_IDX + 1 : 1 - (cpu_params_STQ_IDX + 0)) - 1:0] sv2v_tmp_cast;
							sv2v_tmp_cast = counter_nxt + 1;
							counter_nxt = sv2v_tmp_cast;
						end
						if (dequeue) begin : sv2v_autoblock_227
							reg [((cpu_params_STQ_IDX + 0) >= 0 ? cpu_params_STQ_IDX + 1 : 1 - (cpu_params_STQ_IDX + 0)) - 1:0] sv2v_tmp_cast_1;
							sv2v_tmp_cast_1 = counter_nxt - 1;
							counter_nxt = sv2v_tmp_cast_1;
						end
					end
					always @(posedge clk) begin
						if (cpu.backend_i.lsu_i.agu_lsq_i.valid) begin : sv2v_autoblock_228
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_STQ_DEPTH; i = i + 1)
								if (fifo[i][cpu_params_ROB_IDX + 132-:((cpu_params_ROB_IDX + 132) >= 133 ? cpu_params_ROB_IDX + 0 : 134 - (cpu_params_ROB_IDX + 132))] == cpu.backend_i.lsu_i.agu_lsq_i.data[sv2v_cast_1($clog2(1'd0 * 1'd0)) + 131-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + 131) >= 132 ? sv2v_cast_1($clog2(1'd0 * 1'd0)) + 0 : 133 - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + 131))]) begin
									fifo[i][132] <= 1'b1;
									fifo[i][131-:32] <= cpu.backend_i.lsu_i.agu_lsq_i.data[131-:32];
									fifo[i][99-:4] <= cpu.backend_i.lsu_i.agu_lsq_i.data[67-:4];
									fifo[i][95-:32] <= cpu.backend_i.lsu_i.agu_lsq_i.data[99-:32];
									fifo[i][63-:32] <= cpu.backend_i.lsu_i.agu_lsq_i.data[63-:32];
									fifo[i][31-:32] <= cpu.backend_i.lsu_i.agu_lsq_i.data[31-:32];
								end
						end
						if (enqueue) begin
							fifo[wr_ptr_actual][cpu_params_ROB_IDX + 132-:((cpu_params_ROB_IDX + 132) >= 133 ? cpu_params_ROB_IDX + 0 : 134 - (cpu_params_ROB_IDX + 132))] <= cpu.backend_i.lsu_i.ds_stq_i.uop[sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))-:((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) >= (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) ? ((sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32)))) - (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33)))) + 1 : ((sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 33))) - (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))) + 1)];
							fifo[wr_ptr_actual][132] <= 1'b0;
						end
					end
					wire full;
					wire empty;
					reg want_dequeue;
					assign enqueue = (cpu.backend_i.lsu_i.ds_stq_i.valid && cpu.backend_i.lsu_i.ds_stq_i.ready) && cpu.backend_i.lsu_i.ds_stq_i.uop[6 + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (34 + (sv2v_cast_1($clog2(1'd0 * 1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + (sv2v_cast_1($clog2(1'd0)) + 32))))))))];
					always @(*) begin
						if (_sv2v_0)
							;
						if (empty)
							want_dequeue = 1'b0;
						else
							want_dequeue = fifo[rd_ptr_actual][132];
					end
					assign dequeue = (want_dequeue && cpu.backend_i.stq_rob_itf.ready) && cpu.backend_i.lsu_i.stq_stb_i.ready;
					assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
					assign empty = wr_ptr == rd_ptr;
					assign cpu.backend_i.lsu_i.ds_stq_i.ready = ~full;
					assign cpu.backend_i.lsu_i.stq_stb_i.valid = want_dequeue && cpu.backend_i.stq_rob_itf.ready;
					assign cpu.backend_i.lsu_i.stq_stb_i.wmask = fifo[rd_ptr_actual][99-:4];
					assign cpu.backend_i.lsu_i.stq_stb_i.addr = {fifo[rd_ptr_actual][131:102], 2'b00};
					assign cpu.backend_i.lsu_i.stq_stb_i.wdata = fifo[rd_ptr_actual][95-:32];
					assign cpu.backend_i.stq_rob_itf.valid = want_dequeue && cpu.backend_i.lsu_i.stq_stb_i.ready;
					assign cpu.backend_i.stq_rob_itf.rob_id = fifo[rd_ptr_actual][cpu_params_ROB_IDX + 132-:((cpu_params_ROB_IDX + 132) >= 133 ? cpu_params_ROB_IDX + 0 : 134 - (cpu_params_ROB_IDX + 132))];
					assign cpu.backend_i.stq_rob_itf.addr_dbg = {fifo[rd_ptr_actual][131:102], 2'b00};
					assign cpu.backend_i.stq_rob_itf.wmask_dbg = fifo[rd_ptr_actual][99-:4];
					assign cpu.backend_i.stq_rob_itf.wdata_dbg = fifo[rd_ptr_actual][95-:32];
					assign cpu.backend_i.stq_rob_itf.rs1_value_dbg = fifo[rd_ptr_actual][63-:32];
					assign cpu.backend_i.stq_rob_itf.rs2_value_dbg = fifo[rd_ptr_actual][31-:32];
					assign cpu.backend_i.lsu_i.ldq_stq_i.stq_tail = counter;
					assign cpu.backend_i.lsu_i.ldq_stq_i.stq_deq = dequeue;
					localparam cpu_params_LDQ_DEPTH = 8;
					reg [cpu_params_STQ_DEPTH - 1:0] same_addr [0:cpu_params_LDQ_DEPTH - 1];
					reg [cpu_params_STQ_DEPTH - 1:0] potential_conflict [0:cpu_params_LDQ_DEPTH - 1];
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_229
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								begin
									same_addr[i] = 1'sb0;
									begin : sv2v_autoblock_230
										reg signed [31:0] j;
										for (j = 0; j < cpu_params_STQ_DEPTH; j = j + 1)
											if (~fifo[j][132] || ((fifo[j][131:102] == cpu.backend_i.lsu_i.ldq_stq_i.ldq_addr[i][31:2]) && ((cpu.backend_i.lsu_i.ldq_stq_i.ldq_rmask[i] & ~fifo[j][99-:4]) != cpu.backend_i.lsu_i.ldq_stq_i.ldq_rmask[i])))
												same_addr[i][j] = 1'b1;
									end
								end
						end
					end
					reg [cpu_params_STQ_IDX:0] tracked_tail [0:cpu_params_LDQ_DEPTH - 1];
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_231
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								begin
									potential_conflict[i] = 1'sb0;
									begin : sv2v_autoblock_232
										reg [31:0] j;
										for (j = 0; j < cpu_params_STQ_DEPTH; j = j + 1)
											begin
												begin : sv2v_autoblock_233
													reg signed [((cpu_params_STQ_IDX + 0) >= 0 ? cpu_params_STQ_IDX + 1 : 1 - (cpu_params_STQ_IDX + 0)) - 1:0] sv2v_tmp_cast;
													reg [((cpu_params_STQ_IDX + 0) >= 0 ? cpu_params_STQ_IDX + 1 : 1 - (cpu_params_STQ_IDX + 0)) - 1:0] sv2v_tmp_cast_1;
													sv2v_tmp_cast = 1;
													sv2v_tmp_cast_1 = (rd_ptr + cpu.backend_i.lsu_i.ldq_stq_i.ldq_tracker[i]) - sv2v_tmp_cast;
													tracked_tail[i] = sv2v_tmp_cast_1;
												end
												if (tracked_tail[i][cpu_params_STQ_IDX] == rd_ptr[cpu_params_STQ_IDX]) begin : sv2v_autoblock_234
													reg [cpu_params_STQ_IDX - 1:0] sv2v_tmp_cast_2;
													reg [cpu_params_STQ_IDX - 1:0] sv2v_tmp_cast_3;
													sv2v_tmp_cast_2 = j;
													sv2v_tmp_cast_3 = j;
													potential_conflict[i][j] = (rd_ptr[cpu_params_STQ_IDX - 1:0] <= sv2v_tmp_cast_2) && (sv2v_tmp_cast_3 <= tracked_tail[i][cpu_params_STQ_IDX - 1:0]);
												end
												else begin : sv2v_autoblock_235
													reg [cpu_params_STQ_IDX - 1:0] sv2v_tmp_cast_4;
													reg [cpu_params_STQ_IDX - 1:0] sv2v_tmp_cast_5;
													sv2v_tmp_cast_4 = j;
													sv2v_tmp_cast_5 = j;
													potential_conflict[i][j] = (rd_ptr[cpu_params_STQ_IDX - 1:0] <= sv2v_tmp_cast_4) || (sv2v_tmp_cast_5 <= tracked_tail[i][cpu_params_STQ_IDX - 1:0]);
												end
											end
									end
								end
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_236
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								cpu.backend_i.lsu_i.ldq_stq_i.has_conflicting_store[i] = |(same_addr[i] & potential_conflict[i]);
						end
					end
					initial _sv2v_0 = 0;
				end
				assign stq_i.clk = clk;
				assign stq_i.rst = rst;
				assign stq_i.backend_flush = backend_flush;
				if (1) begin : stb_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam cpu_params_STB_DEPTH = 4;
					reg [68:0] fifo [0:cpu_params_STB_DEPTH - 1];
					localparam cpu_params_STB_IDX = $clog2(1'd0);
					reg [cpu_params_STB_IDX:0] wr_ptr;
					wire [cpu_params_STB_IDX - 1:0] wr_ptr_actual;
					wire wr_ptr_flag;
					reg [cpu_params_STB_IDX:0] rd_ptr;
					wire [cpu_params_STB_IDX - 1:0] rd_ptr_actual;
					wire rd_ptr_flag;
					assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
					assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;
					wire enqueue;
					wire dequeue;
					always @(posedge clk)
						if (rst) begin
							wr_ptr <= 1'sb0;
							rd_ptr <= 1'sb0;
						end
						else begin
							if (enqueue) begin : sv2v_autoblock_237
								reg [((cpu_params_STB_IDX + 0) >= 0 ? cpu_params_STB_IDX + 1 : 1 - (cpu_params_STB_IDX + 0)) - 1:0] sv2v_tmp_cast;
								sv2v_tmp_cast = wr_ptr + 1;
								wr_ptr <= sv2v_tmp_cast;
							end
							if (dequeue) begin : sv2v_autoblock_238
								reg [((cpu_params_STB_IDX + 0) >= 0 ? cpu_params_STB_IDX + 1 : 1 - (cpu_params_STB_IDX + 0)) - 1:0] sv2v_tmp_cast_1;
								sv2v_tmp_cast_1 = rd_ptr + 1;
								rd_ptr <= sv2v_tmp_cast_1;
							end
						end
					always @(posedge clk)
						if (rst) begin : sv2v_autoblock_239
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_STB_DEPTH; i = i + 1)
								fifo[i][68] <= 1'b0;
						end
						else begin
							if (enqueue) begin
								fifo[wr_ptr_actual][68] <= 1'b1;
								fifo[wr_ptr_actual][67-:32] <= cpu.backend_i.lsu_i.stq_stb_i.addr;
								fifo[wr_ptr_actual][35-:4] <= cpu.backend_i.lsu_i.stq_stb_i.wmask;
								fifo[wr_ptr_actual][31-:32] <= cpu.backend_i.lsu_i.stq_stb_i.wdata;
							end
							if (dequeue)
								fifo[rd_ptr_actual][68] <= 1'b0;
						end
					wire full;
					wire empty;
					wire want_dequeue;
					assign enqueue = cpu.backend_i.lsu_i.stq_stb_i.valid && cpu.backend_i.lsu_i.stq_stb_i.ready;
					assign want_dequeue = ~empty;
					assign dequeue = want_dequeue && cpu.backend_i.lsu_i.st_dmem_itf_i.ready;
					assign full = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == ~rd_ptr_flag);
					assign empty = wr_ptr == rd_ptr;
					assign cpu.backend_i.lsu_i.stq_stb_i.ready = ~full;
					assign cpu.backend_i.lsu_i.st_dmem_itf_i.valid = want_dequeue;
					assign cpu.backend_i.lsu_i.st_dmem_itf_i.wmask = fifo[rd_ptr_actual][35-:4];
					assign cpu.backend_i.lsu_i.st_dmem_itf_i.addr = {fifo[rd_ptr_actual][67:38], 2'b00};
					assign cpu.backend_i.lsu_i.st_dmem_itf_i.wdata = fifo[rd_ptr_actual][31-:32];
					localparam cpu_params_LDQ_DEPTH = 8;
					reg [cpu_params_STB_DEPTH - 1:0] same_addr [0:cpu_params_LDQ_DEPTH - 1];
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_240
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								begin
									same_addr[i] = 1'sb0;
									begin : sv2v_autoblock_241
										reg signed [31:0] j;
										for (j = 0; j < cpu_params_STB_DEPTH; j = j + 1)
											if ((fifo[j][68] && (fifo[j][67:38] == cpu.backend_i.lsu_i.ldq_stb_i.ldq_addr[i][31:2])) && ((cpu.backend_i.lsu_i.ldq_stb_i.ldq_rmask[i] & ~fifo[j][35-:4]) != cpu.backend_i.lsu_i.ldq_stb_i.ldq_rmask[i]))
												same_addr[i][j] = 1'b1;
									end
								end
						end
					end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_242
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_LDQ_DEPTH; i = i + 1)
								cpu.backend_i.lsu_i.ldq_stb_i.has_conflicting_store[i] = |same_addr[i];
						end
					end
					initial _sv2v_0 = 0;
				end
				assign stb_i.clk = clk;
				assign stb_i.rst = rst;
				if (1) begin : dmem_arb_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					wire backend_flush;
					wire dmem_valid;
					reg dmem_pending;
					reg pending_store;
					wire dmem_busy;
					reg dmem_flushed;
					wire [0:0] arbiter_priority;
					assign cpu.backend_i.lsu_i.ld_dmem_itf_i.ready = (arbiter_priority == 1'b0 ? ~dmem_busy && ~dmem_flushed : (~dmem_busy && ~dmem_flushed) && ~cpu.backend_i.lsu_i.st_dmem_itf_i.valid);
					assign cpu.backend_i.lsu_i.st_dmem_itf_i.ready = (arbiter_priority == 1'b1 ? ~dmem_busy && ~dmem_flushed : (~dmem_busy && ~dmem_flushed) && ~cpu.backend_i.lsu_i.ld_dmem_itf_i.valid);
					assign arbiter_priority = 1'b0;
					always @(posedge clk)
						if (rst)
							dmem_pending <= 1'sb0;
						else if ((cpu.backend_i.lsu_i.ld_dmem_itf_i.valid && cpu.backend_i.lsu_i.ld_dmem_itf_i.ready) || (cpu.backend_i.lsu_i.st_dmem_itf_i.valid && cpu.backend_i.lsu_i.st_dmem_itf_i.ready))
							dmem_pending <= 1'sb1;
						else if (cpu.backend_i.lsu_i.dmem_itf_i.resp)
							dmem_pending <= 1'sb0;
					always @(posedge clk)
						if (rst)
							pending_store <= 1'sb0;
						else if (cpu.backend_i.lsu_i.st_dmem_itf_i.valid && cpu.backend_i.lsu_i.st_dmem_itf_i.ready)
							pending_store <= 1'sb1;
						else if (cpu.backend_i.lsu_i.dmem_itf_i.resp)
							pending_store <= 1'sb0;
					always @(posedge clk)
						if (rst)
							dmem_flushed <= 1'sb0;
						else if (dmem_busy && backend_flush)
							dmem_flushed <= 1'sb1;
						else if (cpu.backend_i.lsu_i.dmem_itf_i.resp)
							dmem_flushed <= 1'sb0;
					assign dmem_busy = dmem_pending && ~cpu.backend_i.lsu_i.dmem_itf_i.resp;
					assign cpu.backend_i.lsu_i.dmem_itf_i.rmask = (cpu.backend_i.lsu_i.ld_dmem_itf_i.valid && cpu.backend_i.lsu_i.ld_dmem_itf_i.ready ? cpu.backend_i.lsu_i.ld_dmem_itf_i.rmask : {4 {1'sb0}});
					assign cpu.backend_i.lsu_i.dmem_itf_i.wmask = (cpu.backend_i.lsu_i.st_dmem_itf_i.valid && cpu.backend_i.lsu_i.st_dmem_itf_i.ready ? cpu.backend_i.lsu_i.st_dmem_itf_i.wmask : {4 {1'sb0}});
					assign cpu.backend_i.lsu_i.dmem_itf_i.wdata = cpu.backend_i.lsu_i.st_dmem_itf_i.wdata;
					assign cpu.backend_i.lsu_i.ld_dmem_itf_i.rdata = cpu.backend_i.lsu_i.dmem_itf_i.rdata;
					always @(*) begin
						if (_sv2v_0)
							;
						if (cpu.backend_i.lsu_i.ld_dmem_itf_i.valid && cpu.backend_i.lsu_i.ld_dmem_itf_i.ready)
							cpu.backend_i.lsu_i.dmem_itf_i.addr = cpu.backend_i.lsu_i.ld_dmem_itf_i.addr;
						else if (cpu.backend_i.lsu_i.st_dmem_itf_i.valid && cpu.backend_i.lsu_i.st_dmem_itf_i.ready)
							cpu.backend_i.lsu_i.dmem_itf_i.addr = cpu.backend_i.lsu_i.st_dmem_itf_i.addr;
						else
							cpu.backend_i.lsu_i.dmem_itf_i.addr = 1'sbx;
					end
					assign cpu.backend_i.lsu_i.ld_dmem_itf_i.resp = ((cpu.backend_i.lsu_i.dmem_itf_i.resp && dmem_pending) && ~pending_store) && ~dmem_flushed;
					initial _sv2v_0 = 0;
				end
				assign dmem_arb_i.clk = clk;
				assign dmem_arb_i.rst = rst;
				assign dmem_arb_i.backend_flush = backend_flush;
				if (1) begin : dcache_i
					reg _sv2v_0;
					wire clk;
					wire rst;
					localparam cpu_params_D_NUM_WAYS = 4;
					reg data_csb0 [0:cpu_params_D_NUM_WAYS - 1];
					reg tag_csb0 [0:cpu_params_D_NUM_WAYS - 1];
					reg valid_csb0 [0:cpu_params_D_NUM_WAYS - 1];
					wire plru_csb0;
					wire plru_csb1;
					reg data_web0 [0:cpu_params_D_NUM_WAYS - 1];
					reg tag_web0 [0:cpu_params_D_NUM_WAYS - 1];
					reg valid_web0 [0:cpu_params_D_NUM_WAYS - 1];
					wire plru_web1;
					reg [31:0] data_wmask0;
					reg [255:0] data_din0;
					localparam cpu_params_D_TAG_IDX = 23;
					wire [cpu_params_D_TAG_IDX:0] tag_din0;
					wire valid_din0;
					localparam cpu_params_D_PLRU_BITS = cpu_params_D_NUM_WAYS - 1;
					wire [cpu_params_D_PLRU_BITS - 1:0] plru_din1;
					wire [255:0] data_dout0 [0:cpu_params_D_NUM_WAYS - 1];
					wire [(cpu_params_D_TAG_IDX >= 0 ? (cpu_params_D_NUM_WAYS * (cpu_params_D_TAG_IDX + 1)) - 1 : (cpu_params_D_NUM_WAYS * (1 - cpu_params_D_TAG_IDX)) + (cpu_params_D_TAG_IDX - 1)):(cpu_params_D_TAG_IDX >= 0 ? 0 : cpu_params_D_TAG_IDX + 0)] tag_dout0;
					wire [0:cpu_params_D_NUM_WAYS - 1] valid_dout0;
					wire [cpu_params_D_PLRU_BITS - 1:0] plru_dout0;
					localparam cpu_params_D_OFFSET_IDX = 5;
					wire [cpu_params_D_OFFSET_IDX - 1:0] ufp_offset;
					localparam cpu_params_D_SET_IDX = 4;
					wire [cpu_params_D_SET_IDX - 1:0] ufp_set;
					wire [cpu_params_D_TAG_IDX - 1:0] ufp_tag;
					wire [cpu_params_D_SET_IDX - 1:0] next_set;
					wire [cpu_params_D_SET_IDX - 1:0] sram_operating_set;
					reg [(((40 + cpu_params_D_OFFSET_IDX) + cpu_params_D_SET_IDX) + cpu_params_D_TAG_IDX) - 1:0] stage_reg;
					wire hit;
					localparam cpu_params_D_WAY_BITS = $clog2(1'd0);
					wire [cpu_params_D_WAY_BITS - 1:0] hit_way;
					wire [cpu_params_D_WAY_BITS - 1:0] replace_way;
					wire replace_way_dirty;
					wire hit_way_dirty;
					wire stall;
					wire allocate_done;
					wire write_hit_rec;
					wire write_hit;
					assign ufp_offset = cpu.backend_i.lsu_i.dmem_itf_i.addr[cpu_params_D_OFFSET_IDX - 1:0];
					assign ufp_set = cpu.backend_i.lsu_i.dmem_itf_i.addr[(cpu_params_D_SET_IDX + cpu_params_D_OFFSET_IDX) - 1:cpu_params_D_OFFSET_IDX];
					assign ufp_tag = cpu.backend_i.lsu_i.dmem_itf_i.addr[((cpu_params_D_TAG_IDX + cpu_params_D_SET_IDX) + cpu_params_D_OFFSET_IDX) - 1:cpu_params_D_SET_IDX + cpu_params_D_OFFSET_IDX];
					assign sram_operating_set = (write_hit || stall ? stage_reg[cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)-:((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) >= (cpu_params_D_TAG_IDX + 0) ? ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) - (cpu_params_D_TAG_IDX + 0)) + 1 : ((cpu_params_D_TAG_IDX + 0) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) + 1)] : ufp_set);
					genvar _gv_i_1;
					for (_gv_i_1 = 0; _gv_i_1 < cpu_params_D_NUM_WAYS; _gv_i_1 = _gv_i_1 + 1) begin : arrays
						localparam i = _gv_i_1;
						dcache_data_array data_array(
							.clk0(clk),
							.csb0(data_csb0[i]),
							.web0(data_web0[i]),
							.wmask0(data_wmask0),
							.addr0(sram_operating_set),
							.din0(data_din0),
							.dout0(data_dout0[i])
						);
						dcache_tag_array tag_array(
							.clk0(clk),
							.csb0(tag_csb0[i]),
							.web0(tag_web0[i]),
							.addr0(sram_operating_set),
							.din0(tag_din0),
							.dout0(tag_dout0[(cpu_params_D_TAG_IDX >= 0 ? 0 : cpu_params_D_TAG_IDX) + (((cpu_params_D_NUM_WAYS - 1) - i) * (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX + 1 : 1 - cpu_params_D_TAG_IDX))+:(cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX + 1 : 1 - cpu_params_D_TAG_IDX)])
						);
						valid_array #(
							.S_INDEX(cpu_params_D_SET_IDX),
							.WIDTH(1)
						) valid_array(
							.clk0(clk),
							.rst0(rst),
							.csb0(valid_csb0[i]),
							.web0(valid_web0[i]),
							.addr0(sram_operating_set),
							.din0(valid_din0),
							.dout0(valid_dout0[i])
						);
					end
					localparam sv2v_uu_lru_array_WIDTH = cpu_params_D_PLRU_BITS;
					localparam [sv2v_uu_lru_array_WIDTH - 1:0] sv2v_uu_lru_array_ext_din0_x = 1'sbx;
					lru_array #(
						.S_INDEX(cpu_params_D_SET_IDX),
						.WIDTH(cpu_params_D_PLRU_BITS)
					) lru_array(
						.clk0(clk),
						.rst0(rst),
						.csb0(plru_csb0),
						.addr0(ufp_set),
						.din0(sv2v_uu_lru_array_ext_din0_x),
						.dout0(plru_dout0),
						.csb1(plru_csb1),
						.web1(plru_web1),
						.addr1(stage_reg[cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)-:((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) >= (cpu_params_D_TAG_IDX + 0) ? ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) - (cpu_params_D_TAG_IDX + 0)) + 1 : ((cpu_params_D_TAG_IDX + 0) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) + 1)]),
						.din1(plru_din1)
					);
					hit_detection #(
						.TAG_IDX(cpu_params_D_TAG_IDX),
						.NUM_WAYS(cpu_params_D_NUM_WAYS),
						.WAY_BITS(cpu_params_D_WAY_BITS)
					) hit_detection_i(
						.tag(stage_reg[cpu_params_D_TAG_IDX - 1-:cpu_params_D_TAG_IDX]),
						.tag_arr_out(tag_dout0),
						.valid_arr_out(valid_dout0),
						.hit(hit),
						.hit_way(hit_way)
					);
					dcache_ctrl dcache_ctrl_i(
						.clk(clk),
						.rst(rst),
						.hit(hit),
						.dirty(replace_way_dirty),
						.rmask(stage_reg[40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)]),
						.wmask(stage_reg[36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)]),
						.stall(stall),
						.allocate_done(allocate_done),
						.write_hit_rec(write_hit_rec),
						.write_hit(write_hit),
						.dfp_addr(cpu.dcache_itf_i.addr),
						.dfp_read(cpu.dcache_itf_i.read),
						.dfp_write(cpu.dcache_itf_i.write),
						.dfp_ready(cpu.dcache_itf_i.ready),
						.dfp_raddr(cpu.dcache_itf_i.raddr),
						.dfp_rvalid(cpu.dcache_itf_i.rvalid)
					);
					plru_update #(
						.NUM_WAYS(cpu_params_D_NUM_WAYS),
						.PLRU_BITS(cpu_params_D_PLRU_BITS),
						.WAY_BITS(cpu_params_D_WAY_BITS)
					) plru_update_i(
						.current_plru(plru_dout0),
						.next_plru(plru_din1),
						.hit_way(hit_way),
						.replace_way(replace_way)
					);
					always @(posedge clk)
						if (rst) begin
							stage_reg[40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)] <= 1'sb0;
							stage_reg[36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)] <= 1'sb0;
						end
						else if (~stall) begin
							stage_reg[40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)] <= cpu.backend_i.lsu_i.dmem_itf_i.rmask;
							stage_reg[36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)] <= cpu.backend_i.lsu_i.dmem_itf_i.wmask;
							stage_reg[32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))) ? ((32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) + 1 : ((cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))) - (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)] <= cpu.backend_i.lsu_i.dmem_itf_i.wdata;
							stage_reg[cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))-:((cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) >= (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)) ? ((cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))) + 1 : ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)) - (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) + 1)] <= ufp_offset;
							stage_reg[cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)-:((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) >= (cpu_params_D_TAG_IDX + 0) ? ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) - (cpu_params_D_TAG_IDX + 0)) + 1 : ((cpu_params_D_TAG_IDX + 0) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) + 1)] <= ufp_set;
							stage_reg[cpu_params_D_TAG_IDX - 1-:cpu_params_D_TAG_IDX] <= ufp_tag;
						end
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_243
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_D_NUM_WAYS; i = i + 1)
								begin
									data_csb0[i] = 1'b1;
									tag_csb0[i] = 1'b1;
									valid_csb0[i] = 1'b1;
								end
						end
						if (~stall || write_hit_rec) begin : sv2v_autoblock_244
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_D_NUM_WAYS; i = i + 1)
								begin
									data_csb0[i] = 1'b0;
									tag_csb0[i] = 1'b0;
									valid_csb0[i] = 1'b0;
								end
						end
						if (allocate_done) begin
							data_csb0[replace_way] = 1'b0;
							tag_csb0[replace_way] = 1'b0;
							valid_csb0[replace_way] = 1'b0;
						end
					end
					assign plru_csb0 = stall;
					assign plru_csb1 = ~cpu.backend_i.lsu_i.dmem_itf_i.resp;
					always @(*) begin
						if (_sv2v_0)
							;
						begin : sv2v_autoblock_245
							reg signed [31:0] i;
							for (i = 0; i < cpu_params_D_NUM_WAYS; i = i + 1)
								begin
									data_web0[i] = 1'b1;
									tag_web0[i] = 1'b1;
									valid_web0[i] = 1'b1;
								end
						end
						if (allocate_done) begin
							data_web0[replace_way] = 1'b0;
							tag_web0[replace_way] = 1'b0;
							valid_web0[replace_way] = 1'b0;
						end
						if (write_hit) begin
							data_web0[hit_way] = 1'b0;
							tag_web0[hit_way] = hit_way_dirty;
						end
					end
					assign plru_web1 = plru_csb1;
					always @(*) begin
						if (_sv2v_0)
							;
						if (write_hit) begin
							data_wmask0 = 1'sb0;
							begin : sv2v_autoblock_246
								reg signed [31:0] i;
								for (i = 0; i < 4; i = i + 1)
									if (stage_reg[(36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (3 - i)])
										data_wmask0[stage_reg[cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))-:((cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) >= (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)) ? ((cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))) + 1 : ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)) - (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) + 1)] + sv2v_cast_1($unsigned(i))] = 1'b1;
							end
							begin : sv2v_autoblock_247
								reg signed [31:0] i;
								for (i = 0; i < 256; i = i + 1)
									data_din0[i] = stage_reg[(32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (31 - (i % 32))];
							end
						end
						else if (allocate_done) begin
							data_wmask0 = 1'sb1;
							data_din0 = cpu.dcache_itf_i.rdata;
						end
						else begin
							data_wmask0 = 1'sbx;
							data_din0 = 1'sbx;
						end
					end
					assign tag_din0 = {|stage_reg[36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)], stage_reg[cpu_params_D_TAG_IDX - 1-:cpu_params_D_TAG_IDX]};
					assign valid_din0 = 1'b1;
					assign cpu.dcache_itf_i.addr = (cpu.dcache_itf_i.write ? {tag_dout0[(cpu_params_D_TAG_IDX >= 0 ? (((cpu_params_D_NUM_WAYS - 1) - replace_way) * (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX + 1 : 1 - cpu_params_D_TAG_IDX)) + (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX - 1 : cpu_params_D_TAG_IDX - (cpu_params_D_TAG_IDX - 1)) : (((((cpu_params_D_NUM_WAYS - 1) - replace_way) * (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX + 1 : 1 - cpu_params_D_TAG_IDX)) + (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX - 1 : cpu_params_D_TAG_IDX - (cpu_params_D_TAG_IDX - 1))) + cpu_params_D_TAG_IDX) - 1)-:cpu_params_D_TAG_IDX], stage_reg[cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)-:((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) >= (cpu_params_D_TAG_IDX + 0) ? ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) - (cpu_params_D_TAG_IDX + 0)) + 1 : ((cpu_params_D_TAG_IDX + 0) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) + 1)], {cpu_params_D_OFFSET_IDX {1'b0}}} : {stage_reg[cpu_params_D_TAG_IDX - 1-:cpu_params_D_TAG_IDX], stage_reg[cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)-:((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) >= (cpu_params_D_TAG_IDX + 0) ? ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)) - (cpu_params_D_TAG_IDX + 0)) + 1 : ((cpu_params_D_TAG_IDX + 0) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) + 1)], {cpu_params_D_OFFSET_IDX {1'b0}}});
					assign cpu.dcache_itf_i.wdata = data_dout0[replace_way];
					assign cpu.backend_i.lsu_i.dmem_itf_i.rdata = data_dout0[hit_way][8 * stage_reg[cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))-:((cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) >= (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)) ? ((cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))) - (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))) + 1 : ((cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)) - (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) + 1)]+:32];
					assign cpu.backend_i.lsu_i.dmem_itf_i.resp = (|stage_reg[40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (40 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)] || |stage_reg[36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))-:((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) >= (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) ? ((36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1)))) - (32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0))))) + 1 : ((32 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX + 0)))) - (36 + (cpu_params_D_OFFSET_IDX + (cpu_params_D_SET_IDX + (cpu_params_D_TAG_IDX - 1))))) + 1)]) && ~stall;
					assign replace_way_dirty = tag_dout0[(((cpu_params_D_NUM_WAYS - 1) - replace_way) * (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX + 1 : 1 - cpu_params_D_TAG_IDX)) + (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX : cpu_params_D_TAG_IDX - cpu_params_D_TAG_IDX)] && valid_dout0[replace_way];
					assign hit_way_dirty = tag_dout0[(((cpu_params_D_NUM_WAYS - 1) - hit_way) * (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX + 1 : 1 - cpu_params_D_TAG_IDX)) + (cpu_params_D_TAG_IDX >= 0 ? cpu_params_D_TAG_IDX : cpu_params_D_TAG_IDX - cpu_params_D_TAG_IDX)] && valid_dout0[hit_way];
					initial _sv2v_0 = 0;
				end
				assign dcache_i.clk = clk;
				assign dcache_i.rst = rst;
			end
			assign lsu_i.clk = clk;
			assign lsu_i.rst = rst;
			assign lsu_i.alu_bypass = alu_bypass;
			assign lsu_i.backend_flush = backend_flush;
			localparam _bbase_D0047_from_rs = 0;
			localparam _bbase_D0047_cdb = 0;
			if (1) begin : prf_i
				reg _sv2v_0;
				wire clk;
				localparam cpu_params_CDB_WIDTH = 5;
				localparam _mbase_from_rs = 0;
				localparam _mbase_cdb = 0;
				localparam cpu_params_NUM_FAST_BYPASS = 2;
				localparam cpu_params_PRF_DEPTH = 64;
				localparam cpu_params_PRF_IDX = $clog2(1'd0);
				wire [(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (cpu_params_NUM_FAST_BYPASS * ((1 + cpu_params_PRF_IDX) + 32)) - 1 : (cpu_params_NUM_FAST_BYPASS * (1 - ((1 + cpu_params_PRF_IDX) + 31))) + ((1 + cpu_params_PRF_IDX) + 30)):(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 0 : (1 + cpu_params_PRF_IDX) + 31)] alu_bypass;
				reg [31:0] prf_data [cpu_params_PRF_DEPTH - 1:1];
				wire [cpu_params_PRF_IDX + 32:0] cdb_local [0:cpu_params_CDB_WIDTH - 1];
				localparam cpu_params_INT_ISSUE_WIDTH = 2;
				localparam cpu_params_INT_ISSUE_IDX = $clog2(1'd0);
				wire [(((cpu_params_PRF_IDX + cpu_params_PRF_IDX) + 64) + ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)) - 1:0] from_rs_local_in [0:cpu_params_CDB_WIDTH - 1];
				reg [(((cpu_params_PRF_IDX + cpu_params_PRF_IDX) + 64) + ((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX)) - 1:0] from_rs_local_out [0:cpu_params_CDB_WIDTH - 1];
				genvar _gv_i_25;
				for (_gv_i_25 = 0; _gv_i_25 < cpu_params_CDB_WIDTH; _gv_i_25 = _gv_i_25 + 1) begin : genblk1
					localparam i = _gv_i_25;
					assign cdb_local[i][0] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].valid;
					assign cdb_local[i][cpu_params_PRF_IDX + 32-:((cpu_params_PRF_IDX + 32) >= 33 ? cpu_params_PRF_IDX + 0 : 34 - (cpu_params_PRF_IDX + 32))] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].rd_phy;
					assign cdb_local[i][32-:32] = cpu.backend_i.cdb_itfs[i + _mbase_cdb].rd_value;
					assign from_rs_local_in[i][cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))-:((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) >= (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) - (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)))) + 1 : ((cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)))) + 1)] = cpu.backend_i.rs_prf_itfs[i + _mbase_from_rs].rs1_phy;
					assign from_rs_local_in[i][cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)-:((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) >= (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) - (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) + 1)] = cpu.backend_i.rs_prf_itfs[i + _mbase_from_rs].rs2_phy;
					assign from_rs_local_in[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = 1'sbx;
					assign from_rs_local_in[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = 1'sbx;
					assign from_rs_local_in[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1-:(((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX] = cpu.backend_i.rs_prf_itfs[i + _mbase_from_rs].rs_bypass;
					assign cpu.backend_i.rs_prf_itfs[i + _mbase_from_rs].rs1_value = from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)];
					assign cpu.backend_i.rs_prf_itfs[i + _mbase_from_rs].rs2_value = from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)];
				end
				always @(posedge clk) begin : sv2v_autoblock_248
					reg signed [31:0] i;
					for (i = 0; i < cpu_params_CDB_WIDTH; i = i + 1)
						if (cdb_local[i][0] && (cdb_local[i][cpu_params_PRF_IDX + 32-:((cpu_params_PRF_IDX + 32) >= 33 ? cpu_params_PRF_IDX + 0 : 34 - (cpu_params_PRF_IDX + 32))] != {((cpu_params_PRF_IDX + 32) >= 33 ? cpu_params_PRF_IDX + 0 : 34 - (cpu_params_PRF_IDX + 32)) * 1 {1'sb0}}))
							prf_data[cdb_local[i][cpu_params_PRF_IDX + 32-:((cpu_params_PRF_IDX + 32) >= 33 ? cpu_params_PRF_IDX + 0 : 34 - (cpu_params_PRF_IDX + 32))]] <= cdb_local[i][32-:32];
				end
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_249
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_CDB_WIDTH; i = i + 1)
							(* full_case, parallel_case *)
							case (from_rs_local_in[i][(((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)))))-:(((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)))) >= ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX + 0))) ? (((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)))) - ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX + 0)))) + 1 : (((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX + 0))) - ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1))))) + 1)])
								6'b000000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = (from_rs_local_in[i][cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))-:((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) >= (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) - (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)))) + 1 : ((cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)))) + 1)] == {((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) >= (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) - (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)))) + 1 : ((cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)))) + 1) * 1 {1'sb0}} ? {((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1) * 1 {1'sb0}} : prf_data[from_rs_local_in[i][cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))-:((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) >= (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) ? ((cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) - (cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)))) + 1 : ((cpu_params_PRF_IDX + (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) - (cpu_params_PRF_IDX + (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)))) + 1)]]);
								6'b000001: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = cdb_local[0][32-:32];
								6'b000010: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = cdb_local[1][32-:32];
								6'b000100: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = cdb_local[2][32-:32];
								6'b001000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = cdb_local[3][32-:32];
								6'b010000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = cdb_local[4][32-:32];
								6'b100000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = alu_bypass[(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (((cpu_params_NUM_FAST_BYPASS - 1) - from_rs_local_in[i][(((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)))-:((cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)) >= (cpu_params_INT_ISSUE_IDX + 0) ? ((cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)) - (cpu_params_INT_ISSUE_IDX + 0)) + 1 : ((cpu_params_INT_ISSUE_IDX + 0) - (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1))) + 1)]) * (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (1 + cpu_params_PRF_IDX) + 32 : 1 - ((1 + cpu_params_PRF_IDX) + 31))) + (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 31 : (1 + cpu_params_PRF_IDX) + 0) : ((((cpu_params_NUM_FAST_BYPASS - 1) - from_rs_local_in[i][(((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)))-:((cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)) >= (cpu_params_INT_ISSUE_IDX + 0) ? ((cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)) - (cpu_params_INT_ISSUE_IDX + 0)) + 1 : ((cpu_params_INT_ISSUE_IDX + 0) - (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1))) + 1)]) * (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (1 + cpu_params_PRF_IDX) + 32 : 1 - ((1 + cpu_params_PRF_IDX) + 31))) + (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 31 : (1 + cpu_params_PRF_IDX) + 0)) + 31)-:32];
								default: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) >= (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63) - (32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((32 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) + 1)] = 1'sbx;
							endcase
					end
				end
				always @(*) begin
					if (_sv2v_0)
						;
					begin : sv2v_autoblock_250
						reg signed [31:0] i;
						for (i = 0; i < cpu_params_CDB_WIDTH; i = i + 1)
							(* full_case, parallel_case *)
							case (from_rs_local_in[i][(((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1))))-:(((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1))) >= (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX + 0)) ? (((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1))) - (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX + 0))) + 1 : ((cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX + 0)) - ((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_INT_ISSUE_IDX + (cpu_params_INT_ISSUE_IDX - 1)))) + 1)])
								6'b000000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = (from_rs_local_in[i][cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)-:((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) >= (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) - (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) + 1)] == {((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) >= (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) - (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) + 1) * 1 {1'sb0}} ? {((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1) * 1 {1'sb0}} : prf_data[from_rs_local_in[i][cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)-:((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) >= (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) ? ((cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63)) - (64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0))) + 1 : ((64 + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) - (cpu_params_PRF_IDX + (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 63))) + 1)]]);
								6'b000001: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = cdb_local[0][32-:32];
								6'b000010: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = cdb_local[1][32-:32];
								6'b000100: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = cdb_local[2][32-:32];
								6'b001000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = cdb_local[3][32-:32];
								6'b010000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = cdb_local[4][32-:32];
								6'b100000: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = alu_bypass[(((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (((cpu_params_NUM_FAST_BYPASS - 1) - from_rs_local_in[i][(((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - (cpu_params_INT_ISSUE_IDX - 1))-:cpu_params_INT_ISSUE_IDX]) * (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (1 + cpu_params_PRF_IDX) + 32 : 1 - ((1 + cpu_params_PRF_IDX) + 31))) + (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 31 : (1 + cpu_params_PRF_IDX) + 0) : ((((cpu_params_NUM_FAST_BYPASS - 1) - from_rs_local_in[i][(((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) - 1) - (cpu_params_INT_ISSUE_IDX - 1))-:cpu_params_INT_ISSUE_IDX]) * (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? (1 + cpu_params_PRF_IDX) + 32 : 1 - ((1 + cpu_params_PRF_IDX) + 31))) + (((1 + cpu_params_PRF_IDX) + 31) >= 0 ? 31 : (1 + cpu_params_PRF_IDX) + 0)) + 31)-:32];
								default: from_rs_local_out[i][((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31-:((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) >= (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) ? ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0)) + 1 : ((((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 0) - (((((cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH) + (cpu_params_CDB_WIDTH >= 0 ? cpu_params_CDB_WIDTH + 1 : 1 - cpu_params_CDB_WIDTH)) + cpu_params_INT_ISSUE_IDX) + cpu_params_INT_ISSUE_IDX) + 31)) + 1)] = 1'sbx;
							endcase
					end
				end
				initial _sv2v_0 = 0;
			end
			assign prf_i.clk = clk;
			assign prf_i.alu_bypass = alu_bypass;
		end
	endgenerate
	assign backend_i.clk = clk;
	assign backend_i.rst = rst;
	assign backend_flush = backend_i.backend_flush;
	assign backend_redirect_pc = backend_i.backend_redirect_pc;
endmodule
module hit_detection (
	tag,
	tag_arr_out,
	valid_arr_out,
	hit,
	hit_way
);
	reg _sv2v_0;
	parameter TAG_IDX = 23;
	parameter NUM_WAYS = 4;
	parameter WAY_BITS = 2;
	input wire [TAG_IDX - 1:0] tag;
	input wire [(TAG_IDX >= 0 ? (NUM_WAYS * (TAG_IDX + 1)) - 1 : (NUM_WAYS * (1 - TAG_IDX)) + (TAG_IDX - 1)):(TAG_IDX >= 0 ? 0 : TAG_IDX + 0)] tag_arr_out;
	input wire [NUM_WAYS - 1:0] valid_arr_out;
	output reg hit;
	output reg [WAY_BITS - 1:0] hit_way;
	function automatic [WAY_BITS - 1:0] sv2v_cast_91C21;
		input reg [WAY_BITS - 1:0] inp;
		sv2v_cast_91C21 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		hit = 1'b0;
		hit_way = 1'sbx;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_WAYS; i = i + 1)
				if ((tag_arr_out[(TAG_IDX >= 0 ? (((NUM_WAYS - 1) - i) * (TAG_IDX >= 0 ? TAG_IDX + 1 : 1 - TAG_IDX)) + (TAG_IDX >= 0 ? TAG_IDX - 1 : TAG_IDX - (TAG_IDX - 1)) : (((((NUM_WAYS - 1) - i) * (TAG_IDX >= 0 ? TAG_IDX + 1 : 1 - TAG_IDX)) + (TAG_IDX >= 0 ? TAG_IDX - 1 : TAG_IDX - (TAG_IDX - 1))) + TAG_IDX) - 1)-:TAG_IDX] == tag) && valid_arr_out[(NUM_WAYS - 1) - i+:1]) begin
					hit = 1'b1;
					hit_way = sv2v_cast_91C21($unsigned(i));
				end
		end
	end
	initial _sv2v_0 = 0;
endmodule
module dcache_ctrl (
	clk,
	rst,
	hit,
	dirty,
	rmask,
	wmask,
	stall,
	allocate_done,
	write_hit,
	write_hit_rec,
	dfp_addr,
	dfp_read,
	dfp_write,
	dfp_ready,
	dfp_raddr,
	dfp_rvalid
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire hit;
	input wire dirty;
	input wire [3:0] rmask;
	input wire [3:0] wmask;
	output wire stall;
	output reg allocate_done;
	output reg write_hit;
	output reg write_hit_rec;
	input wire [31:0] dfp_addr;
	output reg dfp_read;
	output reg dfp_write;
	input wire dfp_ready;
	input wire [31:0] dfp_raddr;
	input wire dfp_rvalid;
	reg [1:0] state;
	reg [1:0] next_state;
	always @(posedge clk)
		if (rst)
			state <= 2'b00;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		allocate_done = 1'b0;
		write_hit = 1'b0;
		dfp_read = 1'b0;
		dfp_write = 1'b0;
		(* full_case, parallel_case *)
		case (state)
			2'b00:
				if ((|rmask || |wmask) && ~write_hit_rec) begin
					if (~hit) begin
						if (dirty) begin
							dfp_write = 1'b1;
							if (dfp_ready)
								next_state = 2'b11;
						end
						else begin
							dfp_read = 1'b1;
							if (dfp_ready)
								next_state = 2'b01;
						end
					end
					write_hit = |wmask && hit;
				end
			2'b01:
				if (dfp_rvalid && (dfp_addr == dfp_raddr)) begin
					next_state = 2'b10;
					allocate_done = 1'b1;
				end
			2'b10: next_state = 2'b00;
			2'b11: begin
				dfp_read = 1'b1;
				if (dfp_ready)
					next_state = 2'b01;
			end
			default:
				;
		endcase
	end
	assign stall = (|rmask || |wmask) && (write_hit_rec || ~hit);
	always @(posedge clk)
		if (rst)
			write_hit_rec <= 1'b0;
		else if (write_hit_rec)
			write_hit_rec <= 1'b0;
		else if (write_hit)
			write_hit_rec <= 1'b1;
	initial _sv2v_0 = 0;
endmodule
module fu_agu (
	clk,
	rst,
	prv_valid,
	prv_ready,
	agu_reg_in,
	nxt_valid,
	to_lsq
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire prv_valid;
	output wire prv_ready;
	localparam cpu_params_ID_WIDTH = 2;
	localparam cpu_params_ROB_DEPTH = 32;
	localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
	input wire [cpu_params_ROB_IDX + 99:0] agu_reg_in;
	output wire nxt_valid;
	output reg [cpu_params_ROB_IDX + 131:0] to_lsq;
	reg [cpu_params_ROB_IDX + 99:0] agu_reg;
	reg agu_valid;
	assign prv_ready = 1'b1;
	always @(posedge clk)
		if (rst)
			agu_valid <= 1'sb0;
		else if (prv_ready)
			agu_valid <= prv_valid;
	function automatic [cpu_params_ROB_IDX - 1:0] sv2v_cast_70972;
		input reg [cpu_params_ROB_IDX - 1:0] inp;
		sv2v_cast_70972 = inp;
	endfunction
	always @(posedge clk)
		if (rst)
			agu_reg <= {sv2v_cast_70972(1'sbx), 100'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx};
		else if (prv_valid && prv_ready)
			agu_reg <= agu_reg_in;
	wire [31:0] unaligned_addr;
	assign unaligned_addr = agu_reg[63-:32] + agu_reg[95-:32];
	assign nxt_valid = agu_valid;
	wire [((cpu_params_ROB_IDX + 131) >= 132 ? cpu_params_ROB_IDX + 0 : 133 - (cpu_params_ROB_IDX + 131)) * 1:1] sv2v_tmp_850EE;
	assign sv2v_tmp_850EE = agu_reg[cpu_params_ROB_IDX + 99-:((cpu_params_ROB_IDX + 99) >= 100 ? cpu_params_ROB_IDX + 0 : 101 - (cpu_params_ROB_IDX + 99))];
	always @(*) to_lsq[cpu_params_ROB_IDX + 131-:((cpu_params_ROB_IDX + 131) >= 132 ? cpu_params_ROB_IDX + 0 : 133 - (cpu_params_ROB_IDX + 131))] = sv2v_tmp_850EE;
	wire [32:1] sv2v_tmp_8162A;
	assign sv2v_tmp_8162A = unaligned_addr;
	always @(*) to_lsq[131-:32] = sv2v_tmp_8162A;
	wire [32:1] sv2v_tmp_993EE;
	assign sv2v_tmp_993EE = agu_reg[63-:32];
	always @(*) to_lsq[63-:32] = sv2v_tmp_993EE;
	wire [32:1] sv2v_tmp_4946E;
	assign sv2v_tmp_4946E = agu_reg[31-:32];
	always @(*) to_lsq[31-:32] = sv2v_tmp_4946E;
	always @(*) begin
		if (_sv2v_0)
			;
		to_lsq[99-:32] = 1'sbx;
		(* full_case, parallel_case *)
		case (agu_reg[99-:4])
			4'b1000: to_lsq[68 + (8 * unaligned_addr[1:0])+:8] = agu_reg[7:0];
			4'b1001: to_lsq[68 + (16 * unaligned_addr[1])+:16] = agu_reg[15:0];
			4'b1010: to_lsq[99-:32] = agu_reg[31-:32];
			default: to_lsq[99-:32] = 1'sbx;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (agu_reg[99-:4])
			4'b0000, 4'b0100, 4'b1000: to_lsq[67-:4] = 4'b0001 << unaligned_addr[1:0];
			4'b0001, 4'b0101, 4'b1001: to_lsq[67-:4] = 4'b0011 << unaligned_addr[1:0];
			4'b0010, 4'b1010: to_lsq[67-:4] = 4'b1111;
			default: to_lsq[67-:4] = 4'bxxxx;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module plru_update (
	current_plru,
	next_plru,
	hit_way,
	replace_way
);
	reg _sv2v_0;
	parameter NUM_WAYS = 4;
	parameter PLRU_BITS = 3;
	parameter WAY_BITS = 2;
	input wire [PLRU_BITS - 1:0] current_plru;
	output reg [PLRU_BITS - 1:0] next_plru;
	input wire [WAY_BITS - 1:0] hit_way;
	output reg [WAY_BITS - 1:0] replace_way;
	function automatic [WAY_BITS - 1:0] sv2v_cast_91C21;
		input reg [WAY_BITS - 1:0] inp;
		sv2v_cast_91C21 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		replace_way = 1'sb0;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < WAY_BITS; i = i + 1)
				if (current_plru[replace_way])
					replace_way = sv2v_cast_91C21((replace_way * 2) + 1);
				else
					replace_way = sv2v_cast_91C21((replace_way * 2) + 2);
		end
		replace_way = sv2v_cast_91C21(replace_way + 1);
	end
	reg [WAY_BITS:0] visit_bit;
	function automatic [((WAY_BITS + 0) >= 0 ? WAY_BITS + 1 : 1 - (WAY_BITS + 0)) - 1:0] sv2v_cast_E0E81;
		input reg [((WAY_BITS + 0) >= 0 ? WAY_BITS + 1 : 1 - (WAY_BITS + 0)) - 1:0] inp;
		sv2v_cast_E0E81 = inp;
	endfunction
	function automatic signed [((WAY_BITS + 0) >= 0 ? WAY_BITS + 1 : 1 - (WAY_BITS + 0)) - 1:0] sv2v_cast_E0E81_signed;
		input reg signed [((WAY_BITS + 0) >= 0 ? WAY_BITS + 1 : 1 - (WAY_BITS + 0)) - 1:0] inp;
		sv2v_cast_E0E81_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		next_plru = current_plru;
		visit_bit = sv2v_cast_E0E81(hit_way + sv2v_cast_E0E81($unsigned(NUM_WAYS - 1)));
		begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < WAY_BITS; i = i + 1)
				if (visit_bit[0]) begin
					visit_bit = sv2v_cast_E0E81((visit_bit - sv2v_cast_E0E81_signed(1)) / sv2v_cast_E0E81_signed(2));
					next_plru[visit_bit[WAY_BITS - 1:0]] = 1'b0;
				end
				else begin
					visit_bit = sv2v_cast_E0E81((visit_bit - sv2v_cast_E0E81_signed(1)) / sv2v_cast_E0E81_signed(2));
					next_plru[visit_bit[WAY_BITS - 1:0]] = 1'b1;
				end
		end
	end
	initial _sv2v_0 = 0;
endmodule
module skid_buffer_B8AA9_185B4 (
	clk,
	rst,
	prv_valid,
	prv_ready,
	nxt_valid,
	nxt_ready,
	prv_data,
	nxt_data
);
	parameter [0:0] DATA_T_cpu_params_ARF_IDX = 0;
	parameter [0:0] DATA_T_cpu_params_PRF_IDX = 0;
	parameter [0:0] DATA_T_cpu_params_ROB_IDX = 0;
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire prv_valid;
	output reg prv_ready;
	output reg nxt_valid;
	input wire nxt_ready;
	input wire [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_ARF_IDX) + DATA_T_cpu_params_PRF_IDX) + 67:0] prv_data;
	output reg [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_ARF_IDX) + DATA_T_cpu_params_PRF_IDX) + 67:0] nxt_data;
	reg [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_ARF_IDX) + DATA_T_cpu_params_PRF_IDX) + 67:0] buffer;
	reg [2:0] state;
	reg [2:0] state_nxt;
	reg accept;
	reg transmit;
	always @(*) begin
		if (_sv2v_0)
			;
		accept = prv_valid && prv_ready;
		transmit = nxt_valid && nxt_ready;
		state_nxt = 3'b001;
		(* full_case, parallel_case *)
		case (state)
			3'b001: begin
				state_nxt = 3'b001;
				if (accept)
					state_nxt = 3'b010;
			end
			3'b010: begin
				state_nxt = 3'b010;
				if (accept && !transmit)
					state_nxt = 3'b100;
				else if (!accept && transmit)
					state_nxt = 3'b001;
			end
			3'b100: begin
				state_nxt = 3'b100;
				if (transmit)
					state_nxt = 3'b010;
			end
			default: state_nxt = 3'b001;
		endcase
	end
	always @(posedge clk)
		if (rst) begin
			state <= 3'b001;
			prv_ready <= 1'b0;
			nxt_valid <= 1'b0;
		end
		else begin
			state <= state_nxt;
			prv_ready <= state_nxt != 3'b100;
			nxt_valid <= state_nxt != 3'b001;
		end
	reg buf_we;
	reg data_we;
	always @(*) begin
		if (_sv2v_0)
			;
		buf_we = ((state == 3'b010) && accept) && !transmit;
		data_we = ((((state == 3'b001) && accept) && !transmit) || (((state == 3'b010) && accept) && transmit)) || (((state == 3'b100) && !accept) && transmit);
	end
	always @(posedge clk) begin
		if (data_we) begin
			if (state == 3'b100)
				nxt_data <= buffer;
			else
				nxt_data <= prv_data;
		end
		if (buf_we)
			buffer <= prv_data;
	end
	initial _sv2v_0 = 0;
endmodule
module lru_array (
	clk0,
	rst0,
	csb0,
	addr0,
	din0,
	dout0,
	csb1,
	web1,
	addr1,
	din1
);
	reg _sv2v_0;
	parameter S_INDEX = 4;
	parameter WIDTH = 3;
	input wire clk0;
	input wire rst0;
	input wire csb0;
	input wire [S_INDEX - 1:0] addr0;
	input wire [WIDTH - 1:0] din0;
	output reg [WIDTH - 1:0] dout0;
	input wire csb1;
	input wire web1;
	input wire [S_INDEX - 1:0] addr1;
	input wire [WIDTH - 1:0] din1;
	localparam NUM_SETS = 2 ** S_INDEX;
	reg [S_INDEX - 1:0] addr0_reg;
	reg [WIDTH - 1:0] din0_reg;
	reg web1_reg;
	reg [S_INDEX - 1:0] addr1_reg;
	reg [WIDTH - 1:0] din1_reg;
	reg [WIDTH - 1:0] internal_array [0:NUM_SETS - 1];
	always @(posedge clk0)
		if (rst0) begin
			addr0_reg <= 1'sbx;
			din0_reg <= 1'sbx;
			web1_reg <= 1'b1;
			addr1_reg <= 1'sbx;
			din1_reg <= 1'sbx;
		end
		else begin
			if (!csb0) begin
				addr0_reg <= addr0;
				din0_reg <= din0;
			end
			if (!csb1) begin
				web1_reg <= web1;
				addr1_reg <= addr1;
				din1_reg <= din1;
			end
		end
	always @(posedge clk0)
		if (rst0) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_SETS; i = i + 1)
				internal_array[i] <= 1'sb0;
		end
		else if (!web1_reg)
			internal_array[addr1_reg] <= din1_reg;
	always @(*) begin
		if (_sv2v_0)
			;
		dout0 = ((addr0_reg == addr1_reg) && ~web1_reg ? din1_reg : internal_array[addr0_reg]);
	end
	initial _sv2v_0 = 0;
endmodule
module valid_array (
	clk0,
	rst0,
	csb0,
	web0,
	addr0,
	din0,
	dout0
);
	reg _sv2v_0;
	parameter S_INDEX = 4;
	parameter WIDTH = 1;
	input wire clk0;
	input wire rst0;
	input wire csb0;
	input wire web0;
	input wire [S_INDEX - 1:0] addr0;
	input wire [WIDTH - 1:0] din0;
	output reg [WIDTH - 1:0] dout0;
	localparam NUM_SETS = 2 ** S_INDEX;
	reg web0_reg;
	reg [S_INDEX - 1:0] addr0_reg;
	reg [WIDTH - 1:0] din0_reg;
	reg [WIDTH - 1:0] internal_array [0:NUM_SETS - 1];
	always @(posedge clk0)
		if (rst0) begin
			web0_reg <= 1'b1;
			addr0_reg <= 1'sbx;
			din0_reg <= 1'sbx;
		end
		else if (!csb0) begin
			web0_reg <= web0;
			addr0_reg <= addr0;
			din0_reg <= din0;
		end
	always @(posedge clk0)
		if (rst0) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_SETS; i = i + 1)
				internal_array[i] <= 1'sb0;
		end
		else if (!web0_reg)
			internal_array[addr0_reg] <= din0_reg;
	always @(*) begin
		if (_sv2v_0)
			;
		dout0 = internal_array[addr0_reg];
	end
	initial _sv2v_0 = 0;
endmodule
module one_hot_mux_3CA04_C50D1 (
	data_in,
	select,
	data_out
);
	parameter [0:0] T_cpu_params_ARF_IDX = 0;
	parameter [0:0] T_cpu_params_PRF_IDX = 0;
	parameter [0:0] T_cpu_params_ROB_IDX = 0;
	reg _sv2v_0;
	parameter NUM_INPUTS = 4;
	input wire [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) >= 0 ? (NUM_INPUTS * (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 101)) - 1 : (NUM_INPUTS * (1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100))) + (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 99)):((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) >= 0 ? 0 : ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100)] data_in;
	input wire [NUM_INPUTS - 1:0] select;
	output reg [((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100:0] data_out;
	function automatic [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 101 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100)) - 1:0] sv2v_cast_1AA73;
		input reg [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 101 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100)) - 1:0] inp;
		sv2v_cast_1AA73 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		data_out = sv2v_cast_1AA73(1'sb0);
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_INPUTS; i = i + 1)
				if (select[i])
					data_out = data_out | data_in[((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) >= 0 ? 0 : ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) + (i * ((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 101 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100)))+:((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 101 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 100))];
		end
	end
	initial _sv2v_0 = 0;
endmodule
module one_hot_mux_602F0_CCEF1 (
	data_in,
	select,
	data_out
);
	parameter [0:0] T_cpu_params_CDB_WIDTH = 0;
	parameter [0:0] T_cpu_params_INT_ISSUE_IDX = 0;
	reg _sv2v_0;
	parameter NUM_INPUTS = 4;
	input wire [(NUM_INPUTS * ((((T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH) + (T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH)) + T_cpu_params_INT_ISSUE_IDX) + T_cpu_params_INT_ISSUE_IDX)) - 1:0] data_in;
	input wire [NUM_INPUTS - 1:0] select;
	output reg [((((T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH) + (T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH)) + T_cpu_params_INT_ISSUE_IDX) + T_cpu_params_INT_ISSUE_IDX) - 1:0] data_out;
	function automatic [((((T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH) + (T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH)) + T_cpu_params_INT_ISSUE_IDX) + T_cpu_params_INT_ISSUE_IDX) - 1:0] sv2v_cast_F8051;
		input reg [((((T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH) + (T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH)) + T_cpu_params_INT_ISSUE_IDX) + T_cpu_params_INT_ISSUE_IDX) - 1:0] inp;
		sv2v_cast_F8051 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		data_out = sv2v_cast_F8051(1'sb0);
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_INPUTS; i = i + 1)
				if (select[i])
					data_out = data_out | data_in[i * ((((T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH) + (T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH)) + T_cpu_params_INT_ISSUE_IDX) + T_cpu_params_INT_ISSUE_IDX)+:(((T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH) + (T_cpu_params_CDB_WIDTH >= 0 ? T_cpu_params_CDB_WIDTH + 1 : 1 - T_cpu_params_CDB_WIDTH)) + T_cpu_params_INT_ISSUE_IDX) + T_cpu_params_INT_ISSUE_IDX];
		end
	end
	initial _sv2v_0 = 0;
endmodule
module one_hot_mux_6420F_858A2 (
	data_in,
	select,
	data_out
);
	parameter [0:0] T_cpu_params_ARF_IDX = 0;
	parameter [0:0] T_cpu_params_PRF_IDX = 0;
	parameter [0:0] T_cpu_params_ROB_IDX = 0;
	reg _sv2v_0;
	parameter NUM_INPUTS = 4;
	input wire [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) >= 0 ? (NUM_INPUTS * (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 4)) - 1 : (NUM_INPUTS * (1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3))) + (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 2)):((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3)] data_in;
	input wire [NUM_INPUTS - 1:0] select;
	output reg [((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3:0] data_out;
	function automatic [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 4 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3)) - 1:0] sv2v_cast_99FC9;
		input reg [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 4 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3)) - 1:0] inp;
		sv2v_cast_99FC9 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		data_out = sv2v_cast_99FC9(1'sb0);
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_INPUTS; i = i + 1)
				if (select[i])
					data_out = data_out | data_in[((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) >= 0 ? 0 : ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) + (i * ((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 4 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3)))+:((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 4 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 3))];
		end
	end
	initial _sv2v_0 = 0;
endmodule
module one_hot_mux_921A8_BE200 (
	data_in,
	select,
	data_out
);
	parameter [0:0] T_cpu_params_PRF_IDX = 0;
	parameter [0:0] T_cpu_params_ROB_IDX = 0;
	reg _sv2v_0;
	parameter NUM_INPUTS = 4;
	input wire [(((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) >= 0 ? (NUM_INPUTS * ((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 37)) - 1 : (NUM_INPUTS * (1 - ((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36))) + ((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 35)):(((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) >= 0 ? 0 : (((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36)] data_in;
	input wire [NUM_INPUTS - 1:0] select;
	output reg [(((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36:0] data_out;
	function automatic [(((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) >= 0 ? (((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 37 : 1 - ((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36)) - 1:0] sv2v_cast_FC416;
		input reg [(((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) >= 0 ? (((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 37 : 1 - ((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36)) - 1:0] inp;
		sv2v_cast_FC416 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		data_out = sv2v_cast_FC416(1'sb0);
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_INPUTS; i = i + 1)
				if (select[i])
					data_out = data_out | data_in[(((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) >= 0 ? 0 : (((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) + (i * (((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) >= 0 ? (((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 37 : 1 - ((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36)))+:(((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36) >= 0 ? (((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 37 : 1 - ((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 36))];
		end
	end
	initial _sv2v_0 = 0;
endmodule
module one_hot_mux_A9A2C_2CF1C (
	data_in,
	select,
	data_out
);
	parameter [0:0] T_cpu_params_ARF_IDX = 0;
	parameter [0:0] T_cpu_params_PRF_IDX = 0;
	parameter [0:0] T_cpu_params_ROB_IDX = 0;
	reg _sv2v_0;
	parameter NUM_INPUTS = 4;
	input wire [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) >= 0 ? (NUM_INPUTS * (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 38)) - 1 : (NUM_INPUTS * (1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37))) + (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 36)):((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37)] data_in;
	input wire [NUM_INPUTS - 1:0] select;
	output reg [((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37:0] data_out;
	function automatic [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 38 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37)) - 1:0] sv2v_cast_6D53B;
		input reg [((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 38 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37)) - 1:0] inp;
		sv2v_cast_6D53B = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		data_out = sv2v_cast_6D53B(1'sb0);
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_INPUTS; i = i + 1)
				if (select[i])
					data_out = data_out | data_in[((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) >= 0 ? 0 : ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) + (i * ((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 38 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37)))+:((((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37) >= 0 ? ((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 38 : 1 - (((((((T_cpu_params_ROB_IDX + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + 1) + T_cpu_params_PRF_IDX) + T_cpu_params_ARF_IDX) + 37))];
		end
	end
	initial _sv2v_0 = 0;
endmodule
module pipeline_reg_A3B61_DD976 (
	clk,
	rst,
	flush,
	prv_valid,
	prv_ready,
	nxt_valid,
	nxt_ready,
	prv_data,
	nxt_data
);
	parameter [0:0] DATA_T_cpu_params_ARF_IDX = 0;
	parameter [0:0] DATA_T_cpu_params_PRF_IDX = 0;
	parameter [0:0] DATA_T_cpu_params_ROB_IDX = 0;
	input wire clk;
	input wire rst;
	input wire flush;
	input wire prv_valid;
	output wire prv_ready;
	output wire nxt_valid;
	input wire nxt_ready;
	input wire [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_PRF_IDX) + DATA_T_cpu_params_ARF_IDX) + 31:0] prv_data;
	output wire [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_PRF_IDX) + DATA_T_cpu_params_ARF_IDX) + 31:0] nxt_data;
	reg reg_valid;
	reg [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_PRF_IDX) + DATA_T_cpu_params_ARF_IDX) + 31:0] reg_data;
	assign nxt_valid = reg_valid;
	assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);
	always @(posedge clk)
		if (rst || flush)
			reg_valid <= 1'sb0;
		else if (prv_ready)
			reg_valid <= prv_valid;
	always @(posedge clk)
		if (prv_ready && prv_valid)
			reg_data <= prv_data;
	assign nxt_data = reg_data;
endmodule
module pipeline_reg_DE194 (
	clk,
	rst,
	flush,
	prv_valid,
	prv_ready,
	nxt_valid,
	nxt_ready,
	prv_data,
	nxt_data
);
	input wire clk;
	input wire rst;
	input wire flush;
	input wire prv_valid;
	output wire prv_ready;
	output wire nxt_valid;
	input wire nxt_ready;
	input wire [131:0] prv_data;
	output wire [131:0] nxt_data;
	reg reg_valid;
	reg [131:0] reg_data;
	assign nxt_valid = reg_valid;
	assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);
	always @(posedge clk)
		if (rst || flush)
			reg_valid <= 1'sb0;
		else if (prv_ready)
			reg_valid <= prv_valid;
	always @(posedge clk)
		if (prv_ready && prv_valid)
			reg_data <= prv_data;
	assign nxt_data = reg_data;
endmodule
module pipeline_reg_E6238_A4C6B (
	clk,
	rst,
	flush,
	prv_valid,
	prv_ready,
	nxt_valid,
	nxt_ready,
	prv_data,
	nxt_data
);
	parameter [0:0] DATA_T_cpu_params_ARF_IDX = 0;
	parameter [0:0] DATA_T_cpu_params_PRF_IDX = 0;
	parameter [0:0] DATA_T_cpu_params_ROB_IDX = 0;
	input wire clk;
	input wire rst;
	input wire flush;
	input wire prv_valid;
	output wire prv_ready;
	output wire nxt_valid;
	input wire nxt_ready;
	input wire [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_ARF_IDX) + DATA_T_cpu_params_PRF_IDX) + 95:0] prv_data;
	output wire [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_ARF_IDX) + DATA_T_cpu_params_PRF_IDX) + 95:0] nxt_data;
	reg reg_valid;
	reg [((DATA_T_cpu_params_ROB_IDX + DATA_T_cpu_params_ARF_IDX) + DATA_T_cpu_params_PRF_IDX) + 95:0] reg_data;
	assign nxt_valid = reg_valid;
	assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);
	always @(posedge clk)
		if (rst || flush)
			reg_valid <= 1'sb0;
		else if (prv_ready)
			reg_valid <= prv_valid;
	always @(posedge clk)
		if (prv_ready && prv_valid)
			reg_data <= prv_data;
	assign nxt_data = reg_data;
endmodule
module issue_arbiter (
	rs_request,
	rs_grant,
	rs_compress,
	fu_issue
);
	reg _sv2v_0;
	localparam cpu_params_INTRS_DEPTH = 8;
	input wire [cpu_params_INTRS_DEPTH - 1:0] rs_request;
	output reg [cpu_params_INTRS_DEPTH - 1:0] rs_grant;
	localparam cpu_params_INT_ISSUE_WIDTH = 2;
	output reg [(cpu_params_INTRS_DEPTH * cpu_params_INT_ISSUE_WIDTH) - 1:0] rs_compress;
	output reg [(cpu_params_INT_ISSUE_WIDTH * cpu_params_INTRS_DEPTH) - 1:0] fu_issue;
	reg [cpu_params_INT_ISSUE_WIDTH - 1:0] prev_assigned [0:cpu_params_INTRS_DEPTH - 1];
	always @(*) begin
		if (_sv2v_0)
			;
		rs_grant = 1'sb0;
		fu_issue[(cpu_params_INT_ISSUE_WIDTH - 1) * cpu_params_INTRS_DEPTH+:cpu_params_INTRS_DEPTH] = 1'sb0;
		fu_issue[(cpu_params_INT_ISSUE_WIDTH - 2) * cpu_params_INTRS_DEPTH+:cpu_params_INTRS_DEPTH] = 1'sb0;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
				begin
					prev_assigned[i][0] = 1'sb0;
					prev_assigned[i][1] = 1'sb0;
					begin : sv2v_autoblock_2
						reg signed [31:0] j;
						for (j = 0; j < i; j = j + 1)
							begin
								if (rs_request[j])
									prev_assigned[i][0] = 1'sb1;
								if (rs_request[j] & prev_assigned[j][0])
									prev_assigned[i][1] = 1'sb1;
							end
					end
					if (~prev_assigned[i][0] & rs_request[i]) begin
						rs_grant[i] = 1'sb1;
						fu_issue[((cpu_params_INT_ISSUE_WIDTH - 1) * cpu_params_INTRS_DEPTH) + i] = 1'sb1;
					end
					else if (~prev_assigned[i][1] & rs_request[i]) begin
						rs_grant[i] = 1'sb1;
						fu_issue[((cpu_params_INT_ISSUE_WIDTH - 2) * cpu_params_INTRS_DEPTH) + i] = 1'sb1;
					end
				end
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_3
			reg signed [31:0] i;
			for (i = 0; i < cpu_params_INTRS_DEPTH; i = i + 1)
				(* full_case, parallel_case *)
				case (prev_assigned[i])
					2'b00: rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH] = (rs_grant[i] ? 2'b01 : 2'b00);
					2'b01: rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH] = (rs_grant[i] ? 2'b10 : 2'b01);
					2'b11: rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH] = 2'b10;
					default: rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH] = 1'sbx;
				endcase
		end
		begin : sv2v_autoblock_4
			reg signed [31:0] i;
			for (i = 0; i < (cpu_params_INTRS_DEPTH - 1); i = i + 1)
				if ((rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH] != 2'b00) && rs_grant[i + 1])
					rs_compress[((cpu_params_INTRS_DEPTH - 1) - i) * cpu_params_INT_ISSUE_WIDTH+:cpu_params_INT_ISSUE_WIDTH] = 2'b10;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module fu_div (
	clk,
	rst,
	prv_valid,
	prv_ready,
	nxt_valid,
	nxt_ready,
	iss_in,
	cdb_out
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire prv_valid;
	output wire prv_ready;
	output wire nxt_valid;
	input wire nxt_ready;
	localparam cpu_params_ARF_DEPTH = 32;
	localparam cpu_params_ARF_IDX = $clog2(1'd0);
	localparam cpu_params_PRF_DEPTH = 64;
	localparam cpu_params_PRF_IDX = $clog2(1'd0);
	localparam cpu_params_ID_WIDTH = 2;
	localparam cpu_params_ROB_DEPTH = 32;
	localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
	input wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] iss_in;
	output wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_out;
	localparam DATA_WIDTH = 32;
	localparam A_WIDTH = 33;
	localparam B_WIDTH = 33;
	wire div_start;
	reg [32:0] a;
	reg [32:0] b;
	wire [32:0] quotient;
	wire [32:0] remainder;
	wire divide_by_0;
	wire complete;
	reg [31:0] outcome;
	wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] intm_rs_reg;
	wire [DATA_WIDTH:0] au;
	wire [DATA_WIDTH:0] bu;
	wire [DATA_WIDTH:0] as;
	wire [DATA_WIDTH:0] bs;
	wire reg_valid;
	reg prv_reg_valid;
	wire reg_start;
	wire divider_ready;
	reg prv_divider_ready;
	skid_buffer_B8AA9_185B4 #(
		.DATA_T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
		.DATA_T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
		.DATA_T_cpu_params_ROB_IDX(cpu_params_ROB_IDX)
	) cdb_reg(
		.clk(clk),
		.rst(rst),
		.prv_valid(prv_valid),
		.prv_ready(prv_ready),
		.nxt_valid(reg_valid),
		.nxt_ready(divider_ready),
		.prv_data(iss_in),
		.nxt_data(intm_rs_reg)
	);
	always @(posedge clk) prv_reg_valid <= reg_valid;
	always @(posedge clk) prv_divider_ready <= divider_ready;
	assign div_start = (reg_valid && ~prv_reg_valid) || (reg_valid && prv_divider_ready);
	assign divider_ready = nxt_valid && nxt_ready;
	assign au = {1'b0, intm_rs_reg[63-:32]};
	assign bu = {1'b0, intm_rs_reg[31-:32]};
	assign as = {intm_rs_reg[63], intm_rs_reg[63-:32]};
	assign bs = {intm_rs_reg[31], intm_rs_reg[31-:32]};
	always @(*) begin
		if (_sv2v_0)
			;
		a = 1'sb0;
		b = 1'sb0;
		outcome = 1'sbx;
		(* full_case, parallel_case *)
		case (intm_rs_reg[67-:4])
			4'b0100: begin
				a = as;
				b = bs;
				outcome = quotient[31:0];
				if (divide_by_0)
					outcome = 1'sb1;
			end
			4'b0101: begin
				a = au;
				b = bu;
				outcome = quotient[31:0];
				if (divide_by_0)
					outcome = 1'sb1;
			end
			4'b0110: begin
				a = as;
				b = bs;
				outcome = remainder[31:0];
				if (divide_by_0)
					outcome = intm_rs_reg[63-:32];
			end
			4'b0111: begin
				a = au;
				b = bu;
				outcome = remainder[31:0];
				if (divide_by_0)
					outcome = intm_rs_reg[63-:32];
			end
			default:
				;
		endcase
	end
	localparam NUM_CYC_DIV = 12;
	localparam TC_MODE = 1;
	localparam RST_MODE = 1;
	localparam INPUT_MODE = 0;
	localparam OUTPUT_MODE = 0;
	localparam EARLY_START = 0;
	DW_div_seq #(
		A_WIDTH,
		B_WIDTH,
		TC_MODE,
		NUM_CYC_DIV,
		RST_MODE,
		INPUT_MODE,
		OUTPUT_MODE,
		EARLY_START
	) divider(
		.clk(clk),
		.rst_n(~rst),
		.hold(1'sb0),
		.start(div_start),
		.a(a),
		.b(b),
		.complete(complete),
		.divide_by_0(divide_by_0),
		.quotient(quotient),
		.remainder(remainder)
	);
	assign nxt_valid = (reg_valid && complete) && ~div_start;
	assign cdb_out[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)] = intm_rs_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)))) + 1)];
	assign cdb_out[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)] = intm_rs_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) >= (cpu_params_PRF_IDX + 68) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) - (cpu_params_PRF_IDX + 68)) + 1 : ((cpu_params_PRF_IDX + 68) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) + 1)];
	assign cdb_out[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))] = intm_rs_reg[cpu_params_PRF_IDX + 67-:((cpu_params_PRF_IDX + 67) >= 68 ? cpu_params_PRF_IDX + 0 : 69 - (cpu_params_PRF_IDX + 67))];
	assign cdb_out[95-:32] = outcome;
	assign cdb_out[63-:32] = intm_rs_reg[63-:32];
	assign cdb_out[31-:32] = intm_rs_reg[31-:32];
	initial _sv2v_0 = 0;
endmodule
module fu_div_dual (
	clk,
	rst,
	prv_valid,
	prv_ready,
	nxt_valid,
	iss_in,
	cdb_out
);
	input wire clk;
	input wire rst;
	input wire prv_valid;
	output wire prv_ready;
	output wire nxt_valid;
	localparam cpu_params_ARF_DEPTH = 32;
	localparam cpu_params_ARF_IDX = $clog2(1'd0);
	localparam cpu_params_PRF_DEPTH = 64;
	localparam cpu_params_PRF_IDX = $clog2(1'd0);
	localparam cpu_params_ID_WIDTH = 2;
	localparam cpu_params_ROB_DEPTH = 32;
	localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
	input wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] iss_in;
	output wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_out;
	wire fu_div1_valid;
	wire fu_div2_valid;
	wire fu_div1_ready;
	wire fu_div2_ready;
	wire cdb_div1_valid;
	wire cdb_div2_valid;
	wire cdb_div1_ready;
	wire cdb_div2_ready;
	wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_div1_out;
	wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_div2_out;
	assign fu_div1_valid = prv_valid;
	assign fu_div2_valid = prv_valid && ~fu_div1_ready;
	assign prv_ready = fu_div1_ready || fu_div2_ready;
	fu_div fu_div_1_i(
		.clk(clk),
		.rst(rst),
		.prv_valid(fu_div1_valid),
		.prv_ready(fu_div1_ready),
		.nxt_valid(cdb_div1_valid),
		.nxt_ready(cdb_div1_ready),
		.iss_in(iss_in),
		.cdb_out(cdb_div1_out)
	);
	fu_div fu_div_2_i(
		.clk(clk),
		.rst(rst),
		.prv_valid(fu_div2_valid),
		.prv_ready(fu_div2_ready),
		.nxt_valid(cdb_div2_valid),
		.nxt_ready(cdb_div2_ready),
		.iss_in(iss_in),
		.cdb_out(cdb_div2_out)
	);
	assign nxt_valid = cdb_div1_valid || cdb_div2_valid;
	assign cdb_out = (cdb_div1_valid ? cdb_div1_out : cdb_div2_out);
	assign cdb_div1_ready = 1'b1;
	assign cdb_div2_ready = ~cdb_div1_valid;
endmodule
module fu_mul (
	clk,
	rst,
	prv_valid,
	prv_ready,
	nxt_valid,
	nxt_ready,
	iss_in,
	cdb_out
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire prv_valid;
	output wire prv_ready;
	output wire nxt_valid;
	input wire nxt_ready;
	localparam cpu_params_ARF_DEPTH = 32;
	localparam cpu_params_ARF_IDX = $clog2(1'd0);
	localparam cpu_params_PRF_DEPTH = 64;
	localparam cpu_params_PRF_IDX = $clog2(1'd0);
	localparam cpu_params_ID_WIDTH = 2;
	localparam cpu_params_ROB_DEPTH = 32;
	localparam cpu_params_ROB_IDX = $clog2(1'd0 * 1'd0);
	input wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] iss_in;
	output wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 95:0] cdb_out;
	localparam DATA_WIDTH = 32;
	localparam A_WIDTH = 33;
	localparam B_WIDTH = 33;
	wire mul_start;
	reg [32:0] a;
	reg [32:0] b;
	wire [65:0] product;
	wire complete;
	reg [31:0] outcome;
	wire [((cpu_params_ROB_IDX + cpu_params_ARF_IDX) + cpu_params_PRF_IDX) + 67:0] intm_rs_reg;
	wire [DATA_WIDTH:0] au;
	wire [DATA_WIDTH:0] bu;
	wire [DATA_WIDTH:0] as;
	wire [DATA_WIDTH:0] bs;
	wire reg_valid;
	reg prv_reg_valid;
	wire reg_start;
	wire mul_ready;
	reg prv_mul_ready;
	skid_buffer_B8AA9_185B4 #(
		.DATA_T_cpu_params_ARF_IDX(cpu_params_ARF_IDX),
		.DATA_T_cpu_params_PRF_IDX(cpu_params_PRF_IDX),
		.DATA_T_cpu_params_ROB_IDX(cpu_params_ROB_IDX)
	) cdb_reg(
		.clk(clk),
		.rst(rst),
		.prv_valid(prv_valid),
		.prv_ready(prv_ready),
		.nxt_valid(reg_valid),
		.nxt_ready(mul_ready),
		.prv_data(iss_in),
		.nxt_data(intm_rs_reg)
	);
	always @(posedge clk) prv_reg_valid <= reg_valid;
	always @(posedge clk) prv_mul_ready <= mul_ready;
	assign mul_start = (reg_valid && ~prv_reg_valid) || (reg_valid && prv_mul_ready);
	assign mul_ready = nxt_valid && nxt_ready;
	assign au = {1'b0, intm_rs_reg[63-:32]};
	assign bu = {1'b0, intm_rs_reg[31-:32]};
	assign as = {intm_rs_reg[63], intm_rs_reg[63-:32]};
	assign bs = {intm_rs_reg[31], intm_rs_reg[31-:32]};
	always @(*) begin
		if (_sv2v_0)
			;
		a = 1'sb0;
		b = 1'sb0;
		outcome = 1'sbx;
		(* full_case, parallel_case *)
		case (intm_rs_reg[67-:4])
			4'b0000: begin
				a = as;
				b = bs;
				outcome = product[31:0];
			end
			4'b0001: begin
				a = as;
				b = bs;
				outcome = product[63:DATA_WIDTH];
			end
			4'b0010: begin
				a = as;
				b = bu;
				outcome = product[63:DATA_WIDTH];
			end
			4'b0011: begin
				a = au;
				b = bu;
				outcome = product[63:DATA_WIDTH];
			end
			default:
				;
		endcase
	end
	localparam NUM_CYC_MUL = 3;
	localparam TC_MODE = 1;
	localparam RST_MODE = 1;
	localparam INPUT_MODE = 0;
	localparam OUTPUT_MODE = 0;
	localparam EARLY_START = 0;
	DW_mult_seq #(
		A_WIDTH,
		B_WIDTH,
		TC_MODE,
		NUM_CYC_MUL,
		RST_MODE,
		INPUT_MODE,
		OUTPUT_MODE,
		EARLY_START
	) signed_mul(
		.clk(clk),
		.rst_n(~rst),
		.hold(1'sb0),
		.start(mul_start),
		.a(a),
		.b(b),
		.complete(complete),
		.product(product)
	);
	assign nxt_valid = (reg_valid && complete) && ~mul_start;
	assign cdb_out[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 96)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)))) + 1)] = intm_rs_reg[cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))-:((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) >= (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) ? ((cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68))) + 1 : ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 68)) - (cpu_params_ROB_IDX + (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)))) + 1)];
	assign cdb_out[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) >= (cpu_params_PRF_IDX + 96) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95)) - (cpu_params_PRF_IDX + 96)) + 1 : ((cpu_params_PRF_IDX + 96) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 95))) + 1)] = intm_rs_reg[cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)-:((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) >= (cpu_params_PRF_IDX + 68) ? ((cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67)) - (cpu_params_PRF_IDX + 68)) + 1 : ((cpu_params_PRF_IDX + 68) - (cpu_params_ARF_IDX + (cpu_params_PRF_IDX + 67))) + 1)];
	assign cdb_out[cpu_params_PRF_IDX + 95-:((cpu_params_PRF_IDX + 95) >= 96 ? cpu_params_PRF_IDX + 0 : 97 - (cpu_params_PRF_IDX + 95))] = intm_rs_reg[cpu_params_PRF_IDX + 67-:((cpu_params_PRF_IDX + 67) >= 68 ? cpu_params_PRF_IDX + 0 : 69 - (cpu_params_PRF_IDX + 67))];
	assign cdb_out[95-:32] = outcome;
	assign cdb_out[63-:32] = intm_rs_reg[63-:32];
	assign cdb_out[31-:32] = intm_rs_reg[31-:32];
	initial _sv2v_0 = 0;
endmodule
module decoder (
	inst,
	rs_type,
	fu_type,
	fu_opcode,
	op1_sel,
	op2_sel,
	imm,
	rd_arch,
	rd_en,
	rs1_arch,
	rs2_arch,
	is_store
);
	reg _sv2v_0;
	input wire [31:0] inst;
	output reg [1:0] rs_type;
	output reg [1:0] fu_type;
	output reg [3:0] fu_opcode;
	output reg [0:0] op1_sel;
	output reg [0:0] op2_sel;
	output reg [31:0] imm;
	localparam cpu_params_ARF_DEPTH = 32;
	localparam cpu_params_ARF_IDX = $clog2(1'd0);
	output wire [cpu_params_ARF_IDX - 1:0] rd_arch;
	output wire rd_en;
	output wire [cpu_params_ARF_IDX - 1:0] rs1_arch;
	output wire [cpu_params_ARF_IDX - 1:0] rs2_arch;
	output wire is_store;
	wire [6:0] opcode;
	wire [2:0] funct3;
	wire [6:0] funct7;
	assign opcode = inst[6:0];
	assign funct3 = inst[14:12];
	assign funct7 = inst[31:25];
	assign rd_en = |{opcode == 7'b0110111, opcode == 7'b0010111, opcode == 7'b0010011, opcode == 7'b0110011, opcode == 7'b1101111, opcode == 7'b1100111, opcode == 7'b0000011};
	assign rd_arch = (rd_en ? inst[11:7] : {cpu_params_ARF_IDX {1'sb0}});
	assign rs1_arch = (|{opcode == 7'b0010011, opcode == 7'b0110011, opcode == 7'b1100111, opcode == 7'b1100011, opcode == 7'b0000011, opcode == 7'b0100011} ? inst[19:15] : {cpu_params_ARF_IDX {1'sb0}});
	assign rs2_arch = (|{opcode == 7'b0110011, opcode == 7'b1100011, opcode == 7'b0100011} ? inst[24:20] : {cpu_params_ARF_IDX {1'sb0}});
	assign is_store = opcode == 7'b0100011;
	always @(*) begin
		if (_sv2v_0)
			;
		rs_type = 2'b00;
		fu_type = 2'b00;
		fu_opcode = 1'sb0;
		op1_sel = 1'b0;
		op2_sel = 1'b0;
		(* full_case, parallel_case *)
		case (opcode)
			7'b0110111: begin
				rs_type = 2'b00;
				fu_type = 2'b00;
				op1_sel = 1'b1;
				op2_sel = 1'b1;
				fu_opcode = 4'b0000;
			end
			7'b0010111: begin
				rs_type = 2'b10;
				fu_type = 2'b10;
				fu_opcode = 4'b1111;
			end
			7'b1101111: begin
				rs_type = 2'b10;
				fu_type = 2'b10;
				fu_opcode = 4'b1000;
			end
			7'b1100111: begin
				rs_type = 2'b10;
				fu_type = 2'b10;
				fu_opcode = 4'b1001;
			end
			7'b1100011: begin
				rs_type = 2'b10;
				fu_type = 2'b10;
				fu_opcode = {1'b0, funct3};
			end
			7'b0000011: begin
				rs_type = 2'b11;
				fu_type = 2'b11;
				fu_opcode = {1'b0, funct3};
			end
			7'b0100011: begin
				rs_type = 2'b11;
				fu_type = 2'b11;
				fu_opcode = {1'b1, funct3};
			end
			7'b0010011: begin
				rs_type = 2'b00;
				fu_type = 2'b00;
				op1_sel = 1'b0;
				op2_sel = 1'b1;
				(* full_case, parallel_case *)
				case (funct3)
					3'b010: fu_opcode = 4'b1000;
					3'b011: fu_opcode = 4'b1001;
					3'b101: fu_opcode = (funct7[5] ? 4'b0010 : 4'b0101);
					default: fu_opcode = {1'b0, funct3};
				endcase
			end
			7'b0110011: begin
				op1_sel = 1'b0;
				op2_sel = 1'b0;
				if (funct7[0]) begin
					rs_type = 2'b01;
					fu_type = 2'b01;
					fu_opcode = {1'b0, funct3};
				end
				else begin
					rs_type = 2'b00;
					fu_type = 2'b00;
					(* full_case, parallel_case *)
					case (funct3)
						3'b010: fu_opcode = 4'b1000;
						3'b011: fu_opcode = 4'b1001;
						3'b101: fu_opcode = (funct7[5] ? 4'b0010 : 4'b0101);
						3'b000: fu_opcode = (funct7[5] ? 4'b0011 : 4'b0000);
						default: fu_opcode = {1'b0, funct3};
					endcase
				end
			end
			default:
				;
		endcase
	end
	wire [31:0] i_imm;
	wire [31:0] s_imm;
	wire [31:0] b_imm;
	wire [31:0] u_imm;
	wire [31:0] j_imm;
	assign i_imm = {{21 {inst[31]}}, inst[30:20]};
	assign s_imm = {{21 {inst[31]}}, inst[30:25], inst[11:7]};
	assign b_imm = {{20 {inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
	assign u_imm = {inst[31:12], 12'h000};
	assign j_imm = {{12 {inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (opcode)
			7'b1100111, 7'b0010011, 7'b0000011: imm = i_imm;
			7'b0100011: imm = s_imm;
			7'b1100011: imm = b_imm;
			7'b0110111, 7'b0010111: imm = u_imm;
			7'b1101111: imm = j_imm;
			default: imm = 1'sbx;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module icache_ctrl (
	clk,
	rst,
	kill,
	read,
	tag,
	set,
	tag_arr_out,
	valid_arr_out,
	stall,
	allocate_done,
	hit_way,
	dfp_addr,
	dfp_read,
	dfp_write,
	dfp_ready,
	dfp_raddr,
	dfp_rvalid
);
	reg _sv2v_0;
	parameter TAG_IDX = 23;
	parameter NUM_WAYS = 4;
	parameter WAY_BITS = 2;
	parameter OFFSET_IDX = 5;
	parameter SET_IDX = 5;
	input wire clk;
	input wire rst;
	input wire kill;
	input wire read;
	input wire [TAG_IDX - 1:0] tag;
	input wire [SET_IDX - 1:0] set;
	input wire [(TAG_IDX >= 0 ? (NUM_WAYS * (TAG_IDX + 1)) - 1 : (NUM_WAYS * (1 - TAG_IDX)) + (TAG_IDX - 1)):(TAG_IDX >= 0 ? 0 : TAG_IDX + 0)] tag_arr_out;
	input wire [0:NUM_WAYS - 1] valid_arr_out;
	output wire stall;
	output reg allocate_done;
	output reg [WAY_BITS - 1:0] hit_way;
	output wire [31:0] dfp_addr;
	output reg dfp_read;
	output wire dfp_write;
	input wire dfp_ready;
	input wire [31:0] dfp_raddr;
	input wire dfp_rvalid;
	reg [1:0] state;
	reg [1:0] next_state;
	reg hit;
	always @(posedge clk)
		if (rst)
			state <= 2'b00;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		dfp_read = 1'b0;
		allocate_done = 1'b0;
		(* full_case, parallel_case *)
		case (state)
			2'b00:
				if (kill)
					next_state = 2'b00;
				else if (read) begin
					if (~hit) begin
						dfp_read = 1'b1;
						if (dfp_ready)
							next_state = 2'b01;
					end
				end
			2'b01:
				if (kill)
					next_state = 2'b00;
				else if (dfp_rvalid && (dfp_addr == dfp_raddr)) begin
					next_state = 2'b10;
					allocate_done = 1'b1;
				end
			2'b10: next_state = 2'b00;
			default:
				;
		endcase
	end
	assign stall = read && ~hit;
	function automatic [WAY_BITS - 1:0] sv2v_cast_91C21;
		input reg [WAY_BITS - 1:0] inp;
		sv2v_cast_91C21 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		hit = 1'b0;
		hit_way = 1'sbx;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NUM_WAYS; i = i + 1)
				if ((tag_arr_out[(TAG_IDX >= 0 ? (((NUM_WAYS - 1) - i) * (TAG_IDX >= 0 ? TAG_IDX + 1 : 1 - TAG_IDX)) + (TAG_IDX >= 0 ? 22 : TAG_IDX - 22) : ((((NUM_WAYS - 1) - i) * (TAG_IDX >= 0 ? TAG_IDX + 1 : 1 - TAG_IDX)) + (TAG_IDX >= 0 ? 22 : TAG_IDX - 22)) + 22)-:23] == tag) && valid_arr_out[i]) begin
					hit = 1'b1;
					hit_way = sv2v_cast_91C21($unsigned(i));
				end
		end
	end
	assign dfp_write = 1'b0;
	assign dfp_addr = {tag, set, {OFFSET_IDX {1'b0}}};
	initial _sv2v_0 = 0;
endmodule
module icache_tag_array (
	clk0,
	csb0,
	web0,
	addr0,
	din0,
	dout0
);
	parameter DATA_WIDTH = 24;
	parameter ADDR_WIDTH = 4;
	parameter RAM_DEPTH = 1 << ADDR_WIDTH;
	input clk0;
	input csb0;
	input web0;
	input [ADDR_WIDTH - 1:0] addr0;
	input [DATA_WIDTH - 1:0] din0;
	output reg [DATA_WIDTH - 1:0] dout0;
	reg [DATA_WIDTH - 1:0] mem [0:RAM_DEPTH - 1];
	reg web0_reg;
	reg [ADDR_WIDTH - 1:0] addr0_reg;
	reg [DATA_WIDTH - 1:0] din0_reg;
	always @(posedge clk0)
		if (!csb0) begin
			web0_reg <= web0;
			addr0_reg <= addr0;
			din0_reg <= din0;
		end
	always @(posedge clk0) begin : MEM_WRITE0
		if (!web0_reg)
			mem[addr0_reg][23:0] <= din0_reg[23:0];
	end
	always @(*) begin : MEM_READ0
		dout0 = mem[addr0_reg];
	end
endmodule
module dcache_data_array (
	clk0,
	csb0,
	web0,
	wmask0,
	addr0,
	din0,
	dout0
);
	parameter NUM_WMASKS = 32;
	parameter DATA_WIDTH = 256;
	parameter ADDR_WIDTH = 4;
	parameter RAM_DEPTH = 1 << ADDR_WIDTH;
	input clk0;
	input csb0;
	input web0;
	input [ADDR_WIDTH - 1:0] addr0;
	input [NUM_WMASKS - 1:0] wmask0;
	input [DATA_WIDTH - 1:0] din0;
	output reg [DATA_WIDTH - 1:0] dout0;
	reg [DATA_WIDTH - 1:0] mem [0:RAM_DEPTH - 1];
	reg web0_reg;
	reg [NUM_WMASKS - 1:0] wmask0_reg;
	reg [ADDR_WIDTH - 1:0] addr0_reg;
	reg [DATA_WIDTH - 1:0] din0_reg;
	always @(posedge clk0)
		if (!csb0) begin
			web0_reg <= web0;
			wmask0_reg <= wmask0;
			addr0_reg <= addr0;
			din0_reg <= din0;
		end
	always @(posedge clk0) begin : MEM_WRITE0
		if (!web0_reg) begin
			if (wmask0_reg[0])
				mem[addr0_reg][7:0] <= din0_reg[7:0];
			if (wmask0_reg[1])
				mem[addr0_reg][15:8] <= din0_reg[15:8];
			if (wmask0_reg[2])
				mem[addr0_reg][23:16] <= din0_reg[23:16];
			if (wmask0_reg[3])
				mem[addr0_reg][31:24] <= din0_reg[31:24];
			if (wmask0_reg[4])
				mem[addr0_reg][39:32] <= din0_reg[39:32];
			if (wmask0_reg[5])
				mem[addr0_reg][47:40] <= din0_reg[47:40];
			if (wmask0_reg[6])
				mem[addr0_reg][55:48] <= din0_reg[55:48];
			if (wmask0_reg[7])
				mem[addr0_reg][63:56] <= din0_reg[63:56];
			if (wmask0_reg[8])
				mem[addr0_reg][71:64] <= din0_reg[71:64];
			if (wmask0_reg[9])
				mem[addr0_reg][79:72] <= din0_reg[79:72];
			if (wmask0_reg[10])
				mem[addr0_reg][87:80] <= din0_reg[87:80];
			if (wmask0_reg[11])
				mem[addr0_reg][95:88] <= din0_reg[95:88];
			if (wmask0_reg[12])
				mem[addr0_reg][103:96] <= din0_reg[103:96];
			if (wmask0_reg[13])
				mem[addr0_reg][111:104] <= din0_reg[111:104];
			if (wmask0_reg[14])
				mem[addr0_reg][119:112] <= din0_reg[119:112];
			if (wmask0_reg[15])
				mem[addr0_reg][127:120] <= din0_reg[127:120];
			if (wmask0_reg[16])
				mem[addr0_reg][135:128] <= din0_reg[135:128];
			if (wmask0_reg[17])
				mem[addr0_reg][143:136] <= din0_reg[143:136];
			if (wmask0_reg[18])
				mem[addr0_reg][151:144] <= din0_reg[151:144];
			if (wmask0_reg[19])
				mem[addr0_reg][159:152] <= din0_reg[159:152];
			if (wmask0_reg[20])
				mem[addr0_reg][167:160] <= din0_reg[167:160];
			if (wmask0_reg[21])
				mem[addr0_reg][175:168] <= din0_reg[175:168];
			if (wmask0_reg[22])
				mem[addr0_reg][183:176] <= din0_reg[183:176];
			if (wmask0_reg[23])
				mem[addr0_reg][191:184] <= din0_reg[191:184];
			if (wmask0_reg[24])
				mem[addr0_reg][199:192] <= din0_reg[199:192];
			if (wmask0_reg[25])
				mem[addr0_reg][207:200] <= din0_reg[207:200];
			if (wmask0_reg[26])
				mem[addr0_reg][215:208] <= din0_reg[215:208];
			if (wmask0_reg[27])
				mem[addr0_reg][223:216] <= din0_reg[223:216];
			if (wmask0_reg[28])
				mem[addr0_reg][231:224] <= din0_reg[231:224];
			if (wmask0_reg[29])
				mem[addr0_reg][239:232] <= din0_reg[239:232];
			if (wmask0_reg[30])
				mem[addr0_reg][247:240] <= din0_reg[247:240];
			if (wmask0_reg[31])
				mem[addr0_reg][255:248] <= din0_reg[255:248];
		end
	end
	always @(*) begin : MEM_READ0
		dout0 = mem[addr0_reg];
	end
endmodule
module icache_data_array (
	clk0,
	csb0,
	web0,
	wmask0,
	addr0,
	din0,
	dout0
);
	parameter NUM_WMASKS = 32;
	parameter DATA_WIDTH = 256;
	parameter ADDR_WIDTH = 4;
	parameter RAM_DEPTH = 1 << ADDR_WIDTH;
	input clk0;
	input csb0;
	input web0;
	input [ADDR_WIDTH - 1:0] addr0;
	input [NUM_WMASKS - 1:0] wmask0;
	input [DATA_WIDTH - 1:0] din0;
	output reg [DATA_WIDTH - 1:0] dout0;
	reg [DATA_WIDTH - 1:0] mem [0:RAM_DEPTH - 1];
	reg web0_reg;
	reg [NUM_WMASKS - 1:0] wmask0_reg;
	reg [ADDR_WIDTH - 1:0] addr0_reg;
	reg [DATA_WIDTH - 1:0] din0_reg;
	always @(posedge clk0)
		if (!csb0) begin
			web0_reg <= web0;
			wmask0_reg <= wmask0;
			addr0_reg <= addr0;
			din0_reg <= din0;
		end
	always @(posedge clk0) begin : MEM_WRITE0
		if (!web0_reg) begin
			if (wmask0_reg[0])
				mem[addr0_reg][7:0] <= din0_reg[7:0];
			if (wmask0_reg[1])
				mem[addr0_reg][15:8] <= din0_reg[15:8];
			if (wmask0_reg[2])
				mem[addr0_reg][23:16] <= din0_reg[23:16];
			if (wmask0_reg[3])
				mem[addr0_reg][31:24] <= din0_reg[31:24];
			if (wmask0_reg[4])
				mem[addr0_reg][39:32] <= din0_reg[39:32];
			if (wmask0_reg[5])
				mem[addr0_reg][47:40] <= din0_reg[47:40];
			if (wmask0_reg[6])
				mem[addr0_reg][55:48] <= din0_reg[55:48];
			if (wmask0_reg[7])
				mem[addr0_reg][63:56] <= din0_reg[63:56];
			if (wmask0_reg[8])
				mem[addr0_reg][71:64] <= din0_reg[71:64];
			if (wmask0_reg[9])
				mem[addr0_reg][79:72] <= din0_reg[79:72];
			if (wmask0_reg[10])
				mem[addr0_reg][87:80] <= din0_reg[87:80];
			if (wmask0_reg[11])
				mem[addr0_reg][95:88] <= din0_reg[95:88];
			if (wmask0_reg[12])
				mem[addr0_reg][103:96] <= din0_reg[103:96];
			if (wmask0_reg[13])
				mem[addr0_reg][111:104] <= din0_reg[111:104];
			if (wmask0_reg[14])
				mem[addr0_reg][119:112] <= din0_reg[119:112];
			if (wmask0_reg[15])
				mem[addr0_reg][127:120] <= din0_reg[127:120];
			if (wmask0_reg[16])
				mem[addr0_reg][135:128] <= din0_reg[135:128];
			if (wmask0_reg[17])
				mem[addr0_reg][143:136] <= din0_reg[143:136];
			if (wmask0_reg[18])
				mem[addr0_reg][151:144] <= din0_reg[151:144];
			if (wmask0_reg[19])
				mem[addr0_reg][159:152] <= din0_reg[159:152];
			if (wmask0_reg[20])
				mem[addr0_reg][167:160] <= din0_reg[167:160];
			if (wmask0_reg[21])
				mem[addr0_reg][175:168] <= din0_reg[175:168];
			if (wmask0_reg[22])
				mem[addr0_reg][183:176] <= din0_reg[183:176];
			if (wmask0_reg[23])
				mem[addr0_reg][191:184] <= din0_reg[191:184];
			if (wmask0_reg[24])
				mem[addr0_reg][199:192] <= din0_reg[199:192];
			if (wmask0_reg[25])
				mem[addr0_reg][207:200] <= din0_reg[207:200];
			if (wmask0_reg[26])
				mem[addr0_reg][215:208] <= din0_reg[215:208];
			if (wmask0_reg[27])
				mem[addr0_reg][223:216] <= din0_reg[223:216];
			if (wmask0_reg[28])
				mem[addr0_reg][231:224] <= din0_reg[231:224];
			if (wmask0_reg[29])
				mem[addr0_reg][239:232] <= din0_reg[239:232];
			if (wmask0_reg[30])
				mem[addr0_reg][247:240] <= din0_reg[247:240];
			if (wmask0_reg[31])
				mem[addr0_reg][255:248] <= din0_reg[255:248];
		end
	end
	always @(*) begin : MEM_READ0
		dout0 = mem[addr0_reg];
	end
endmodule
module dcache_tag_array (
	clk0,
	csb0,
	web0,
	addr0,
	din0,
	dout0
);
	parameter DATA_WIDTH = 24;
	parameter ADDR_WIDTH = 4;
	parameter RAM_DEPTH = 1 << ADDR_WIDTH;
	input clk0;
	input csb0;
	input web0;
	input [ADDR_WIDTH - 1:0] addr0;
	input [DATA_WIDTH - 1:0] din0;
	output reg [DATA_WIDTH - 1:0] dout0;
	reg [DATA_WIDTH - 1:0] mem [0:RAM_DEPTH - 1];
	reg web0_reg;
	reg [ADDR_WIDTH - 1:0] addr0_reg;
	reg [DATA_WIDTH - 1:0] din0_reg;
	always @(posedge clk0)
		if (!csb0) begin
			web0_reg <= web0;
			addr0_reg <= addr0;
			din0_reg <= din0;
		end
	always @(posedge clk0) begin : MEM_WRITE0
		if (!web0_reg)
			mem[addr0_reg][23:0] <= din0_reg[23:0];
	end
	always @(*) begin : MEM_READ0
		dout0 = mem[addr0_reg];
	end
endmodule
