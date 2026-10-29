
module matrix_baseline (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [5:0]  c_addr,
    output wire [35:0] c_data,
    output reg         done
);

    localparam IDLE  = 2'd0;
    localparam READ  = 2'd1;
    localparam MAC   = 2'd2;
    localparam STORE = 2'd3;

    reg [1:0] state;
    reg [2:0] i, j, k;

    // Input memories initialized from MIF files
    (* ram_init_file = "matrix_a.mif" *)
    reg [15:0] matrix_a [0:63];

    (* ram_init_file = "matrix_b.mif" *)
    reg [15:0] matrix_b [0:63];

    // Output memory
    reg [35:0] matrix_c [0:63];

    reg signed [15:0] a_data, b_data;
    reg signed [35:0] sum;

    wire signed [31:0] product = a_data * b_data;

    // Row-major address mapping
    wire [5:0] addr_a = {i, k};
    wire [5:0] addr_b = {k, j};
    wire [5:0] addr_c = {i, j};

    // Synchronous ROM reads
    always @(posedge clk) begin
        a_data <= matrix_a[addr_a];
        b_data <= matrix_b[addr_b];
    end

    // Read result from Matrix C
    assign c_data = matrix_c[c_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i     <= 0;
            j     <= 0;
            k     <= 0;
            sum   <= 0;
            done  <= 0;
        end else begin
            case (state)

                IDLE: begin
                    if (start) begin
                        i     <= 0;
                        j     <= 0;
                        k     <= 0;
                        sum   <= 0;
                        done  <= 0;
                        state <= READ;
                    end
                end

                READ: begin
                    state <= MAC;
                end

                MAC: begin
                    sum <= sum + product;

                    if (k == 7) begin
                        state <= STORE;
                    end else begin
                        k     <= k + 1'b1;
                        state <= READ;
                    end
                end

                STORE: begin
                    matrix_c[addr_c] <= sum;
                    sum <= 0;
                    k   <= 0;

                    if (j == 7) begin
                        j <= 0;

                        if (i == 7) begin
                            done  <= 1;
                            state <= IDLE;
                        end else begin
                            i     <= i + 1'b1;
                            state <= READ;
                        end
                    end else begin
                        j     <= j + 1'b1;
                        state <= READ;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
