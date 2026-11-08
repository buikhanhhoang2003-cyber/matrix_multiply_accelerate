`timescale 1ns / 1ps

module speed_select #(
    parameter integer CLKS_PER_BIT = 5208
)(
    input clk,
    input rst_n,
    input bps_start,
    output reg clk_bps
);

reg [12:0] count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 0;
        clk_bps <= 0;
    end else begin
        if (!bps_start || count == CLKS_PER_BIT - 1)
            count <= 0;
        else
            count <= count + 1'b1;
        clk_bps <= bps_start && count == (CLKS_PER_BIT / 2) - 1;
    end
end

endmodule
