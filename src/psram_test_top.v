

module memory_test (
    input sys_clk,  // 27 Mhz, crystal clock from board
    input sys_resetn,
    input button,   // 0 when pressed

    output [5:0] led,
    output uart_txp,

    output [1:0] O_psram_ck,       // Magic ports for PSRAM to be inferred
    output [1:0] O_psram_ck_n,
    inout [1:0] IO_psram_rwds,
    inout [15:0] IO_psram_dq,
    output [1:0] O_psram_reset_n,
    output [1:0] O_psram_cs_n
);

// Customization of the test
localparam [23:0] BYTES = 4*1024*1024;    // Test write/read this many bytes
//localparam [23:0] BYTES = 128;    // Test write/read this many bytes

// Change PLL and here to choose another speed.
//localparam FREQ = 96_000_000;           
localparam LATENCY = 4;
//localparam FREQ = 102_600_000;           
//localparam LATENCY = 4;
//localparam FREQ = 100_286_000;           
//localparam LATENCY = 4;
//localparam FREQ = 100_281_250;
//localparam FREQ = 100_287_500;                 
localparam FREQ = 100_000_000;

// Remove UART print module for timing closure (check LED5 for error)
//`define NO_UART_PRINT

// For GAO debug
//localparam [21:0] BYTES = 2;
//localparam NO_PAUSE = 1;
parameter NO_PAUSE = 0;                // Pause between states to allow UART printing

// End of customization

assign O_psram_reset_n = sys_resetn;

//Gowin_rPLL pll(
Gowin_rPLL2 pll(
    .clkout(clk),        // MHZ main clock
    .clkoutp(clk_p),     // MHZ phase shifted (90 degrees)
    .clkin(sys_clk)      // 27Mhz system clock
);

// Memory Controller under test ---------------------------
reg read, readd, write, byte_write;
reg [23:0] address;
reg [15:0] din;
wire [15:0] dout;
wire [7:0] dout_byte = address[0] ? dout[15:8] : dout[7:0];

PsramController #(
    .LATENCY(LATENCY),
    .FREQ(FREQ)
) mem_ctrl(
    .clk(clk), .clk_p(clk_p), .resetn(sys_resetn), .read(read), .write(write), .byte_write(byte_write),
    .addr(address[21:0]), .din(din), .dout(dout), .busy(busy),
    .O_psram_ck(O_psram_ck), .O_psram_ck_n(O_psram_ck_n), .IO_psram_rwds(IO_psram_rwds), .IO_psram_dq(IO_psram_dq),
    .O_psram_cs_n(O_psram_cs_n)
);

// The test ------------------------------------------------

localparam [3:0] TEST_ZERO = 4'd0;
localparam [3:0] TEST_INIT = 4'd1;
localparam [3:0] TEST_WRITE = 4'd2;
localparam [3:0] TEST_READ = 4'd3;
localparam [3:0] TEST_DONE = 4'd4;
localparam [3:0] TEST_FAIL_INIT_TIMEOUT = 4'd5;
localparam [3:0] TEST_FAIL_WRITE_TIMEOUT = 4'd6;
localparam [3:0] TEST_FAIL_READ_TIMEOUT = 4'd7;
localparam [3:0] TEST_FAIL_READ_WRONG = 4'd8;
localparam [3:0] PAUSE = 4'd9;
localparam [3:0] TEST_READ_DUMP = 4'd10;
localparam [3:0] TEST_READ_DUMP_DONE = 4'd11;
localparam [3:0] TEST_READ_DUMP_NEXT = 4'd13;

