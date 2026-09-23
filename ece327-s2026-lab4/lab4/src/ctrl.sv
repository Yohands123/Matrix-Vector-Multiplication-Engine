/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2026 */
/* Lab 4                                           */
/* MVM Control FSM                                 */
/***************************************************/

module ctrl # (
    parameter VEC_ADDRW = 8,
    parameter MAT_ADDRW = 9,
    parameter VEC_SIZEW = VEC_ADDRW + 1,
    parameter MAT_SIZEW = MAT_ADDRW + 1
    
)(
    input  clk,
    input  rst,
    input  start,
    input  [VEC_ADDRW-1:0] vec_start_addr,
    input  [VEC_SIZEW-1:0] vec_num_words,
    input  [MAT_ADDRW-1:0] mat_start_addr,
    input  [MAT_SIZEW-1:0] mat_num_rows_per_olane,
    output [VEC_ADDRW-1:0] vec_raddr,
    output [MAT_ADDRW-1:0] mat_raddr,
    output accum_first,
    output accum_last,
    output ovalid,
    output busy
);

/******* Your code starts here *******/
typedef enum logic {IDLE, COMPUTE} state_t;
state_t state;

logic [VEC_ADDRW-1:0] vec_start_reg;
logic [VEC_SIZEW-1:0] vec_words_reg;
logic [MAT_ADDRW-1:0] mat_start_reg;
logic [MAT_SIZEW-1:0] mat_rows_reg;

logic [VEC_ADDRW-1:0] vec_addr_reg;
logic [MAT_ADDRW-1:0] mat_addr_reg;
logic [VEC_SIZEW-1:0] word_count;
logic [MAT_SIZEW-1:0] row_count;

always_ff @(posedge clk) begin
    if (rst) begin
        state         <= IDLE;
        vec_start_reg <= '0;
        vec_words_reg <= '0;
        mat_start_reg <= '0;
        mat_rows_reg  <= '0;
        vec_addr_reg  <= '0;
        mat_addr_reg  <= '0;
        word_count    <= '0;
        row_count     <= '0;
    end
    else begin
        case (state)
            IDLE: begin
                /* Register the requested operation while idle. */
                vec_start_reg <= vec_start_addr;
                vec_words_reg <= vec_num_words;
                mat_start_reg <= mat_start_addr;
                mat_rows_reg  <= mat_num_rows_per_olane;
                word_count    <= '0;
                row_count     <= '0;

                if (start && (vec_num_words != 0) &&
                             (mat_num_rows_per_olane != 0)) begin
                    vec_addr_reg <= vec_start_addr;
                    mat_addr_reg <= mat_start_addr;
                    state        <= COMPUTE;
                end
                else begin
                    vec_addr_reg <= '0;
                    mat_addr_reg <= '0;
                end
            end

            COMPUTE: begin
                /* Matrix words are contiguous across all rows in a lane. */
                mat_addr_reg <= mat_addr_reg + 1'b1;

                if (word_count == (vec_words_reg - 1'b1)) begin
                    word_count   <= '0;
                    vec_addr_reg <= vec_start_reg;

                    if (row_count == (mat_rows_reg - 1'b1)) begin
                        row_count <= '0;
                        state     <= IDLE;
                    end
                    else begin
                        row_count <= row_count + 1'b1;
                    end
                end
                else begin
                    word_count   <= word_count + 1'b1;
                    vec_addr_reg <= vec_addr_reg + 1'b1;
                end
            end

            default: begin
                state         <= IDLE;
                vec_addr_reg  <= '0;
                mat_addr_reg  <= '0;
                word_count    <= '0;
                row_count     <= '0;
            end
        endcase
    end
end

assign vec_raddr   = (state == COMPUTE) ? vec_addr_reg : '0;
assign mat_raddr   = (state == COMPUTE) ? mat_addr_reg : '0;
assign accum_first = (state == COMPUTE) && (word_count == 0);
assign accum_last  = (state == COMPUTE) &&
                     (word_count == (vec_words_reg - 1'b1));
assign ovalid      = (state == COMPUTE);
assign busy        = (state == COMPUTE);


/******* Your code ends here ********/

endmodule