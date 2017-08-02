`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/04/2016 03:42:52 PM
// Design Name: 
// Module Name: sampler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Use this version of the sampler module when running sampler_tb. Allows testbench to feed in fake RAM and SD input.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sampler_debug(
    //input from sequencer
    input wire [3:0] trigger,
    input wire start_load,
    input wire reset,
    
    //clock inputs
    input wire clk100,
    input wire clk200,
    input wire sample_clk,
    
    output reg signed [15:0] audio_out,

    //SRAM to DDR converter interface
    input wire device_temp,
    output wire [15:0] LED_OUT,
    output wire [12:0] ddr2_addr,
    output wire [2:0] ddr2_ba,
    output wire ddr2_ras_n,
    output wire ddr2_cas_n,
    output wire ddr2_we_n,
    output wire ddr2_ck_p,
    output wire ddr2_ck_n,
    output wire ddr2_cke,
    output wire ddr2_cs_n,
    output wire [1:0] ddr2_dm,
    output wire ddr2_odt,
    inout wire signed [15:0] ddr2_dq,
    inout wire [1:0] ddr2_dqs_p,
    inout wire [1:0] ddr2_dqs_n,
    
    //SD interface
      output wire cs, // Connect to SD_DAT[3].
      output wire mosi, // Connect to SD_CMD.
     input wire miso, // Connect to SD_DAT[0].
     output wire sclk, // Connect to SD_SCK.
     output wire [31:0] sd_address,
     
     //debug 
     output wire sd_rd_debug,
     output wire sd_wr_debug,
     output signed [7:0] sd_din_debug,
     input wire sd_ready_debug,
     input wire signed [7:0] sd_dout_debug,
     input wire  sd_byte_available_debug,
     output wire signed [15:0] ram_dq_i_debug,
     input wire signed [15:0] ram_dq_o_debug 
     
    );

    `include "globalparams.vh"

    assign LED_OUT[0] = start_load;
    assign LED_OUT[1] = reset;
    assign LED_OUT[2] = initial_load_finished;
    assign LED_OUT[15:8] = sd_dout;
    assign LED_OUT[7:3] = 0;

    //25 MHz clock divider for SD card
    wire spi_clk;
    reg spi_clk_reg = 0;
    
    sd_divider div (
        .clk(clk100),
        .reset(reset),
        .spi_clk(spi_clk)
    );
    
    //instantiate sd controller
    wire sd_rd;
    wire sd_wr;
    wire sd_byte_available;
    wire sd_ready_for_next_byte;
    wire sd_ready;
    wire signed [7:0] sd_din;
    wire signed [7:0] sd_dout;
     
    //override sd signals
    assign sd_rd_debug = sd_rd;
    assign sd_wr_debug = sd_wr;
    assign sd_byte_available = sd_byte_available_debug;
    assign sd_ready = sd_ready_debug;
//    assign sd_din_debug = sd_din;
    assign sd_dout = sd_dout_debug;
    
     
    sd_controller sdctl (
        .cs(cs),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .rd(sd_rd),
        .dout(),
        .byte_available(),
        .wr(sd_wr),
        .din(sd_din),
        .ready_for_next_byte(sd_ready_for_next_byte),
        .reset(reset),
        .ready(),
        .address(sd_address),
        .clk(spi_clk)
    );

    //instantiate storage controller
    wire update;
    wire [26:0] playback_a_out;
    wire [31:0] sd_address;
    wire signed [15:0] storage_audio_out;
    wire audio_data_ready;
    wire initial_load_finished;
    wire playback_req_available;
    wire [26:0] start_a;
    wire [REQ_ID_SIZE_U:0] r_id_in;
    wire [REQ_ID_SIZE_U:0] r_id_out;
    wire [26:0] ram_a;
    wire signed [15:0] ram_dq_i;
    wire signed [15:0] ram_dq_o;
    wire ram_cen;
    wire ram_oen;
    wire ram_wen;
    wire ram_ub;
    wire ram_lb;
    
    assign ram_dq_i_debug = ram_dq_i;
    assign ram_dq_o = ram_dq_o_debug;
    
    storagectl storage_controller (
        .load(start_load),
        .initial_load_finished(initial_load_finished),
        .sd_ready(sd_ready),
        .sd_address(sd_address),
        .sd_rd(sd_rd),
        .sd_dout(sd_dout),
        .sd_byte_available(sd_byte_available),
        .sd_wr(sd_wr),
        .sd_din(sd_din),
        .ready_for_next_byte(sd_ready_for_next_byte),
        .update(update),
        .playback_req_available(playback_req_available),
        .playback_a(playback_a_out),
        .r_id_in(r_id_in),
        .start_a(start_a),
        .ram_a(ram_a),
        .ram_dq_i(ram_dq_i),
        .ram_dq_o(ram_dq_o),
        .ram_cen(ram_cen),
        .ram_oen(ram_oen),
        .ram_wen(ram_wen),
        .audio_data_ready(audio_data_ready),
        .audio_out(storage_audio_out),
        .r_id_out(r_id_out),
        .spi_clk(spi_clk),
        .clk(clk200),
        .reset(reset)
    );
    
    //instantiate SDRAM -> DDR converter
    //ram2ddr mem_interface (
    ram2ddrxadc mem_interface (
        .clk_200MHz_i(clk200),
        .rst_i(reset),
        .device_temp_i(device_temp),
        .ram_a(ram_a),
        .ram_dq_i(),
        .ram_dq_o(),
        .ram_cen(ram_cen),
        .ram_oen(ram_oen),
        .ram_wen(ram_wen),
        .ram_ub(ram_ub),
        .ram_lb(ram_lb),
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
        .ddr2_dqs_n(ddr2_dqs_n)
    );
    
    //instantiate sample controller
    
    wire [26:0] playback_a_in;
    wire trigger_playback;
    wire [3:0] samplectl_trigger;
    
    samplectl sample_controller(
        .trigger(samplectl_trigger),
        .update(update),
        .address_in(start_a),
        .address_out(playback_a_in),
        .trigger_playback(trigger_playback),
        .clk(clk200),
        .reset(reset)
    );
    
    //instantiate playback module
    wire signed [15:0] playback_audio_out;
    
    playback playback_module(
        .play(trigger_playback),
        .address_in(playback_a_in),
        .data_in(storage_audio_out),
        .address_out(playback_a_out),
        .req_available(playback_req_available),
        .audio_out(playback_audio_out),
        .r_id_in(r_id_out),
        .r_id_out(r_id_in),
        .data_ready(audio_data_ready),
        .sample_clk(sample_clk),
        .clk(clk200),
        .reset(reset)
    );

    //initialization FSM - prevent audio output until initial load has occured
    //states
    parameter INIT = 1'd0;
    parameter READY = 1'd1;
    
    (* mark_debug = "true" *)  reg state = INIT;
    reg [1:0] next_state = INIT;
    
    assign samplectl_trigger = (state == READY) ? trigger : 1'd0;
    
    always @(*) begin
        if (reset) next_state = INIT;
        else begin
            case (state)
                INIT: begin
                    if (initial_load_finished) next_state = READY;
                    else next_state = INIT;
                end
                READY: begin
                    next_state = READY;
                end
            endcase
        end
    end
    
    always @(posedge clk200) state <= next_state;
    
    always @(posedge clk200) begin
        if (reset) begin
            audio_out <= 1'd0;
        end
        else begin
            case (state)
                INIT: begin
                    audio_out <= 1'd0;
                end
                READY: begin
                    audio_out <= playback_audio_out;
                end
            endcase
        end
    end
    
endmodule
