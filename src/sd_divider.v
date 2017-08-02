`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
//
// Create Date: 12/5/2016
// Design Name:
// Module Name: sd_divider
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies: Create 25MHz clock from 100MHz input
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module sd_divider(
       input wire  clk,
       input wire  reset,
       output reg  spi_clk
   );

   initial spi_clk = 0;
   
   reg [8:0] count = 0;

   always @(posedge clk) begin
      if (reset) begin
         count <= 1'd0;
         spi_clk <= 0;
      end

      if (count == 9'd4) begin
        count <= 1'd0;
        spi_clk <= !spi_clk;
      end
      else
        count <= count + 1;
   end

endmodule
`default_nettype wire
