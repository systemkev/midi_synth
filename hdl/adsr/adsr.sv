`default_nettype none

module adsr (
    input  wire         clk,
    input  wire         rst,

    // ADSR parameters
    input  wire  [15:0] attack,
    input  wire  [15:0] decay,
    input  wire  [15:0] sustain,
    input  wire  [15:0] release_i,

    // Control signals
    input  wire         note_on_pulse,
    input  wire         note_off_pulse,
    input  wire         sample_tick,

    // Outputs
    output logic [15:0] env_out,
    output logic        synth_idle
);

    parameter logic [21:0] MAX_ACC_VAL = {16'hFFFF, 6'b0};

    typedef enum logic [2:0] { 
        IDLE, ATTACK, DECAY, SUSTAIN, RELEASE
    } state_t;

    state_t state; 

    logic [21:0] accumulator; 
    logic [15:0] attack_r, decay_r, sustain_r, release_r;
    logic note_on_sticky;
    logic note_off_sticky;

    assign synth_idle = (state == IDLE);
    assign env_out = accumulator[21:6];

    always_ff @(posedge clk) begin 
        if (rst) begin 
            state       <= IDLE;
            attack_r    <= '0;
            decay_r     <= '0;
            sustain_r   <= '0; 
            release_r   <= '0; 
            accumulator <= '0;

            note_on_sticky  <= '0;
            note_off_sticky <= '0;
        end else begin 

            if (sample_tick) begin 

                if (note_on_sticky || note_on_pulse) begin 
                    attack_r    <= attack;
                    decay_r     <= decay;
                    sustain_r   <= sustain;
                    release_r   <= release_i;

                    note_on_sticky  <= 1'b0;
                    note_off_sticky <= 1'b0;

                    if (attack == '0 && decay == '0) begin 
                        accumulator <= {sustain, 6'b0};
                        state       <= SUSTAIN;
                    end else if (attack == '0) begin 
                        accumulator <= MAX_ACC_VAL;
                        state       <= DECAY;
                    end else begin 
                        accumulator <= '0;
                        state       <= ATTACK;
                    end 
                end else if (note_off_sticky || note_off_pulse) begin 
                    if (state == IDLE || release_r == 0) begin
                        state       <= IDLE;
                        accumulator <= '0;
                    end else begin
                        state <= RELEASE;
                    end

                    note_off_sticky <= 1'b0;
                    note_on_sticky  <= 1'b0;

                end else begin 
                    case (state)
                        IDLE : begin 
                            accumulator <= '0;
                            attack_r    <= '0;
                            decay_r     <= '0;
                            sustain_r   <= '0;
                            release_r   <= '0;

                            note_off_sticky <= 1'b0;
                        end 

                        ATTACK : begin

                            if ({1'b0, accumulator} + attack_r >= {1'b0, MAX_ACC_VAL}) begin
                                accumulator <= MAX_ACC_VAL;

                                if (decay_r == '0) begin 
                                    accumulator <= {sustain_r, 6'b0};

                                    state <= SUSTAIN;
                                end else begin 
                                    state <= DECAY;
                                end 

                            end else begin 
                                accumulator <= accumulator + attack_r;
                            end 

                        end 

                        DECAY : begin 

                            if ({1'b0, accumulator} <= {sustain_r, 6'b0} + decay_r) begin
                                accumulator <= {sustain_r, 6'b0};
                                state       <= SUSTAIN;
                            end else begin 
                                accumulator <= accumulator - decay_r;
                            end 

                        end 

                        SUSTAIN : begin 

                            // sustainnnnn!

                        end 

                        RELEASE : begin 

                            note_off_sticky <= 1'b0;

                            if (release_r == '0 || accumulator <= release_r) begin 
                                state       <= IDLE;
                                accumulator <= '0;
                            end else begin 
                                accumulator <= accumulator - release_r;
                            end 

                        end 
                    endcase 
                end 
            end else if (note_on_pulse) begin 
                note_on_sticky  <= 1'b1;
            end else if (note_off_pulse) begin 
                note_off_sticky <= 1'b1;
            end 

        end 
    end 

endmodule 

`default_nettype wire