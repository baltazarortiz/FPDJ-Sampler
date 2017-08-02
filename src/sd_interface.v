`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
// 
// Create Date: 11/11/2016 01:02:37 PM
// Design Name: 
// Module Name: sd_interface
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Handle SD reads. Interfaces with SD controller. Takes in signal to start
//              a block read and outputs the bits as they arrive. Continues to read until
//              all of the data on the SD card has been read.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sd_interface(
    input wire sd_start_read, //external trigger to start load from sd
    output reg initial_load_finished,
    input wire [9:0] req_count, //number of requests currently stored in the FIFO
    //------------   SD Interface -----------------
    input wire sd_ready, // HIGH if the SD card is ready for a read or write operation. 
    output reg [31:0] sd_address, // Memory address for read/write operation. This MUST 
                                      // be a multiple of 512 bytes, due to SD sectoring.   
    
    output reg sd_rd, // Read-enable. When [ready] is HIGH, asseting [rd] will 
                      // begin a 512-byte READ operation at [address]. 
                      // [byte_available] will transition HIGH as a new byte has been
                      // read from the SD card. The byte is presented on [dout].
    input wire signed [7:0]  sd_dout,  // Data output for READ operation.
    input wire sd_byte_available, // A new byte has been presented on [dout].
    
    output reg sd_wr, // Write-enable. When [ready] is HIGH, asserting [wr] will
                      // begin a 512-byte WRITE operation at [address].
                      // [ready_for_next_byte] will transition HIGH to request that
                      // the next byte to be written should be presentaed on [din].
    output reg [7:0] sd_din, // Data input for WRITE operation.   
    input wire ready_for_next_byte, // A new byte should be presented on [din].
    //--------------------------------------------
    
    output reg signed [15:0] sd_read_out, //buffered data from SD card - primary output of this module to other modules
    output reg new_file, //signal if a new file is being transmitted
    output reg req_available, //signal when a request has been generated
    input wire clk, //25 MHz
    input wire reset
    );
     
    //shift register to process SD read output
    reg [31:0] sd_buf = 1'd0;
    reg [15:0] out_buf = 1'd0; 
    reg new_file_buf = 1'd0;
    
    reg [9:0] read_count = 1'd0; //count how many byes have been read
    
    
    //parameters inserted into SD by python script
    parameter DEADBEEF = 32'hDEADBEEF;
    parameter FEELDEAD = 32'hFEE1DEAD;
    
    //FSM
    //states
    parameter IDLE = 3'd0;
    parameter SD_START = 3'd1; //sends start signal to SD controller
    parameter SD_LISTEN = 3'd2; //waits for SD to present data on sd_dout
    parameter SD_REC = 3'd3; //adds sd_dout to buffer
    parameter SD_FINISH_1 = 3'd4; //2 more clock cycles needed before done because of buffer, so go from rec -> finish1 -> finish2
    parameter SD_FINISH_2 = 3'd5;
    parameter SD_DONE = 3'd6; //read complete

    reg [2:0] state = IDLE;
    reg [2:0] next_state = IDLE;
    
    //state transition logic
    always @(*) begin
        if (reset) next_state = IDLE;
        else begin
            case (state) 
                IDLE: begin
                    if (sd_start_read || (initial_load_finished == 0))                next_state = SD_START;
                    else                                                              next_state = IDLE;
                end
                SD_START: begin
                    if (sd_ready && req_count < 17'd512)                     next_state = SD_REC;
                    else                                                     next_state = SD_START;
                end
                SD_REC: begin
                    if (sd_buf == FEELDEAD)           next_state = SD_FINISH_1;     //end of file, finish the read
                    else if (read_count == 10'd511)   next_state = SD_START;        //file not ended, start another 512 byte read 
                    else                              next_state = SD_REC;
                end
                SD_FINISH_1: next_state = SD_FINISH_2;
                SD_FINISH_2: next_state = SD_DONE;
                SD_DONE: next_state = SD_DONE;
            endcase
        end
    end
    
    always @(posedge clk) begin
        state <= next_state;
    end
    
    //state output logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                sd_rd       <= 0;
                sd_wr       <= 0;
                sd_din      <= 8'd0;
                sd_address  <= 32'd0;
                req_available <= 0;
                new_file <= 0;
                sd_read_out <= 0;
                initial_load_finished <= 0;
            end
            SD_START: begin
                //Start read once SD card is ready
                if (sd_ready && req_count <= 17'd512) begin 
                    sd_rd <= 1;
                    sd_buf <= 1'd0; //clear buffer just in case
                    read_count <= 10'd0;
                    req_available <= 0;

                    if (read_count == 10'd511)  //increment read address if we're continuing a read
                        sd_address <= sd_address + 32'd512; 
                    else
                        sd_address <= 32'd0; 
                end
            end
            SD_REC,SD_FINISH_1,SD_FINISH_2: begin
                sd_rd <= 0;
                
                if(sd_byte_available) begin
                    //Put byte from SD into buffer for processing and output to other modules
                    sd_buf <= {sd_buf[23:0],sd_dout};
                    
                    out_buf <= {out_buf[7:0],sd_buf[31:24]};

                    read_count <= read_count + 10'd1;
                end
                
                //don't start signalling for available requests
                //until shift buffer is outputting real data
                if (read_count >= 10'd6 && read_count % 2 == 0) begin 
                    req_available <= 1;
                    new_file <= new_file_buf;
                    new_file_buf <= 0;
                    sd_read_out <= out_buf;
                end
                else req_available <= 0;
                
                //Signal if new file is starting
                if (sd_buf == DEADBEEF)    new_file_buf <= 1;

                if (new_file) new_file <= 0;
                
            end
            SD_DONE: begin
                sd_rd       <= 0;
                sd_wr       <= 0;
                sd_din      <= 8'd0;
                sd_address  <= 32'd0;
                req_available <= 0;
                new_file <= 0;
                initial_load_finished <= 1;
            end
        endcase
    end
    
endmodule
`default_nettype wire
