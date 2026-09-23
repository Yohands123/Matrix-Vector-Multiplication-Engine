/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* Matrix Vector Multiplication (MVM) Module       */
/***************************************************/

module mvm # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32,
    parameter MEM_DATAW = IWIDTH * 8,
    parameter VEC_MEM_DEPTH = 256,
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH),
    parameter MAT_MEM_DEPTH = 512,
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH),
    parameter NUM_OLANES = 8
)(
    input clk,
    input rst,
    input [MEM_DATAW-1:0] i_vec_wdata,
    input [VEC_ADDRW-1:0] i_vec_waddr,
    input i_vec_wen,
    input [MEM_DATAW-1:0] i_mat_wdata,
    input [MAT_ADDRW-1:0] i_mat_waddr,
    input [NUM_OLANES-1:0] i_mat_wen,
    input i_start,
    input [VEC_ADDRW-1:0] i_vec_start_addr,
    input [VEC_ADDRW:0] i_vec_num_words,
    input [MAT_ADDRW-1:0] i_mat_start_addr,
    input [MAT_ADDRW:0] i_mat_num_rows_per_olane,
    output o_busy,
    output [OWIDTH*NUM_OLANES-1:0] o_result,
    output o_valid
);

/******* Your code starts here *******/
localparam VEC_SIZEW = VEC_ADDRW + 1;
localparam MAT_SIZEW = MAT_ADDRW + 1;

logic [VEC_ADDRW-1:0] vec_raddr;
logic [MAT_ADDRW-1:0] mat_raddr;
logic ctrl_accum_first;
logic ctrl_accum_last;
logic ctrl_ovalid;
logic ctrl_busy;

logic [MEM_DATAW-1:0] vec_rdata;
logic [MEM_DATAW-1:0] mat_rdata [0:NUM_OLANES-1];

logic signed [OWIDTH-1:0] dot_result [0:NUM_OLANES-1];
logic [NUM_OLANES-1:0] dot_ovalid;
logic signed [OWIDTH-1:0] accum_result [0:NUM_OLANES-1];
logic [NUM_OLANES-1:0] accum_ovalid;

/* One cycle aligns ctrl_ovalid with the synchronous memory outputs. */
localparam LANES_PER_BCAST_GROUP = 8;
localparam NUM_BCAST_GROUPS =
    (NUM_OLANES + LANES_PER_BCAST_GROUP - 1) / LANES_PER_BCAST_GROUP;

/*
 * Replicated operand registers reduce the vector-memory broadcast fanout.
 * Matrix data is registered by lane so both operands remain aligned.
 */
logic [MEM_DATAW-1:0] vec_bcast_reg [0:NUM_BCAST_GROUPS-1];
logic [MEM_DATAW-1:0] mat_operand_reg [0:NUM_OLANES-1];

/* Two cycles align controller valid with the registered operands. */
logic [1:0] ctrl_ovalid_delay;

/*
 * ctrl -> memory             = 1 cycle
 * memory -> operand register = 1 cycle
 * dot8                       = 5 cycles
 * Therefore first/last need seven cycles before the accumulator.
 */
logic [6:0] accum_first_delay;
logic [6:0] accum_last_delay;

logic busy_reg;
logic [MAT_SIZEW-1:0] rows_expected;
logic [MAT_SIZEW-1:0] rows_emitted;
logic start_accepted;

assign start_accepted = i_start && !busy_reg &&
                        (i_vec_num_words != 0) &&
                        (i_mat_num_rows_per_olane != 0);

ctrl #(
    .VEC_ADDRW(VEC_ADDRW),
    .MAT_ADDRW(MAT_ADDRW),
    .VEC_SIZEW(VEC_SIZEW),
    .MAT_SIZEW(MAT_SIZEW)
) ctrl_inst (
    .clk(clk),
    .rst(rst),
    .start(start_accepted),
    .vec_start_addr(i_vec_start_addr),
    .vec_num_words(i_vec_num_words),
    .mat_start_addr(i_mat_start_addr),
    .mat_num_rows_per_olane(i_mat_num_rows_per_olane),
    .vec_raddr(vec_raddr),
    .mat_raddr(mat_raddr),
    .accum_first(ctrl_accum_first),
    .accum_last(ctrl_accum_last),
    .ovalid(ctrl_ovalid),
    .busy(ctrl_busy)
);

