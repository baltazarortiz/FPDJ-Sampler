`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
// Create Date: 12/4/2016
// Module Name: fpdj
// Project Name: FPDJ
// Target Devices: Nexys 4 DDR
// Description: Top level module to test the sampler on the labkit without the sequencer or synth.
// 
// Dependencies: 
// 
// 
//////////////////////////////////////////////////////////////////////////////////


module fpdj_only_sampler(
    input wire CLK100MHZ,
    input wire[15:0] SW, 
    input wire BTNC, BTNU, BTNL, BTNR, BTND,
    input wire CPU_RESETN,
    output wire [15:0] LED,
    output wire SD_RESET,
    input wire SD_CD,
    output wire SD_SCK,
    output wire SD_CMD,
    inout wire [3:0] SD_DAT,
    output wire AUD_PWM,
    output wire AUD_SD,
    
    //memory signals
    output wire   [12:0] ddr2_addr,
    output wire  [2:0] ddr2_ba,
    output wire  ddr2_ras_n,
    output wire  ddr2_cas_n,
    output wire  ddr2_we_n,
    output wire  ddr2_ck_p,
    output wire  ddr2_ck_n,
    output wire  ddr2_cke,
    output wire  ddr2_cs_n,
    output wire  [1:0] ddr2_dm,
    output wire  ddr2_odt,
    inout  wire  [15:0] ddr2_dq,
    inout  wire  [1:0] ddr2_dqs_p,
    inout  wire  [1:0] ddr2_dqs_n
   );

    wire RESET;
    assign RESET = SW[15];
    
    wire CLK200MHZ;
    wire CLK100_PLL;
    clkgen clk_gen (
        .reset(RESET),
        .clk_in1(CLK100MHZ),
        .CLK100(CLK100_PLL),
        .CLK200(CLK200MHZ),
        .locked()
    );
    
    wire BTNC_DB;
    wire BTNU_DB;
    wire BTNL_DB;
    wire BTNR_DB;
    wire BTND_DB;
    wire CPU_RESETN_DB;
    
    debounce db_btnc(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNC),.clean(BTNC_DB));
    debounce db_bdnu(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNU),.clean(BTNU_DB));
    debounce db_btnl(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNL),.clean(BTNL_DB));
    debounce db_btnr(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNR),.clean(BTNR_DB));
    debounce db_btnrd(.reset(RESET),.clock(CLK100_PLL),.noisy(BTND),.clean(BTND_DB));

    wire sample_clk;

    wire sample_clock;
    sample_clock_divider sample_div (
        .clock(CLK200MHZ),
        .div(sample_clk)
);
 
    //trigger sampler by setting switches and pressing enter
    reg [3:0] trigger = 1'd0;

    always @(posedge CLK200MHZ) begin
        if (BTNC_DB) begin
            trigger <= SW[3:0];
        end
        else begin
            trigger <= 1'd0;
        end
    end
    
    //instantiate sampler
    wire signed [15:0] sam_audio_out;
        
    //set SD wires to constant as defined in provided sd interface
    assign SD_DAT[2] = 1;
    assign SD_DAT[1] = 1;
    assign SD_RESET = 0;
    
    sampler SAM (
        .trigger(trigger),
        .reset(RESET),
        .LED_OUT(LED),
        .clk100(CLK100_PLL),
        .clk200(CLK200MHZ),
        .sample_clk(sample_clk),
        .audio_out(sam_audio_out),
        .device_temp(),
        .ddr2_addr(ddr2_addr),
        .ddr2_ba(ddr2_ba),
        .ddr2_ras_n(ddr2_ras_n),
        .ddr2_cas_n(ddr2_cas_n),
        .ddr2_we_n(ddr2_we_n),
        .ddr2_ck_p(ddr2_ck_p),
        .ddr2_ck_n(ddr2_ck_n),
        .ddr2_cke(ddr2_cke),
        .ddr2_cs_n(ddr2_cs_n),
        .ddr2_dm(ddr2_dm),
        .ddr2_odt(ddr2_odt),
        .ddr2_dq(ddr2_dq),
        .ddr2_dqs_p(ddr2_dqs_p),
        .ddr2_dqs_n(ddr2_dqs_n),
        .cs(SD_DAT[3]),
        .mosi(SD_CMD),
        .miso(SD_DAT[0]),
        .sclk(SD_SCK)
    );

    //enable PWM
    assign AUD_SD = 1'b1;
    
    audio_PWM PWM (
        .clock(CLK200MHZ),
        .reset(RESET),
        .music_data($signed(sam_audio_out[15:6])),
        .PWM_out(AUD_PWM)
    );

endmodule
`default_nettype wire
