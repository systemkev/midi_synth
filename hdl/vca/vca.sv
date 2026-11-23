`default_nettype none

module vca (
    input  wire clk,
    input  wire rst,

    input  wire audio_in_vld,
    input  wire signed [23:0] audio_in,

    input  wire [15:0] gain,

    output logic audio_out_vld,
    output logic signed [23:0] audio_out
);

    always_ff @(posedge clk) begin 
        if (rst) begin 
            audio_out     <= '0;
            audio_out_vld <= 1'b0;
        end else begin
            audio_out     <= 41'($signed({1'b0, gain}) * audio_in) >>> 16; 
            audio_out_vld <= audio_in_vld;
        end 
    end 

endmodule

`default_nettype wire