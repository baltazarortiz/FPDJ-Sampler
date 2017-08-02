`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 6.111
// Engineer: Baltazar Ortiz
// 
// Create Date: 11/11/2016 02:07:11 PM
// Design Name: 
// Module Name: arbiter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Take in read and write requests and add to FIFO. Use FIFO to access RAM one
//              request at a time.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module arbiter(
    //RAM interface
    output reg[26:0] ram_a,
    output reg signed [15:0] ram_dq_i,
    input wire signed [15:0] ram_dq_o,
    output reg ram_cen,
    output reg ram_oen,
    output reg ram_wen,
    //------------
    //Input from SD control module
    input wire signed [15:0] sd_data,
    input wire sd_req, //trigger when request is available
    input wire new_file, //trigger when beginning of new file is coming in
    //output to SD control module
    output wire [9:0] req_count, //expose FIFO count to the SD controller
    //-----------
    //Input from playback module
    input wire [26:0] playback_addr,
    input wire [REQ_ID_SIZE_U:0] r_id_in,
    input wire playback_req, //trigger when request is available
    //-----------
    //output to samplectl
    output reg update, //trigger when address is available
    output reg [26:0] start_addr,
    //-----------
    //output to playback
    output reg data_ready, //trigger when data is available
    output reg signed [15:0] from_ram,
    output reg [REQ_ID_SIZE_U:0] r_id_out,
    //-----------
    input wire clk,
    input wire spi_clk,
    input wire reset
    );            
    
    `include "globalparams.vh"
    
    reg [26:0] cur_ram_addr = 1'd0;
   
   //instantiate FIFO IP core for storage of requests
       
    wire fifo_full;
    wire fifo_empty; 
    wire fifo_valid;
    wire wr_ack;
    reg [REQ_SIZE_U:0] to_fifo = 1'd0;
    wire [REQ_SIZE_U:0] from_fifo;
    reg [REQ_SIZE_U:0] current_req = 1'd0;
    reg fifo_wen = 0;
    reg fifo_oen = 0;

    reg update_toggle = 0; //ensure that only the start address of each new file is sent

    reg delay_exp = 0;
    reg [5:0] hold_count = 6'd0;
    
    wire [9:0] fifo_count;
    assign req_count = fifo_count;

    fifo_req fifo_req (
        //FIFO_WRITE
        .full(fifo_full),
        .din(to_fifo),
        .wr_en(fifo_wen),
        .wr_ack(wr_ack),
        //FIFO_READ
        .empty(fifo_empty),
        .dout(from_fifo),
        .rd_en(fifo_oen),
        .valid(fifo_valid),
        //------
        .data_count(fifo_count),
        .clk(clk),
        .srst(reset)
    );

    //----------------------------------------------------------
    //FSM for reading/writing to DDR through SRAM interface
    //
    //  NOTE: This FSM only controls the oen trigger on the FIFO.
    //        Control of wen is left to the FIFO add FSM.
    //----------------------------------------------------------
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
    
    reg [3:0] state = IDLE;
    reg [3:0] next_state = IDLE;
    
    //state transitions
    always @(*) begin
        if (reset) next_state = IDLE;
        else begin
            case (state)
                IDLE: begin
                    //wait for FIFO to have a request that needs handling
                    if (!fifo_empty)     next_state = NEXT_REQ_START;
                    else                 next_state = IDLE;
                end
                NEXT_REQ_START: begin
                    //trigger fifo read
                    next_state = NEXT_REQ_WAIT;
                end
                NEXT_REQ_WAIT: begin
                    //wait for FIFO to output
                    if (fifo_valid) next_state = START_REQ;
                    else                                                   next_state = NEXT_REQ_WAIT; 
                end
                START_REQ: begin
                    //Check request type
                    if (current_req[REQ_TYPE_U:REQ_TYPE_L] == READ)       next_state = READ_START;
                    else if (current_req[REQ_TYPE_U:REQ_TYPE_L] == WRITE) next_state = WRITE_START;
                    else                                                  next_state = START_REQ;
                end
                WRITE_START: begin
                    //start RAM write
                    next_state = WRITE_HOLD;
                end
                WRITE_HOLD: begin
                    //hold RAM control wires until timing spec is met
                    if (delay_exp)
                        next_state = IDLE;
                    else
                        next_state = WRITE_HOLD;
                    end
                READ_START: begin
                    //start RAM read
                    next_state = READ_HOLD;
                end
                READ_HOLD: begin
                    //hold RAM control wires until timing spec is met
                if (delay_exp)
                    next_state = IDLE;
                else
                    next_state = READ_HOLD;
                end              
                READ_END: begin
                    //output data from RAM
                    next_state = IDLE;
                end
                default: begin
                    next_state = IDLE;
                end
            endcase
        end
    end
    
    always @(posedge clk) begin
        state <= next_state;
    end
    
    //output logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                //no RAM/FIFO access
                ram_a <= 27'd0;
                ram_cen <= 1;
                ram_oen <= 1;
                ram_wen <= 1;
                fifo_oen <= 0;  
                delay_exp <= 0;
                hold_count <= 6'd0;
                update <= 0;
                data_ready <= 0;
                from_ram <= 1'd0;
                r_id_out <= 1'd0;
                start_addr <= 1'd0;
                update_toggle <= 0;
                current_req <= 1'd0;
                ram_dq_i <= 1'd0;
            end
            NEXT_REQ_START: begin
                //Get one value from FIFO
                fifo_oen <= 1;
            end
            NEXT_REQ_WAIT: begin
                fifo_oen <= 0;
                if(fifo_valid) current_req <= from_fifo;
            end
            START_REQ: begin
                fifo_oen <= 0;
                
                //increment ahead of time to avoid double write to same address
                if (current_req[REQ_TYPE_U:REQ_TYPE_L] == WRITE) cur_ram_addr <= cur_ram_addr + 1;
            end
            WRITE_START: begin
                //Turn off FIFO output
                fifo_oen <= 0;
            
                //Set current address and increment for next time
                ram_a    <= cur_ram_addr + 1;
                cur_ram_addr <= cur_ram_addr + 1; //needed twice to avoid double write
                
                //Set input data to be equal to data section of write request
                ram_dq_i <= current_req[REQ_DATA_U:REQ_DATA_L];
                
                //Check if this is the beginning of a new file
                if (current_req[REQ_NEW_FILE] && !update_toggle) begin
                    update <= 1;
                    update_toggle <= 1;
                    start_addr <= cur_ram_addr;
                end
                else begin
                    start_addr <= 1'd0;
                    update <= 0;
                end
                
                //Begin RAM write
                ram_cen <= 0;
                ram_oen <= 1;
                ram_wen <= 0;
            end
            WRITE_HOLD: begin
                //Continue to assert write value until enough time has
                //passed to meet the RAM specifications
                if (hold_count == RAM_WRITE_DELAY) begin
                    delay_exp <= 1;
                end
                else begin
                    delay_exp <= 0;
                    hold_count <= hold_count + 1;
                end
            end
            READ_START: begin
                //Turn off FIFO output
                fifo_oen <= 0;
                            
                //Get ram address from request
                 ram_a <= current_req[REQ_ADDR_U:REQ_ADDR_L];
                
                //Begin RAM read
                 ram_cen <= 0;
                 ram_oen <= 0;
                 ram_wen <= 1;             
            end
            READ_HOLD: begin
                //Continue to assert read address until enough time has
                //passed to meet the RAM specifications
                if (hold_count == RAM_READ_DELAY) begin
                    delay_exp <= 1;
                    from_ram <= ram_dq_o;
                    data_ready <= 1;
                    //end RAM read signals 
                    ram_cen <= 1;
                    ram_oen <= 1;
                    ram_wen <= 1;

                    r_id_out <= current_req[REQ_ID_U:REQ_ID_L];
                end
                else begin
                    delay_exp <= 0;
                    hold_count <= hold_count + 1;
                end
            end
            default: begin
                ram_cen <= 1;
                ram_oen <= 1;
                ram_wen <= 1;
            end
        endcase
    end

    //----------------------------------------------------------
    //FSM to add incoming requests to FIFO
    //
    //  NOTE: This FSM only controls the wen trigger on the FIFO.
    //        Control of oen is left to the main FSM.
    //
    //  Priority given to storing SD data over getting data from playback
    //----------------------------------------------------------    
    
    //Registers to store input from playback and sd
    reg [26:0] address_buf;
    reg [3:0] r_id_buf;
    reg [15:0] sd_buf;
    reg new_file_buf;
    
    //FSM states
    parameter REQ_WAIT = 3'd0;
    parameter REQ_ADD_WRITE = 3'd1; 
    parameter REQ_ADD_READ = 3'd2;
    parameter REQ_ADD_BOTH_1 = 3'd3;
    parameter REQ_ADD_BOTH_2 = 3'd4;
    
    reg [2:0] req_state = REQ_WAIT;
    reg [2:0] next_req_state = REQ_WAIT;
 
    //avoid duplicate sd requests due to different clock speeds
    reg sd_req_already_added = 0;
    reg playback_req_already_added = 0;
    
    //State transitions
    always @(*) begin
        if (reset) begin
            next_req_state = REQ_WAIT;
        end 
        else begin
            case (req_state) 
                REQ_WAIT: begin
                    //Wait for a request to come in
                    if (sd_req && !sd_req_already_added) begin
                        next_req_state = REQ_ADD_WRITE;
                    end
                    else if (playback_req && !playback_req_already_added) begin
                        next_req_state = REQ_ADD_READ;
                    end
                    else begin
                        next_req_state = REQ_WAIT;
                    end
                end
                //Add appropriate requests to FIFO
                REQ_ADD_WRITE: begin
                    next_req_state = REQ_WAIT;
                end
                REQ_ADD_READ: begin
                    next_req_state = REQ_WAIT;
                end
                REQ_ADD_BOTH_1: begin
                    next_req_state = REQ_ADD_BOTH_2;
                end
                REQ_ADD_BOTH_2: begin
                    next_req_state = REQ_WAIT;
                end
                default: begin
                    next_req_state = REQ_WAIT;
                end
            endcase
        end
    end
    
    always @(posedge clk) begin
        req_state <= next_req_state;
    end 
    
    //State logic
    always @(posedge clk) begin
            case (req_state) 
                REQ_WAIT: begin
                    fifo_wen <= 0;
                    to_fifo <= 0;
                    
                    //Store values from SD and Playback
                    if (sd_req) begin
                        sd_buf <= sd_data;
                        new_file_buf <= new_file;
                        sd_req_already_added <= 1;
                    end
                    else sd_req_already_added <= 0;
                    
                    if (playback_req) begin
                        address_buf <= playback_addr;
                        r_id_buf <= r_id_in;
                        playback_req_already_added <= 1;
                    end
                    else playback_req_already_added <= 0;
                end
                REQ_ADD_WRITE: begin
                    fifo_wen <= 1;
                    if (!wr_ack)
                        to_fifo <= {WRITE,new_file_buf,14'd0,sd_buf};
                    else
                        to_fifo <= 1'd0;
                        
                    sd_req_already_added <= 1;
                end
                REQ_ADD_READ: begin
                    fifo_wen <= 1;
                    
                    if (!wr_ack)
                        to_fifo <= {READ,r_id_buf,address_buf};
                    else
                        to_fifo <= 1'd0;
                        
                    playback_req_already_added <= 1;
                end
                REQ_ADD_BOTH_1: begin
                    fifo_wen <= 1;
                    to_fifo <= {WRITE,new_file_buf,14'd0,sd_buf};
                    sd_req_already_added <= 1;
                end
                REQ_ADD_BOTH_2: begin
                    fifo_wen <= 1;
                    to_fifo <= {READ,r_id_buf,address_buf};
                    playback_req_already_added <= 1;
                end
                default: begin
                    fifo_wen <= 0;
                end
            endcase
    end
endmodule
`default_nettype wire
