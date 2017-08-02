`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
//
// Create Date:   09:52:00 11/19/2016
// Design Name:   samplectl_tb
// 
////////////////////////////////////////////////////////////////////////////////

module samplectl_tb;

    //inputs
    reg [3:0] trigger;
    reg update;
    reg [26:0] address_in;
    reg clk;
    reg reset;
    
    //outputs
    wire [26:0] address_out;
    wire play;    
    
    //initialize uut
    samplectl uut(
        .trigger(trigger),
        .update(update),
        .address_in(address_in),
        .address_out(address_out),
        .play(play),
        .clk(clk),
        .reset(reset)
    );
    
    //variables for testing
    reg [26:0] prev_address_out;
    integer i = 0;
    integer j = 0;
    reg valid = 0;
            
    initial begin
        clk = 0;
        prev_address_out = 27'd0;
    end
    
    //start clock
    always #5 clk = !clk;

    initial begin
        $display("Testing samplectl");
        
        //initialize inputs
        trigger = 15'd0;
        update = 0;
        address_in = 27'd0;
        reset = 0;
        
        // Wait 100 ns for global reset to finish
        #100;
        
        //save initial output of address_out
        prev_address_out = address_out;
        
        //----------- test 1 ------------
        //try triggering empty slots
        //should do nothing
        $display("Test 1: trigger empty slots");
        @(posedge clk) trigger = 4'd1;
        
        @(posedge clk) begin
            trigger = 4'd0;
            
            $display("'empty' slot trigger value: %d", address_out);
        end
        
        @(posedge clk) begin
            if (prev_address_out != address_out) begin
                $display("Error: triggering empty slot caused unwanted output.");
                $stop;
            end
        end
        
        $display("Test 1 complete.");
        
        #1000;
        //-------------------------------
        
        //----------- test 2 ------------ 
        //try loading without update being asserted
        //should do nothing
        //-------------------------------
        $display("Test 2: attempt to load without asserting update");
        @(posedge clk) address_in = 27'hFED;
        
        @(posedge clk) begin
            address_in = 27'd0;
            trigger = 4'd1;
        end
        
        @(posedge clk) begin            
            trigger = 4'd0;
        end
        
        @(posedge clk) begin
            if (prev_address_out != address_out) begin
                $display("Error: load occured without asserting update.");
                $stop;
            end
        end
        
        $display("Test 2 complete.");
        
        #1000;   
        @(posedge clk) reset = 1;
        @(posedge clk) reset = 0;
        #10;     
        //----------- test 3 ------------ 
        //load numbers 1-15 into slots
        //should give no external output
        //-------------------------------
        $display("Test 3: load slots with corresponding numbers");
        
        for (i = 1; i < 16; i=i+1) begin
            @(posedge clk) begin
                update = 1;
                address_in = i;
            end
            
            @(posedge clk) update = 0;

            @(posedge clk) begin
                if (prev_address_out != address_out) begin
                    $display("Error: load caused change in output.");
                    $stop;
                end
            end
        end
        
        $display("Test 3 complete."); 
        
        #1000;
        //----------- test 4 ------------
        //trigger sample 1 to 15, one at a time
        //should output corresponding number 
        //-------------------------------
        $display("Test 4: trigger samples one a time");
        $display("Output needs to be manually checked.");
        
        for (i = 1; i < 16; i=i+1) begin
                @(posedge clk) trigger = i;
                
                valid = 0;
       end        
       
        @(posedge clk) trigger = 0;    
            //#150;
                
            for (j = 0; j < 15; j=j+1) begin
                @(posedge clk) if (address_out == i) $display("output (should be %d): %d", i, address_out);
            end
        
        $display("Test 4 complete.");
        
        #1000;
        //----------- test 5 ------------ 
        //trigger group of samples
        //should give one number per clock cycle
        //-------------------------------
        $display("Test 5: trigger group of samples");
        $display("Output needs to be manually checked.");
        
        @(posedge clk) trigger = 4'd0; 
        @(posedge clk) trigger = 4'd1;
        @(posedge clk) trigger = 4'd3;
        @(posedge clk) trigger = 4'd9;
        @(posedge clk) trigger = 0;
        
        for (i = 0; i < 15; i=i+1) begin
            @(posedge clk) $display("output: %d", address_out);
        end
        
        $display("Test 5 complete.");
        
        #1000;
        //----------- test 6 ------------ 
        //trigger all samples at once
        //should output each number, one per clock cycle 
        //-------------------------------
        $display("Test 6: trigger all samples at once");
        $display("Output needs to be manually checked.");
        
        for (i = 1; i < 16; i=i+1) begin
            @(posedge clk) trigger = i;
            @(posedge clk) $display("output: %d", address_out);
        end

        @(posedge clk) trigger = 0;
        
        for (i = 0; i < 15; i=i+1) begin
            @(posedge clk) $display("output: %d", address_out);
        end
        
        $display("Test 6 complete.");
        
        #1000;
        //----------- test 7 ------------ 
        //load more numbers, trigger all samples again to test how slots were updated
        //-------------------------------
        $display("Test 7: load new numbers into slots, trigger all samples at once again to see how slots are updated");
        $display("Output needs to be manually checked.");
        
        for (i = 1; i < 16; i=i+1) begin
            @(posedge clk) begin
                update = 1;
                address_in = i*10; //add a zero to number for easily noticeable difference
            end
            
            @(posedge clk) update = 0;
        end

        @(posedge clk) trigger = 0;
        
        for (i = i; i < 16; i = i + 1) begin
            @(posedge clk) trigger = i;
        end
        
        @(posedge clk) trigger = 0;
        
        for (i = 0; i < 15; i=i+1) begin
            @(posedge clk) $display("output: %d", address_out);
        end
        
        trigger = 1'd0;
        
        $display("Test 7 complete.");
        
        #1000;
        //----------- test 8 ------------ 
        //try triggering while loading
        //-------------------------------
        $display("Test 8: trigger while loading.");
        $display("Output needs to be manually checked.");
         
         @(posedge clk) begin 
            update = 1;
            address_in = 100;
            trigger = 4'd1;
         end
        
        @(posedge clk) begin
            update = 0;
            trigger = 4'd0;
            
            $display("output: %d", address_out);
        end
        
        for (i = 0; i < 15; i = i+1) begin
            @(posedge clk) $display("output: %d", address_out);
        end
        
        $display("Test 8 complete.");
        
        #1000;
        //----------- test 9 ------------ 
        //reset then try triggering
        //-------------------------------
        $display("Test 9: reset then trigger all samples to see behavior.");
        $display("Output needs to be manually checked.");
        
        @(posedge clk) begin
            reset = 1;
        end
        
        @(posedge clk) trigger = 0;
        
        for (i = 1; i < 16; i = i + 1) begin
            @(posedge clk) trigger = i;
        end

        
        for (i = 0; i < 15; i = i+1) begin
            @(posedge clk) $display("output: %d", address_out);
        end
        
        $display("Test 9 complete.");
        $display("Samplectl test complete.");
        $finish;
    end
endmodule

