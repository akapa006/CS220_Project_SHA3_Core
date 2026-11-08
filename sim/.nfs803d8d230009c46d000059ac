`timescale 1ns / 1ps
`define P 20

module test_keccak_vec;

    localparam WBITS  = 64;       // 64 = high-throughput core, 32 = low-throughput core
    localparam WBYTES = WBITS / 8;

    reg          clk, reset;
    reg  [WBITS-1:0] in;
    reg          in_ready, is_last;
    reg  [2:0]   byte_num;
    wire         buffer_full;
    wire [511:0] out;
    wire         out_ready;

    reg [7:0]   bytes   [0:262143];
    reg [31:0]  lens    [0:4095];     // lens[0] = number of vectors
    reg [511:0] digests [0:4095];

    integer nvec, t, off, len, fails, timeout, n_gap;
    reg     gaps;

    keccak uut (
        .clk(clk), .reset(reset), .in(in), .in_ready(in_ready),
        .is_last(is_last), .byte_num(byte_num), .buffer_full(buffer_full),
        .out(out), .out_ready(out_ready)
    );

    always #(`P/2) clk = ~clk;

    /* All inputs change on the falling edge, so the core samples them at the rising edge. */
    task do_reset;
        begin
            in_ready = 0; is_last = 0;
            reset = 1;
            @(negedge clk);
            reset = 0;
        end
    endtask

    /* Present one word and wait until the core has taken it. buffer_full is a
     * register, so if it is 0 at the falling edge the word is accepted. */
    task drive_word;
        input [63:0] w_in;
        input        last;
        input [2:0]  bn;
        begin
            in_ready = 0;
            if (gaps) begin
                n_gap = {$random} % 4;
                repeat (n_gap) @(negedge clk);
            end
            while (buffer_full === 1'b1) @(negedge clk);
            in = w_in; byte_num = bn; is_last = last; in_ready = 1;
            @(negedge clk);
        end
    endtask

    /* Full words first, then ONE final word (is_last=1) with the remaining n%WBYTES
     * bytes left-aligned. If n is a multiple of WBYTES the final word is empty. */
    task send_msg;
        input integer base;
        input integer n;
        integer nfull, j, q;
        reg [63:0] ww;
        begin
            nfull = n / WBYTES;
            for (j = 0; j < nfull; j = j + 1) begin
                ww = 64'd0;
                for (q = 0; q < WBYTES; q = q + 1)
                    ww[WBITS - 1 - 8*q -: 8] = bytes[base + WBYTES*j + q];
                drive_word(ww, 1'b0, 3'd0);
            end
            ww = 64'd0;
            for (q = 0; q < n % WBYTES; q = q + 1)
                ww[WBITS - 1 - 8*q -: 8] = bytes[base + WBYTES*nfull + q];
            drive_word(ww, 1'b1, n % WBYTES);
            in_ready = 0; is_last = 0;
        end
    endtask

    initial begin
        clk = 0; reset = 0; in = 0; in_ready = 0; is_last = 0; byte_num = 0;
        gaps = $test$plusargs("gaps");

        $readmemh("lens.hex",    lens);
        $readmemh("msgs.hex",    bytes);
        $readmemh("digests.hex", digests);
        nvec = lens[0];
        fails = 0; off = 0;

        #100;
        @(negedge clk);

        for (t = 0; t < nvec; t = t + 1) begin
            len = lens[t + 1];
            do_reset;
            send_msg(off, len);

            timeout = 0;
            while (out_ready !== 1'b1 && timeout < 2000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if (out_ready !== 1'b1) begin
                $display("FAIL vec %0d (len %0d): out_ready never rose", t, len);
                fails = fails + 1;
            end else if (out !== digests[t]) begin
                $display("FAIL vec %0d (len %0d)\n  got %h\n  exp %h", t, len, out, digests[t]);
                fails = fails + 1;
            end
            off = off + len;
        end

        if (fails == 0) begin
            if (gaps) $display("ALL %0d VECTORS PASSED (with input gaps)", nvec);
            else      $display("ALL %0d VECTORS PASSED", nvec);
        end else
            $display("%0d of %0d VECTORS FAILED", fails, nvec);
        $finish;
    end

endmodule

`undef P