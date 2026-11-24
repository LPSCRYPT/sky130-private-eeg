// Public replay bridge: exercise the actual capture port on the same slots,
// challenge and blinds as the authenticated proof manifest. Never use subject data.
module tb_record;
    reg clk=0, rst=1, start=0, slot_tick=0, sample_valid=0;
    always #1 clk=~clk;
    reg [127:0] nonce=0;
    reg [15:0] window_index=0;
    reg [254:0] blind=0;
    reg [23:0] sample_raw=0;
    wire busy, ready, root_valid;
    wire [254:0] root;
    eeg_capture dut (.*);
    string path;
    integer fd, count, i, j, elapsed;
    reg [254:0] expected;
    reg [24:0] word_in;
    initial begin
        if (!$value$plusargs("PUBLIC_FIXTURE=%s",path)) $fatal(1,"missing test vector path");
        fd=$fopen(path,"r");
        if (fd==0 || $fscanf(fd,"%d %h",count,nonce)!=2 || count<1 || count>65535)
            $fatal(1,"invalid replay header");
        @(negedge clk); rst=0;
        for(i=0;i<count;i=i+1) begin
            if ($fscanf(fd,"%h %h",blind,expected)!=2) $fatal(1,"invalid window header");
            window_index=i[15:0]; start=1; @(negedge clk); start=0;
            for(j=0;j<500;j=j+1) begin
                if (!ready || root_valid || $fscanf(fd,"%h",word_in)!=1) $fatal(1,"bad slot %0d:%0d",i,j);
                {sample_valid,sample_raw}=word_in; slot_tick=1; @(negedge clk); slot_tick=0;
                if(j!=499) repeat(21999) @(negedge clk);
            end
            elapsed=0;
            while(!root_valid && elapsed<213000) begin @(negedge clk); elapsed=elapsed+1; end
            if(!root_valid || busy || root !== expected) $fatal(1,"manifest root mismatch for window %0d",i);
            $display("PASS signed-manifest replay window=%0d root=%064h",i,root);
        end
        $fclose(fd); $finish;
    end
endmodule