mem #(
    .DATAW(MEM_DATAW),
    .DEPTH(VEC_MEM_DEPTH),
    .ADDRW(VEC_ADDRW)
) vector_mem (
    .clk(clk),
    .wdata(i_vec_wdata),
    .waddr(i_vec_waddr),
    .wen(i_vec_wen),
    .raddr(vec_raddr),
    .rdata(vec_rdata)
);

integer group_id;
always_ff @(posedge clk) begin
    if (rst) begin
        ctrl_ovalid_delay <= '0;
        accum_first_delay <= '0;
        accum_last_delay  <= '0;

        for (group_id = 0; group_id < NUM_BCAST_GROUPS; group_id = group_id + 1)
            vec_bcast_reg[group_id] <= '0;
    end
    else begin
        ctrl_ovalid_delay <= {ctrl_ovalid_delay[0], ctrl_ovalid};
        accum_first_delay <= {accum_first_delay[5:0], ctrl_accum_first};
        accum_last_delay  <= {accum_last_delay[5:0], ctrl_accum_last};

        for (group_id = 0; group_id < NUM_BCAST_GROUPS; group_id = group_id + 1)
            vec_bcast_reg[group_id] <= vec_rdata;
    end
end

/* Keep o_busy asserted until the final accumulated output is visible. */
always_ff @(posedge clk) begin
    if (rst) begin
        busy_reg      <= 1'b0;
        rows_expected <= '0;
        rows_emitted  <= '0;
    end
    else begin
        if (start_accepted) begin
            busy_reg      <= 1'b1;
            rows_expected <= i_mat_num_rows_per_olane;
            rows_emitted  <= '0;
        end
        else if (busy_reg && accum_ovalid[0]) begin
            if (rows_emitted == (rows_expected - 1'b1)) begin
                busy_reg     <= 1'b0;
                rows_emitted <= '0;
            end
            else begin
                rows_emitted <= rows_emitted + 1'b1;
            end
        end
    end
end

genvar lane;
generate
    for (lane = 0; lane < NUM_OLANES; lane = lane + 1) begin : GEN_OLANES
        mem #(
            .DATAW(MEM_DATAW),
            .DEPTH(MAT_MEM_DEPTH),
            .ADDRW(MAT_ADDRW)
        ) matrix_mem (
            .clk(clk),
            .wdata(i_mat_wdata),
            .waddr(i_mat_waddr),
            .wen(i_mat_wen[lane]),
            .raddr(mat_raddr),
            .rdata(mat_rdata[lane])
        );

        localparam integer BCAST_GROUP = lane / LANES_PER_BCAST_GROUP;

        always_ff @(posedge clk) begin
            if (rst)
                mat_operand_reg[lane] <= '0;
            else
                mat_operand_reg[lane] <= mat_rdata[lane];
        end

        dot8 #(
            .IWIDTH(IWIDTH),
            .OWIDTH(OWIDTH)
        ) dot8_inst (
            .clk(clk),
            .rst(rst),
            .vec0(vec_bcast_reg[BCAST_GROUP]),
            .vec1(mat_operand_reg[lane]),
            .ivalid(ctrl_ovalid_delay[1]),
            .result(dot_result[lane]),
            .ovalid(dot_ovalid[lane])
        );

        accum #(
            .DATAW(OWIDTH),
            .ACCUMW(OWIDTH)
        ) accum_inst (
            .clk(clk),
            .rst(rst),
            .data(dot_result[lane]),
            .ivalid(dot_ovalid[lane]),
            .first(accum_first_delay[6]),
            .last(accum_last_delay[6]),
            .result(accum_result[lane]),
            .ovalid(accum_ovalid[lane])
        );

        assign o_result[lane*OWIDTH +: OWIDTH] = accum_result[lane];
    end
endgenerate

assign o_valid = accum_ovalid[0];
assign o_busy  = busy_reg;
/******* Your code ends here ********/

endmodule