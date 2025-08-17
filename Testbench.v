`timescale 1ns/1ps

// Testbench for cache_core
// "Human-written" style: informal comments, clear steps, small stimuli batches
// This bench exercises basic read/write sequences to produce hits and misses

module tb_cache_core;

    // Clock / reset
    reg         clk = 0;
    reg         reset = 1;

    // DUT signals
    reg  [31:0] address  = 32'd0;
    reg  [31:0] data_in  = 32'd0;
    reg         read_en  = 1'b0;
    reg         write_en = 1'b0;
    wire [31:0] data_out;
    wire        hit_flag;
    wire [7:0]  hit_count;
    wire [7:0]  miss_count;

    // Instantiate the design under test (DUT)
    cache_core uut (
        .clk(clk),
        .reset(reset),
        .address(address),
        .data_in(data_in),
        .read_en(read_en),
        .write_en(write_en),
        .data_out(data_out),
        .hit_flag(hit_flag),
        .hit_count(hit_count),
        .miss_count(miss_count)
    );

    // Clock generator: 10 ns period (100 MHz)
    always #5 clk = ~clk;

    // Simple task to perform a write transaction
    task do_write(input [31:0] addr, input [31:0] d);
    begin
        @(posedge clk);
        address  <= addr;
        data_in  <= d;
        write_en <= 1'b1;
        read_en  <= 1'b0;
        @(posedge clk);
        // De-assert
        write_en <= 1'b0;
        data_in  <= 32'hx;
    end
    endtask

    // Simple task to perform a read transaction
    task do_read(input [31:0] addr);
    begin
        @(posedge clk);
        address <= addr;
        read_en <= 1'b1;
        write_en <= 1'b0;
        @(posedge clk);
        // sample data_out on next cycle
        @(posedge clk);
        read_en <= 1'b0;
    end
    endtask

    // Test sequence
    initial begin
        // VCD dump for waveform viewing
        $dumpfile("tb_cache_core.vcd");
        $dumpvars(0, tb_cache_core);

        // Basic banner so the simulation log looks friendly
        $display("\n--- tb_cache_core: starting simulation ---\n");

        // Apply reset
        reset = 1'b1;
        repeat (2) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        // 1) Access a sequence of addresses (expected: first accesses are misses)
        integer i;
        for (i = 0; i < 8; i = i + 1) begin
            do_read(i*4);   // word addresses
            #2; // little gap to visualize in waveform
        end

        // 2) Write to a few addresses (populate cache / backing memory)
        do_write(0, 32'hA5A5_A5A5);
        #5;
        do_write(4, 32'h5A5A_5A5A);
        #5;

        // 3) Read back the same addresses (should produce hits if cache stores them)
        do_read(0);
        #2;
        do_read(4);
        #2;

        // 4) Stress: random-ish accesses to show hit/miss behaviour
        for (i = 0; i < 16; i = i + 1) begin
            address = (i % 6) * 4; // reuse some addresses to create hits
            read_en = 1'b1;
            @(posedge clk);
            read_en = 1'b0;
            @(posedge clk);
        end

        // Print summary
        #1;
        $display("\nSimulation finished. hit_count = %0d, miss_count = %0d", hit_count, miss_count);
        $display("Final hit_flag for last access = %b, last data_out = 0x%08h", hit_flag, data_out);

        $display("--- tb_cache_core: done ---\n");
        #10;
        $finish;
    end

    // Optional monitor that prints some signals on each cycle (human-friendly)
    always @(posedge clk) begin
        $display("time=%0t | addr=0x%08h | read=%b write=%b | hit=%b | data_out=0x%08h | hits=%0d misses=%0d",
                 $time, address, read_en, write_en, hit_flag, data_out, hit_count, miss_count);
    end

endmodule
