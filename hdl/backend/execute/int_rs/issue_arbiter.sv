module issue_arbiter
import cpu_params::*;
(
    input   logic   [INTRS_DEPTH-1:0]           rs_request,
    output  logic   [INTRS_DEPTH-1:0]           rs_grant,
    output  logic   [INT_ISSUE_WIDTH-1:0]       rs_compress     [INTRS_DEPTH],
    output  logic   [INTRS_DEPTH-1:0]           fu_issue        [INT_ISSUE_WIDTH]
);

    // prev_assigned[i] encodes min(2, popcount(rs_request strictly below i)):
    //   [0] = at least one earlier requester  (count_below >= 1)
    //   [1] = at least two earlier requesters  (count_below >= 2)
    // The original built this with a serial j-below-i accumulate, an O(n)
    // ripple on the single-cycle wakeup->select path. Recast as two balanced
    // prefix-OR reductions (log-depth) -- behaviourally identical, since
    //   count_below(i) >= 1  <=>  any request below i
    //   count_below(i) >= 2  <=>  any "second-or-later" requester below i,
    // where a position j is second-or-later iff it requests and some position
    // below j also requests.
    logic   [INT_ISSUE_WIDTH-1:0]   prev_assigned [INTRS_DEPTH];
    logic   [INTRS_DEPTH-1:0]       ge1;        // ge1[j] = any request strictly below j
    logic   [INTRS_DEPTH-1:0]       second;     // second[j] = j is a 2nd-or-later requester

    always_comb begin
        rs_grant = '0;
        fu_issue[0] = '0;
        fu_issue[1] = '0;
        for (int j = 0; j < INTRS_DEPTH; j++) begin
            automatic logic [INTRS_DEPTH-1:0] mask_below;
            mask_below = ~({INTRS_DEPTH{1'b1}} << j);    // bits [j-1:0] set
            ge1[j]    = |(rs_request & mask_below);
            second[j] = rs_request[j] & ge1[j];
        end
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            automatic logic [INTRS_DEPTH-1:0] mask_below;
            mask_below = ~({INTRS_DEPTH{1'b1}} << i);    // bits [i-1:0] set
            prev_assigned[i][0] = ge1[i];                // |(rs_request & mask_below)
            prev_assigned[i][1] = |(second & mask_below);
            if( ~prev_assigned[i][0] & rs_request[i] ) begin
                rs_grant[i] = '1;
                fu_issue[0][i] = '1;
            end else if ( ~prev_assigned[i][1] & rs_request[i] ) begin
                rs_grant[i] = '1;
                fu_issue[1][i] = '1;
            end
        end
    end

    always_comb begin
        // hardcoded for simplicity
        for ( int i = 0; i < INTRS_DEPTH; i++ ) begin
            unique case (prev_assigned[i])
                2'b00:      rs_compress[i] = (rs_grant[i]) ? 2'b01: 2'b00;
                2'b01:      rs_compress[i] = (rs_grant[i]) ? 2'b10: 2'b01;
                2'b11:      rs_compress[i] = 2'b10;
                default:    rs_compress[i] = 'x;
            endcase
        end       
        // for consecutive pop corner case
        for ( int i = 0; i < INTRS_DEPTH-1; i++ ) begin
            if( rs_compress[i]!=2'b00 && rs_grant[i+1] )   rs_compress[i] = 2'b10;
        end   
    end

endmodule
