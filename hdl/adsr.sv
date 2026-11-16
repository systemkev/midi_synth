`default_nettype none

module adsr (
    input  logic        clk,
    input  logic        rst_n,

    // ADSR parameters
    input  logic [15:0] attack,
    input  logic [15:0] decay,
    input  logic [15:0] sustain,
    input  logic [15:0] release,

    // Control signals
    input  logic        note_on_pulse,
    input  logic        note_off_pulse,
    input  logic        sample_tick,

    // Outputs
    output logic [15:0] env_out,
    output logic        synth_idle
);

endmodule 

`default_nettype wire