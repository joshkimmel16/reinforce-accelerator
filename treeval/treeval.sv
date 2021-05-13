// define local parameters
localparam MAX_NUM_NODES = 1024; // statically define this
localparam MAX_NUM_ACTIONS = 8; // constrain # of actions
localparam NODE_SIZE = 32; // statitcally defined this
localparam W_ADDR = 10; // based on MAX_NUM_NODES
localparam W_WEIGHT = 7; // need 7 bits to represent values 0-100
localparam MAX_DATA_WIDTH = 12; // maximum possible node data width based on above (weight, address, reward, action)
localparam MAX_CONFIG_WIDTH = 10; // maximum possible config data width based on above (# nodes)
localparam W_ACTION = 3; // limit the # of distinct actions that can be taken (for now...)
localparam W_REWARD = 12; // 12 remaining bits for reward

// helpers for parsing data values within a node
localparam PARENT_START = NODE_SIZE-1;
localparam PARENT_END = NODE_SIZE-W_ADDR;
localparam ACTION_START = PARENT_END-1;
localparam ACTION_END = PARENT_END-W_ACTION;
localparam REWARD_START = ACTION_END-1;
localparam REWARD_END = ACTION_END-W_REWARD;
localparam WEIGHT_START = REWARD_END-1;
localparam WEIGHT_END = REWARD_END-W_WEIGHT;

// define states for processing
localparam W_STATES = 2;
localparam PROCESS_START = 0;
localparam PROCESS_COMPUTE = 1;
localparam PROCESS_DONE = 2;

// treeval implements a backwards propagation through a decision tree
// to compute the expected reward associated with the best initial decision to take
module treeval (
    input wire clk, // clock 
    input wire rst, // reset
    input wire mem_weight, // data on mem_data line should be read and is a weight 
    input wire mem_par, // data on mem_data line should be read and is a parent
    input wire mem_rew, // data on mem_data line should be read and is a reward
    input wire mem_act, // data on mem_data line should be read and is an action
    input wire [W_ADDR-1:0] mem_addr, // data on mem_data corresponds to which node
    input wire [MAX_DATA_WIDTH-1:0] mem_data, // node-specific data to capture
    input wire conf_nodes, // data on conf_data line should be read and is the node count
    input wire [MAX_CONFIG_WIDTH-1:0] conf_data, // config-specific data to capture
    output wire exp_change, // pulse to indicate new expectation computed
    output wire signed [W_REWARD-1:0] exp, // computed expectation value
    output wire [W_ACTION-1:0] act // action to take
);

// declare inputs and outputs
//input clk,rst,mem_weight,mem_par,mem_rew,mem_act,conf_nodes;
//input [W_ADDR-1:0] mem_addr;
//input [MAX_DATA_WIDTH-1:0] mem_data;
//input [MAX_CONFIG_WIDTH-1:0] conf_data;
//output reg exp_change;
//output reg signed [W_REWARD-1:0] exp;
//output reg [W_ACTION-1:0] act;

// internal state elements
reg [W_STATES-1:0] current_state; // current state determines what must happen in the given cycle
reg [W_STATES-1:0] next_state; // next state determines what current_state changes to
reg [W_ADDR-1:0] current_node = 1023; // track the current node we are processing
reg [W_ADDR-1:0] current_parent; // track the current parent node being processing
reg [W_ADDR-1:0] commit_parent; // track the parent node to commit to
reg [MAX_NUM_NODES-1:0] num_nodes = 1024; // track the total number of nodes in the tree
reg [MAX_NUM_NODES-1:0] node_buff [NODE_SIZE-1:0]; // buffer for all node data
reg signed [MAX_NUM_ACTIONS-1:0] act_buff [W_REWARD-1:0]; // accumulation buffer for expected rewards of all actions (for a given node)
reg [MAX_NUM_ACTIONS-1:0] num_acts; // track # of actions for the given node

// define drivers for outputs
assign exp = node_buff[0][REWARD_START:REWARD_END]; // always output root node's reward
assign act = node_buff[0][ACTION_START:ACTION_END]; // always output root node's action
assign exp_change = (current_node == num_nodes-1); // once we've cycled back to the final node, indicate that the expectation must have changed

// logic to update which node is being processed
always @(posedge clk) begin
    if (rst) begin // if reset, go back to final node
        current_node <= num_nodes-1;
    end
    else if (current_state == PROCESS_COMPUTE) begin // when running, move to next node
        if (current_node == 1) begin // don't actually process root node, go back to final node
            current_node <= num_nodes-1;
        end
        else begin // decrement node counter
            current_node <= current_node - 1;
        end
    end
end

// logic to control the update of current_state
always @(posedge clk) begin
    if (rst) begin
        current_state <= PROCESS_START;
    end
    else begin
        current_state <= next_state;
    end
end

// logic to control the value of next_state
// this block is also the driver of commit_parent
always @(posedge clk) begin
    if (current_state == PROCESS_START) begin // assume start takes 1 cycle
        next_state = PROCESS_COMPUTE;
    end
    else if (current_state == PROCESS_COMPUTE) begin // compare the current parent to the prior
        if (~(node_buff[current_node][PARENT_START:PARENT_END] == current_parent)) begin // new parent, so need to finish up here
            commit_parent = current_parent; // must save current_parent for final commit
            next_state = PROCESS_DONE;
        end
        else begin
            next_state = PROCESS_COMPUTE;
        end
    end
    else begin // assume end takes 1 cycle
        next_state = PROCESS_START;
    end
end

// logic block to control the value of current_parent
always @(posedge clk) begin
    current_parent <= node_buff[current_node][PARENT_START:PARENT_END];
end

