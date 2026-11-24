
`default_nettype none

module midi_cc_decoder (
    input  wire clk,
    input  wire rst,

    input  wire        midi_valid,
    input  wire [7:0]  midi_status,
    input  wire [7:0]  midi_data1,
    input  wire [7:0]  midi_data2,

    // Parameter Manager interface
    output logic        param_write,
    output logic [7:0]  param_addr,
    output logic [15:0] param_data
);

    always_ff @(posedge clk) begin 
        if (rst) begin
            param_write <= 1'b0;
            param_addr  <= '0;
            param_data  <= '0; 
        end else begin 

            param_write <= 1'b0;

            if (midi_valid) begin 
                if (midi_status[7:4] == 4'hB) begin 
                    param_write <= 1'b1;
                    param_data  <= {midi_data2, 9'b0};

                    case (midi_data1) 
                        8'h46 : begin 
                            param_addr  <= 8'h30;
                        end 

                        8'h47 : begin 
                            param_addr  <= 8'h10;
                        end

                        8'h48 : begin 
                            param_addr  <= 8'h11;
                        end

                        8'h49 : begin 
                            param_addr      <= 8'h12;
                            if (midi_data2 < 8'd43)
                                param_data[1:0] <= 2'b00; // Low-pass
                            else if (midi_data2 < 8'd85)
                                param_data[1:0] <= 2'b01; // High-pass
                            else
                                param_data[1:0] <= 2'b10; // Band-pass
                        end

                        8'h4A : begin 
                            param_addr <= 8'h21;
                            param_data[1:0] <= midi_data2[6:5];
                        end 

                        default : begin 
                            param_write <= 1'b0;
                        end 
                    endcase 
                end 
            end 

        end 
    end 

endmodule

`default_nettype wire
