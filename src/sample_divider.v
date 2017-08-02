`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
//
// Create Date: 12/5/2016
// Design Name:
// Module Name: sample_divider
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies: Create 44.1 khz divider
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module sample_divider(
               input wire  clk,
               input wire  reset,
               output wire sample_clk
               );

   reg [12:0]              count = 0;
//2268 -- 100mhz
//4535 -- 200mhz
   always @(posedge clk) begin
      if (reset) begin
         count <= 1'd0;
      end

      if (count == 12'd2268)
        count <= 1'd0;
      else
        count <= count + 1;
   end

   assign sample_clk = (count == 12'd2268);

endmodule
`default_nettype wire
