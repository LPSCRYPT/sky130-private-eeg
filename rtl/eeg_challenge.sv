// Public-fixture challenge harness only: these pins expose raw inputs and
// the blind. Never bond this loader to a private subject-data capture path.
module eeg_challenge (
    input wire clk, rst, strobe,
    input wire [2:0] op,
    input wire [7:0] din,
    output reg [7:0] dout,
    output wire busy, ready, root_valid
);
    localparam [2:0] CONFIG_BYTE=0, START=1, SAMPLE_BYTE=2, PRESENT=3, MISSING=4, READ_ROOT=5;
    reg [399:0] cfg;
    reg [5:0] cfg_bytes;
    reg [23:0] sample;
    reg [1:0] sample_bytes;
    reg malformed;
    always @* begin
        case (op)
            CONFIG_BYTE: malformed = busy || cfg_bytes >= 50;
            START: malformed = busy || cfg_bytes != 50 || cfg[399];
            SAMPLE_BYTE: malformed = !ready || sample_bytes == 3;
            PRESENT: malformed = !busy || sample_bytes != 3 || !ready;
            MISSING: malformed = !busy || (sample_bytes != 0 && sample_bytes != 3) || !ready;
            READ_ROOT: malformed = !root_valid || din >= 32;
            default: malformed = 1;
        endcase
    end
    wire fault = strobe && malformed;
    wire [254:0] root;
    wire [255:0] root_padded = {1'b0, root};
    eeg_capture capture (.clk(clk), .rst(rst || fault), .start(strobe && op == START),
        .nonce(cfg[143:16]), .window_index(cfg[15:0]), .blind(cfg[398:144]),
        .slot_tick(strobe && (op == PRESENT || op == MISSING)), .sample_valid(op == PRESENT),
        .sample_raw(sample), .busy(busy), .ready(ready), .root_valid(root_valid), .root(root));

    always @(posedge clk) begin
        if (rst || fault) begin
            cfg <= 0;
            cfg_bytes <= 0;
            sample <= 0;
            sample_bytes <= 0;
            dout <= 0;
        end else if (strobe) begin
            case (op)
                CONFIG_BYTE: begin
                    cfg <= {din, cfg[399:8]};
                    cfg_bytes <= cfg_bytes + 1'b1;
                end
                START: begin
                    cfg <= 0;
                    cfg_bytes <= 0;
                    dout <= 0;
                end
                SAMPLE_BYTE: begin
                    sample <= {din, sample[23:8]};
                    sample_bytes <= sample_bytes + 1'b1;
                end
                PRESENT, MISSING: begin
                    sample_bytes <= 0;
                    sample <= 0;
                end
                READ_ROOT: dout <= root_padded[{din[4:0], 3'b0} +: 8];
                default: dout <= 0;
            endcase
        end
    end
endmodule
