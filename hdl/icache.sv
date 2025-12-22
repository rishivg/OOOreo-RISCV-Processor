module icache (
    input   logic           clk,
    input   logic           rst,
    
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    output  logic   [31:0]  ufp_rdata,
    output  logic   [255:0] ufp_rcache_line,
    output  logic           ufp_resp,

    
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    input   logic   [255:0] dfp_rdata,
    input   logic           dfp_resp
);

    
    localparam TAG_BITS = 23;  
    localparam SET_BITS = 4;   
    localparam WAY_COUNT = 4;

    
    typedef enum logic [2:0] {
        IDLE,       
        COMPARE,    
        ALLOCATE,   
        AIDLE,
        AHIT
    } cache_state_t;
    
    cache_state_t state, next_state;

    logic load_tag [WAY_COUNT];
    logic load_data [WAY_COUNT];
    logic load_valid [WAY_COUNT];
    logic load_plru;
    logic [1:0] hit_way;
    logic hit;

    logic [2:0] plru_bits;
    logic [2:0] next_plru_bits;
    
    
    logic [TAG_BITS-1:0] tag_out [WAY_COUNT];
    logic [255:0] data_out [WAY_COUNT];
    logic valid_out [WAY_COUNT];

    logic [255:0] data_write [WAY_COUNT];
    logic [31:0] way_data [WAY_COUNT];
    logic [4:0] addr_offset;

    logic [TAG_BITS-1:0] addr_tag;
    logic [SET_BITS-1:0] addr_set;

    logic [3:0] ufp_rmask_prev;

    logic [TAG_BITS-1:0] addr_tag_instant;
    logic [SET_BITS-1:0] addr_set_instant;

    assign addr_tag_instant = ufp_addr[31:9];
    assign addr_set_instant = ufp_addr[8:5];

    generate for (genvar i = 0; i < WAY_COUNT; i++) begin : arrays
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (~(|ufp_rmask)), 
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
    
    assign victim_way[1] = ~plru_bits[2];
    assign victim_way[0] = plru_bits[2] ? ~plru_bits[1] : ~plru_bits[0];
    
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
        data_write[0] = data_out[0];
        data_write[1] = data_out[1];
        data_write[2] = data_out[2];
        data_write[3] = data_out[3];

        if (state == AIDLE) begin
            data_write[0] = dfp_rdata;
            data_write[1] = dfp_rdata;
            data_write[2] = dfp_rdata;
            data_write[3] = dfp_rdata;
        end
    end

    always_comb begin
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
        end else if (state == AHIT && |ufp_rmask_prev) begin
            ufp_rdata = dfp_rdata[addr_offset[4:2] * 32 +: 32];
            ufp_rcache_line = dfp_rdata;
        end
    end

    always_comb begin
        next_state = state;
        ufp_resp = 1'b0;
        dfp_read = 1'b0;
        dfp_addr = 32'b0;
        load_plru = 1'b0;

        load_tag[0] = 1'b0;
        load_data[0] = 1'b0;
        load_valid[0] = 1'b0;

        load_tag[1] = 1'b0;
        load_data[1] = 1'b0;
        load_valid[1] = 1'b0;

        load_tag[2] = 1'b0;
        load_data[2] = 1'b0;
        load_valid[2] = 1'b0;

        load_tag[3] = 1'b0;
        load_data[3] = 1'b0;
        load_valid[3] = 1'b0;

        case (state)
            IDLE: begin
                if (|ufp_rmask) begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                if (hit) begin
                    load_plru = 1'b1;
                    ufp_resp = 1'b1;
                    next_state = IDLE;
                end else begin
                    next_state = ALLOCATE;
                end
            end
            
            ALLOCATE: begin
                dfp_read = 1'b1;
                dfp_addr = {addr_tag, addr_set, 5'b0};

                if (dfp_resp) begin
                    next_state = AIDLE;
                end
            end
            AIDLE: begin
                load_tag[victim_way] = 1'b1;
                load_valid[victim_way] = 1'b1;
                load_data[victim_way] = 1'b1;
                load_plru = 1'b1;
                next_state = AHIT;
            end
            AHIT: begin
                next_state = IDLE;
                ufp_resp = 1'b1;
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
        end
        else begin
            if (|ufp_rmask) begin
                if (state == IDLE) begin
                    addr_tag <= ufp_addr[31:9];
                    addr_set <= ufp_addr[8:5];
                    addr_offset <= ufp_addr[4:0];
                    ufp_rmask_prev <= ufp_rmask;
                end
            end
        end
    end



endmodule
