
`timescale 1ns/1ps

module tb_matrix_baseline;

    reg clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    reg rst_n = 0;
    reg start = 0;
    reg [5:0] c_addr = 0;
    wire [35:0] c_data;
    wire done;

    reg signed [15:0] ref_a [0:63];
    reg signed [15:0] ref_b [0:63];
    reg signed [63:0] expected [0:63];

    integer row, col, k, cycles, errors;

    // Instantiate DUT
    matrix_baseline dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .c_addr(c_addr),
        .c_data(c_data),
        .done(done)
    );

    initial begin
        // Step 1: Initialize matrix A and B
        for (row = 0; row < 8; row = row + 1) begin
            for (col = 0; col < 8; col = col + 1) begin
                ref_a[row*8 + col] = row*8 + col - 32;
                ref_b[row*8 + col] = ((row*3 + col*5) % 11) - 5;

                // Simulation-only memory initialization
                dut.matrix_a[row*8 + col] = ref_a[row*8 + col];
                dut.matrix_b[row*8 + col] = ref_b[row*8 + col];
            end
        end

        // Step 2: Calculate golden matrix C
        for (row = 0; row < 8; row = row + 1) begin
            for (col = 0; col < 8; col = col + 1) begin
                expected[row*8 + col] = 0;
                for (k = 0; k < 8; k = k + 1)
                    expected[row*8 + col] =
                        expected[row*8 + col] +
                        $signed(ref_a[row*8 + k]) *
                        $signed(ref_b[k*8 + col]);
            end
        end

        // Step 3: Reset and start
        repeat (3) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;

        // Step 4: Wait until computation completes
        cycles = 0;
        while ((done !== 1'b1) && (cycles < 1300)) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (done !== 1'b1) begin
            $display("FAIL: timeout after %0d cycles", cycles);
            $finish;
        end

        $display("DONE after %0d cycles", cycles);

        // Step 5: Verify all 64 outputs
        errors = 0;

        for (row = 0; row < 8; row = row + 1) begin
            for (col = 0; col < 8; col = col + 1) begin
                c_addr = row*8 + col;
                #1;

                if ($signed(c_data) !== expected[row*8 + col]) begin
                    $display("FAIL C[%0d][%0d]: got %0d expected %0d",
                        row, col, $signed(c_data),
                        expected[row*8 + col]);
                    errors = errors + 1;
                end
            end
        end

        if (errors == 0)
            $display("PASS: All 64 matrix C elements matched");
        else
            $display("FAIL: %0d matrix elements mismatched", errors);

        $finish;
    end

endmodule
