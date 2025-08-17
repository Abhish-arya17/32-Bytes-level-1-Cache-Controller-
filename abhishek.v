`timescale 1ns / 1ps

module cache_core (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] address,
    input  wire [31:0] data_in,
    input  wire        read_en,
    input  wire        write_en,
    output reg  [31:0] data_out,
    output wire        hit_flag,
    output reg  [7:0]  hit_count,
    output reg  [7:0]  miss_count
);

    // Parameters
    localparam CACHE_SIZE   = 32;
    localparam WORD_SIZE    = 4;
    localparam SETS         = 8;
    localparam TAG_LEN      = 26;

    // Storage arrays
    reg [TAG_LEN-1:0] tag_mem   [0:SETS-1];
    reg [31:0]        line_data [0:SETS-1];
    reg               valid_bit [0:SETS-1];

    // Memory model
    reg [31:0] backing_mem [0:39];
    integer j;
    initial begin
        for (j=0; j<40; j=j+1)
            backing_mem[j] = j * 32'h4;
    end

    // Address split
    wire [2:0] set_index = address[4:2];
    wire [TAG_LEN-1:0] tag_value = address[31:5];

    // Cache hit check
    assign hit_flag = valid_bit[set_index] && (tag_mem[set_index] == tag_value);

    // State encoding
    localparam ST_IDLE  = 2'b00,
               ST_FETCH = 2'b01,
               ST_STORE = 2'b10;

    reg [1:0] state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (j=0; j<SETS; j=j+1) begin
                valid_bit[j] <= 1'b0;
                tag_mem[j]   <= 0;
                line_data[j] <= 0;
            end
            hit_count  <= 0;
            miss_count <= 0;
            data_out   <= 0;
            state      <= ST_IDLE;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (read_en) begin
                        if (hit_flag) begin
                            data_out   <= line_data[set_index];
                            hit_count  <= hit_count + 1;
                        end else begin
                            miss_count <= miss_count + 1;
                            state      <= ST_FETCH;
                        end
                    end else if (write_en) begin
                        if (hit_flag) begin
                            line_data[set_index] <= data_in;
                        end
                        state <= ST_STORE;
                    end
                end

                ST_FETCH: begin
                    line_data[set_index] <= backing_mem[address[31:2]];
                    tag_mem[set_index]   <= tag_value;
                    valid_bit[set_index] <= 1'b1;
                    data_out             <= backing_mem[address[31:2]];
                    state                <= ST_IDLE;
                end

                ST_STORE: begin
                    backing_mem[address[31:2]] <= data_in;
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
