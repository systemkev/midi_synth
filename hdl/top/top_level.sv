
`default_nettype none

module top_level (
    input  wire clk_100mhz,
    input  wire rst_bttn,
    input  wire uart_rx,

    output logic uart_tx,

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

    logic        param_write;
    logic [7:0]  param_addr;
    logic [15:0] param_data;

    midi_cc_decoder u_midi_cc_decoder (
        .clk          (sys_clk),
        .rst          (rst),
        .midi_valid   (midi_valid),
        .midi_status  (midi_status),
        .midi_data1   (midi_data1),
        .midi_data2   (midi_data2),
        .param_write  (param_write),
        .param_addr   (param_addr),
        .param_data   (param_data)
    );

    logic [15:0] amp_attack;
    logic [15:0] amp_decay;
    logic [15:0] amp_sustain;
    logic [15:0] amp_release;

    logic [15:0] filter_attack;
    logic [15:0] filter_decay;
    logic [15:0] filter_sustain;
    logic [15:0] filter_release;

    logic [15:0] cutoff;
    logic [15:0] resonance;
    logic [1:0]  filter_mode;

    logic [15:0] pulse_width;
    logic [1:0]  waveform_select;

    logic [15:0] master_gain;

    parameter_manager u_param_mgr (
        .clk             (sys_clk),
        .rst             (rst),

        // Parameter write interface
        .param_write     (param_write),
        .param_addr      (param_addr),
        .param_data      (param_data),

        // Amplitude ADSR
        .amp_attack      (amp_attack),
        .amp_decay       (amp_decay),
        .amp_sustain     (amp_sustain),
        .amp_release     (amp_release),

        // Filter ADSR
        .filter_attack   (filter_attack),
        .filter_decay    (filter_decay),
        .filter_sustain  (filter_sustain),
        .filter_release  (filter_release),

        // VCF
        .cutoff          (cutoff),
        .resonance       (resonance),
        .filter_mode     (filter_mode),

        // Oscillator
        .pulse_width     (pulse_width),
        .waveform_select (waveform_select),

        // Master volume
        .master_gain     (master_gain)
    );

    // uart_tx #(
    //     .CLK_HZ (98_297_872),
    //     .BAUD   (115_200)
    // ) u_debug_uart (
    //     .i_clk   (sys_clk),
    //     .i_rst   (rst),

    //     .i_valid (uart_vld),
    //     .i_data  (uart_byte),

    //     .o_ready (),
    //     .o_tx    (uart_tx),
    //     .o_done  ()
    // );

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
    logic osc_vld;
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
        .osc_vld     (osc_vld),
        .sync        ()
    );

    logic signed [23:0] vcf_in;
    logic signed [23:0] vcf_out;
    logic vcf_out_vld;

    always_comb begin
        case (waveform_select) 
            2'd0: begin 
                vcf_in <= sine;
            end  

            2'd1 : begin 
                vcf_in <= pulse;
            end  

            2'd2 : begin 
                vcf_in <= saw;
            end  

            2'd3 : begin 
                vcf_in <= triangle;
            end  
        endcase 
    end

    vcf vcf_1 (
        .clk           (sys_clk),
        .rst           (rst),
        .audio_in_vld  (osc_vld),
        .audio_in      (vcf_in),
        .cutoff        (cutoff),
        .resonance     (resonance),
        .filter_mode   (filter_mode),
        .audio_out_vld (vcf_out_vld),
        .audio_out     (vcf_out)
    );

    logic signed [23:0] vca_out;
    logic vca_out_vld;
    vca vca_1 (
        .clk           (sys_clk),
        .rst           (rst),
        .audio_in_vld  (vcf_out_vld),
        .audio_in      (vcf_out),
        .gain          (master_gain),
        .audio_out_vld (vca_out_vld),
        .audio_out     (vca_out)
    );

    
    // Capture 512 consecutive samples, then transmit at 115200 baud.
    // Packet: 4-byte header + 512 * 9 bytes (3 signed 24-bit signals).

    localparam logic [31:0] SYNC_WORD = 32'hA55AC33C;
    typedef enum logic [1:0] {CAPTURE, HEADER, LOAD, SEND} debug_state_t;

    (* ram_style = "block" *) logic [71:0] debug_mem [0:511];
    logic [71:0] tx_word;
    logic [8:0] wr_addr, rd_addr;
    logic [1:0] header_idx;
    logic [3:0] byte_idx;
    logic [7:0] tx_data;
    logic tx_ready;
    debug_state_t debug_state;

    wire tx_valid = (debug_state == HEADER || debug_state == SEND);

    assign tx_data = (debug_state == HEADER) ?
        SYNC_WORD[31 - 8*header_idx -: 8] :
        tx_word[71 - 8*byte_idx -: 8];

    always_ff @(posedge sys_clk) begin
        if (rst) begin
            debug_state <= CAPTURE;
            wr_addr <= 0;
            rd_addr <= 0;
            header_idx <= 0;
            byte_idx <= 0;
            tx_word <= 0;
        end else begin
            case (debug_state)
                CAPTURE: if (sample_tick) begin
                    debug_mem[wr_addr] <= {vcf_in, vcf_out, vca_out};
                    if (wr_addr == 9'd511) begin
                        wr_addr <= 0;
                        header_idx <= 0;
                        debug_state <= HEADER;
                    end else wr_addr <= wr_addr + 1'b1;
                end

                HEADER: if (tx_ready) begin
                    if (header_idx == 2'd3) begin
                        rd_addr <= 0;
                        debug_state <= LOAD;
                    end else header_idx <= header_idx + 1'b1;
                end

                LOAD: begin
                    tx_word <= debug_mem[rd_addr];
                    byte_idx <= 0;
                    debug_state <= SEND;
                end

                SEND: if (tx_ready) begin
                    if (byte_idx == 4'd8) begin
                        if (rd_addr == 9'd511) debug_state <= CAPTURE;
                        else begin
                            rd_addr <= rd_addr + 1'b1;
                            debug_state <= LOAD;
                        end
                    end else byte_idx <= byte_idx + 1'b1;
                end
            endcase
        end
    end

    uart_tx #(.CLK_HZ(98_297_872), .BAUD(115_200)) u_debug_uart (
        .i_clk(sys_clk), .i_rst(rst), .i_valid(tx_valid),
        .i_data(tx_data), .o_ready(tx_ready), .o_tx(uart_tx), .o_done()
    );


    // I2S transmitter
    i2s_transmitter i2s_tx (
        .clk          (sys_clk),
        .rst          (rst),

        .left_sample  (vca_out),
        .right_sample (vca_out),
        .sample_valid (1'b1),
        .sample_ready (sample_tick),

        .i2s_mclk     (I2S2_MCLK),
        .i2s_sclk     (I2S2_SCLK),
        .i2s_lrclk    (I2S2_LRCLK),
        .i2s_sdout    (I2S2_SDIN)
    );


endmodule

`default_nettype wire
