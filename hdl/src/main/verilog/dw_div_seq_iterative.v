// Restoring divider with num_cyc enabled clocks from start to completion.
// hold freezes all state, including a completed result. Reset is asynchronous.
module DW_div_seq #(
    parameter a_width = 32, b_width = 32, tc_mode = 0, num_cyc = 3,
    parameter rst_mode = 0, input_mode = 1, output_mode = 1, early_start = 0
) (
    input clk, rst_n, hold, start,
    input [a_width-1:0] a,
    input [b_width-1:0] b,
    output reg complete, divide_by_0,
    output reg [a_width-1:0] quotient,
    output reg [b_width-1:0] remainder
);
    localparam GROUPS = (num_cyc > 1) ? num_cyc - 1 : 1;
    localparam STEP = (a_width + GROUPS - 1) / GROUPS;
    localparam COUNT_W = (num_cyc < 2) ? 1 : $clog2(num_cyc + 1);

    reg busy, zero_divisor, q_negative, r_negative;
    reg [COUNT_W-1:0] cycle;
    reg [a_width-1:0] qmag, original_a;
    reg [b_width-1:0] divisor;
    reg [b_width:0] remmag;
    reg [a_width-1:0] qnext;
    reg [b_width:0] rnext, trial, subtracted;
    integer step_index;

    always @* begin
        qnext = qmag;
        rnext = remmag;
        trial = 0;
        subtracted = 0;
        for (step_index = 0; step_index < STEP; step_index = step_index + 1) begin
            if (cycle * STEP + step_index < a_width) begin
                trial = {rnext[b_width-1:0], qnext[a_width-1]};
                subtracted = trial - {1'b0, divisor};
                qnext = qnext << 1;
                if (!subtracted[b_width]) begin
                    rnext = subtracted;
                    qnext[0] = 1'b1;
                end else begin
                    rnext = trial;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            cycle <= 0;
            complete <= 0;
            divide_by_0 <= 0;
            quotient <= 0;
            remainder <= 0;
            qmag <= 0;
            remmag <= 0;
            divisor <= 0;
            original_a <= 0;
            zero_divisor <= 0;
            q_negative <= 0;
            r_negative <= 0;
        end else if (!hold) begin
            complete <= 0;
            if (start && !busy) begin
                busy <= 1;
                cycle <= 0;
                remmag <= 0;
                original_a <= a;
                zero_divisor <= b == 0;
                q_negative <= tc_mode && (a[a_width-1] ^ b[b_width-1]);
                r_negative <= tc_mode && a[a_width-1];
                qmag <= (tc_mode && a[a_width-1]) ? (~a + 1'b1) : a;
                divisor <= (tc_mode && b[b_width-1]) ? (~b + 1'b1) : b;
            end else if (busy) begin
                if (cycle < GROUPS) begin
                    qmag <= qnext;
                    remmag <= rnext;
                    cycle <= cycle + 1'b1;
                end else begin
                    busy <= 0;
                    complete <= 1;
                    divide_by_0 <= zero_divisor;
                    quotient <= zero_divisor ? {a_width{1'b1}}
                        : (q_negative ? (~qmag + 1'b1) : qmag);
                    remainder <= zero_divisor ? original_a
                        : (r_negative ? (~remmag[b_width-1:0] + 1'b1) : remmag[b_width-1:0]);
                end
            end
        end
    end

    initial if (num_cyc < 2) $error("iterative divider requires num_cyc >= 2");
endmodule
