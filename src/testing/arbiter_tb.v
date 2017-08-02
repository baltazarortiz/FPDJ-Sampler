`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
//
// Create Date:   18:23:00 11/23/2016
// Design Name:   ram_fifo_tb
// 
////////////////////////////////////////////////////////////////////////////////

module ram_fifo_tb;
    
    `include "../globalparams.vh"

    //reg -> inputs to uut
    //wire -> outputs from uut

    //RAM interface
    wire[26:0] ram_a;
    wire [15:0] ram_dq_i;
    reg [15:0] ram_dq_o;
    wire ram_cen;
    wire ram_oen;
    wire ram_wen;
    //------------
    //Input from SD control module
    reg [15:0] sd_data;
    reg sd_req;
    reg new_file;
    //-----------
    //Input from playback module
    reg [26:0] playback_addr;
    reg [REQ_ID_SIZE_U:0] r_id_in;
    reg playback_req;
    //-----------
    //output to samplectl
    wire update;
    wire [26:0] start_addr;
    //-----------
    //output to playback
    wire data_ready;
    wire [15:0] from_ram;
    wire [REQ_ID_SIZE_U:0] r_id_out;
    //-----------
    reg clk;
    reg reset;

    //main FSM states
    parameter IDLE = 4'd0;
    parameter NEXT_REQ_WAIT = 4'd1;
    parameter NEXT_REQ_START = 4'd2;
    parameter START_REQ = 4'd3;
    parameter WRITE_START = 4'd4;
    parameter WRITE_HOLD = 4'd5;
    parameter READ_START = 4'd6;
    parameter READ_HOLD = 4'd7;
    parameter READ_END = 4'd8;
    
    //req FSM states    
    parameter REQ_WAIT = 3'd0;      //idle until request comes in
    parameter REQ_ADD_WRITE = 3'd1; 
    parameter REQ_ADD_READ = 3'd2;
    parameter REQ_ADD_BOTH_1 = 3'd3;
    parameter REQ_ADD_BOTH_2 = 3'd4;
    
    //initialize uut
    arbiter uut (
    .ram_a(ram_a),
    .ram_dq_i(ram_dq_i),
    .ram_dq_o(ram_dq_o),
    .ram_cen(ram_cen),
    .ram_oen(ram_oen),
    .ram_wen(ram_wen),
    .sd_data(sd_data),
    .sd_req(sd_req),
    .new_file(new_file),
    .playback_addr(playback_addr),
    .r_id_in(r_id_in),
    .playback_req(playback_req),
    .update(update),
    .start_addr(start_addr),
    .data_ready(data_ready),
    .from_ram(from_ram),
    .r_id_out(r_id_out),
    .clk(clk),
    .reset(reset)
    );
    
    //variables for testing
    integer i = 0;
    
    initial begin
        clk = 0;
    end
         
    //start clock
    always #5 clk = !clk;
    
    initial begin
        $display("Testing Arbiter");
        
        //initialize inputs
        ram_dq_o = 1'd0;
        sd_data = 1'd0;
        playback_addr = 1'd0;
        r_id_in = 1'd0;
        playback_req = 1'd0;
        reset = 1'd1;
                
        // Wait 100 ns for global reset to finish
        #100;
       reset = 1'd0;
       #10;
        //----------- test 1 ------------
        // Read request
        //
        $display("Test 1: Read request");
        
        if(uut.state != IDLE) begin
            $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
            $stop;
        end    
        if(uut.req_state != REQ_WAIT) begin
                $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                $stop;
        end
        
        //assert a read request
        @(posedge clk) begin 
            playback_addr = 26'd1;
            r_id_in = 3'd1;
            playback_req = 1;
        end
        
        #20;
        
        @(posedge clk) begin
            playback_addr = 26'd0;
            r_id_in = 3'd0;
            playback_req = 0;        
        
            if(uut.state != IDLE) begin
                $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
                $stop;
            end    
            if(uut.req_state != REQ_ADD_READ) begin
                    $display("Expected req state: %d. Actual req state: %d",REQ_ADD_READ, uut.req_state);
                    $stop;
            end
        end
        
        @(posedge uut.state) begin
            if(uut.state != NEXT_REQ_WAIT) begin
                $display("Expected main state: %d. Actual main state: %d",NEXT_REQ_WAIT, uut.state);
                $stop;
            end    
            if(uut.req_state != REQ_WAIT) begin
                    $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                    $stop;
            end
        end
        #20;
        @(posedge clk) begin
            if(uut.state != NEXT_REQ_WAIT) begin
                $display("Expected main state: %d. Actual main state: %d",NEXT_REQ_WAIT, uut.state);
                $stop;
            end   
        end
      
        #50;
        
        //fifo will deassert ram_oen to start RAM read (active low)
        @(posedge clk) begin            
            if (ram_oen == 0) begin

                #370;
                ram_dq_o = 1;
            end
            else begin
                $display("RAM read not started as expected.");
                $stop;
            end
        end 

        @(posedge from_ram) begin
            if (from_ram != 1 && r_id_out != 1) begin
                $display("FIFO did not output expected values. from_ram: %d, r_id: %d", from_ram, r_id_out);
                $stop;
            end
        end
        
        #50;
        
        $display("Test 1 complete."); 
        
        @(posedge clk) begin
            reset = 1;
        end
        #30;
        @(posedge clk) begin
            reset = 0;
        end
        
        //----------- test 2 ------------
        // Write request (without new file)
        //
        $display("Test 2: Write request (without new file)");
       
        if(uut.state != IDLE) begin
            $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
            $stop;
        end    
        if(uut.req_state != REQ_WAIT) begin
                $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                $stop;
        end
        
        //assert a write request
        @(posedge clk) begin 
            sd_req = 1;
            new_file = 0;
            sd_data = 8'd1;
        end
        
        #20;
        
        @(posedge clk) begin
            sd_data = 1'd0;
            sd_req = 0;        
        
            if(uut.state != IDLE) begin
                $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
                $stop;
            end    
            if(uut.req_state != REQ_ADD_WRITE) begin
                    $display("Expected req state: %d. Actual req state: %d",REQ_ADD_WRITE, uut.req_state);
                    $stop;
            end
        end
        
        @(posedge uut.state) begin
            if(uut.state != NEXT_REQ_WAIT) begin
                $display("Expected main state: %d. Actual main state: %d",NEXT_REQ_WAIT, uut.state);
                $stop;
            end    
            if(uut.req_state != REQ_WAIT) begin
                    $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                    $stop;
            end
        end
      
        #100;
        
        //fifo will deassert ram_wen to start RAM write (active low)
        @(posedge clk) begin            
            if (ram_wen == 0) begin
                #470;
                
                if(update != 0 || start_addr != 0) begin
                    $display("update and start_addr should not be asserted");
                    $stop;
                end
            
            end
            else begin
                $display("RAM write not started as expected.");
                $stop;
            end
        end 

        #50;
        
        $display("Test 2 complete."); 
        
        @(posedge clk) begin
            reset = 1;
        end
        #30;
        @(posedge clk) begin
            reset = 0;
        end
        
        //----------- test 3 ------------
        // Write request (with new file)
        //
        $display("Test 3: Write request (with new file)");
       
        if(uut.state != IDLE) begin
            $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
            $stop;
        end    
        if(uut.req_state != REQ_WAIT) begin
                $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                $stop;
        end
        
        //assert a write request
        @(posedge clk) begin 
            sd_req = 1;
            new_file = 1;
            sd_data = 16'd1;
        end
        
        #20;
        
        @(posedge clk) begin
            sd_data = 1'd0;
            new_file = 0;
            sd_req = 0;        
        
            if(uut.state != IDLE) begin
                $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
                $stop;
            end    
            if(uut.req_state != REQ_ADD_WRITE) begin
                    $display("Expected req state: %d. Actual req state: %d",REQ_ADD_WRITE, uut.req_state);
                    $stop;
            end
        end
        
        @(posedge uut.state) begin
            if(uut.state != NEXT_REQ_WAIT) begin
                $display("Expected main state: %d. Actual main state: %d",NEXT_REQ_WAIT, uut.state);
                $stop;
            end    
            if(uut.req_state != REQ_WAIT) begin
                    $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                    $stop;
            end
        end
      
        #100;
        
        //fifo will deassert ram_wen to start RAM write (active low)
        @(posedge clk) begin            
            if (ram_wen == 0) begin
                #470;
                
                if(update == 0 || start_addr == 0) begin
                    $display("update and start_addr should not be asserted");
                    $stop;
                end
            
            end
            else begin
                $display("RAM write not started as expected.");
                $stop;
            end
        end 

        #50;

        $display("Test 3 complete."); 
   
        @(posedge clk) begin
            reset = 1;
        end
        #30;
        @(posedge clk) begin
            reset = 0;
        end
   
        //----------- test 4 ------------
        // Multiple read requests
        //
        $display("Test 4: Multiple read requests");
        $display("Must check output manually.");
        
        if(uut.state != IDLE) begin
            $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
            $stop;
        end    
        if(uut.req_state != REQ_WAIT) begin
                $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                $stop;
        end
        
        
        for (i = 0; i < 7; i = i + 1) begin
            //assert a read request
            @(posedge clk) begin 
                playback_addr = i;
                r_id_in = i;
                playback_req = 1;
            end
            
            @(posedge clk) playback_req = 0;
            
            #50;
        end
        
        for (i = 0; i < 7; i = i + 1) begin
            @(posedge uut.delay_exp) begin
                ram_dq_o = i;
            end
        end
       
        #500;

        $display("Test 4 complete."); 
       
        @(posedge clk) begin
            reset = 1;
        end
        #30;
        @(posedge clk) begin
            reset = 0;
        end 
        
        //----------- test 5 ------------
        // 1 write w/ new file, then writes w/o new file
        //
        $display("Test 5: 1 write w/ new file, then writes w/o new file");
        $display("Output needs to be manually verified");
        
        if(uut.state != IDLE) begin
            $display("Expected main state: %d. Actual main state: %d",IDLE, uut.state);
            $stop;
        end    
        if(uut.req_state != REQ_WAIT) begin
                $display("Expected req state: %d. Actual req state: %d",REQ_WAIT, uut.req_state);
                $stop;
        end
        
        //assert a write request w/ new file
        @(posedge clk) begin 
            sd_req = 1;
            new_file = 1;
            sd_data = 16'd1;
        end
        
        #20;
        
        @(posedge clk) begin
            sd_data = 16'd0;
            new_file = 0;
            sd_req = 0;        
        end
        
        //assert write requests w/o new file
        for (i = 1; i < 20; i = i + 1) begin
            @(posedge clk) begin 
                sd_req = 1;
                new_file = 1;
                sd_data = i;
            end
            
            #20;
            
            @(posedge clk) begin
                sd_data = 1'd0;
                new_file = 0;
                sd_req = 0;        
            end
        end
        
        #1000;      

        $display("Test 5 complete."); 
        
        @(posedge clk) begin
            reset = 1;
        end
        #30;
        @(posedge clk) begin
            reset = 0;
        end

        //----------- test 6 ------------
        // Mix of both request types
        //
        $display("Test 6: Mix of both request types");
        
        for (i = 0; i < 30; i = i + 1) begin
            //assert a write request w/ new file
            @(posedge clk) begin 
                sd_req = 1;
                new_file = 1;
                sd_data = 16'd1;
            end
            
            #20;
            
            @(posedge clk) begin
                sd_data = 1'd0;
                new_file = 0;
                sd_req = 0;        
            end

            #20;

            //assert a write request w/o new file
            @(posedge clk) begin 
                sd_req = 1;
                new_file = 0;
                sd_data = 16'd1;
            end
            
            #20;
            
            @(posedge clk) begin
                sd_data = 1'd0;
                new_file = 0;
                sd_req = 0;
            end
            
            #20; 
            
            //assert a read request
            @(posedge clk) begin 
                playback_addr = 26'd1;
                r_id_in = 3'd1;
                playback_req = 1;
            end
            #20;
            @(posedge clk) playback_req = 0;
            
            #20;
        end

        @(uut.fifo_req.data_count == 0) $display("done");

        $display("Test 6 complete."); 
                
        $display("SD interface test complete.");

        //TODO: simultaneous request trigger

        $finish;
    end


endmodule
