`timescale 1ns / 1ps
`define P 20

/* Small self-contained testbench: 10 regular + 10 edge cases, no external files.
 * Message byte k of every test is (7*k + 1) mod 256; expected digests are the
 * original-Keccak-512 (0x01 padding) values for those messages. */
module test_keccak_small;

    reg          clk, reset;
    reg  [63:0]  in;
    reg          in_ready, is_last;
    reg  [2:0]   byte_num;
    wire         buffer_full;
    wire [511:0] out;
    wire         out_ready;

    integer pass, fail;

    keccak uut (
        .clk(clk), .reset(reset), .in(in), .in_ready(in_ready),
        .is_last(is_last), .byte_num(byte_num), .buffer_full(buffer_full),
        .out(out), .out_ready(out_ready)
    );

    always #(`P/2) clk = ~clk;

    function [7:0] msg_byte;
        input integer k;
        begin
            msg_byte = k * 7 + 1;      // truncated to 8 bits
        end
    endfunction

    /* Present one word and wait until the core has taken it (inputs change on the
     * falling edge; buffer_full is a register, so 0 here means "accepted"). */
    task drive_word;
        input [63:0] w_in;
        input        last;
        input [2:0]  bn;
        begin
            in_ready = 0;
            while (buffer_full === 1'b1) @(negedge clk);
            in = w_in; byte_num = bn; is_last = last; in_ready = 1;
            @(negedge clk);
        end
    endtask

    /* Reset, send an n-byte message, wait for the digest, compare. */
    task hash_test;
        input integer n;
        input         is_edge;
        input [511:0] expected;
        integer nfull, j, q, timeout;
        reg [63:0] w;
        begin
            in_ready = 0; is_last = 0;
            reset = 1; @(negedge clk); reset = 0;

            nfull = n / 8;
            for (j = 0; j < nfull; j = j + 1) begin
                w = 64'd0;
                for (q = 0; q < 8; q = q + 1)
                    w[63 - 8*q -: 8] = msg_byte(8*j + q);
                drive_word(w, 1'b0, 3'd0);
            end
            // final word: the n%8 leftover bytes, left-aligned (empty if n%8 == 0)
            w = 64'd0;
            for (q = 0; q < n % 8; q = q + 1)
                w[63 - 8*q -: 8] = msg_byte(8*nfull + q);
            drive_word(w, 1'b1, n % 8);
            in_ready = 0; is_last = 0;

            timeout = 0;
            while (out_ready !== 1'b1 && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if (out_ready !== 1'b1) begin
                $display("FAIL len=%0d%s: out_ready never rose", n, is_edge ? " (edge)" : "");
                fail = fail + 1;
            end else if (out !== expected) begin
                $display("FAIL len=%0d%s\n  got %h\n  exp %h", n, is_edge ? " (edge)" : "", out, expected);
                fail = fail + 1;
            end else begin
                $display("pass len=%0d%s", n, is_edge ? " (edge)" : "");
                pass = pass + 1;
            end
        end
    endtask

    initial begin
        clk = 0; reset = 0; in = 0; in_ready = 0; is_last = 0; byte_num = 0;
        pass = 0; fail = 0;
        #100;
        @(negedge clk);

        // hash_test(length_bytes, is_edge, expected_digest)
        // ---- 10 regular cases ----
        // ---- 10 edge cases: empty, 71 / 72 / 73 bytes (block boundary), 144 (two blocks) ----
        hash_test(  1, 0, 512'h9e8ca28141be27be1bbc11e5d4304514c548d3ea99a058a9a6802ea4e2357b91c4df65bd97353aa37369d3d74b47ca0902fd197b4171a3297d8c5cee41bba240);
        hash_test(  5, 0, 512'hee07f44607fe30680c5493b219dacbdb0b627cf97b7e1743760caf8312611f051088c7cf2fadd38beeae8ba135cd1402de57ee0061e3dde59db852b688511168);
        hash_test(  8, 0, 512'h00cb6b4f2a925496c3ee414298da657872358ea9ba8a7792ae572bee57d645f51d1cb21ff95d1c0b6789872820b891fac5d421d8ffa9fac5bc393a786aaf757c);
        hash_test( 16, 0, 512'hc9e9a361b48e22b47ee1d9b35e1a069dc52dbc6ae13ee87d855df9e4c8621321a797a4dfde43321f52d42f880debbfd7626f09fedf7a4f927a207e14b8053f23);
        hash_test( 33, 0, 512'h79c4f9f2a8a9e934e0d4812b0a9b409b16c66647d7792637cf86a79220d6ddfcd5df7bcbf0d6f21f71b336e6624f131b7ee0d4e60c9c6acfeda3402cc6dfa8a6);
        hash_test( 50, 0, 512'h3c4958b8dd5b55948111ae71f2a6ea8abd09ad57c48cffdc1eb1d566b42a359e9141da2dd8251ad7609f9457fd38ac91d1efb1f7f091493065383a401a91b577);
        hash_test(100, 0, 512'h0738e4a5bf1c6dbaabadedb4d2ad46cc73a6d84e9e34ea7771f6b7f24f510d8c16634a5222fa047d66bdbc333d24e623aa8a89dfa74184ccde99ce3508f79e42);
        hash_test(120, 0, 512'h55eabd775b2bc9e934bdf609f9be6ed1955d6ce1a58c82591782366525fec8f376b616292e2f193d50aa7b843f15172c345e339a6e4e742a0f72442190497d63);
        hash_test(150, 0, 512'h9aaf5349c93573d737ccf4509ec9f785dbed21ef6543e88b9446c95a6cf528898d66ed1a53bf3a5f8b9350b10509cb786e80b7cdfdac9e7bd01cf42d5abc4dd3);
        hash_test(200, 0, 512'he543c2be968e2aac4cee3e2125f3863593f12d26615c54717c94f7b2b51eaa6a9f2131bd66280a24f8b0c536e56c0b807ce50b088b5949120804a9ebacc38645);
        hash_test(  0, 1, 512'h0eab42de4c3ceb9235fc91acffe746b29c29a8c366b7c60e4e67c466f36a4304c00fa9caf9d87976ba469bcbe06713b435f091ef2769fb160cdab33d3670680e);
        hash_test( 71, 1, 512'h34910be49b70462bb8ef8df0c64e9d66d6ab341c914b5af1acedd3168e83b2d4fcfa75aad03a4407e4d1add2e7f11cf46588da6fa86add4028146bd79aee6f31);
        hash_test( 72, 1, 512'hf4543c426e3521c5079911da94a75a6d14897039742677e383b3a09bbbb14365cc9eee0a138fe35f3a390d6da073e2ec15398808a1cb2d72a8f9d5a6ed537792);
        hash_test( 73, 1, 512'hcd91b596d500c274fbce67fb146c17acb3244d3e729dcc3929ccca972d3340582604ea0eb0228e290ba9c25e6b9209a9147e1a2101d38ee6c9d740fcac36d15c);
        hash_test(144, 1, 512'h44d41e6ebdf4062014cf772c9cbc9abe6ab040b696f288af5f0bfcc7d0889c855274d6dd7192ffecfda77d68a1ce00c69e68550640f88fffe59009e47baaf618);
        hash_test( 64, 1, 512'h47566762b31eeff4a6f6b7e20df89850ba9b0dab16e9527883ca51a6d78c58b4ea8c910f8898fec8c52d30ec8893708cfdf9f5d4e5f10a67bb17eaf40fc14792);
        hash_test( 70, 1, 512'h3b6bde1e3c13ddb392fea526c2d003455129db9cb2921a001389fb650443700620f6a8b95046fb8e71d1a4d7fa2de4cebf9f24399c402e8cf4a495f0c70e26b3);
        hash_test(143, 1, 512'h378653b6e80672d897a6737978df934fa249a27ec9e229ec5c7320b04d7b26bf049a22933870a091298eafedb560513434a82e80967564d17fe28f1f453c0f9b);
        hash_test(145, 1, 512'h7d0ba086039a795dc51c885475ceb00a20e52b4a2df68eed609641e9fb6725fc442742e86947763882abe95100731fd73bd0dcff1ebb9044822d4632dfa48bd9);
        hash_test(216, 1, 512'hee284963a924534386aaa9677a672d02a12aa7d8860efdf7a936f0fd1bfbfbce9e48831dc86935dc6387623678f2323f9d5fc18265170f4b6783f11422c75299);

        if (fail == 0) $display("ALL %0d TESTS PASSED", pass);
        else           $display("%0d PASSED, %0d FAILED", pass, fail);
        $finish;
    end

endmodule

`undef P