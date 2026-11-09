module vco #(
    parameter FILE_NAME = "sine4096_24bit.mem",
    parameter LUT_DEPTH = 12,
    parameter SIN_WIDTH = 24,
    parameter SND_WIDTH = 24,
    parameter ACC_WIDTH = 32,
    parameter PUL_WIDTH = 16,
)(
    input  wire clk,
    input  wire rst,
    input  wire sample_tick,

    input  wire [ACC_WIDTH-1:0] freq_inc,
    input  wire [PUL_WIDTH-1:0] pw,

    output logic signed [SND_WIDTH-1:0] osc_sin,
    output logic signed [SND_WIDTH-1:0] osc_pulse,
    output logic signed [SND_WIDTH-1:0] osc_saw,
    output logic signed [SND_WIDTH-1:0] osc_tri,

    output logic osc_vld,
    output logic sync
);

    logic [SIN_WIDTH-1:0] sine_lut [0:2**(LUT_DEPTH)-1];

    // bring in LUT sine table
    initial begin 
        $readmemh("sine4096_24bit.mem", sin_lut);
    end 

    logic [ACC_WIDTH-1:0] accum;
    logic [LUT_DEPTH-1:0] addr;
    logic [SIN_WIDTH-1:0] sin_read;

    logic tick_dly;
    always_ff @(posedge clk) begin 
        sin_read <= sine_lut[accum[ACC_WIDTH-1:ACC_WIDTH-LUT_DEPTH]];
        osc_sin  <= sine_read;
    end 

    assign osc_saw   = ();
    assign osc_pulse = (accum[ACC_WIDTH-1:ACC_WIDTH-PUL_WIDTH] < pw)? ('1 >> 1) : ~('1 >> 1);

    always_ff @(posedge clk) begin 
        if (rst) begin
            osc_sin   <= '0;
            osc_pulse <= '0;
            osc_saw   <= '0;
            osc_tri   <= '0;
            osc_vld   <= 1'b0; 
            sync      <= 1'b0;
            tick_dly  <= 1'b0;
        end else begin
            tick_dly <= sample_tick;
            osc_vld  <= tick_dly;

            if (sample_tick) begin 
                accum <= accum + freq_inc;
            end 

            if (tick_dly) begin 
                osc_pulse <= (accum[ACC_WIDTH-1:ACC_WIDTH-PUL_WIDTH] < pw)? ('1 >> 1) : ~('1 >> 1);
                osc_saw   <= {~accum[ACC_WIDTH-1], accum[ACC_WIDTH-2:ACC_WIDTH-SND_WIDTH]};
                
                if (accum[ACC_WIDTH-1]) begin 
                    osc_tri <= {~accum[ACC_WIDTH-1], accum[ACC_WIDTH-2:0]};
                end 
            end 
        end 
    end 

endmodule 