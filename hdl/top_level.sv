
`default_nettype none

module top_level (
    input  wire clk_100mhz,
    input  wire rst_bttn,
    input  wire uart_rx,

    output logic I2S2_MCLK,
    output logic I2S2_SCLK,
    output logic I2S2_LRCLK,
    output logic I2S2_SDIN
);

    logic sys_clk;
    logic [31:0] midi_note_lut [0:127];

    initial begin 
        $readmemh("mem/midi_phase_inc.mem", midi_note_lut);
    end 

    logic [6:0]  midi_note;
    logic [31:0] freq_inc;
    logic [31:0] freq_inc_read;

    always_ff @(posedge sys_clk) begin 
        freq_inc_read <= midi_note_lut[midi_note];
        freq_inc <= freq_inc_read;
    end 

    logic mmcm_locked;
    logic rst;
    
    assign rst = rst_bttn | ~mmcm_locked;

    logic sample_tick;

    // sys_clk = ~98.298 MHz
    clk_wiz_0 clk_wiz (
        .clk_in1  (clk_100mhz),
        .clk_out1 (sys_clk),
        .clk_out2 (),
        .reset    (rst_bttn),
        .locked   (mmcm_locked)
    );

    logic [7:0] uart_byte;
    logic uart_vld;

    uart_rx uart_receiver (
        .i_clk   (sys_clk),
        .i_rst   (rst),
        .i_rx    (uart_rx),
        .o_data  (uart_byte),
        .o_valid (uart_vld)
    );

    logic midi_valid;
    logic [7:0] midi_status;
    logic [3:0] midi_channel;
    logic [7:0] midi_data1;
    logic [7:0] midi_data2;
    
    midi_parser u_midi_parser (
        .clk          (sys_clk),
        .rst          (rst),
        .byte_vld     (uart_vld),
        .byt          (uart_byte),
        .midi_valid   (midi_valid),
        .midi_status  (midi_status),
        .midi_channel (midi_channel),
        .midi_data1   (midi_data1),
        .midi_data2   (midi_data2)
    );  

    always_ff @(posedge sys_clk) begin 
        if (rst) begin 
            midi_note <= 64;
        end else begin 
            if (midi_valid && midi_status[7:4] == 4'h9 && midi_data2 != 8'h00) begin
                midi_note <= midi_data1;
            end 
        end 
    end 
    
    // 261.63 Hz at ~96 kHz sample rate
    logic signed [23:0] sine, pulse, triangle, saw;
    vco vco_1 (
        .clk         (sys_clk),
        .rst         (rst),
        .sample_tick (sample_tick),
        .freq_inc    (freq_inc),
        .pw          (32768),
        .osc_sin     (sine),
        .osc_pulse   (pulse),
        .osc_saw     (saw),
        .osc_tri     (triangle),
        .osc_vld     (),
        .sync        ()
    );

    // I2S transmitter
    i2s_transmitter i2s_tx (
        .clk          (sys_clk),
        .rst          (rst),

        .left_sample  (sine),
        .right_sample (sine),
        .sample_valid (1'b1),
        .sample_ready (sample_tick),

        .i2s_mclk     (I2S2_MCLK),
        .i2s_sclk     (I2S2_SCLK),
        .i2s_lrclk    (I2S2_LRCLK),
        .i2s_sdout    (I2S2_SDIN)
    );

endmodule

`default_nettype wire
