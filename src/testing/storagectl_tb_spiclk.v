`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
//
// Create Date:   14:06:00 11/26/2016
// Design Name:   storagectl_tb
// 
////////////////////////////////////////////////////////////////////////////////

module storagectl_tb_spiclk;
    //reg -> inputs to uut
    //wire -> outputs from uut
        
    reg load; //external trigger to start loading samples from SD
    
    //------------   SD Interface -----------------
    reg sd_ready; // HIGH if the SD card is ready for a read or write operation. 
    wire [31:0] sd_address; // Memory address for read/write operation. This MUST 
                                      // be a multiple of 512 bytes; due to SD sectoring.   
    
    wire sd_rd; // Read-enable. When [ready] is HIGH; asseting [rd] will 
                      // begin a 512-byte READ operation at [address]. 
                      // [byte_available] will transition HIGH as a new byte has been
                      // read from the SD card. The byte is presented on [dout].
    reg [7:0]  sd_dout;  // Data output for READ operation.
    reg sd_byte_available; // A new byte has been presented on [dout].
    
    wire sd_wr; // Write-enable. When [ready] is HIGH; asserting [wr] will
                      // begin a 512-byte WRITE operation at [address].
                      // [ready_for_next_byte] will transition HIGH to request that
                      // the next byte to be written should be presentaed on [din].
    wire [7:0] sd_din; // Data input for WRITE operation.   
    reg ready_for_next_byte; // A new byte should be presented on [din].
    //--------------------------------------------
    
    wire update; //signal to sampler controller that sample start addresses are being sent
    
    reg play; //external trigger to start reading audio from RAM    
    reg [26:0] playback_a; //start address sent by playback module
    wire [26:0] start_a; //start address sent to samplectl module
    
    //------------- RAM Interface ----------------    
    wire[26:0] ram_a;
    wire [15:0] ram_dq_i;
    reg [15:0] ram_dq_o;
    wire ram_cen;
    wire ram_oen;
    wire ram_wen;
   //---------------------------------------------
   
    wire [15:0] audio_out; //audio data to send back to playback module
    
    reg clk;
    reg reset;

    //25 MHz clock divider for SD card
    wire spi_clk;
    reg spi_clk_reg = 0;
    
    sd_divider div (
        .clk(clk),
        .reset(reset),
        .spi_clk(spi_clk)
    );
    
    always @(posedge spi_clk) spi_clk_reg <= !spi_clk_reg;

    storagectl uut (
        .load(load),
        .sd_ready(sd_ready),
        .sd_address(sd_address),
        .sd_rd(sd_rd),
        .sd_dout(sd_dout),
        .sd_byte_available(sd_byte_available),
        .sd_wr(sd_wr),
        .sd_din(sd_din),
        .ready_for_next_byte(ready_for_next_byte),
        .update(update),
        .play(play),
        .playback_a(playback_a),
        .start_a(start_a),
        .ram_a(ram_a),
        .ram_dq_i(ram_dq_i),
        .ram_dq_o(ram_dq_o),
        .ram_cen(ram_cen),
        .ram_oen(ram_oen),
        .ram_wen(ram_wen),
        .audio_out(audio_out),
        .clk(clk),
        .spi_clk(spi_clk_reg),
        .reset(reset)
    );

    //SD FSM states
    parameter IDLE = 3'd0;
    parameter SD_START = 3'd1; //sends start signal to SD controller
    parameter SD_LISTEN = 3'd2; //waits for SD to present data on sd_dout
    parameter SD_REC = 3'd3; //adds sd_dout to buffer
    parameter SD_FINISH_1 = 3'd4;
    parameter SD_FINISH_2 = 3'd5;
    parameter SD_DONE = 3'd6;

    //variables for testing
    //TODO: Change this to a size that can hold the entire file
    parameter SAMPLESIZE = 10000;
    reg signed [15:0] samples [SAMPLESIZE:0];
    integer file;
    reg [31:0] read_c;
    integer i;
    integer j;
    
    initial begin
        clk = 0;
    end
         
    //start clock
    always #5 clk = !clk;
    
    initial begin
        $display("Testing storagectl");

        //initialize inputs
        load = 0;
        sd_ready = 0;
        sd_dout = 0;
        sd_byte_available = 0;
        ready_for_next_byte = 0;
        playback_a = 1'd0;
        play = 0;
        ram_dq_o = 1'd0;
        reset = 1'd1;
                
        // Wait 100 ns for global reset to finish
        #120;
        reset = 1'd0;
        #120;
        
        $display("Load datafile");
      
        //TODO: choose a filename
        file = $fopen("datfile.dat", "rb");
        read_c = $fread(samples, file);
        $display("%d bytes read", read_c);
        $display("Load complete."); 
        
        //----------- test 1 ------------
        // Load from SD
        //
                $display("Test 1: simulate load");
        //trigger read start
        load = 1;       
        
        #120;
        //FSM should be in START state
        if(uut.sd_i.state != SD_START) begin
            $display("Expected state: %d. Actual state: %d",SD_START, uut.sd_i.state);
            $stop;
        end

        load = 0;
        #120;
        //Trigger SD ready signal
        @(posedge spi_clk_reg) sd_ready = 1;
        
        //FSM should be in SD_REC state
        #140;
        @(posedge spi_clk_reg) begin
            if(uut.sd_i.state != SD_REC) begin
                $display("Expected state: %d. Actual state: %d",SD_REC, uut.sd_i.state);
                $stop;
            end
        end
        
        #40;
        @(posedge spi_clk_reg) sd_ready = 0;
        #120;
        //simulate 512 byte read burst from SD
        i = 0; //total number of reads
        j = 0; //loop counter 
        while (i < read_c && uut.sd_i.state != 32'hFEE1DEAD) begin        
            for (j = 0; j < 512; j = j + 1) begin
            
               
                @(posedge spi_clk_reg) begin   
                    sd_byte_available = 1;
                    sd_dout = samples[i];
                    if (i < read_c) i = i + 1;
                end  
                @(posedge spi_clk_reg) sd_byte_available = 0;
                 #80;
            end
            #40;
            if(uut.sd_i.state != 32'hFEE1DEAD) begin
                if(uut.sd_i.state != SD_START) begin
                    $display("Expected state: %d. Actual state: %d",SD_START, uut.sd_i.state);
                    $stop;
                end    
                
                //Trigger SD ready signal
                sd_ready = 1;
                #40;
                //FSM should be in SD_REC state
                if(uut.sd_i.state != SD_REC) begin
                    $display("Expected state: %d. Actual state: %d",SD_REC, uut.sd_i.state);
                    $stop;
                end
                
                #40;
                sd_ready = 0;
            end
        end

        #800;
        
        //FSM should go to SD_DONE state once read is over
        if(uut.sd_i.state != SD_DONE) begin
            $display("Expected state: %d. Actual state: %d",SD_DONE, uut.sd_i.state);
            $stop;
        end    
        
        while (uut.arbiter.fifo_req.empty != 1) begin
            #10000;
            $display("finishing requests");
        end
        
        #900000;
        
        $display("Test 1 complete."); 
        $stop;
        @(posedge clk) begin
            reset = 1;
        end
        #30;
        @(posedge clk) begin
            reset = 0;
        end     
        
        $stop;
        
        //----------- test 2 ------------
        // Write to SD (not implemented)
        //
        $display("Test 2: Playback");
           
        #50;
        
        $display("Test 2 complete."); 
        
        @(posedge clk) begin
            reset = 1;
        end
        #30;
        @(posedge clk) begin
            reset = 0;
        end     
        
        $display("storagectl test complete.");
        $finish;
    end

endmodule

