`default_nettype none

module noise #(
    parameter SEED = 32'h12345678 
)(
    input  wire clk,
    input  wire rst,
    output logic signed [23:0] osc_noise
);

    logic [31:0] state;    
    logic [31:0] temp1, temp2, next_state;

    assign temp1      = state ^ (state << 13);
    assign temp2      = temp1 ^ (temp1 >> 17);
    assign next_state = temp2 ^ (temp2 << 5);

    always_ff @(posedge clk) begin 
        if (rst) begin
            state <= SEED;
        end else begin
            state <= next_state;
        end 
    end 

    assign osc_noise = state[23:0];

endmodule 

`default_nettype wire