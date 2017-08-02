`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
//
// Create Date:   11:44:00 11/21/2016
// Design Name:   sd_interface_tb
// 
////////////////////////////////////////////////////////////////////////////////

module sd_interface_tb;

    //reg -> inputs
    //wire -> outputs

    reg sd_start_read; //external trigger to start load from sd
    
    //------------   SD Interface -----------------
    reg sd_ready; // HIGH if the SD card is ready for a read or write operation. 
    wire [31:0] sd_address; // Memory address for read/write operation. This MUST 
                                      // be a multiple of 512 bytes, due to SD sectoring.   
    
    wire sd_rd; // Read-enable. When [ready] is HIGH, asseting [rd] will 
                      // begin a 512-byte READ operation at [address]. 
                      // [byte_available] will transition HIGH as a new byte has been
                      // read from the SD card. The byte is presented on [dout].
    reg [7:0]  sd_dout;  // Data output for READ operation.
    reg sd_byte_available; // A new byte has been presented on [dout].
    
    wire sd_wr; // Write-enable. When [ready] is HIGH, asserting [wr] will
                      // begin a 512-byte WRITE operation at [address].
                      // [ready_for_next_byte] will transition HIGH to request that
                      // the next byte to be written should be presentaed on [din].
    wire [7:0] sd_din; // Data input for WRITE operation.   
    reg ready_for_next_byte; // A new byte should be presented on [din].
    //--------------------------------------------
    
    wire [15:0] sd_read_out; //buffered data from SD card - primary output of this module to other modules
    wire new_file; //signal if a new file is being transmitted
    wire req_available; //signal when a request has been generated
    
    reg [16:0] req_count = 0; //set to zero because testbed for just the sd interface can continue running without having to wait for FIFO
    
    reg clk;
    reg reset;

    //FSM
    //states
    parameter IDLE = 3'd0;
    parameter SD_START = 3'd1; //sends start signal to SD controller
    parameter SD_LISTEN = 3'd2; //waits for SD to present data on sd_dout
    parameter SD_REC = 3'd3; //adds sd_dout to buffer
    parameter SD_FINISH_1 = 3'd4;
    parameter SD_FINISH_2 = 3'd5;
    parameter SD_DONE = 3'd6;


    //initialize uut
    sd_interface uut (
    .sd_start_read(sd_start_read), 
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
    .req_available(req_available),
    .clk(clk),
    .reset(reset),
    .req_count(req_count)
    );
    
    //variables for testing
    //TODO: Change this to a size that can hold the entire file
    parameter SAMPLESIZE = 10000;
    reg signed [7:0] samples [SAMPLESIZE:0];
    integer file;
    reg [31:0] read_c;
    integer i;
    integer j;
    
    initial begin
        clk = 0;
    end
         
    //start 25 MHz clock
    always #20 clk = !clk;
    
    initial begin
        $display("Testing sd interface");
        
        //initialize inputs
        sd_start_read = 0;
        sd_ready = 0;
        sd_dout = 0;
        sd_byte_available = 0;
        ready_for_next_byte = 0;
        
        // Wait 100 ns for global reset to finish
        #400;
       
        $display("Load datafile");
      
        //TODO: choose a filename
        file = $fopen("datfile.dat", "rb");
        read_c = $fread(samples, file);
        $display("%d bytes read", read_c);
        $display("Load complete."); 
    
        //----------- test 1 ------------
        // Simulate a load from SD using data in text file
        //
        
        $display("Test 1: simulate load");
        //trigger read start
        sd_start_read = 1;       
        
        #120;
        //FSM should be in START state
        if(uut.state != SD_START) begin
            $display("Expected state: %d. Actual state: %d",SD_START, uut.state);
            $stop;
        end

        sd_start_read = 0;
        #120;
        //Trigger SD ready signal
        @(posedge clk) sd_ready = 1;
        
        //FSM should be in LISTEN state
        #120;
        @(posedge clk) begin
            if(uut.state != SD_REC) begin
                $display("Expected state: %d. Actual state: %d",SD_REC, uut.state);
                $stop;
            end
        end
        
        #40;
        @(posedge clk) sd_ready = 0;
        #120;
        //simulate 512 byte read burst from SD
        i = 0; //total number of reads
        j = 0; //loop counter 
        while (i < read_c && uut.sd_buf != 32'hFEE1DEAD) begin        
            for (j = 0; j < 512; j = j + 1) begin
            
               
                @(posedge clk) begin     
                    sd_byte_available = 1;
                    sd_dout = samples[i];
                    if (i < read_c) i = i + 1;
                end  
                @(posedge clk) sd_byte_available = 0;
                 #80;
            end
            #40;
            if(uut.sd_buf != 32'hFEE1DEAD) begin
                if(uut.state != SD_START) begin
                    $display("Expected state: %d. Actual state: %d",SD_START, uut.state);
                    $stop;
                end    
                
                //Trigger SD ready signal
                sd_ready = 1;
                #40;
                //FSM should be in SD_REC state
                if(uut.state != SD_REC) begin
                    $display("Expected state: %d. Actual state: %d",SD_REC, uut.state);
                    $stop;
                end
                
                #40;
                sd_ready = 0;
            end
        end

        #800;
        
        //FSM should return to IDLE state once read is over
        if(uut.state != IDLE) begin
            $display("Expected state: %d. Actual state: %d",IDLE, uut.state);
            $stop;
        end    

        $display("Test 1 complete."); 
        $display("SD interface test complete.");

        $finish;
    end


endmodule
