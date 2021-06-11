localparam W_MSG = 64; // message length
localparam W_FIFO = 8; // # of elements in FIFOs
localparam W_LOG_FIFO = 3; // # of bits in W_FIFO

// axi_fifo_dummy mocks up to the interface to an AXI IP
// that is capable of sending/receiving P2P messages from other components in the NoC
module axi_fifo_dummy (
    input logic clk, // clock
    input logic rst, // reset

    // ACK signals
    input logic i_in_msg_ack, // ack from inside that msg (top of in_fifo) received
    input logic o_out_msg_ack, // ack from outside that msg (top of out_fifo) received
    output logic i_out_msg_ack, // ack to inside that msg (placed at bottom of out_fifo) received
    output logic o_in_msg_ack, // ack to outside that msg (placed at bottom of in_fifo) received

    // READY signals
    input logic i_out_msg_rdy, // a new msg from inside is ready to be placed at the bottom of out_fifo
    input logic o_in_msg_rdy, // a new msg from outside is ready to be placed at the bottom of in_fifo
    output logic i_in_msg_rdy, // the top of in_fifo is ready to be consumed by the inside
    output logic o_out_msg_rdy, // the top of out_fifo is ready to be consumed by the outside

    // DATA signals
    input logic [W_MSG-1:0] i_out_msg, // a new msg from inside to be placed at the bottom of out_fifo
    input logic [W_MSG-1:0] o_in_msg, // a new msg from outside to be placed at the bottom of in_fifo
    output logic [W_MSG-1:0] i_in_msg, // the top of in_fifo
    output logic [W_MSG-1:0] o_out_msg // the top of out_fifo
);

logic [W_FIFO-1:0][W_MSG:0] in_fifo; // W_MSG+1 for valid bit
logic [W_FIFO-1:0][W_MSG:0] out_fifo; // W_MSG+1 for valid bit
logic [W_LOG_FIFO-1:0] in_fifo_head = 0;
logic [W_LOG_FIFO-1:0] out_fifo_head = 0;
logic [W_LOG_FIFO-1:0] in_fifo_tail = 0;
logic [W_LOG_FIFO-1:0] out_fifo_tail = 0;

logic o_should_ack = 0;
logic i_should_ack = 0;

assign o_in_msg_ack = o_should_ack;
assign i_in_msg_rdy = in_fifo[in_fifo_head][W_MSG];
assign i_in_msg = in_fifo[in_fifo_head][W_MSG-1:0];
assign i_out_msg_ack = i_should_ack;
assign o_out_msg_rdy = out_fifo[out_fifo_head][W_MSG];
assign o_out_msg = out_fifo[out_fifo_head][W_MSG-1:0];

// initialize all FIFO queues to invalid
initial begin
    InvalidateInFifo();
    InvalidateOutFifo();
end

// logic to drive in_fifo_head
always @(posedge clk) begin
    if (rst) begin
        in_fifo_head <= 0;
    end
    else if (i_in_msg_ack) begin
        in_fifo_head <= in_fifo_head + 1; // move to next slot (overflow is desirable)
    end
    else begin
        in_fifo_head <= in_fifo_head;
    end
end

// logic to drive in_fifo_tail
always @(posedge clk) begin
    if (rst) begin
        in_fifo_tail <= 0;
    end
    else if (o_in_msg_rdy && ~o_should_ack) begin
        if (~(in_fifo[in_fifo_tail][W_MSG])) begin
            in_fifo_tail <= in_fifo_tail + 1; // move to next slot (overflow is desirable)
        end
        else begin
            in_fifo_tail <= in_fifo_tail;
        end
    end
    else begin
        in_fifo_tail <= in_fifo_tail;
    end
end

// logic to drive i_should_ack
always @(posedge clk) begin
    if (rst) begin
        i_should_ack <= 0;
    end
    else if (i_out_msg_rdy && ~i_should_ack) begin
        if (~(out_fifo[out_fifo_tail][W_MSG])) begin
            i_should_ack <= 1;
        end
        else begin
            i_should_ack <= 0;
        end
    end
    else begin
        i_should_ack <= 0;
    end
end

// logic to drive out_fifo_head
always @(posedge clk) begin
    if (rst) begin
        out_fifo_head <= 0;
    end
    else if (o_out_msg_ack) begin
        out_fifo_head <= out_fifo_head + 1; // move to next slot (overflow is desirable)
    end
    else begin
        out_fifo_head <= out_fifo_head;
    end
end

// logic to drive out_fifo_tail
always @(posedge clk) begin
    if (rst) begin
        out_fifo_tail <= 0;
    end
    else if (i_out_msg_rdy && ~i_should_ack) begin
        if (~(out_fifo[out_fifo_tail][W_MSG])) begin
            out_fifo_tail <= out_fifo_tail + 1; // move to next slot (overflow is desirable)
        end
        else begin
            out_fifo_tail <= out_fifo_tail;
        end
    end
    else begin
        out_fifo_tail <= out_fifo_tail;
    end
end

// logic to drive o_should_ack
always @(posedge clk) begin
    if (rst) begin
        o_should_ack <= 0;
    end
    else if (o_in_msg_rdy && ~o_should_ack) begin
        if (~(in_fifo[in_fifo_tail][W_MSG])) begin
            o_should_ack <= 1;
        end
        else begin
            o_should_ack <= 0;
        end
    end
    else begin
        o_should_ack <= 0;
    end
