`default_nettype none

module vcf #(
    parameter FILE_NAME = "mem/g_tan_lut.mem",
    parameter SOUND_WIDTH = 24,
    parameter CTRL_WIDTH = 16,
    parameter LUT_DEPTH = 12
)(
    input  wire clk,
    input  wire rst,

    input  wire audio_in_vld,
    input  wire signed [SOUND_WIDTH-1:0] audio_in,

    input  wire [CTRL_WIDTH-1:0] cutoff,
    input  wire [CTRL_WIDTH-1:0] resonance,

    input  wire [1:0] filter_mode,

    output logic audio_out_vld,
    output logic signed [SOUND_WIDTH-1:0] audio_out
);

    // UQ2.24 constants
    localparam logic [25:0] K_MAX   = 26'd33554432; // 2.0
    localparam logic [25:0] K_MIN   = 26'd1677722;  // 0.1
    localparam logic [25:0] K_RANGE = 26'd31876710; // 1.9

    logic [SOUND_WIDTH-1:0] tan_lut [(2**LUT_DEPTH)-1:0];

    // bring in LUT sine table
    initial begin 
        $readmemh(FILE_NAME, tan_lut);
    end 

    logic [23:0] g;  // UQ0.24
    logic [25:0] k;  // UQ2.24
    logic [24:0] a1; // UQ1.24
    logic [23:0] a2; // UQ0.24
    logic [31:0] a3; // UQ0.32

    logic [23:0] g_r;  // UQ0.24
    logic [25:0] k_r;  // UQ2.24
    logic [24:0] a1_r; // UQ1.24
    logic [23:0] a2_r; // UQ0.24
    logic [31:0] a3_r; // UQ0.32

    logic [25:0] divisor_tdata;
    logic [55:0] dout_tdata;
    logic din_tvalid;
    logic dout_tvalid; 

    // divider (vivado IP block)
    // dividend (UQ1.24), divisor (UQ2.24)
    div_gen_0_1 your_divider_inst (
        .aclk                   (clk),                                     

        .s_axis_divisor_tvalid  (din_tvalid),         
        .s_axis_divisor_tdata   (divisor_tdata),           

        .s_axis_dividend_tvalid (din_tvalid),        
        .s_axis_dividend_tdata  (32'd16777216),          

        .m_axis_dout_tvalid     (dout_tvalid),               
        .m_axis_dout_tdata      (dout_tdata)                   
    );
    
    typedef enum logic [2:0] {
        SAMPLE, DIVISOR, WAIT, MULT_1, MULT_2, OUTPUT
    } state_t;

    state_t state;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            divisor_tdata <= 1'b1;
            g  <= '0;
            k  <= '0;
            a1 <= '0;
            a2 <= '0;
            a3 <= '0;
            g_r  <= '0;
            k_r  <= '0;
            a1_r <= '0;
            a2_r <= '0;
            a3_r <= '0;
            audio_out <= '0;
            din_tvalid <= 1'b0;
            audio_out_vld <= 1'b0;
            state <= SAMPLE;
        end else begin 
            din_tvalid <= 1'b0;

            case (state)  
                SAMPLE : begin 
                    din_tvalid <= 1'b0;
                    g_r <= tan_lut[cutoff[15:4]];

                    // k = 2 - 1.9 * R / (65535)
                    // k = KMAX - 1.9 * resonance / 65535
                    k_r <= K_MAX - ((42'(K_RANGE * resonance)) >> 16);

                    state <= DIVISOR;
                end 
                
                DIVISOR : begin
                    din_tvalid <= 1'b1;

                    // 1 + g (g + k)
                    // g is UQ0.24, k is UQ2.24, 1 in UQ2.24 is 16777216
                    // g + k = UQ3.24
                    // g * (g + k) = UQ3.48
                    divisor_tdata <= 'd16777216 + ((51'(g_r * (27'(g_r + k_r)))) >> 24);

                    state <= WAIT;
                end 

                WAIT : begin 
                    if (dout_tvalid) begin
                        a1_r <= {dout_tdata[24:0]};
                        state <= MULT_1;
                    end
                end 

                MULT_1 : begin 
                    a2_r <= (49'(g_r * a1_r)) >> 24;
                    state <= MULT_2;
                end 

                MULT_2 : begin 
                    a3_r <= (48'(g_r * a2_r)) >> 16;
                    state <= OUTPUT;
                end  

                OUTPUT : begin 
                    g  <= g_r;
                    k  <= k_r;
                    a1 <= a1_r;
                    a2 <= a2_r;
                    a3 <= a3_r;
                    state <= SAMPLE;
                end 
            endcase 
        end 
    end

    // Q8.32
    logic signed [39:0] v3, bp, lp, hp, s1, s2;

    // stage 1
    logic signed [41:0] mult_a1_s1; // Q2.24 * Q8.32 = Q10.56 (chop to Q10.32)
    logic signed [40:0] mult_a3_v3; // Q1.32 * Q8.32 = Q9.64 (chop to Q9.32)
    logic signed [40:0] mult_a2_s1; // Q1.24 * Q8.32 = Q9.56 (chop to Q9.32)
    logic signed [40:0] mult_a2_v3; // Q1.24 * Q8.32 = Q9.56 (chop to Q9.32)

    // stage 3
    logic signed [42:0] mult_k_bp; // Q3.24 * Q8.32 = Q11.56 (chop off to Q11.32)

    typedef enum logic [2:0] {
        IDLE, BP_LP, HP, OUT
    } state2_t;
    state2_t state2;

    logic [23:0] g_rr;  // UQ0.24
    logic [25:0] k_rr;  // UQ2.24
    logic [24:0] a1_rr; // UQ1.24
    logic [23:0] a2_rr; // UQ0.24
    logic [31:0] a3_rr; // UQ0.32
    logic signed [23:0] latched_aud;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            v3 <= '0;   
            bp <= '0;  
            lp <= '0;
            hp <= '0;
            s1 <= '0;
            s2 <= '0;
            g_rr  <= '0;
            k_rr  <= '0;
            a1_rr <= '0;
            a2_rr <= '0;
            a3_rr <= '0;
            latched_aud <= '0;
            state2 <= IDLE;
        end else begin
            case (state2)
                IDLE : begin 
                    audio_out_vld <= 1'b0;

                    if (audio_in_vld) begin 
                        v3 <= (audio_in << 9) - s2; 
                        mult_a1_s1 <= (66'($signed({1'b0, a1}) * s1)) >>> 24;
                        mult_a3_v3 <= (73'($signed({1'b0, a3}) * 40'((audio_in << 9) - s2))) >>> 32;
                        mult_a2_s1 <= (65'($signed({1'b0, a2}) * s1)) >>> 24;
                        mult_a2_v3 <= (65'($signed({1'b0, a2}) * 40'((audio_in << 9) - s2))) >>> 24;
                        latched_aud <= audio_in; 

                        g_rr  <= g;
                        k_rr  <= k;
                        a1_rr <= a1;
                        a2_rr <= a2;
                        a3_rr <= a3;

                        state2 <= BP_LP;
                    end 
                end 

                BP_LP : begin 
                    bp <= mult_a1_s1 + mult_a2_v3;
                    lp <= s2 + mult_a2_s1 + mult_a3_v3;
                    
                    state2 <= HP;
                end 

                HP : begin 
                    mult_k_bp <= (67'($signed({1'b0, k_rr}) * bp)) >>> 24;
                    hp <= ((latched_aud) << 9) - lp;
                    
                    state2 <= OUT;
                end 

                OUT : begin 
                    s1 <= (bp << 1) - s1;
                    s2 <= (lp << 1) - s2;
                    hp <= hp - mult_k_bp;

                    case (filter_mode)
                        2'b00 : begin 
                            audio_out <= (lp >>> 9);
                        end 
                        2'b01 : begin 
                            audio_out <= ((hp - mult_k_bp) >>> 9);
                        end 
                        2'b10 : begin 
                            audio_out <= (bp >>> 9);
                        end 
                        default : begin 
                            audio_out <= '0;
                        end
                    endcase

                    audio_out_vld <= 1'b1;

                    state2 <= IDLE;
                end 
            endcase 
        end 
    end 

endmodule 

`default_nettype wire