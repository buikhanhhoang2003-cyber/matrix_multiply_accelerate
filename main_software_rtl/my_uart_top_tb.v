`timescale 1ns / 1ps

module my_uart_top_tb;
localparam integer BIT_NS = 5208 * 20;
localparam [79:0] DIGIT_SEGMENTS = 80'h90_80_f8_82_92_99_b0_a4_f9_c0;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg mode_sw_n = 1'b1;
reg rs232_rx = 1'b1;
reg expect_tx_idle = 1'b1;
wire rs232_tx;
wire [7:0] seg_n;
wire [3:0] digit_n;
integer i;

always #10 clk = !clk;

my_uart_top dut(
    .clk_50mhz(clk), .reset_n(rst_n), .key_n({3'b111, mode_sw_n}),
    .uart_rx(rs232_rx), .uart_tx(rs232_tx),
    .seg_n(seg_n), .digit_n(digit_n)
);

always @(negedge rs232_tx)
    if (rst_n && expect_tx_idle)
        $fatal(1, "UART transmitted in receive mode");

task send_frame;
    input [7:0] data;
    input stop_bit;
    integer bit_index;
    begin
        rs232_rx = 1'b0;
        #(BIT_NS);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            rs232_rx = data[bit_index];
            #(BIT_NS);
        end
        rs232_rx = stop_bit;
        #(BIT_NS);
        rs232_rx = 1'b1;
    end
endtask

task check_display;
    input [7:0] segments;
    begin
        if (digit_n !== 4'b1110 || seg_n !== segments)
            $fatal(1, "Display: digits=%b segments=%h, expected DIG1 / %h",
                   digit_n, seg_n, segments);
    end
endtask

task read_a;
    input switch_off;
    reg [7:0] data;
    integer bit_index;
    begin
        @(negedge rs232_tx);
        #(BIT_NS / 2);
        if (rs232_tx !== 1'b0)
            $fatal(1, "TX start bit too short");
        if (switch_off)
            mode_sw_n = 1'b1;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            #(BIT_NS);
            data[bit_index] = rs232_tx;
        end
        #(BIT_NS);
        if (data !== 8'h41 || rs232_tx !== 1'b1)
            $fatal(1, "Expected A with a valid stop bit, got %h", data);
        #(BIT_NS / 2);
    end
endtask

initial begin
    #100;
    rst_n = 1'b1;
    #200;
    if (digit_n !== 4'b1111 || rs232_tx !== 1'b1)
        $fatal(1, "Reset must leave the display blank and TX idle");

    // A non-clock-aligned stream with exactly one stop bit between digits.
    #137;
    for (i = 0; i < 10; i = i + 1) begin
        send_frame(8'h30 + i, 1'b1);
        check_display(DIGIT_SEGMENTS[i*8 +: 8]);
    end
    send_frame(8'h41, 1'b1);
    send_frame(8'h09, 1'b1);
    send_frame(8'h0d, 1'b1);
    send_frame(8'h0a, 1'b1);
    check_display(8'h90);

    // A bad stop bit and a short start glitch must not update the display.
    send_frame(8'h36, 1'b0);
    #(BIT_NS);
    check_display(8'h90);
    rs232_rx = 1'b0;
    #(BIT_NS / 4);
    rs232_rx = 1'b1;
    #(BIT_NS);
    check_display(8'h90);
    send_frame(8'h32, 1'b1);
    check_display(8'ha4);

    expect_tx_idle = 1'b0;
    mode_sw_n = 1'b0;
    #200;
    if (digit_n !== 4'b1111)
        $fatal(1, "Transmit mode must blank the display");
    fork
        begin
            read_a(1'b0);
            read_a(1'b0);
            // Switching off mid-frame must still send all of this A.
            read_a(1'b1);
        end
        send_frame(8'h37, 1'b1);
    join
    expect_tx_idle = 1'b1;
    #(BIT_NS * 2);
    check_display(8'ha4);
    send_frame(8'h35, 1'b1);
    check_display(8'h92);

    // Reset in the middle of transmission, then receive again.
    expect_tx_idle = 1'b0;
    mode_sw_n = 1'b0;
    @(negedge rs232_tx);
    #(BIT_NS * 2);
    rst_n = 1'b0;
    mode_sw_n = 1'b1;
    #100;
    if (rs232_tx !== 1'b1 || digit_n !== 4'b1111)
        $fatal(1, "Reset failed during transmission");
    rst_n = 1'b1;
    #200;
    expect_tx_idle = 1'b1;
    send_frame(8'h34, 1'b1);
    check_display(8'h99);

    $display("PASS: digits 0-9, continuous A, mode changes, invalid frames and reset");
    $finish;
end

initial begin
    #(BIT_NS * 1000);
    $fatal(1, "Simulation timed out");
end
endmodule
