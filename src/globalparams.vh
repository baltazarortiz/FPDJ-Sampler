//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
// 
// Create Date: 11/23/2016 10:35:00 AM
// Design Name: 
// Module Name: globalparams
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Contains parameters used by multiple modules
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//NOTE: sizes are upper bounds, not widths

//////
//Request structure:
//bit 32:31 - READ or WRITE (10 or 11)
//
//READ
//bits 30:27  request id number
//bits 26:0 - RAM address
//
//WRITE
//bit 30 - new file? (1 or 0)
//bits 15:0 - data to write
/////

    parameter REQ_SIZE_U = 32;

    parameter REQ_TYPE_U = 32; //highest two bits are the type of the request
    parameter REQ_TYPE_L = 31;
    
    parameter REQ_NEW_FILE = 30; //next bit of write requests is the new file toggle
    //bounds for ID, read address, and write data
    parameter REQ_ID_SIZE_U = 4;
    parameter REQ_ID_U = 30;
    parameter REQ_ID_L = 27;

    parameter REQ_ADDR_SIZE_U = 26;
    parameter REQ_ADDR_U = 26;
    parameter REQ_ADDR_L = 0;

    parameter REQ_DATA_SIZE_U = 15;
    parameter REQ_DATA_U = 15;
    parameter REQ_DATA_L = 0;

    parameter READ = 2'b10;
    parameter WRITE = 2'b11;

    //parameter RAM_WRITE_DELAY = 6'd55; //200mhz clk
    parameter RAM_WRITE_DELAY = 6'd28; //100mhz clk
    parameter RAM_READ_DELAY = 6'd28; //This can be made lower, but its easier to use the same for both for now
