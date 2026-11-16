`default_nettype none

module midi_parser (
    input wire          clk,
    input wire          rst,
    input wire          byte_vld,
    input wire [7:0]    byt,

    output logic        midi_valid,
    output logic [7:0]  midi_status,
    output logic [3:0]  midi_channel,
    output logic [7:0]  midi_data1,
    output logic [7:0]  midi_data2
);

    typedef enum logic [2:0] { 
        IDLE, DATA1, DATA2
    } state_t;
    state_t state; 

    logic sys_ex_mode;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            state        <= IDLE;
            midi_valid   <= 1'b0;
            midi_status  <= 8'd0;
            midi_channel <= 4'd0;
            midi_data1   <= 8'd0;
            midi_data2   <= 8'd0;
            sys_ex_mode  <= 1'b0;
        end else begin 

            midi_valid   <= 1'b0;

            if (byte_vld) begin 
                if (byt == 8'hF0) begin 
                    sys_ex_mode <= 1'b1;
                    state       <= IDLE;
                end else if (sys_ex_mode && byt == 8'hF7) begin 
                    sys_ex_mode <= 1'b0;
                    // stay in idle
                end else if (sys_ex_mode || (byt >= 8'hF8)) begin 
                    // ignore byte, preserve current state
                end else if (byt >= 8'hF1 && byt <= 8'hF7) begin
                    state <= IDLE;
                end else begin 
                    case (state)
                        IDLE : begin 
                            midi_data1 <= '0;
                            midi_data2 <= '0;

                            if (byt >= 8'h80 && byt <= 8'hEF) begin
                                midi_status  <= byt;
                                midi_channel <= byt[3:0];
                                
                                state <= DATA1;
                            end 
                        end 

                        DATA1 : begin 
                            midi_data2 <= '0;

                            if (byt >= 8'h80 && byt <= 8'hEF) begin 
                                midi_status  <= byt;
                                midi_channel <= byt[3:0];
                            end else begin
                                state      <= DATA2;
                                midi_data1 <= byt; 

                                if (midi_status[7:4] == 4'hC || midi_status[7:4] == 4'hD) begin 
                                    state      <= DATA1;
                                    midi_valid <= 1'b1;
                                end
                            end 
                        end 

                        DATA2 : begin 
                            state <= DATA1;

                            if (byt >= 8'h80 && byt <= 8'hEF) begin 
                                midi_status  <= byt;
                                midi_channel <= byt[3:0];
                            end else begin
                                midi_data2 <= byt; 
                                midi_valid <= 1'b1;
                            end 
                        end 

                        default : begin
                            state <= IDLE;
                        end 
                    endcase 
                end 
            end 
        end 
    end 

endmodule 

`default_nettype wire