// Fixed-latency shift/add multiplication of canonical BLS12-381 Fr elements.
// A go edge loads operands; done is asserted 255 rising edges later.
module fr_mul (
    input wire clk, rst, go,
    input wire [254:0] a, b,
    output reg [254:0] product,
    output reg done
);
    localparam [254:0] P = 255'h73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;
    reg [254:0] addend, bits_left;
    reg [7:0] steps_left;

    // Both candidates are below 2P. An underflow of the 256-bit
    // subtraction has its top bit set; a successful reduction cannot.
    wire [255:0] sum = {1'b0, product} + {1'b0, addend};
    wire [255:0] sum_minus_p = sum - {1'b0, P};
    wire [255:0] twice = {addend, 1'b0};
    wire [255:0] twice_minus_p = twice - {1'b0, P};
    always @(posedge clk) begin
        if (rst) begin
            addend <= 0;
            bits_left <= 0;
            steps_left <= 0;
            product <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (go) begin
                addend <= a;
                bits_left <= b;
                steps_left <= 8'd255;
                product <= 0;
            end else if (steps_left != 0) begin
                if (bits_left[0]) product <= sum_minus_p[255] ? sum[254:0] : sum_minus_p[254:0];
                addend <= twice_minus_p[255] ? twice[254:0] : twice_minus_p[254:0];
                bits_left <= bits_left >> 1;
                steps_left <= steps_left - 1'b1;
                done <= (steps_left == 1);
            end
        end
    end
endmodule
