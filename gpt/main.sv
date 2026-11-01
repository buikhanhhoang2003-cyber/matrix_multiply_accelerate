
module matrix_board_top (
    input  wire clk,
    input  wire rst_n,
    output wire led_pass_n,
    output wire led_fail_n
);

    reg start;
    reg started;
    reg checking;
    reg finished;
    reg mismatch;

    reg [5:0] c_addr;
    reg [10:0] timer;

    wire [35:0] c_data;
    wire done;

    wire signed [35:0] row_idx = {33'b0, c_addr[5:3]};
    wire signed [35:0] col_idx = {33'b0, c_addr[2:0]};

    wire signed [35:0] expected =
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

    always @(posedge clk or negedge rst_n) begin
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
