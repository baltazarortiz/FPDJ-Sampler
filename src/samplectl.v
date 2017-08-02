`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
// 
// Create Date: 11/04/2016 03:42:52 PM
// Design Name: 
// Module Name: samplectl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Translate sample triggers from sequencer into addresses to be
//              sent to the playback module. Also associates addresses from
//              storagectl with trigger inputs. 
//
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module samplectl(
    input wire [3:0] trigger, //0 corresponds to silence, 1-15 corresponds to loaded samples
    input wire update, //trigger when new sample is loaded
    input wire [26:0] address_in, //start address of new sample 
    output reg [26:0] address_out, //start address of playback requeset
    output reg trigger_playback, //trigger when sending playback request
    input wire clk,
    input wire reset
    );
    
    initial address_out = 27'd0;
    initial trigger_playback = 0;
    
    reg [3:0] i = 4'd1;
        
    reg [26:0] s_ptr [15:1];
        
    //initialize bram to 0
    integer k;
    initial 
      for(k = 1; k < 16; k = k+1) 
        s_ptr[k] = 26'd0;
    
    reg already_updated = 0;
    
    always @(posedge clk) begin
        if (reset) begin
            address_out <= 27'd0;
            trigger_playback <= 0;
            i <= 4'd1;
            already_updated <= 0;
        end
        else begin
        
            //replace sample pointers when update asserted
            if (update && !already_updated) begin
                s_ptr[i] <= address_in;
                i <= (i == 4'd15) ? 1 : i + 1;
                already_updated <= 1;
            end
            else if (!update) already_updated <= 0;
        
            //process triggers
            if (trigger != 0) begin
                trigger_playback <= 1;
                address_out <= s_ptr[trigger];
            end
            else begin
                trigger_playback <= 0;
            end
        end
    end
    
endmodule
`default_nettype wire
