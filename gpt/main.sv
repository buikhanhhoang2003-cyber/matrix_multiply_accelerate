
module matrix_board_top (
    input  logic clk,
    input  logic rst_n,
    output logic led_pass_n,
    output logic led_fail_n
);

    logic start;
    logic started;
    logic checking;
    logic finished;
    logic mismatch;

    logic [5:0] c_addr;
    logic [10:0] timer;

    logic [35:0] c_data;
    logic done;

    logic signed [35:0] row_idx;
    assign row_idx = {33'b0, c_addr[5:3]};
    logic signed [35:0] col_idx;
    assign col_idx = {33'b0, c_addr[2:0]};

    logic signed [35:0] expected;
    assign expected =
        36'sd64 * row_idx * col_idx
        - 36'sd256 * row_idx
        - 36'sd228 * col_idx
        + 36'sd1248;

    matrix_baseline dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .c_addr(c_addr),
        .c_data(c_data),
        .done(done)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start    <= 0;
            started  <= 0;
            checking <= 0;
            finished <= 0;
            mismatch <= 0;
            c_addr   <= 0;
            timer    <= 0;
        end else begin
            // Start once after reset
            start <= !started;
            started <= 1;

            // Wait for multiplication
            if (done && !checking && !finished) begin
                checking <= 1;
                c_addr <= 0;
            end
            // Compare all 64 results
            else if (checking) begin
                if (c_data != expected)
                    mismatch <= 1;

                if (c_addr == 63) begin
                    checking <= 0;
                    finished <= 1;
                end else begin
                    c_addr <= c_addr + 1'b1;
                end
            end
            // Timeout if DUT never finishes
            else if (!finished) begin
                if (timer == 2000) begin
                    mismatch <= 1;
                    finished <= 1;
                end else begin
                    timer <= timer + 1'b1;
                end
            end
        end
    end

    // Active-low LEDs
    assign led_pass_n = ~(finished && !mismatch);
    assign led_fail_n = ~(finished && mismatch);

endmodule
