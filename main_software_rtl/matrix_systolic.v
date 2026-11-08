`timescale 1ns / 1ps

// Four PEs compute one 2x2 tile at a time, covering all sixteen tiles of C=A*B.
module matrix_systolic(
    input clk,
    input rst_n,
    input load_we,
    input load_b,
    input [5:0] load_addr,
    input signed [15:0] load_data,
    input start,
    output busy,
    output reg done,
    input [1:0] read_matrix,
    input [5:0] read_addr,
    output reg signed [34:0] read_data
);

localparam IDLE = 3'd0, CLEAR = 3'd1, READ = 3'd2,
           STEP = 3'd3, STORE = 3'd4;
reg [2:0] state;
reg [1:0] tile_row, tile_col;
reg [3:0] step;
assign busy = state != IDLE;

// Bank A by row parity and B by column parity for two synchronous reads each.
(* ramstyle = "M9K" *) reg signed [15:0] a_even [0:31], a_odd [0:31];
(* ramstyle = "M9K" *) reg signed [15:0] b_even [0:31], b_odd [0:31];
(* ramstyle = "M9K" *) reg signed [34:0] c00 [0:15], c01 [0:15], c10 [0:15], c11 [0:15];
reg signed [15:0] a0_read, a1_read, b0_read, b1_read;
reg signed [34:0] c00_read, c01_read, c10_read, c11_read;
reg [1:0] read_bank, read_matrix_q;
// Prefetch the next k while the PEs consume the current synchronous RAM output.
wire [2:0] read_k = state == STEP ? step[2:0] + 3'd1 : 3'd0;
wire [4:0] a_read_addr = busy ? {tile_row, read_k} : {read_addr[5:4], read_addr[2:0]};
wire [4:0] b_read_addr = busy ? {read_k, tile_col} : read_addr[5:1];
wire [4:0] a_load_addr = {load_addr[5:4], load_addr[2:0]};
wire [3:0] c_read_addr = {read_addr[5:4], read_addr[2:1]};

reg signed [15:0] a0_right, b0_down, a1_right, b1_down;
reg signed [15:0] a1_skew, b1_skew;
reg signed [34:0] sum00, sum01, sum10, sum11;
wire signed [15:0] a0_in = step < 8 ? a0_read : 16'sd0;
wire signed [15:0] b0_in = step < 8 ? b0_read : 16'sd0;
wire signed [31:0] product00 = a0_in * b0_in;
wire signed [31:0] product01 = a0_right * b1_skew;
wire signed [31:0] product10 = a1_skew * b0_down;
wire signed [31:0] product11 = a1_right * b1_down;

// Memories have no reset so Quartus can implement them in embedded RAM.
always @(posedge clk) begin
    if (load_we && !busy) begin
        if (load_b) begin
            if (load_addr[0]) b_odd[load_addr[5:1]] <= load_data;
            else b_even[load_addr[5:1]] <= load_data;
        end else begin
            if (load_addr[3]) a_odd[a_load_addr] <= load_data;
            else a_even[a_load_addr] <= load_data;
        end
    end
    a0_read <= a_even[a_read_addr];
    a1_read <= a_odd[a_read_addr];
    b0_read <= b_even[b_read_addr];
    b1_read <= b_odd[b_read_addr];

    if (state == STORE) begin
        c00[{tile_row, tile_col}] <= sum00;
        c01[{tile_row, tile_col}] <= sum01;
        c10[{tile_row, tile_col}] <= sum10;
        c11[{tile_row, tile_col}] <= sum11;
    end
    c00_read <= c00[c_read_addr];
    c01_read <= c01[c_read_addr];
    c10_read <= c10[c_read_addr];
    c11_read <= c11[c_read_addr];
    read_bank <= {read_addr[3], read_addr[0]};
    read_matrix_q <= read_matrix;
end

always @* begin
    case (read_matrix_q)
        2'd1: read_data = read_bank[1] ? a1_read : a0_read;
        2'd2: read_data = read_bank[0] ? b1_read : b0_read;
        default: case (read_bank)
            2'b00: read_data = c00_read;
            2'b01: read_data = c01_read;
            2'b10: read_data = c10_read;
            default: read_data = c11_read;
        endcase
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        tile_row <= 0;
        tile_col <= 0;
        step <= 0;
        done <= 0;
        a0_right <= 0;
        b0_down <= 0;
        a1_right <= 0;
        b1_down <= 0;
        a1_skew <= 0;
        b1_skew <= 0;
        sum00 <= 0;
        sum01 <= 0;
        sum10 <= 0;
        sum11 <= 0;
    end else begin
        done <= 0;
        case (state)
            IDLE: if (start) begin
                tile_row <= 0;
                tile_col <= 0;
                state <= CLEAR;
            end
            CLEAR: begin
                step <= 0;
                a0_right <= 0;
                b0_down <= 0;
                a1_right <= 0;
                b1_down <= 0;
                a1_skew <= 0;
                b1_skew <= 0;
                sum00 <= 0;
                sum01 <= 0;
                sum10 <= 0;
                sum11 <= 0;
                state <= READ;
            end
            READ: state <= STEP;
            STEP: begin
                // A moves right and B moves down; skew the second row/column.
                sum00 <= sum00 + product00;
                sum01 <= sum01 + product01;
                sum10 <= sum10 + product10;
                sum11 <= sum11 + product11;
                a0_right <= a0_in;
                b0_down <= b0_in;
                a1_right <= a1_skew;
                b1_down <= b1_skew;
                a1_skew <= step < 8 ? a1_read : 16'sd0;
                b1_skew <= step < 8 ? b1_read : 16'sd0;
                if (step == 9) state <= STORE;
                else begin
                    step <= step + 1'b1;
                end
            end
            STORE: begin
                if (tile_col == 3) begin
                    tile_col <= 0;
                    if (tile_row == 3) begin
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        tile_row <= tile_row + 1'b1;
                        state <= CLEAR;
                    end
                end else begin
                    tile_col <= tile_col + 1'b1;
                    state <= CLEAR;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