// pass in address to get hash value
`define hash(a) (a[7:0] ^ a[15:8] ^ a[23:16] ^ 8'hc3)

reg [3:0] state, new_state;
reg [4:0] cycle = 0;        // max 16
reg [23:0] write_1x, write_2x, read_1x, read_2x;        // counter for 1x or 2x latencies
reg tick;                   // pulse once per 0.1 second
reg [3:0] ticks = 0;        // counter for 0.1 second delays
reg error;
assign dout_parity = dout[7] & dout[6] & dout[5] & dout[4] & dout[3] & dout[2] & dout[1] & dout[0];
assign led = ~{error, dout_parity, state};

// pipeline addr+1 to meet timing constraint
reg [8:0] new_addr_0;
reg [8:0] new_addr_1;
reg [23:0] new_addr;        // available after 3 cycles
always @(posedge clk) begin
    // stage 0
    new_addr_0 = address[7:0] + 1;
    // stage 1
    new_addr_1 = address[15:8] + new_addr_0[8];
    // stage 2, add higher 6 bits
    new_addr = {address[23:16] + new_addr_1[8], new_addr_1[7:0], new_addr_0[7:0]};
end

always @(posedge clk) begin
    read <= 0; write <= 0; byte_write <= 1;  // default values
    ticks <= tick && (state == TEST_INIT || state == PAUSE) ? ticks + 1 : ticks;
    if (~sys_resetn || state == TEST_ZERO) begin
        cycle <= 0;
        ticks <= 0;
        new_state <= TEST_INIT;
        state <= PAUSE;
        error <= 0;
        //DB: reset counters!
        write_1x <= 'd0;
        write_2x <= 'd0;
        read_1x <= 'd0;
        read_2x <= 'd0;
        address <= 0;
    end else if (state == TEST_INIT) begin
        // wait for memory to become ready
        if (!busy) begin
            address <= 0;
            new_state <= TEST_WRITE;
            state <= PAUSE;
        end else if (ticks == 5) begin   // 0.5 second timeout
            new_state <= TEST_FAIL_INIT_TIMEOUT;
            error <= 1'b1;
            state <= PAUSE;
        end

    end else if (state == TEST_WRITE) begin
        // write some bytes
        cycle <= cycle + 1;
        if (cycle == 0) begin
            // issue write command
            write <= 1;
            din <= {`hash(address), `hash(address)};
        end else if (!write && !busy) begin
            // write finished
            cycle <= 0;
            if (cycle > 5+LATENCY)
                write_2x <= write_2x + 1;
            else
                write_1x <= write_1x + 1;
            if (new_addr >= BYTES) begin
                new_state <= TEST_READ_DUMP;
                state <= PAUSE;
                address <= 0;
            end else
                address <= new_addr;
        end else if (cycle == 5+LATENCY*2) begin
            new_state <= TEST_FAIL_WRITE_TIMEOUT;
            error <= 1'b1;
            state <= PAUSE;
        end

    end else if (state == TEST_READ) begin
        // read and verify some bytes
        cycle <= cycle + 1;
        if (cycle == 0) begin
            // issue read command
            read <= 1;
        end else if (!read && !busy) begin
            // read finished
            cycle <= 0;
            if (cycle > 10+LATENCY)     // read_is on cycle 1, so cycle==13 means latency is 12
                read_2x <= read_2x + 1;
            else
                read_1x <= read_1x + 1;
            if (dout_byte != `hash(address)) begin
                new_state <= TEST_FAIL_READ_WRONG;
                error <= 1'b1;
                state <= PAUSE;
            end else if (new_addr >= BYTES) begin
                new_state <= TEST_DONE;
                state <= PAUSE;
            end else
                address <= new_addr;
        end else if (cycle == 10+LATENCY*2) begin
            new_state <= TEST_FAIL_READ_TIMEOUT;
            error <= 1'b1;
            state <= PAUSE;
        end

    end else if (state == TEST_READ_DUMP) begin
        // read and verify some bytes
        cycle <= cycle + 1;
        if (cycle == 0) begin
            // issue read command
            read <= 1;
        end else if (!read && !busy) begin
            // read finished
            cycle <= 0;
            state <= TEST_READ_DUMP_DONE;
        end
    end else if (state == TEST_READ_DUMP_DONE) begin
        cycle <= cycle + 1;
        if (cycle[3]) begin
            state <= PAUSE;
            new_state <= TEST_READ_DUMP_NEXT;
            cycle <= 0;
        end
    end else if (state == TEST_READ_DUMP_NEXT) begin
        if (new_addr[4]) begin
            state <= TEST_READ;
            address <= 0;
        end else begin
            address <= new_addr;
            state <= TEST_READ_DUMP;
        end
    end else if (state == PAUSE) begin
        // pause for 0.1 seconds for print to finish, then enter new_state
        if (ticks == 2 || NO_PAUSE) begin     // pause for 0.1 second
            ticks <= 0;
            state <= new_state;
        end
    end
