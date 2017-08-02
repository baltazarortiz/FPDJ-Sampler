`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// 
// Create Date: 12/7/2016
// Module Name: fpdj
// Project Name: FPDJ
// Target Devices: Nexys 4 DDR
// Description: 
// 
// Dependencies: 
// 
// 
//////////////////////////////////////////////////////////////////////////////////


module sampler_tb();
 reg CLK100MHZ;
    reg[15:0] SW = 1'd0; 
    reg BTNC = 0;
    reg BTNU = 0; 
    reg BTNL = 0; 
    reg BTNR = 0; 
    reg BTND = 0;
    reg CPU_RESETN;
   // reg [15:0] LED;
    wire [15:0] LED;
    //reg [7:0] SEG;  // segments A-G (0-6); DP (7)
   // reg[7:0] AN;    // Display 0-7
    wire SD_RESET;
    wire SD_CD ;
    wire SD_SCK ;
    wire SD_CMD ;
    wire [3:0] SD_DAT;
    wire AUD_PWM;
    wire AUD_SD;
    
    //memory signals
    wire   [12:0] ddr2_addr;
    wire  [2:0] ddr2_ba;
    wire  ddr2_ras_n;
    wire  ddr2_cas_n ;
    wire  ddr2_we_n ;
    wire  ddr2_ck_p ;
    wire  ddr2_ck_n ;
    wire  ddr2_cke ;
    wire  ddr2_cs_n ;
    wire  [1:0] ddr2_dm ;
    wire  ddr2_odt ;
    wire  [15:0] ddr2_dq;
    wire  [1:0] ddr2_dqs_p;
    wire  [1:0] ddr2_dqs_n;   

    reg reset = 0;
    //assign RESET = SW[15];
    
    initial CLK100MHZ = 0;
    always #10 CLK100MHZ = !CLK100MHZ;
    
    wire CLK200MHZ;
    wire CLK100_PLL;
    
    clkgen clk_gen (
        .reset(reset),
        .clk_in1(CLK100MHZ),
        .CLK100(CLK100_PLL),
        .CLK200(CLK200MHZ),
        .locked()
    );
    
    wire spi_clk;
    reg spi_clk_reg = 0;
    
    sd_divider div2 (
        .clk(CLK100_PLL),
        .reset(reset),
        .spi_clk(spi_clk)
    );
    
    wire BTNC_DB;
    wire BTNU_DB;
    wire BTNL_DB;
    wire BTNR_DB;
    wire BTND_DB;
    wire CPU_RESETN_DB;
    
    debounce db_btnc(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNC),.clean(BTNC_DB));
    debounce db_bdnu(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNU),.clean(BTNU_DB));
    debounce db_btnl(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNL),.clean(BTNL_DB));
    debounce db_btnr(.reset(RESET),.clock(CLK100_PLL),.noisy(BTNR),.clean(BTNR_DB));
    debounce db_btnrd(.reset(RESET),.clock(CLK100_PLL),.noisy(BTND),.clean(BTND_DB));

    wire sample_clk;

    //divider for sample clock
    sample_divider div (
        .clk(CLK100_PLL),
        .reset(reset),
        .sample_clk(sample_clk)
    );
    
    reg [3:0] trigger = 1'd0;
    
    //instantiate sampler
    wire signed [15:0] sam_audio_out;
        
    assign SD_DAT[2] = 1;
    assign SD_DAT[1] = 1;
    assign SD_RESET = 0;
    
        wire sd_rd;
    wire sd_wr;
    reg sd_ready = 0;
    wire [7:0] sd_din;
    reg signed [7:0] sd_dout = 0;
    reg sd_byte_available = 0;
    wire signed[15:0] ram_dq_i_debug;
   reg signed [15:0] ram_dq_o_debug = 0;
   
    sampler_debug uut (
        .trigger(trigger),
        .start_load(SW[0]),
        .reset(reset),
        .LED_OUT(LED),
        .clk100(CLK100_PLL),
        .clk200(CLK200MHZ),
        .sample_clk(sample_clk),
        .audio_out(sam_audio_out),
        .device_temp(),
        .ddr2_addr(ddr2_addr),
        .ddr2_ba(ddr2_ba),
        .ddr2_ras_n(ddr2_ras_n),
        .ddr2_cas_n(ddr2_cas_n),
        .ddr2_we_n(ddr2_we_n),
        .ddr2_ck_p(ddr2_ck_p),
        .ddr2_ck_n(ddr2_ck_n),
        .ddr2_cke(ddr2_cke),
        .ddr2_cs_n(ddr2_cs_n),
        .ddr2_dm(ddr2_dm),
        .ddr2_odt(ddr2_odt),
        .ddr2_dq(ddr2_dq),
        .ddr2_dqs_p(ddr2_dqs_p),
        .ddr2_dqs_n(ddr2_dqs_n),
        .cs(SD_DAT[3]),
        .mosi(SD_CMD),
        .miso(SD_DAT[0]),
        .sclk(SD_SCK),
        .sd_address(),
        .sd_rd_debug(sd_rd),
        .sd_wr_debug(sd_wr),
        .sd_din_debug(sd_din),
        .sd_ready_debug(sd_ready),
        .sd_dout_debug(sd_dout),
        .sd_byte_available_debug(sd_byte_available),
        .ram_dq_i_debug(ram_dq_i_debug),
        .ram_dq_o_debug(ram_dq_o_debug)
    );

    //instantiate master mixer and PWM
    //enable PWM
    assign AUD_SD = 1'b1;
    
    audio_PWM PWM (
        .clk(CLK100_PLL),
        .reset(reset),
        .music_data(sam_audio_out[15:8]),
        .PWM_out(AUD_PWM)
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
    reg [7:0] samples [SAMPLESIZE:0];
    reg [15:0] fakeRAM [SAMPLESIZE:0];
    
    integer file;
    reg [31:0] read_c;
    integer i;
    integer j;

    initial begin
        $display("Testing sampler");
        #1000;
        //initialize inputs
        
        @(posedge spi_clk) reset = 1'd1;
        #100;
        reset = 1'd0;
        #10;
        
        $display("Load datafile");
      
        //TODO: choose a filename
        file = $fopen("datfile.dat", "rb");
        read_c = $fread(samples, file);
       
        $display("%d bytes read", read_c);
        $display("Load complete."); 
        
        #120;
        //FSM should be in START state
        if(uut.storage_controller.sd_i.state != SD_START) begin
            $display("Expected state: %d. Actual state: %d",SD_START, uut.storage_controller.sd_i.state);
            $stop;
        end

        #160;
        //Trigger SD ready signal
        @(posedge spi_clk) sd_ready = 1;
        
        //FSM should be in SD_REC state
        #160;
        while (uut.storage_controller.sd_i.state != SD_REC) begin
            @(posedge spi_clk) $display("waiting");
        end
        
        
        
        #40;
        @(posedge spi_clk) sd_ready = 0;
        #120;
        //simulate 512 byte read burst from SD
        i = 0; //total number of reads
        j = 0; //loop counter 
        while (i < read_c && uut.storage_controller.sd_i.state != 32'hFEE1DEAD) begin        
            for (j = 0; j < 512; j = j + 1) begin
            
               
                @(posedge spi_clk) begin   
                    sd_byte_available = 1;
                    sd_dout = samples[i];
                    if (i < read_c) i = i + 1;
                end  
                @(posedge spi_clk) sd_byte_available = 0;
                 #80;
                 
                if (i >= read_c) j = 513;
            end
            #40;
            if(uut.storage_controller.sd_i.sd_buf != 32'hFEE1DEAD) begin
                if(uut.storage_controller.sd_i.state != SD_START) begin
                    $display("Expected state: %d. Actual state: %d",SD_START, uut.storage_controller.sd_i.state);
                    $stop;
                end    
                
                 $display("waiting for state to finish after load");
                
                //Trigger SD ready signal
                sd_ready = 1;
                #80;
                //FSM should be in SD_REC state
                while (uut.storage_controller.sd_i.state != SD_REC) begin
                    @(posedge spi_clk) $display("waiting");
                end
                
                #40;
                sd_ready = 0;
            end
        end

        #800;
        
        //FSM should go to SD_DONE state once read is over
        while (uut.storage_controller.sd_i.state != SD_DONE) begin
            @(posedge spi_clk) $display("Waiting for sd to finish");
        end    
        
        if (uut.storage_controller.arbiter.fifo_req.empty != 1) $display("finishing write requests");
        while (uut.storage_controller.arbiter.fifo_req.empty != 1) begin
            #1000;
        end
        
        #1000;
        $display("starting trigger");
        
        trigger = 1;
        #10;
        trigger = 0;
        
        while (uut.playback_module.data_buf[0] != 32'hFECA0DD0) begin
            @(negedge uut.ram_oen) ram_dq_o_debug = fakeRAM[uut.ram_a];
        end
        
        @(posedge sample_clk) #5000;
        
        for (k = 0; k < 50; k = k + 1) begin
            address_in = SINE_START;
            #1000;
            trigger = 1;
            #10;
            trigger = 0;
    
            while (uut.data_buf[k%31] != 32'hFECA0DD0) begin
                @(negedge uut.ram_oen) begin
                    ram_dq_o_debug = fakeRAM[uut.ram_a];
                end
            end
            #20;
        end
        $finish;
        
    end
    
    initial begin
        while (1 != 0) begin
            @(negedge uut.ram_wen) begin
                fakeRAM[uut.ram_a] = ram_dq_i_debug;
            end
        end
    end

endmodule
