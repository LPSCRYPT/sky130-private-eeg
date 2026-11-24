// Both interfaces run against independent external roots, not a hash model
// in this testbench. All fixtures below are public, including their blinds.
module tb_capture;
    localparam integer SLOT_PERIOD = 22000;   // 250 Hz at 5.5 MHz
    localparam integer FINAL_TAIL = 212993;   // last tick -> published root
    localparam [254:0] P = 255'h73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;
    reg clk = 0;
    always #1 clk = ~clk;
    integer cycles = 0;
    always @(posedge clk) cycles <= cycles + 1;

    reg rst=1, start=0, slot_tick=0, sample_valid=0;
    reg [23:0] sample_raw=0;
    reg [15:0] window_index=0;
    reg [127:0] nonce=42;
    reg [254:0] blind=100;
    wire busy, ready, root_valid;
    wire [254:0] root;
    eeg_capture core (.*);

    reg harness_rst=1, strobe=0;
    reg [2:0] op=0;
    reg [7:0] din=0;
    wire [7:0] dout;
    wire harness_busy, harness_ready, harness_valid;
    eeg_challenge harness (.clk(clk), .rst(harness_rst), .strobe(strobe),
        .op(op), .din(din), .dout(dout), .busy(harness_busy),
        .ready(harness_ready), .root_valid(harness_valid));

    reg [254:0] expected0, expected1, expected_missing;
    function automatic [23:0] fixture_sample(input integer t, input integer idx);
        if (idx == 0 && t < 4) fixture_sample = 24'h800000;
        else if (idx == 1 && t < 5) fixture_sample = 24'h7fffff;
        else fixture_sample = 24'((t*73 + idx*11) % 'h700000);
    endfunction

    // Tasks enter and leave on a falling edge; inputs settle before sampling.
    task automatic advance;
        @(negedge clk);
    endtask
    task automatic must_be_empty;
        if ({busy,ready,root_valid,root} !== 0) $fatal(1, "core did not wipe/abort");
    endtask
    task automatic launch;
        start=1; advance(); start=0;
        if ({busy,ready,root_valid} !== 3'b110 || root !== 0) $fatal(1, "start failed");
    endtask
    task automatic harness_cmd(input reg [2:0] command, input reg [7:0] value);
        strobe=1; op=command; din=value; advance(); strobe=0;
    endtask
    task automatic load_fixture1;
        reg [399:0] packet;
        integer i;
        begin
            packet = {256'd101, 128'd42, 16'd1};
            for (i=0; i<50; i=i+1) harness_cmd(0, packet[8*i +: 8]);
            harness_cmd(1, 0);
            if ({harness_busy,harness_ready,harness_valid} !== 3'b110) $fatal(1, "loader start failed");
        end
    endtask

    task automatic direct_fixture(input bit missing, input reg [254:0] expected);
        integer i, arm, last_tick;
        begin
            launch(); arm=cycles;
            for (i=0; i<500; i=i+1) begin
                if (ready !== 1'b1 || root_valid !== 1'b0) $fatal(1, "core slot %0d not serviceable", i);
                slot_tick=1;
                sample_valid=!(missing && i==7);
                sample_raw=sample_valid ? fixture_sample(i,0) : 24'hdeadbe;
                advance(); slot_tick=0;
                if (i != 499) repeat (SLOT_PERIOD-1) advance();
            end
            last_tick=cycles;
            if (last_tick-arm != 1+499*SLOT_PERIOD || ready !== 1'b0 || busy !== 1'b1)
                $fatal(1, "wrong capture schedule");
            while (root_valid === 1'b0 && cycles-last_tick <= FINAL_TAIL) advance();
            if ({busy,ready,root_valid} !== 3'b001 || root !== expected || cycles-last_tick != FINAL_TAIL)
                $fatal(1, "core missing=%0d root=%064h expected=%064h tail=%0d", missing, root, expected, cycles-last_tick);
            $display("PASS core missing=%0d slots=500 spacing=%0d arm_to_root=%0d last_tick_to_root=%0d root=%064h",
                     missing, SLOT_PERIOD, cycles-arm, cycles-last_tick, root);
        end
    endtask

    task automatic byte_fixture;
        integer i, arm, last_tick;
        reg [23:0] raw;
        reg [255:0] collected;
        begin
            load_fixture1(); arm=cycles;
            for (i=0; i<500; i=i+1) begin
                if (harness_ready !== 1'b1 || harness_valid !== 1'b0) $fatal(1, "loader slot %0d not serviceable", i);
                raw = fixture_sample(i,1);
                harness_cmd(2,raw[7:0]); harness_cmd(2,raw[15:8]); harness_cmd(2,raw[23:16]); harness_cmd(3,0);
                if (i != 499) repeat (SLOT_PERIOD-4) advance();
            end
            last_tick=cycles;
            if (last_tick-arm != 4+499*SLOT_PERIOD || harness_ready !== 1'b0 || harness_busy !== 1'b1)
                $fatal(1, "wrong byte harness schedule");
            while (harness_valid === 1'b0 && cycles-last_tick <= FINAL_TAIL) advance();
            if ({harness_busy,harness_ready,harness_valid} !== 3'b001 || cycles-last_tick != FINAL_TAIL)
                $fatal(1, "wrong harness completion");
            for (i=0; i<32; i=i+1) begin
                harness_cmd(5,i[7:0]); collected[8*i +: 8]=dout;
            end
            if (collected !== {1'b0,expected1}) $fatal(1, "harness root=%064h expected=%064h", collected, expected1);
            $display("PASS byte harness slots=500 spacing=%0d last_tick_to_root=%0d root=%064h", SLOT_PERIOD, FINAL_TAIL, collected);
        end
    endtask

    integer t;
    initial begin
        if (!$value$plusargs("ROOT0=%h",expected0) || !$value$plusargs("ROOT1=%h",expected1) ||
            !$value$plusargs("ROOT_MISSING=%h",expected_missing))
            $fatal(1, "supply independent +ROOT0=<hex> +ROOT1=<hex> +ROOT_MISSING=<hex>");
        if (expected0 === expected1 || expected0 === expected_missing) $fatal(1, "distinct roots required");
        advance(); rst=0; must_be_empty();
        blind=P; start=1; advance(); start=0; must_be_empty(); blind=100;
        // Start and tick cannot coincide. A second start cannot replace an active window.
        start=1; slot_tick=1; advance(); start=0; slot_tick=0; must_be_empty();
        launch(); start=1; advance(); start=0; must_be_empty();
        // Nineteen contiguous slots fit during init. The twentieth cannot be
        // buffered, even if missing: it must abort, never stall or be skipped.
        launch(); slot_tick=1; sample_valid=1; sample_raw=24'hffffff;
        for (t=0; t<19; t=t+1) begin
            if (ready !== 1'b1) $fatal(1, "burst rejected prematurely");
            advance();
        end
        if (ready !== 1'b0) $fatal(1, "overrun not signaled");
        sample_valid=0; advance(); slot_tick=0; must_be_empty();
        // Reset after a packed word has entered the permutation, then restart.
        launch(); slot_tick=1; repeat(10) advance(); slot_tick=0;
        repeat(214000) advance(); rst=1; advance(); rst=0; must_be_empty();
        direct_fixture(0,expected0);
        repeat(3) advance();
        if (root_valid !== 1'b1 || root !== expected0) $fatal(1, "root not held until next start/reset");
        direct_fixture(1,expected_missing);
        rst=1; advance(); must_be_empty();

        harness_rst=0;
        load_fixture1(); harness_cmd(2,8'h12); harness_cmd(3,0);
        if ({harness_busy,harness_ready,harness_valid,dout} !== 0) $fatal(1, "malformed present tick accepted");
        byte_fixture(); harness_rst=1; advance();
        if ({harness_busy,harness_ready,harness_valid,dout} !== 0) $fatal(1, "harness reset did not wipe");
        $display("PASS all capture, reset, overrun and wrapper checks");
        $finish;
    end
endmodule
