`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Baltazar Ortiz
// 
// Create Date: 11/04/2016 03:42:52 PM
// Design Name: 
// Module Name: playback
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Plays 16 bit, mono, 44.1khz wav files from the RAM
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module playback(
    input wire play, //signal from samplectl for a new sample being played
    input wire [REQ_ADDR_SIZE_U:0] address_in, //start address from samplectl
    
    output reg [REQ_ADDR_SIZE_U:0] address_out,
    output reg req_available, //signal to storage control when request has been generated
    output reg [REQ_ID_SIZE_U:0] r_id_out, //slot id of outgoing request


    input wire signed [15:0] data_in, //data from RAM
    input wire [REQ_ID_SIZE_U:0] r_id_in, //slot ID of incoming data
    input wire data_ready, //signal from storage controller when data is available from ram

    output reg signed [15:0] audio_out, //send to mixer

    input wire sample_clk,
    input wire clk,
    input wire reset
    );
    
    `include "globalparams.vh"
    
    //skip DEADBEEF bytes when starting
    parameter DATA_START = 2;

    parameter NUM_PLAYBACK_SLOTS = 30;
    parameter I_U = 5; //needs to be able index all playback slots. If this changes, REQ_ID_SIZE_U and other parts of the request mechanism must be changed

    //The playback module contains a number of "slots," each of which can handle the playback
    //of one sample at a time.
    //Slot related registers:
    //current address for the slot
    reg [REQ_ADDR_SIZE_U:0] addr [NUM_PLAYBACK_SLOTS:0];
    
    //flag for whether data for the current slot has already been received for this sample cycle
    reg [NUM_PLAYBACK_SLOTS:0] data_received = 1'd0;
    //flag for whether the current slot has already generated a request during this sample cycle
    reg [NUM_PLAYBACK_SLOTS:0] req_generated = 1'd0;
    //shift buffer for received data
    reg signed [31:0] data_buf [NUM_PLAYBACK_SLOTS:0];
    
    reg [I_U:0] s_update_ptr = 0; //next slot to replace when a new start address comes in
    reg [I_U:0] i = 0; //active slot for this clock cycle
    
    //Current summed sample to output next cycle
    reg signed [15:0] current_mix = 1'd0;
    
    //CAFEDUDE gets flipped when interpreting WAV data as little endian
    parameter CAFEDUDE = 32'hFECA0DD0; 
    
    //initialize brams to 0
    integer k;
    initial 
    for(k = 0; k < NUM_PLAYBACK_SLOTS + 1; k = k+1) begin
        addr[k] <= 1'd0;
        data_buf[k] <= 1'd0;
    end
    
    //registers to prevent issues from different width handshake signals
    reg already_updated = 0;
    reg already_played = 0; 
    reg [NUM_PLAYBACK_SLOTS:0] currently_playing = 1'd0;
    
    reg loopcount = 0;
    
    always @(posedge clk) begin
        if (reset) begin
            address_out <= 1'd0;
            audio_out <= 1'd0;
            r_id_out <= 1'd0;
            req_available <= 1'd0;
            s_update_ptr <= 1'd0;
            already_updated <= 1'd0;
            currently_playing <= 1'd0;
            already_played <= 1'd0;
            loopcount <= 1'd0;
            
        end
        else begin
            //on sample clock: output mix of all current samples
            if (sample_clk && !already_updated && currently_playing) begin
                audio_out <= current_mix;
                already_updated <= 1'd1;
                current_mix <= 1'd0;
                i <= 0;
                data_received <= 1'd0;
            end
            
            //only look at each slot once per sample cycle
            if (currently_playing != 0) begin
                
                //end of file, clear the slot
                if (data_buf[i] == CAFEDUDE) begin 
                    addr[i] <= 1'd0;
                    data_received[i] <= 1'd0;
                    req_generated[i] <= 1'd0;
                    data_buf[i] <= 1'd0;
                    address_out <= 0;
                    req_available <= 0;
                    currently_playing[i] <= 0;
                end
                //generate a request for the current slot if it doesn't have data yet
                //address can never be 0 because of jump to data section
                else if(addr[i] != 0 && data_received[i] == 0) begin
                    address_out <= addr[i];
                    addr[i] <= addr[i] + 1;
                    r_id_out <= i;
                    req_generated[i] <= 1;
                    req_available <= 1;
                end
                else begin
                    req_available <= 0;
                end

                if (i == NUM_PLAYBACK_SLOTS) i <= NUM_PLAYBACK_SLOTS + 1;
                else                         i <= i + 1;

            end
            else begin
                address_out <= 0;
                req_available <= 0;
            end
            
            //add incoming data to current_mix
            if (data_ready && !data_received[r_id_in]) begin
                req_generated[r_id_in] <= 0;
                data_received[r_id_in] <= 1;
                //put bytes in little endian order
                data_buf[r_id_in] <= {$signed(data_buf[r_id_in][23:0]),$signed(data_in[7:0]),$signed(data_in[15:8])};

                current_mix <= current_mix + ($signed(data_buf[r_id_in][31:16])) >>> 1; //shift to avoid clipping
            end
            
            //When a new address comes in, update a slot and increment the counter
            if (play && !already_played) begin
                //skip file header and jump straight to data
                addr[s_update_ptr] <= address_in + DATA_START;
                currently_playing[s_update_ptr] <= 1'd1; 
                already_played <= 1'd1;
                 
                //reset the slot
                data_received[s_update_ptr] <= 1'd0;
                req_generated[s_update_ptr] <= 1'd0;
                data_buf[s_update_ptr] <= 1'd0;
                
                i <= 1'd0;
                
                //wrap count or increment
                s_update_ptr <= (s_update_ptr == NUM_PLAYBACK_SLOTS ) ? 0 : s_update_ptr + 1;
            end
            
            //end handshake check signals when the signals that triggered them go low
            if (!sample_clk) begin
                already_updated <= 1'd0;
            end
            
            if (!play) begin
                already_played <= 1'd0;
            end
            
            if (currently_playing == 1'd0) audio_out <= 1'd0;
            
        end
    end
endmodule
`default_nettype wire
