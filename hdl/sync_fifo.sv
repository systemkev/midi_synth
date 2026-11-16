
`timescale 1ns / 1ps
`default_nettype none

module command_fifo #(
    parameter DEPTH = 16,
    parameter WIDTH = 16
)(
    input  wire clk,
    input  wire rst,

    input  wire write,
    input  wire [WIDTH-1:0] command_in,
    output logic full,

    output logic [WIDTH-1:0] command_out,
    input  wire read,
    output logic empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Extra bit distinguishes full from empty
    logic [ADDR_WIDTH:0] write_pointer;
    logic [ADDR_WIDTH:0] read_pointer;

    logic [WIDTH-1:0] fifo [0:DEPTH-1];

    // Empty when pointers are identical
    assign empty = (write_pointer == read_pointer);

    // Full when addresses match but wrap bits differ
    assign full =
        (write_pointer[ADDR_WIDTH] != read_pointer[ADDR_WIDTH]) &&
        (write_pointer[ADDR_WIDTH-1:0] ==
         read_pointer[ADDR_WIDTH-1:0]);

    // First-word-fall-through output
    assign command_out = fifo[read_pointer[ADDR_WIDTH-1:0]];

    wire do_read  = read && !empty;
    wire do_write = write && (!full || do_read);

    always_ff @(posedge clk) begin
        if (rst) begin
            write_pointer <= '0;
            read_pointer  <= '0;
        end else begin

            if (do_write) begin
                fifo[write_pointer[ADDR_WIDTH-1:0]]
                    <= command_in;
                write_pointer <= write_pointer + 1'b1;
            end

            if (do_read) begin
                read_pointer <= read_pointer + 1'b1;
            end

        end
    end

endmodule

`default_nettype wire
