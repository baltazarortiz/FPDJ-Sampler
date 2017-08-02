`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
// 
// Create Date: 11/04/2016 03:42:52 PM
// Design Name: 
// Module Name: storagectl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Contains sd interface and ram fifo
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module storagectl(
        input wire load, //external trigger to start loading samples from SD
        output wire initial_load_finished,
        //------------   SD Interface -----------------
        input wire sd_ready, // HIGH if the SD card is ready for a read or write operation. 
        output wire [31:0] sd_address, // Memory address for read/write operation. This MUST 
                                          // be a multiple of 512 bytes, due to SD sectoring.   
        
        output wire sd_rd, // Read-enable. When [ready] is HIGH, asseting [rd] will 
                          // begin a 512-byte READ operation at [address]. 
                          // [byte_available] will transition HIGH as a new byte has been
                          // read from the SD card. The byte is presented on [dout].
        input wire signed [7:0]  sd_dout,  // Data output for READ operation.
        input wire sd_byte_available, // A new byte has been presented on [dout].
        
        output wire sd_wr, // Write-enable. When [ready] is HIGH, asserting [wr] will
                          // begin a 512-byte WRITE operation at [address].
                          // [ready_for_next_byte] will transition HIGH to request that
                          // the next byte to be written should be presentaed on [din].
        output wire signed [7:0] sd_din, // Data input for WRITE operation.   
        input wire ready_for_next_byte, // A new byte should be presented on [din].
        //--------------------------------------------
        
        output wire update, //signal to sampler controller that sample start addresses are being sent
        
        input wire playback_req_available, //external trigger to start reading audio from RAM    
        input wire [26:0] playback_a, //start address sent by playback module
        input wire [REQ_ID_U:0] r_id_in,
        output wire [26:0] start_a, //start address sent to samplectl module
        
        //------------- RAM Interface ----------------    
        output wire[26:0] ram_a,
        output wire signed [15:0] ram_dq_i,
        input wire signed  [15:0] ram_dq_o,
        output wire ram_cen,
        output wire ram_oen,
        output wire ram_wen,
       //---------------------------------------------
        //output to playback module
        output wire audio_data_ready,
        output wire signed [15:0] audio_out, //audio data to send back to playback module
        output wire [REQ_ID_SIZE_U:0] r_id_out,
        input wire spi_clk,
        input wire clk,
        input wire reset
    );

    `include "globalparams.vh"

    wire signed [15:0] sd_read_out; 
    wire new_file;
    wire sd_req_available;
    wire [9:0] req_count;
    
    sd_interface sd_i (
    .sd_start_read(load), 
    .initial_load_finished(initial_load_finished),
    .req_count(req_count),
    .sd_ready(sd_ready), 
    .sd_address(sd_address), 
    .sd_rd(sd_rd), 
    .sd_dout(sd_dout),  
    .sd_byte_available(sd_byte_available),
    .sd_wr(sd_wr),
    .sd_din(sd_din), 
    .ready_for_next_byte(ready_for_next_byte),
    .sd_read_out(sd_read_out), 
    .new_file(new_file), 
    .req_available(sd_req_available),
    .clk(spi_clk),
    .reset(reset)
    );
    
    arbiter arbiter1 (
    .ram_a(ram_a),
    .ram_dq_i(ram_dq_i),
    .ram_dq_o(ram_dq_o),
    .ram_cen(ram_cen),
    .ram_oen(ram_oen),
    .ram_wen(ram_wen),
    .sd_data(sd_read_out),
    .sd_req(sd_req_available),
    .new_file(new_file),
    .req_count(req_count),
    .playback_addr(playback_a),
    .r_id_in(r_id_in),
    .playback_req(playback_req_available),
    .update(update),
    .start_addr(start_a),
    .data_ready(audio_data_ready),
    .from_ram(audio_out),
    .r_id_out(r_id_out),
    .clk(clk),
    .spi_clk(spi_clk),
    .reset(reset)
    );
    
endmodule
`default_nettype wire
