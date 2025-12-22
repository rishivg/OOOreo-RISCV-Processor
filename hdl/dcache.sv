module dcache (
    input   logic           clk,
    input   logic           rst,
    
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    output  logic   [255:0] ufp_rcache_line,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

    
    localparam TAG_BITS = 23;  
    localparam SET_BITS = 4;   
    localparam WAY_COUNT = 4;

    
    typedef enum logic [2:0] {
        IDLE,       
        COMPARE,    
        ALLOCATE,   
        WRITEBACK   
    } cache_state_t;
    
    cache_state_t state, next_state;

    logic load_tag [WAY_COUNT];
    logic load_data [WAY_COUNT];
    logic load_valid [WAY_COUNT];
    logic load_dirty [WAY_COUNT];
    logic load_plru;
    logic [1:0] hit_way;
    logic hit;

    logic [2:0] plru_bits;
    logic [2:0] next_plru_bits;
    
    logic dirty_in [WAY_COUNT];
    
    logic [TAG_BITS-1:0] tag_out [WAY_COUNT];
    logic [255:0] data_out [WAY_COUNT];
    logic valid_out [WAY_COUNT];
    logic dirty_out [WAY_COUNT];

    logic [255:0] data_write [WAY_COUNT];
    logic [31:0] way_data [WAY_COUNT];
    logic [4:0] addr_offset;

    logic [TAG_BITS-1:0] addr_tag;
    logic [SET_BITS-1:0] addr_set;

    logic [3:0] ufp_rmask_prev, ufp_wmask_prev;

    logic [TAG_BITS-1:0] addr_tag_instant;
    logic [SET_BITS-1:0] addr_set_instant;

    assign addr_tag_instant = ufp_addr[31:9];
    assign addr_set_instant = ufp_addr[8:5];

    generate for (genvar i = 0; i < WAY_COUNT; i++) begin : arrays
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (~((|ufp_rmask) | (|ufp_wmask))), 
            .web0       (~load_tag[i]), 
            .addr0      (addr_set_instant),      
            .din0       (addr_tag_instant),      
            .dout0      (tag_out[i])
        );
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       ((~load_data[i])),
            .wmask0     (32'hFFFFFFFF),
            .addr0      (addr_set_instant),
            .din0       (data_write[i]),
            .dout0      (data_out[i])
        );
        
        sp_ff_array #(.WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (~load_valid[i]),
            .addr0      (addr_set_instant),
            .din0       (1'b1),          
            .dout0      (valid_out[i])
        );
        
        sp_ff_array #(.WIDTH(1)) dirty_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (~load_dirty[i]),
            .addr0      (addr_set_instant),
            .din0       (dirty_in[i]),
            .dout0      (dirty_out[i])
        );
    end endgenerate

    
    sp_ff_array #(
        .WIDTH      (3)
    ) lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (1'b0),            
        .web0       (~load_plru),      
        .addr0      (addr_set_instant),        
        .din0       (next_plru_bits),  
        .dout0      (plru_bits)        
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    
    logic [WAY_COUNT-1:0] way_hit;

    always_comb begin
        hit = 1'b0;
        hit_way = 2'b00;
        way_hit = '0;
        
        for (integer i = 0; i < WAY_COUNT; i++) begin
            if (valid_out[i] && (tag_out[i] == addr_tag)) begin
                way_hit[i] = 1'b1;
            end
        end

        hit = |way_hit;

        unique case (way_hit)
            4'b0001: hit_way = 2'b00;
            4'b0010: hit_way = 2'b01;
            4'b0100: hit_way = 2'b10;
            4'b1000: hit_way = 2'b11;
            default: hit_way = 2'b00;
        endcase
    end
    
        // Precomputed victim way for allocation
    logic [1:0] victim_way;
    logic dirty_victim;
    
    assign victim_way[1] = ~plru_bits[2];
    assign victim_way[0] = plru_bits[2] ? ~plru_bits[1] : ~plru_bits[0];
    assign dirty_victim = dirty_out[victim_way];
    
    logic [1:0] update_way;
    assign update_way = hit ? hit_way : victim_way;
    
    always_comb begin
        next_plru_bits = plru_bits;

        if (load_plru) begin
            next_plru_bits[2] = update_way[1];
            if (update_way[1] == 1'b0)
                next_plru_bits[1] = update_way[0];
            else
                next_plru_bits[0] = update_way[0];
        end
    end

    always_comb begin
        for (integer i = 0; i < WAY_COUNT; i++) begin
            dirty_in[i] = 1'b1;
        end
        
        if (state == ALLOCATE && dfp_resp) begin
            dirty_in[victim_way] = |ufp_wmask_prev;
        end
    end

    always_comb begin
        data_write[0] = data_out[0];
        data_write[1] = data_out[1];
        data_write[2] = data_out[2];
        data_write[3] = data_out[3];

        if (state == ALLOCATE && dfp_resp) begin
            data_write[0] = dfp_rdata;
            data_write[1] = dfp_rdata;
            data_write[2] = dfp_rdata;
            data_write[3] = dfp_rdata;
        end

        if (state == COMPARE && hit && |ufp_wmask_prev) begin
            if (ufp_wmask[0]) begin
                data_write[hit_way][addr_offset[4:2] * 32 +: 8] = ufp_wdata[7:0];
            end
            if (ufp_wmask[1]) begin
                data_write[hit_way][addr_offset[4:2] * 32 + 8 +: 8] = ufp_wdata[15:8];
            end
            if (ufp_wmask[2]) begin
                data_write[hit_way][addr_offset[4:2] * 32 + 16 +: 8] = ufp_wdata[23:16];
            end
            if (ufp_wmask[3]) begin
                data_write[hit_way][addr_offset[4:2] * 32 + 24 +: 8] = ufp_wdata[31:24];
            end
        end else if ((state == ALLOCATE) && dfp_resp && |ufp_wmask_prev) begin
            if (ufp_wmask[0]) begin
                data_write[victim_way][addr_offset[4:2] * 32 +: 8] = ufp_wdata[7:0];
            end
            if (ufp_wmask[1]) begin
                data_write[victim_way][addr_offset[4:2] * 32 + 8 +: 8] = ufp_wdata[15:8];
            end
            if (ufp_wmask[2]) begin
                data_write[victim_way][addr_offset[4:2] * 32 + 16 +: 8] = ufp_wdata[23:16];
            end
            if (ufp_wmask[3]) begin
                data_write[victim_way][addr_offset[4:2] * 32 + 24 +: 8] = ufp_wdata[31:24];
            end
        end
    end    always_comb begin
        for (integer i = 0; i < WAY_COUNT; i++) begin
            way_data[i] = data_out[i][addr_offset[4:2] * 32 +: 32];
        end

        ufp_rdata = 32'b0;
        ufp_rcache_line = 256'd0;

        if (state == COMPARE && hit && |ufp_rmask_prev) begin
            unique case (way_hit)
                4'b0001: ufp_rdata = way_data[0];
                4'b0010: ufp_rdata = way_data[1];
                4'b0100: ufp_rdata = way_data[2];
                4'b1000: ufp_rdata = way_data[3];
                default: ufp_rdata = 32'b0;
            endcase
            ufp_rcache_line = data_out[hit_way];
        end else if (state == ALLOCATE && dfp_resp && |ufp_rmask_prev) begin
            ufp_rdata = dfp_rdata[addr_offset[4:2] * 32 +: 32];
            ufp_rcache_line = dfp_rdata;
        end
    end

    always_comb begin
        next_state = state;
        ufp_resp = 1'b0;
        dfp_read = 1'b0;
        dfp_write = 1'b0;
        dfp_addr = 32'b0;
        dfp_wdata = 256'b0;
        load_plru = 1'b0;

        load_tag[0] = 1'b0;
        load_data[0] = 1'b0;
        load_valid[0] = 1'b0;
        load_dirty[0] = 1'b0;

        load_tag[1] = 1'b0;
        load_data[1] = 1'b0;
        load_valid[1] = 1'b0;
        load_dirty[1] = 1'b0;

        load_tag[2] = 1'b0;
        load_data[2] = 1'b0;
        load_valid[2] = 1'b0;
        load_dirty[2] = 1'b0;

        load_tag[3] = 1'b0;
        load_data[3] = 1'b0;
        load_valid[3] = 1'b0;
        load_dirty[3] = 1'b0;        case (state)
            IDLE: begin
                
                if ((|ufp_rmask || |ufp_wmask)) begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                if (hit) begin
                    load_plru = 1'b1;
                    ufp_resp = 1'b1;
                    
                if (|ufp_wmask) begin
                    load_data[hit_way] = 1'b1;
                    load_dirty[hit_way] = 1'b1;
                end                    next_state = IDLE;
                end else begin
                    if (dirty_victim) begin
                        next_state = WRITEBACK;
                    end else begin
                        next_state = ALLOCATE;
                    end
                end
            end
            
            WRITEBACK: begin
                
                dfp_write = 1'b1;
                dfp_wdata = data_out[victim_way];
                dfp_addr = {tag_out[victim_way], addr_set, 5'b0}; 
                
                if (dfp_resp) begin
                    next_state = ALLOCATE;
                end
            end
            
            ALLOCATE: begin
                dfp_read = 1'b1;
                dfp_addr = {addr_tag, addr_set, 5'b0};

                if (dfp_resp) begin
                    load_tag[victim_way] = 1'b1;
                    load_valid[victim_way] = 1'b1;
                    load_data[victim_way] = 1'b1;
                    load_plru = 1'b1;
                    load_dirty[victim_way] = 1'b1;
                    
                    ufp_resp = 1'b1;
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end



    always_ff @(posedge clk) begin
        if (rst) begin
            addr_tag <= 23'b0;
            addr_set <= 4'b0;
            addr_offset <= 5'b0;
            ufp_rmask_prev <= 4'b0;
            ufp_wmask_prev <= 4'b0;
        end
        else begin
            if ((|ufp_rmask || |ufp_wmask)) begin
                if (state == IDLE) begin
                    addr_tag <= ufp_addr[31:9];
                    addr_set <= ufp_addr[8:5];
                    addr_offset <= ufp_addr[4:0];
                    ufp_rmask_prev <= ufp_rmask;
                    ufp_wmask_prev <= ufp_wmask;
                end
            end
        end
    end



endmodule
