// Private parallel capture boundary. Slot order comes from the trusted tick,
// not the sample-valid bit. The only sample-dependent output is the digest.
module eeg_capture (
    input wire clk, rst, start,
    input wire [127:0] nonce,
    input wire [15:0] window_index,
    input wire [254:0] blind,
    input wire slot_tick, sample_valid,
    input wire [23:0] sample_raw,
    output reg busy,
    output wire ready,
    output reg root_valid,
    output reg [254:0] root
);
    localparam [254:0] P = 255'h73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;
    reg [224:0] pack_tail;
    reg [3:0] slot_in_word;
    reg [249:0] pending_word;
    reg pending;
    reg [5:0] words_captured, words_issued;
    wire perm_idle, perm_done;
    wire [254:0] digest;
    wire issue_word = busy && pending && perm_idle;
    assign ready = busy && words_captured < 50 &&
                   (slot_in_word != 9 || !pending || issue_word);
    wire reject = (start && (busy || slot_tick || blind >= P)) ||
                  (busy && slot_tick && !ready);
    wire publish = busy && perm_done && words_issued == 50;
    wire [24:0] slot_code = sample_valid ? {1'b1, sample_raw} : 25'b0;

    eeg_poseidon engine (.clk(clk), .rst(rst || reject || publish),
        .begin_window(start && !busy), .absorb(issue_word),
        .window_index(window_index), .nonce(nonce), .blind(blind),
        .word_in(pending_word), .idle(perm_idle), .done(perm_done), .digest(digest));

    always @(posedge clk) begin
        if (rst || reject || publish) begin
            // The same edge that latches a finished root clears the private
            // state, including all controller/multiplier scratch registers.
            root_valid <= publish && !rst && !reject;
            root <= (publish && !rst && !reject) ? digest : 255'b0;
            busy <= 0;
            pack_tail <= 0;
            slot_in_word <= 0;
            pending_word <= 0;
            pending <= 0;
            words_captured <= 0;
            words_issued <= 0;
        end else if (start) begin
            root <= 0;
            root_valid <= 0;
            busy <= 1;
        end else if (busy) begin
            if (issue_word) begin
                words_issued <= words_issued + 1'b1;
                pending <= 0;
                pending_word <= 0;
            end
            if (slot_tick) begin
                if (slot_in_word == 9) begin
                    // Old pending_word may be consumed on this same edge.
                    pending_word <= {slot_code, pack_tail};
                    pending <= 1;
                    pack_tail <= 0;
                    slot_in_word <= 0;
                    words_captured <= words_captured + 1'b1;
                end else begin
                    pack_tail <= {slot_code, pack_tail[224:25]};
                    slot_in_word <= slot_in_word + 1'b1;
                end
            end
        end
    end
endmodule
