`default_nettype none

module i2s_transmitter (
    input  wire        clk,          // 98.298 MHz FPGA clock
    input  wire        rst,         

    input  wire [23:0] left_sample,  
    input  wire [23:0] right_sample, 
    input  wire        sample_valid,

    output wire        sample_ready, 

    output wire        i2s_mclk,
    output wire        i2s_sclk,
    output wire        i2s_lrclk,
    output reg         i2s_sdout
);

    // 1024 FPGA cycles per stereo audio frame
    reg [9:0] clk_count;

    // Hold both samples for an entire stereo frame
    reg [23:0] left_reg;
    reg [23:0] right_reg;

    // Clock generation
    assign i2s_mclk  = clk_count[1]; // /4
    assign i2s_sclk  = clk_count[3]; // /16
    assign i2s_lrclk = clk_count[9]; // /1024

    // Handshake occurs immediately before a new frame
    assign sample_ready = !rst && clk_count == 10'd1023;

    // Clock counter and sample loading
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_count <= 10'd0;
            left_reg  <= 24'd0;
            right_reg <= 24'd0;
        end else begin
            clk_count <= clk_count + 10'd1;

            if (sample_ready && sample_valid) begin
                left_reg  <= left_sample;
                right_reg <= right_sample;
            end
        end
    end

    // I2S data transmitter
    // Data changes on the falling edge of SCLK.
    // The DAC samples data on the rising edge.
    //
    // clk_count[8:4] represents the current
    // 0..31 bit position within a channel slot.
    //
    // Position 0: I2S one-bit delay
    // Positions 1..24: 24 audio bits (MSB first)
    // Positions 25..31: zero padding

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i2s_sdout <= 1'b0;
        end else begin

            // Counter advances from xxx1111 to
            // xxx0000: SCLK falls on this edge.
            if (clk_count[3:0] == 4'hF) begin

                // Current slot position 0..23
                // corresponds to the NEXT slot
                // position 1..24 after this edge.
                if (clk_count[8:4] < 5'd24) begin

                    if (clk_count[9] == 1'b0) begin
                        // Left channel, MSB first
                        i2s_sdout <= left_reg[5'd23 - clk_count[8:4]];
                    end else begin
                        // Right channel, MSB first
                        i2s_sdout <= right_reg[5'd23 - clk_count[8:4]];
                    end

                end else begin
                    // Unused slot bits = zero
                    i2s_sdout <= 1'b0;
                end
            end
        end
    end

endmodule

`default_nettype wire