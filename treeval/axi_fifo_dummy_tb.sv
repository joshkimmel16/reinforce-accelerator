// testbench for axi_fifo_dummy

`timescale 1 ns / 100 ps

module axi_fifo_dummy_tb;

localparam CLOCK = 10; // 100 MHz
localparam W_MSG = 64; // message length
localparam W_FIFO = 8; // # of elements in FIFOs
localparam W_LOG_FIFO = 3; // # of bits in W_FIFO

logic clk;
logic rst;

// ACK signals
logic i_in_msg_ack; // ack from inside that msg (top of in_fifo) received
logic o_out_msg_ack; // ack from outside that msg (top of out_fifo) received
logic i_out_msg_ack; // ack to inside that msg (placed at bottom of out_fifo) received
logic o_in_msg_ack; // ack to outside that msg (placed at bottom of in_fifo) received

// READY signals
logic i_out_msg_rdy; // a new msg from inside is ready to be placed at the bottom of out_fifo
logic o_in_msg_rdy; // a new msg from outside is ready to be placed at the bottom of in_fifo
logic i_in_msg_rdy; // the top of in_fifo is ready to be consumed by the inside
logic o_out_msg_rdy; // the top of out_fifo is ready to be consumed by the outside

// DATA signals
logic [W_MSG-1:0] i_out_msg; // a new msg from inside to be placed at the bottom of out_fifo
logic [W_MSG-1:0] o_in_msg; // a new msg from outside to be placed at the bottom of in_fifo
logic [W_MSG-1:0] i_in_msg; // the top of in_fifo
logic [W_MSG-1:0] o_out_msg; // the top of out_fifo

axi_fifo_dummy DUT (
    .clk(clk),
    .rst(rst),  
    .i_in_msg_ack(i_in_msg_ack),
    .o_out_msg_ack(o_out_msg_ack),
    .i_out_msg_ack(i_out_msg_ack),
    .o_in_msg_ack(o_in_msg_ack),
    .i_out_msg_rdy(i_out_msg_rdy),
    .o_in_msg_rdy(o_in_msg_rdy),
    .i_in_msg_rdy(i_in_msg_rdy),
    .o_out_msg_rdy(o_out_msg_rdy),
    .i_out_msg(i_out_msg),
    .o_in_msg(o_in_msg),
    .i_in_msg(i_in_msg),
    .o_out_msg(o_out_msg)
);

integer i;
integer nErr; // number of errors
integer out;

always 
begin
    #(CLOCK/2) clk=~clk;
end

initial begin
    clk = 0;
    rst = 0;
    i_in_msg_ack = 0;
    i_out_msg_ack = 0;
    o_in_msg_ack = 0;
    o_out_msg_ack = 0;
    i_in_msg_rdy = 0;
    i_out_msg_rdy = 0;
    o_in_msg_rdy = 0;
    o_out_msg_rdy = 0;
    nErr = 0;

    out = $fopen("output.txt", "w");

    #(CLOCK);
    tskWriteInMsg(); // write a message from out to IN_FIFO
    #(CLOCK);
    tskReadInMsg(); // read message from IN_FIFO to in
    #(CLOCK);
    tskWriteOutMsg(); // write a message from in to OUT_FIFO
    #(CLOCK);
    tskReadOutMsg(); // read message from OUT_FIFO to out

    #(CLOCK) $display("%d ... finishing, number of errors = %d",
                     $stime, nErr);
    
    $finish;   // end of simulation
end

task tskWriteInMsg;
    integer count = 0;
    logic [W_MSG-1:0] tmp = 1;
    begin
        o_in_msg = tmp;
        o_in_msg_rdy = 1;
        while (count < 5) begin
            #(CLOCK);
            if (o_in_msg_ack) begin
                count = 6;
            end
            else begin
                count = count + 1;
            end
        end
        if (count == 5) begin
            logError("WriteInMsg", "Never got ack from axi.");
        end
        o_in_msg_rdy = 0;
    end
endtask

task tskReadInMsg;
    integer count = 0;
    begin
        while (count < 5) begin
            if (i_in_msg_rdy) begin
                count = 6;
            end
            else begin
                count = count + 1;
            end
            #(CLOCK);
        end
        if (count == 6) begin
            if (~(i_in_msg == 1)) begin
                logError("ReadInMsg", "Unexpected msg from axi. Should be 1.");
            end
            else begin
                i_in_msg_ack = 1;
                #(CLOCK);
                i_in_msg_ack = 0;
            end
        end
        else begin
            logError("ReadInMsg", "Never got rdy from axi.");
        end
    end
endtask

task tskWriteOutMsg;
    integer count = 0;
    logic [W_MSG-1:0] tmp = 3;
    begin
        i_out_msg = tmp;
        i_out_msg_rdy = 1;
        while (count < 5) begin
            #(CLOCK);
            if (i_out_msg_ack) begin
                count = 6;
            end
            else begin
                count = count + 1;
            end
        end
        if (count == 5) begin
            logError("WriteOutMsg", "Never got ack from axi.");
        end
        i_out_msg_rdy = 0;
    end
endtask

task tskReadOutMsg;
    integer count = 0;
    begin
        while (count < 5) begin
            if (o_out_msg_rdy) begin
                count = 6;
            end
            else begin
                count = count + 1;
            end
            #(CLOCK);
        end
        if (count == 6) begin
            if (~(o_out_msg == 3)) begin
                logError("ReadOutMsg", "Unexpected msg from axi. Should be 3.");
            end
            else begin
                o_out_msg_ack = 1;
                #(CLOCK);
                o_out_msg_ack = 0;
            end
        end
        else begin
            logError("ReadOutMsg", "Never got rdy from axi.");
        end
    end
endtask

task logError;
    input logic[30*8:0] testName;
    input logic[100*8:0] msg;
    begin
        $display ("%d ... Failed test %s: %s", 
                    $stime, testName, msg);
        $fwrite (out, "%d ... Failed test %s: %s", 
                    $stime, testName, msg);
        nErr = nErr + 1;
    end
endtask

endmodule