end


reg [23:0] tick_counter;        // max 16M
always @(posedge clk) begin
    if (~sys_resetn) begin
        tick_counter <= FREQ/10;
    end
    tick_counter <= tick_counter == 0 ? FREQ/10 : tick_counter - 1;
    tick <= tick_counter == 0;
end


//Print Controll -------------------------------------------

`ifndef NO_UART_PRINT
`include "print.v"
defparam tx.uart_freq=115200;
defparam tx.clk_freq=27_000_000;
assign print_clk = sys_clk;
assign txp = uart_txp;

reg [3:0] state_p;
reg [3:0] state_p2; // delay for clock crossing
reg [4:0] print_counters = 0;       // 1. "write_1x=", 2. write_1x, 3. ", write_2x=", 4. write_2x, 5. ", read_1x=", 6. "read_1x", 7, ", read_2x=", 8. read_2x., 9. "\n"
reg [4:0] print_counters_p;

always @(posedge sys_clk) begin
    state_p <= state;
    state_p2 <= state_p;
    print_counters_p <= print_counters;
    if (state_p != state_p2) begin
        if (state_p == TEST_INIT) `print("Initializing HyperRAM test...\n", STR);
        if (state_p == TEST_WRITE) `print("Writing...\n", STR);
        if (state_p == TEST_READ) `print("\nReading...\n", STR);
        if (state_p == TEST_DONE) `print("All done successfully.\n", STR);
        if (state_p == TEST_FAIL_INIT_TIMEOUT) `print("FAIL. Initialization timeout.\n", STR);
        if (state_p == TEST_FAIL_WRITE_TIMEOUT) `print("FAIL. Write time out.\n", STR);
        if (state_p == TEST_FAIL_READ_TIMEOUT) `print("FAIL. Read time out.\n", STR);
        if (state_p == TEST_FAIL_READ_WRONG) `print("FAIL. Read wrong data.\n", STR);

        if (state_p == TEST_DONE || 
            state_p == TEST_FAIL_INIT_TIMEOUT || 
            state_p == TEST_FAIL_READ_TIMEOUT ||  
            state_p == TEST_FAIL_WRITE_TIMEOUT)
            print_counters <= 6;
        else if (state_p == TEST_FAIL_READ_WRONG)
            print_counters <= 1;
        else if (state_p == TEST_READ_DUMP_DONE)
            print_counters <= 15;
    end

    if (print_counters > 0 && print_counters == print_counters_p && print_state == PRINT_IDLE_STATE) begin
        case (print_counters)
        1: `print("Expected ", STR);
        2: `print(`hash(address), 1);
        3: `print(", read ",STR);
        4: `print(dout, 1);
        5: `print(". ", STR);
        6: `print("Latency counters: write_1x=", STR);
        7: `print(write_1x, 3);
        8: `print(", write_2x=", STR);
        9: `print(write_2x, 3);
        10: `print(", read_1x=", STR);
        11: `print(read_1x, 3);
        12: `print(", read_2x=", STR);
        13: `print(read_2x, 3);
        14: `print("\n", STR);
        15: `print(address, 3);
        16: `print(" : ", STR);
        17: `print(dout_byte, 1);
        18: `print("\n", STR);
        endcase
        print_counters <= print_counters == 14 || print_counters == 18 ? 0 : print_counters + 1;
    end

end
`endif


endmodule