end

// logic to drive in_fifo
always @(posedge clk) begin
    if (rst) begin
        InvalidateInFifo();
    end
    if (i_in_msg_ack) begin
        in_fifo[in_fifo_head][W_MSG] <= 0; // invalidate current msg
    end
    if (o_in_msg_rdy && ~o_should_ack) begin
        if (~(in_fifo[in_fifo_tail][W_MSG])) begin // check to ensure tail slot is not already full
            in_fifo[in_fifo_tail] <= {1'b1, o_in_msg}; // capture message (w/ valid bit)
        end
    end
end

// logic to drive out_fifo
always @(posedge clk) begin
    if (rst) begin
        InvalidateOutFifo();
    end
    if (o_out_msg_ack) begin
        out_fifo[out_fifo_head][W_MSG] <= 0; // invalidate current msg
    end
    if (i_out_msg_rdy && ~i_should_ack) begin
        if (~(out_fifo[out_fifo_tail][W_MSG])) begin // check to ensure tail slot is not already full
            out_fifo[out_fifo_tail] <= {1'b1, i_out_msg}; // capture message (w/ valid bit)
        end
    end
end

// helper task to invalidate in FIFO queue
task InvalidateInFifo;
    integer i = 0;
    begin
        in_fifo[0][W_MSG] <= 0; 
        in_fifo[1][W_MSG] <= 0; 
        in_fifo[2][W_MSG] <= 0; 
        in_fifo[3][W_MSG] <= 0; 
        in_fifo[4][W_MSG] <= 0; 
        in_fifo[5][W_MSG] <= 0; 
        in_fifo[6][W_MSG] <= 0; 
        in_fifo[7][W_MSG] <= 0;
    end
endtask

// helper task to invalidate out FIFO queue
task InvalidateOutFifo;
    integer i = 0;
    begin
        out_fifo[0][W_MSG] <= 0;
        out_fifo[1][W_MSG] <= 0;
        out_fifo[2][W_MSG] <= 0;
        out_fifo[3][W_MSG] <= 0;
        out_fifo[4][W_MSG] <= 0;
        out_fifo[5][W_MSG] <= 0;
        out_fifo[6][W_MSG] <= 0;
        out_fifo[7][W_MSG] <= 0;
    end
endtask

/*

// on reset, invalidate all FIFO queues
// TODO: multiple drivers?
always @(posedge clk) begin
    if (rst) begin
        InvalidateFifos();
        in_fifo_head <= 0;
        out_fifo_head <= 0;
        in_fifo_tail <= 0;
        out_fifo_tail <= 0;
        i_should_ack <= 0;
        o_should_ack <= 0;
    end
end

// handle an inbound message from the outside
always @(posedge clk) begin
    if (o_in_msg_rdy && ~o_should_ack) begin
        if (~(in_fifo[in_fifo_tail][W_MSG])) begin // check to ensure tail slot is not already full
            in_fifo[in_fifo_tail] <= {1'b1, o_in_msg}; // capture message (w/ valid bit)
            in_fifo_tail <= in_fifo_tail + 1; // move to next slot (overflow is desirable)
            o_should_ack <= 1;
        end
    end
    else begin
        o_should_ack <= 0;
    end
end

// handle ack of inbound message from inside
always @(posedge clk) begin
    if (i_in_msg_ack) begin
        in_fifo[in_fifo_head][W_MSG] <= 0; // invalidate current msg
        in_fifo_head <= in_fifo_head + 1; // move to next slot (overflow is desirable)
    end
end

// handle an outbound message from the inside
always @(posedge clk) begin
    if (i_out_msg_rdy && ~i_should_ack) begin
        if (~(out_fifo[out_fifo_tail][W_MSG])) begin // check to ensure tail slot is not already full
            out_fifo[out_fifo_tail] <= {1'b1, i_out_msg}; // capture message (w/ valid bit)
            out_fifo_tail <= out_fifo_tail + 1; // move to next slot (overflow is desirable)
            i_should_ack <= 1;
        end
    end
    else begin
        i_should_ack <= 0;
    end
end

// handle ack of outbound message from outside
always @(posedge clk) begin
    if (o_out_msg_ack) begin
        out_fifo[out_fifo_head][W_MSG] <= 0; // invalidate current msg
        out_fifo_head <= out_fifo_head + 1; // move to next slot (overflow is desirable)
    end
end

// helper task to invalidate all FIFO queues
task InvalidateFifos;
    integer i = 0;
    begin
        in_fifo[0][W_MSG] <= 0; out_fifo[0][W_MSG] <= 0;
        in_fifo[1][W_MSG] <= 0; out_fifo[1][W_MSG] <= 0;
        in_fifo[2][W_MSG] <= 0; out_fifo[2][W_MSG] <= 0;
        in_fifo[3][W_MSG] <= 0; out_fifo[3][W_MSG] <= 0;
        in_fifo[4][W_MSG] <= 0; out_fifo[4][W_MSG] <= 0;
        in_fifo[5][W_MSG] <= 0; out_fifo[5][W_MSG] <= 0;
        in_fifo[6][W_MSG] <= 0; out_fifo[6][W_MSG] <= 0;
        in_fifo[7][W_MSG] <= 0; out_fifo[7][W_MSG] <= 0;
    end
endtask

*/

endmodule