// Three retained Fr lanes; commands are sampled only when idle. One Fr
// multiplier serves every x^5 and every entry of the row-major MDS product.
module eeg_poseidon (
    input wire clk, rst, begin_window, absorb,
    input wire [15:0] window_index,
    input wire [127:0] nonce,
    input wire [254:0] blind,
    input wire [249:0] word_in,
    output wire idle,
    output reg done,
    output wire [254:0] digest
);
    localparam [254:0] P = 255'h73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;
    reg [254:0] ark [0:194];
    reg [254:0] mds [0:8];
    initial begin
        $readmemh("params/ark.hex", ark);
        $readmemh("params/mds.hex", mds);
    end

    localparam [2:0] IDLE=0, ARK=1, SBOX_GO=2, SBOX_WAIT=3, MDS_GO=4, MDS_WAIT=5;
    reg [2:0] phase;
    reg [6:0] round_no;
    reg [7:0] ark_addr;
    reg [3:0] mds_addr;
    reg [1:0] lane, power_step, row_no, col_no;
    reg [254:0] x [0:2];
    reg [254:0] row0, row1, partial;
    assign idle = (phase == IDLE);
    assign digest = x[0];

    wire [254:0] product;
    wire mul_done;
    wire mix = (phase == MDS_GO);
    wire [254:0] mul_a = mix ? x[col_no] : (power_step == 0 ? x[lane] : product);
    wire [254:0] mul_b = mix ? mds[mds_addr] : (power_step == 1 ? product : x[lane]);
    fr_mul multiplier (.clk(clk), .rst(rst), .go(mix || phase == SBOX_GO),
        .a(mul_a), .b(mul_b), .product(product), .done(mul_done));

    // One modular adder shared by absorption, round constants and dot products.
    wire [254:0] add_a = phase == ARK ? x[lane] : (phase == MDS_WAIT ? partial : x[0]);
    wire [254:0] add_b = phase == ARK ? ark[ark_addr] : (phase == MDS_WAIT ? product : {5'b0, word_in});
    wire [255:0] sum = {1'b0, add_a} + {1'b0, add_b};
    wire [255:0] reduced = sum - {1'b0, P};
    wire [254:0] add_result = reduced[255] ? sum[254:0] : reduced[254:0];
    wire full_round = round_no < 4 || round_no >= 61;

    always @(posedge clk) begin
        if (rst) begin
            phase <= IDLE;
            round_no <= 0;
            ark_addr <= 0;
            mds_addr <= 0;
            lane <= 0;
            power_step <= 0;
            row_no <= 0;
            col_no <= 0;
            x[0] <= 0;
            x[1] <= 0;
            x[2] <= 0;
            row0 <= 0;
            row1 <= 0;
            partial <= 0;
            done <= 0;
        end else begin
            done <= 0;
            case (phase)
                IDLE: if (begin_window || absorb) begin
                    if (begin_window) begin
                        x[0] <= {207'b0, window_index, 32'h45454701};
                        x[1] <= {127'b0, nonce};
                        x[2] <= blind;
                    end else x[0] <= add_result;
                    round_no <= 0;
                    ark_addr <= 0;
                    lane <= 0;
                    phase <= ARK;
                end
                ARK: begin
                    x[lane] <= add_result;
                    ark_addr <= ark_addr + 1'b1;
                    if (lane == 2) begin
                        lane <= 0;
                        power_step <= 0;
                        phase <= SBOX_GO;
                    end else lane <= lane + 1'b1;
                end
                SBOX_GO: phase <= SBOX_WAIT;
                SBOX_WAIT: if (mul_done) begin
                    if (power_step != 2) begin
                        power_step <= power_step + 1'b1;
                        phase <= SBOX_GO;
                    end else begin
                        x[lane] <= product;
                        power_step <= 0;
                        if (full_round && lane != 2) begin
                            lane <= lane + 1'b1;
                            phase <= SBOX_GO;
                        end else begin
                            row_no <= 0;
                            col_no <= 0;
                            mds_addr <= 0;
                            partial <= 0;
                            phase <= MDS_GO;
                        end
                    end
                end
                MDS_GO: phase <= MDS_WAIT;
                MDS_WAIT: if (mul_done) begin
                    if (col_no != 2) begin
                        partial <= add_result;
                        col_no <= col_no + 1'b1;
                        mds_addr <= mds_addr + 1'b1;
                        phase <= MDS_GO;
                    end else if (row_no != 2) begin
                        if (row_no == 0) row0 <= add_result;
                        else row1 <= add_result;
                        partial <= 0;
                        row_no <= row_no + 1'b1;
                        col_no <= 0;
                        mds_addr <= mds_addr + 1'b1;
                        phase <= MDS_GO;
                    end else begin
                        x[0] <= row0;
                        x[1] <= row1;
                        x[2] <= add_result;
                        if (round_no == 64) begin
                            done <= 1;
                            phase <= IDLE;
                        end else begin
                            round_no <= round_no + 1'b1;
                            lane <= 0;
                            phase <= ARK;
                        end
                    end
                end
                default: phase <= IDLE;
            endcase
        end
    end
endmodule
