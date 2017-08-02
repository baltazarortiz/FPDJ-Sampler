`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
//
// Create Date:   14:48:00 12/2/2016
// Design Name:   playback_tb.v
// 
////////////////////////////////////////////////////////////////////////////////

module playback_tb;

    `include "../globalparams.vh"
    
    //reg -> inputs
    //wire -> outputs

    reg [REQ_ADDR_SIZE_U:0] address_in = 1'd0;
    reg [15:0] data_in = 1'd0;
    reg [REQ_ID_SIZE_U:0] r_id_in = 1'd0;
    reg data_ready = 1'd0;
    wire sample_clk;// = 1'd0;
    wire req_available;
    reg clk = 1'd0;
    reg reset = 1'd0; 
    reg play = 1'd0;
    
    wire [REQ_ADDR_SIZE_U:0] address_out;
    wire signed [15:0] audio_out;
    wire [REQ_ID_SIZE_U:0] r_id_out;
    
    //initialize uut
    playback uut (
        .play(play),
        .address_in(address_in),
        .data_in(data_in),
        .address_out(address_out),
        .req_available(req_available),
        .audio_out(audio_out),
        .r_id_out(r_id_out),
        .r_id_in(r_id_in),
        .data_ready(data_ready),
        .sample_clk(sample_clk),
        .clk(clk),
        .reset(reset)
    );
    

    //variables for testing
    //TODO: Change this to a size that can hold the entire file
    parameter SAMPLESIZE = 10000;
    reg signed [15:0] samples [SAMPLESIZE:0];
    integer file;
    reg [31:0] read_c;
    integer i =0;
    integer j =0;
    integer count = 0;
            integer k = 0; 
    initial begin
        clk = 0;
       // sample_clk = 0;
    end
    
    //sample addresses
    //address = addr = 1 + 1/2 * offset from beginning of file 
    
    //TODO: change these to line up with the dat file
    parameter SAMPLE1_START = 0;
    parameter SAMPLE2_START = 100;
    
    //divider for sample clock
    sample_divider div (
        .clk(clk),
        .reset(RESET),
        .sample_clk(sample_clk)
    );
         
    //start clock
    //200 MHZ
    always #5 begin
        clk = !clk;
    end
    
    initial begin
        $display("Testing playback module");

        reset = 1;
        
        // Wait 100 ns for global reset to finish
        #100;
        
        reset = 0;
       
        $display("Load datafile into fake RAM");
      
        //TODO: choose a filename
        file = $fopen("datfile.dat", "rb");
        read_c = $fread(samples, file);
        $display("%d bytes read", read_c);
        $display("Load complete."); 
        
        #20;
    
        //----------- test 1 ------------
        // Play sample 1 all the way through
        //
        $display("Test 1: Play sample 1");

        play = 1;
        address_in = SAMPLE1_START;
        #10;
        play = 0;

        while (uut.data_buf[0] != 32'hCAFED00D) begin
            @(posedge req_available) begin
                #10;
                data_in = samples[address_out];
                r_id_in = r_id_out;
                data_ready = 1;
                #10;
                data_ready = 0;
                i = i + 1;
            end
        end
        
        #50;
     
        $display("Test 1 complete."); 
        $display("number of 44.1 clock cycles: %d", j);
        $display("number of samples sent to playback module: %d", i);

        @(posedge sample_clk) #5000;
        
        
        //wait for one more sample_clk or buffer won't clear before next test
        @(posedge sample_clk) #5000;
        reset = 1;
        #10;
        reset = 0;
  
        
        //----------- test 2 ------------
        // Play sample 2 all the way through
        //
        $display("Test 2: Play Sample 2");

        play = 1;
        address_in = SAMPLE2_START;
        #1000;
        play = 0;

        while (uut.data_buf[0] != 32'hCAFED00D) begin
            @(posedge req_available) begin
                #80;
                data_in = samples[address_out];
                r_id_in = r_id_out;
                data_ready = 1;
                #10;
                data_ready = 0;
                i = i + 1;
            end
        end
       
        #5000;
        $display("Test 2 complete."); 
        $display("number of 44.1 clock cycles: %d", j);
        $display("number of samples sent to playback module: %d", i);
        
        //wait for one more sample_clk or buffer won't clear before next test
        @(posedge sample_clk) #5000;
        reset = 1;
        #10;
        reset = 0;
      
        //----------- test 3 ------------
        // Play two samples at once
        //
        $display("Test 3: Play both samples at once");

        play = 1;
        address_in = SAMPLE1_START;
        #10;
        play = 0;
        #10;
        play = 1;
        address_in = SAMPLE2_START;
        #10;
        play = 0;
                                  //cafed00d flipped b/c little endian
        while (uut.data_buf[0] != 32'hFECA0DD0) begin
            @(posedge req_available) begin
                #20;
                data_in = samples[address_out];
                r_id_in = r_id_out;
                data_ready = 1;
                #10;
                data_ready = 0;
                i = i + 1;
            end
        end
        
        $display("Test 3 complete."); 
        $display("number of 44.1 clock cycles: %d", j);
        $display("number of samples sent to playback module: %d", i);

        //wait for one more sample_clk or buffer won't clear before next test
        @(posedge sample_clk) #5000;
        reset = 1;
        #10;
        reset = 0;

        //----------- test 4 ------------
        // Play sample 2 all the way through
        //
        $display("Test 4: Play Sample 1 multiple times in a row");
        
        for (k = 0; k < 50; k = k + 1) begin
            play = 1;
            address_in = SAMPLE2_START;
            #1000;
            play = 0;
                                      //cafed00d flipped b/c little endian
            while (uut.data_buf[k%31] != 32'hFECA0DD0) begin
                @(posedge req_available) begin
                    #80;
                    data_in = samples[address_out];
                    r_id_in = r_id_out;
                    data_ready = 1;
                    #10;
                    data_ready = 0;
                    i = i + 1;
                end
            end
            #20;
        end

        $display("Playback module test complete.");

        $finish;
    end


endmodule
