
`default_nettype none

module parameter_manager (
    input  wire clk,
    input  wire rst,

    // Parameter write interface
    input  wire        param_write,
    input  wire [7:0]  param_addr,
    input  wire [15:0] param_data,

    // Amplitude ADSR
    output logic [15:0] amp_attack,
    output logic [15:0] amp_decay,
    output logic [15:0] amp_sustain,
    output logic [15:0] amp_release,

    // Filter ADSR
    output logic [15:0] filter_attack,
    output logic [15:0] filter_decay,
    output logic [15:0] filter_sustain,
    output logic [15:0] filter_release,

    // VCF
    output logic [15:0] cutoff,
    output logic [15:0] resonance,
    output logic [1:0]  filter_mode,

    // Oscillator
    output logic [15:0] pulse_width,
    output logic [1:0]  waveform_select,

    // Master volume
    output logic [15:0] master_gain
);

    // Parameter addresses
    localparam logic [7:0]
        AMP_ATTACK_ADDR      = 8'h00,
        AMP_DECAY_ADDR       = 8'h01,
        AMP_SUSTAIN_ADDR     = 8'h02,
        AMP_RELEASE_ADDR     = 8'h03,

        FILTER_ATTACK_ADDR   = 8'h04,
        FILTER_DECAY_ADDR    = 8'h05,
        FILTER_SUSTAIN_ADDR  = 8'h06,
        FILTER_RELEASE_ADDR  = 8'h07,

        CUTOFF_ADDR          = 8'h10,
        RESONANCE_ADDR       = 8'h11,
        FILTER_MODE_ADDR     = 8'h12,

        PULSE_WIDTH_ADDR     = 8'h20,
        WAVEFORM_SELECT_ADDR = 8'h21,

        MASTER_GAIN_ADDR     = 8'h30;

    always_ff @(posedge clk) begin
        if (rst) begin

            // Default amplitude envelope
            amp_attack  <= 16'd20000;
            amp_decay   <= 16'd1000;
            amp_sustain <= 16'd40000;
            amp_release <= 16'd1000;

            // Default filter envelope
            filter_attack  <= 16'd20000;
            filter_decay   <= 16'd1000;
            filter_sustain <= 16'd40000;
            filter_release <= 16'd1000;

            // Default filter settings
            cutoff      <= 16'hC000;
            resonance   <= 16'd0;
            filter_mode <= 2'b00;

            // Default oscillator settings
            pulse_width     <= 16'd32768;
            waveform_select <= 2'b00;

            // Default master volume
            master_gain <= 16'hFFFF;

        end else if (param_write) begin

            case (param_addr)

                // Amplitude ADSR
                AMP_ATTACK_ADDR:
                    amp_attack <= param_data;

                AMP_DECAY_ADDR:
                    amp_decay <= param_data;

                AMP_SUSTAIN_ADDR:
                    amp_sustain <= param_data;

                AMP_RELEASE_ADDR:
                    amp_release <= param_data;

                // Filter ADSR
                FILTER_ATTACK_ADDR:
                    filter_attack <= param_data;

                FILTER_DECAY_ADDR:
                    filter_decay <= param_data;

                FILTER_SUSTAIN_ADDR:
                    filter_sustain <= param_data;

                FILTER_RELEASE_ADDR:
                    filter_release <= param_data;

                // VCF
                CUTOFF_ADDR:
                    cutoff <= param_data;

                RESONANCE_ADDR:
                    resonance <= param_data;

                FILTER_MODE_ADDR:
                    filter_mode <= param_data[1:0];

                // Oscillator
                PULSE_WIDTH_ADDR:
                    pulse_width <= param_data;

                WAVEFORM_SELECT_ADDR:
                    waveform_select <= param_data[1:0];

                // Master gain
                MASTER_GAIN_ADDR:
                    master_gain <= param_data;

                default: ;

            endcase
        end
    end

endmodule

`default_nettype wire