// logic to handle state level processing
always @(posedge clk) begin
    if (current_state == PROCESS_START) begin // clear the action accumulation buffer
        ClearActionBuffer();
    end
    else if (current_state == PROCESS_COMPUTE) begin // push partial sum to action buffer
        ComputePartialSum(current_node);
    end
    else begin // find max expectation and commit to parent
        CommitMaxReward(commit_parent);
    end
end

// capture inbound node values
// this is a sideband interface of sorts
always @(posedge clk) begin
    if (mem_weight) begin
        node_buff[mem_addr][WEIGHT_START:WEIGHT_END] <= mem_data[W_WEIGHT-1:0]; 
    end
    else if (mem_par) begin
        node_buff[mem_addr][PARENT_START:PARENT_END] <= mem_data[W_ADDR-1:0];
    end
    else if (mem_rew) begin
        node_buff[mem_addr][REWARD_START:REWARD_END] <= mem_data[W_REWARD-1:0];
    end
    else if (mem_act) begin
        node_buff[mem_addr][ACTION_START:ACTION_END] <= mem_data[W_ACTION-1:0];
    end
end

// capture inbound config values
// this is a sideband interface of sorts
always @(posedge clk) begin
    if (conf_nodes) begin
        num_nodes <= conf_data;
    end
end

// set values of all actions in the action buffer to 0 or max negative reward
// 0 for used actions, max negative value for unused actions
// for now, explicitly overwrite each entry => want this to happen in 1 cycle so keep things small
// TODO: fix hardcoding when we scale up # of actions
task ClearActionBuffer; 
    begin
        num_acts = 1; // must have at least 1 action
        act_buff[0] = 0;
        act_buff[1] = 12'b100000000000;
        act_buff[2] = 12'b100000000000;
        act_buff[3] = 12'b100000000000;
        act_buff[4] = 12'b100000000000;
        act_buff[5] = 12'b100000000000;
        act_buff[6] = 12'b100000000000;
        act_buff[7] = 12'b100000000000;
    end
endtask

// multiply current_node's reward with its weight
// then add it to current_node's action's slot in accumulation buffer
// input: current_node's address
// TODO: issues with multiple drivers (num_acts)?
// TODO: non-normalized weights are a problem... => how to divide by 100?
task ComputePartialSum;
    input reg [W_ADDR-1:0] curr;
    reg signed [W_REWARD-1:0] r;
    reg [W_WEIGHT-1:0] w; 
    reg [W_ACTION-1:0] a;
    reg signed [W_REWARD-1:0] tmp;
    begin
        // read relevent data for current node
        r = node_buff[curr][REWARD_START:REWARD_END];
        w = node_buff[curr][WEIGHT_START:WEIGHT_END];
        a = node_buff[curr][ACTION_START:ACTION_END];

        // check if this is a new action
        // assumption is that action nodes are sequential and descending (relative to node address)
        tmp = r*w;
        if (a >= num_acts) begin
            // increment num_acts and 0 out the current action
            num_acts = num_acts + 1;
            act_buff[a] = tmp;
        end
        else begin
            act_buff[a] = act_buff[a] + tmp;
        end
    end
endtask

// find max expected reward in accumulation buffer
// then write it as the reward for the parent node
// inputs: parent node to commit to, # of actions
// TODO: does this handle negative rewards properly??
task CommitMaxReward;
    input reg [W_ADDR-1:0] par;
    reg [W_REWARD-1:0] t1; 
    reg [W_REWARD-1:0] t2; 
    reg [W_REWARD-1:0] t3;
    reg [W_REWARD-1:0] t4; 
    reg [W_REWARD-1:0] t5; 
    reg [W_REWARD-1:0] t6;
    reg [W_REWARD-1:0] t7;
    reg [W_ACTION-1:0] a1;
    reg [W_ACTION-1:0] a2;
    reg [W_ACTION-1:0] a3;
    reg [W_ACTION-1:0] a4;
    reg [W_ACTION-1:0] a5;
    reg [W_ACTION-1:0] a6;
    reg [W_ACTION-1:0] a7;
    begin
        // find max expected reward
        // TODO: truncate this giant if-else sequence somehow?
        if (act_buff[0] > act_buff[1]) begin
            t1 = act_buff[0];
            a1 = 3'b000;
        end
        else begin
            t1 = act_buff[1];
            a1 = 3'b001;
        end
        if (act_buff[2] > act_buff[3]) begin
            t1 = act_buff[2];
            a1 = 3'b010;
        end
        else begin
            t1 = act_buff[3];
            a1 = 3'b011;
        end
        if (act_buff[4] > act_buff[5]) begin
            t1 = act_buff[4];
            a1 = 3'b100;
        end
        else begin
            t1 = act_buff[5];
            a1 = 3'b101;
        end
        if (act_buff[6] > act_buff[7]) begin
            t1 = act_buff[6];
            a1 = 3'b110;
        end
        else begin
            t1 = act_buff[7];
            a1 = 3'b111;
        end
        if (t1 > t2) begin
            t5 = t1;
            a5 = a1;
        end
        else begin
            t5 = t2;
            a5 = a2;
        end
        if (t3 > t4) begin
            t6 = t3;
            a6 = a3;
        end
        else begin
            t6 = t4;
            a6 = a4;
        end
        if (t5 > t6) begin
            t7 = t5;
            a7 = a5;
        end
        else begin
            t7 = t6;
            a7 = a6;
        end
    
        // commit reward
        node_buff[par][REWARD_START:REWARD_END] = t7 >> 7; // divide-by-128 to normalize

        // special case if parent == root
        // also need to commit optimal action
        if (par == 0) begin
            node_buff[0][ACTION_START:ACTION_END] = a7;
        end
    end
endtask

endmodule