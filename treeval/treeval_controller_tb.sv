// testbench for treeval

`timescale 10 ps / 1 ps

module treeval_tb;

localparam CLOCK = 125; // 800 MHz
localparam W_ADDR = 10;
localparam W_N_DATA = 10;
localparam W_C_DATA = 10;
localparam W_REWARD = 10;
localparam W_ACTION = 3;

localparam ACT_PLAY = 3'b001;
localparam ACT_NO_PLAY = 3'b000;

localparam STRAT_MAX = 1'b1;
localparam STRAT_MIN = 1'b0;

localparam W_MSG = 64;
localparam W_CMD = 2;
localparam W_CMD_DATA = W_MSG - W_CMD;

// high-level commands
localparam W_CMD_TYPE = 2;
localparam CMD_RUN_COMPUTATION = 0;
localparam CMD_SET_NODE_DATA = 1;
localparam CMD_SET_CONFIG_DATA = 2;

// commands for config data
localparam W_CFG_CMD = 2;
localparam CFG_CMD_NODES = 0;

// commands for node data
localparam W_NODE_CMD = 2;
localparam NODE_CMD_PARENT = 0;
localparam NODE_CMD_ACTION = 1;
localparam NODE_CMD_REWARD = 2;
localparam NODE_CMD_WEIGHT = 3;

logic clk;
logic rst;

// inputs
logic out_msg_ack;
logic in_msg_rdy;
logic [W_MSG-1:0] in_msg;

// outputs
logic in_msg_ack;
logic out_msg_rdy;
logic [W_MSG-1:0] out_msg;

treeval_controller DUT (
    .clk(clk),
    .rst(rst),  
    .in_msg_ack(in_msg_ack),
    .out_msg_ack(out_msg_ack),
    .in_msg_rdy(in_msg_rdy),
    .out_msg_rdy(out_msg_rdy),
    .in_msg(in_msg),
    .out_msg(out_msg)
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
    out_msg_ack = 0;
    in_msg_rdy = 0;
    nErr = 0;

    out = $fopen("output.txt", "w");

    #(CLOCK);
    tskConfNodes(); // configure # of nodes
    #(CLOCK);
    tskTreeStruct(); // set tree structure
    #(CLOCK);
    tskSetRewards(); // set leaf node rewards
    #(CLOCK);
    tskSetActions(); // set tree actions
    #(CLOCK);
    tskSetTreeWeights(); // set tree weights
    #(CLOCK);
    tskStartComp(); // start computation
    #(CLOCK);
    tskCaptureOutput(); // capture and verify output

    #(CLOCK) $display("%d ... finishing, number of errors = %d",
                     $stime, nErr);
    
    $finish;   // end of simulation
end

// helper task to send messages appropriately
task tskSendMessage;
    input logic [W_MSG-1:0] msg;
    input logic[30*8:0] testName;
    integer count = 0;
    begin
        in_msg_rdy = 1;
        in_msg = msg;
        while (count < 5) begin
            #(CLOCK);
            if (in_msg_ack) begin
                count = 6;
            end
            else begin
                count = count + 1;
            end
        end
        if (count == 5) begin
            logError(testName, "Never got ack from axi.");
        end
        in_msg_rdy = 0;
    end
endtask

task tskConfNodes;
    logic [W_CMD_TYPE-1:0] cmd = CMD_SET_CONFIG_DATA;
    logic [W_CFG_CMD-1:0] cmd_cfg = CFG_CMD_NODES;
    logic [W_C_DATA-1:0] cfg_data = 10'b0000000111; // 7 nodes in tree
    logic [W_MSG-1:0] msg = {cmd, cmd_cfg, 50'd0, cfg_data};
    begin
        tskSendMessage(msg, "tskConfNodes");
    end
endtask

task tskTreeStruct;
    logic [W_CMD_TYPE-1:0] cmd = CMD_SET_NODE_DATA;
    logic [W_NODE_CMD-1:0] cmd_node = NODE_CFG_PARENT;
    logic [W_MSG-1:0] msg;
    begin
        msg = {cmd, 10'b0000000001, cmd_node, 40'd0, 10'b0000000000}; // 0 -> 1
        tskSendMessage(msg, "tskTreeStruct1");
        #(CLOCK);
        msg = {cmd, 10'b0000000010, cmd_node, 40'd0, 10'b0000000000}; // 0 -> 2
        tskSendMessage(msg, "tskTreeStruct2");
        #(CLOCK);
        msg = {cmd, 10'b0000000011, cmd_node, 40'd0, 10'b0000000000}; // 0 -> 3
        tskSendMessage(msg, "tskTreeStruct3");
        #(CLOCK);
        msg = {cmd, 10'b0000000100, cmd_node, 40'd0, 10'b0000000001}; // 1 -> 4
        tskSendMessage(msg, "tskTreeStruct4");
        #(CLOCK);
        msg = {cmd, 10'b0000000101, cmd_node, 40'd0, 10'b0000000001}; // 1 -> 5
        tskSendMessage(msg, "tskTreeStruct5");
        #(CLOCK);
        msg = {cmd, 10'b0000000110, cmd_node, 40'd0, 10'b0000000001}; // 1 -> 6
        tskSendMessage(msg, "tskTreeStruct6");
    end
endtask

task tskSetRewards;
    logic [W_CMD_TYPE-1:0] cmd = CMD_SET_NODE_DATA;
    logic [W_NODE_CMD-1:0] cmd_node = NODE_CFG_REWARD;
    logic [W_MSG-1:0] msg;
    begin
        msg = {cmd, 10'b0000000010, cmd_node, 40'd0, 10'b1111110110}; // node 2 = -10
        tskSendMessage(msg, "tskSetRewards2");
        #(CLOCK);
        msg = {cmd, 10'b0000000011, cmd_node, 40'd0, 10'b0000000000}; // node 3 = 0
        tskSendMessage(msg, "tskSetRewards3");
        #(CLOCK);
        msg = {cmd, 10'b0000000100, cmd_node, 40'd0, 10'b0001100100}; // node 4 = 100
        tskSendMessage(msg, "tskSetRewards4");
        #(CLOCK);
        msg = {cmd, 10'b0000000101, cmd_node, 40'd0, 10'b1111001110}; // node 5 = -50
        tskSendMessage(msg, "tskSetRewards5");
        #(CLOCK);
        msg = {cmd, 10'b0000000110, cmd_node, 40'd0, 10'b0000000000}; // node 6 = 0
        tskSendMessage(msg, "tskSetRewards6");
    end
endtask


task tskSetActions;
    logic [W_CMD_TYPE-1:0] cmd = CMD_SET_NODE_DATA;
    logic [W_NODE_CMD-1:0] cmd_node = NODE_CFG_ACTION;
    logic [W_MSG-1:0] msg;
    begin
        msg = {cmd, 10'b0000000000, cmd_node, 46'd0, {STRAT_MAX, 3'b000}}; // node 0 => MAX, don't care about action
        tskSendMessage(msg, "tskSetActions0");
        #(CLOCK);
        msg = {cmd, 10'b0000000001, cmd_node, 46'd0, {STRAT_MAX, ACT_PLAY}}; // node 1 = PLAY, MAX
        tskSendMessage(msg, "tskSetActions1");
        #(CLOCK);
        msg = {cmd, 10'b0000000010, cmd_node, 46'd0, {STRAT_MAX, ACT_PLAY}}; // node 2 = PLAY, MAX
        tskSendMessage(msg, "tskSetActions2");
        #(CLOCK);
        msg = {cmd, 10'b0000000011, cmd_node, 46'd0, {STRAT_MAX, ACT_NO_PLAY}}; // node 3 = NO PLAY, MAX
        tskSendMessage(msg, "tskSetActions3");
        #(CLOCK);
        msg = {cmd, 10'b0000000100, cmd_node, 46'd0, {STRAT_MAX, ACT_PLAY}}; // node 4 = PLAY, MAX
        tskSendMessage(msg, "tskSetActions4");
        #(CLOCK);
        msg = {cmd, 10'b0000000101, cmd_node, 46'd0, {STRAT_MAX, ACT_PLAY}}; // node 5 = PLAY, MAX
        tskSendMessage(msg, "tskSetActions5");
        #(CLOCK);
        msg = {cmd, 10'b0000000110, cmd_node, 46'd0, {STRAT_MAX, ACT_NO_PLAY}}; // node 6 = NO PLAY, MAX
        tskSendMessage(msg, "tskSetActions6");
    end
endtask

task tskSetTreeWeights;
    logic [W_CMD_TYPE-1:0] cmd = CMD_SET_NODE_DATA;
    logic [W_NODE_CMD-1:0] cmd_node = NODE_CFG_PARENT;
    logic [W_MSG-1:0] msg;
    begin
        msg = {cmd, 10'b0000000001, cmd_node, 40'd0, 10'b0001000000}; // node 1 = 0.5 = 64
        tskSendMessage(msg, "tskTreeWeights1");
        #(CLOCK);
        msg = {cmd, 10'b0000000010, cmd_node, 40'd0, 10'b0001000000}; // node 2 = 0.5 = 64
        tskSendMessage(msg, "tskTreeWeights2");
        #(CLOCK);
        msg = {cmd, 10'b0000000011, cmd_node, 40'd0, 10'b0010000000}; // node 3 = 1 = 128
        tskSendMessage(msg, "tskTreeWeights3");
        #(CLOCK);
        msg = {cmd, 10'b0000000100, cmd_node, 40'd0, 10'b0001000000}; // node 4 = 0.5 = 64
        tskSendMessage(msg, "tskTreeWeights4");
        #(CLOCK);
        msg = {cmd, 10'b0000000101, cmd_node, 40'd0, 10'b0001000000}; // node 5 = 0.5 = 64
        tskSendMessage(msg, "tskTreeWeights5");
        #(CLOCK);
        msg = {cmd, 10'b0000000110, cmd_node, 40'd0, 10'b0010000000}; // node 6 = 1 = 128
        tskSendMessage(msg, "tskTreeWeights6");
    end
endtask

task tskStartComp;
    logic [W_CMD_TYPE-1:0] cmd = CMD_RUN_COMPUTATION;
    logic [W_MSG-1:0] msg = {cmd, 62'd0};
    begin
        tskSendMessage(msg, "tskStartComp");
    end
endtask

task tskCaptureOutput;
    logic [W_MSG-1:0] to_verify;
    integer count = 0;
    begin
        // wait for a ready signal
        while (count < 100) begin
            #(CLOCK);
            if (out_msg_rdy) begin // inbound message arrived
                count = 101;
                to_verify = out_msg;
                out_msg_ack = 1;
            end
            else begin
                count = count + 1;
            end
        end
        #(CLOCK);
        out_msg_ack = 0;

        if (count == 100) begin
            logError("tskCaptureOutput", "Never got outbound message from controller.");
        end
        else begin
            // TODO: verify that outbound message has correct data (action = PLAY, reward = 7)
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