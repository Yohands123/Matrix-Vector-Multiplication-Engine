/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* 8-Lane Dot Product Module                       */
/***************************************************/

module dot8 # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32
)(
    input clk,
    input rst,
    input signed [8*IWIDTH-1:0] vec0,
    input signed [8*IWIDTH-1:0] vec1,
    input ivalid,
    output signed [OWIDTH-1:0] result,
    output ovalid
);

/******* Your code starts here *******/
/*
 * Five-stage pipeline:
 *   1) register both input vectors
 *   2) eight signed multiplications
 *   3) four pairwise additions
 *   4) two pairwise additions
 *   5) one final addition
 *
 * The extra input-register stage removes the long/high-fanout path from
 * the BRAM output directly into all multipliers.
 */

localparam PRODW = 2 * IWIDTH;
localparam ADD1W = PRODW + 1;
localparam ADD2W = PRODW + 2;
localparam ADD3W = PRODW + 3;

/* Stage 1: registered operands. */
logic signed [8*IWIDTH-1:0] vec0_reg;
logic signed [8*IWIDTH-1:0] vec1_reg;

/* Stage 2: force the eight multipliers into DSP slices. */
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product0;
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product1;
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product2;
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product3;
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product4;
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product5;
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product6;
(* use_dsp = "yes" *) logic signed [PRODW-1:0] product7;

/* Stage 3: sums of two products. */
logic signed [ADD1W-1:0] sum1_0;
logic signed [ADD1W-1:0] sum1_1;
logic signed [ADD1W-1:0] sum1_2;
logic signed [ADD1W-1:0] sum1_3;

/* Stage 4: sums of four products. */
logic signed [ADD2W-1:0] sum2_0;
logic signed [ADD2W-1:0] sum2_1;

/* Stage 5: complete dot product. */
logic signed [ADD3W-1:0] final_sum;

/* Valid tag follows the same five stages. */
logic [4:0] valid_pipe;

always_ff @(posedge clk) begin
    if (rst) begin
        vec0_reg <= '0;
        vec1_reg <= '0;

        product0 <= '0;
        product1 <= '0;
        product2 <= '0;
        product3 <= '0;
        product4 <= '0;
        product5 <= '0;
        product6 <= '0;
        product7 <= '0;

        sum1_0 <= '0;
        sum1_1 <= '0;
        sum1_2 <= '0;
        sum1_3 <= '0;

        sum2_0 <= '0;
        sum2_1 <= '0;
        final_sum <= '0;

        valid_pipe <= '0;
    end
    else begin
        /* Stage 1: isolate the memories from the multiplier fanout. */
        vec0_reg <= vec0;
        vec1_reg <= vec1;

        /* Stage 2: eight signed products. */
        product0 <= $signed(vec0_reg[0*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[0*IWIDTH +: IWIDTH]);
        product1 <= $signed(vec0_reg[1*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[1*IWIDTH +: IWIDTH]);
        product2 <= $signed(vec0_reg[2*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[2*IWIDTH +: IWIDTH]);
        product3 <= $signed(vec0_reg[3*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[3*IWIDTH +: IWIDTH]);
        product4 <= $signed(vec0_reg[4*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[4*IWIDTH +: IWIDTH]);
        product5 <= $signed(vec0_reg[5*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[5*IWIDTH +: IWIDTH]);
        product6 <= $signed(vec0_reg[6*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[6*IWIDTH +: IWIDTH]);
        product7 <= $signed(vec0_reg[7*IWIDTH +: IWIDTH]) *
                    $signed(vec1_reg[7*IWIDTH +: IWIDTH]);

        /* Stage 3: four pairwise sums with explicit sign extension. */
        sum1_0 <= {product0[PRODW-1], product0} +
                  {product1[PRODW-1], product1};
        sum1_1 <= {product2[PRODW-1], product2} +
                  {product3[PRODW-1], product3};
        sum1_2 <= {product4[PRODW-1], product4} +
                  {product5[PRODW-1], product5};
        sum1_3 <= {product6[PRODW-1], product6} +
                  {product7[PRODW-1], product7};

        /* Stage 4: two four-product sums. */
        sum2_0 <= {sum1_0[ADD1W-1], sum1_0} +
                  {sum1_1[ADD1W-1], sum1_1};
        sum2_1 <= {sum1_2[ADD1W-1], sum1_2} +
                  {sum1_3[ADD1W-1], sum1_3};

        /* Stage 5: final eight-product sum. */
        final_sum <= {sum2_0[ADD2W-1], sum2_0} +
                     {sum2_1[ADD2W-1], sum2_1};

        valid_pipe <= {valid_pipe[3:0], ivalid};
    end
end

assign result = final_sum;
assign ovalid = valid_pipe[4];

/******* Your code ends here ********/

endmodule