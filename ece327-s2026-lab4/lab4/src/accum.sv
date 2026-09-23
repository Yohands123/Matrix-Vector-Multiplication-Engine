/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* Accumulator Module                              */
/***************************************************/

module accum # (
    parameter DATAW = 32,
    parameter ACCUMW = 32
)(
    input  clk,
    input  rst,
    input  signed [DATAW-1:0] data,
    input  ivalid,
    input  first,
    input  last,
    output signed [ACCUMW-1:0] result,
    output ovalid
);

/******* Your code starts here *******/
logic signed [ACCUMW-1:0] accum_reg;
logic signed [ACCUMW-1:0] data_ext;
logic ovalid_reg;

assign data_ext = data;

always_ff @(posedge clk) begin
    if (rst) begin
        accum_reg  <= '0;
        ovalid_reg <= 1'b0;
    end
    else begin
        ovalid_reg <= 1'b0;

        if (ivalid) begin
            if (first)
                accum_reg <= data_ext;
            else
                accum_reg <= accum_reg + data_ext;

            if (last)
                ovalid_reg <= 1'b1;
        end
    end
end

assign result = accum_reg;
assign ovalid = ovalid_reg;


/******* Your code ends here ********/

endmodule