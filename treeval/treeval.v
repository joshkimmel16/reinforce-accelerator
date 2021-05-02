// TODO: need to add mechanism to capture which is the optimal action for the given node
    // this is challenging because we have many children per action
// TODO: once implementation is finished, test. No way this passes elaboration right now...

// treeval implements a backwards propagation through a decision tree
// to compute the expected reward associated with the best initial decision to take
module treeval (
    clk, // clock 
    rst, // reset
    mem_weight, // data on mem_data line should be read and is a weight 
    mem_par, // data on mem_data line should be read and is a parent
    mem_rew, // data on mem_data line should be read and is a reward
    mem_act, // data on mem_data line should be read and is an action
    mem_addr, // data on mem_data corresponds to which node
    mem_data, // node-specific data to capture
    conf_nodes, // data on conf_data line should be read and is the node count
    conf_data, // config-specific data to capture
    exp_change, // pulse to indicate new expectation computed
    exp, // computed expectation value
    act // action to take
);

// define user-facing parameters
parameter W_REWARD = 10; // can be anything from 1-14, must sum to 15 with W_ACTION
parameter W_ACTION = 5; // can be anything from 1-14, must sum to 15 with W_REWARD

// define local parameters
localparam MAX_NUM_NODES = 1024; // statically define this
localparam MAX_NUM_ACTIONS = 16384; // reward must be at least 1 bit => # actions can be at most remaining 14 bits
localparam NODE_SIZE = 32; // statitcally defined this
localparam W_ADDR = 10; // based on MAX_NUM_NODES
localparam W_WEIGHT = 7; // need 7 bits to represent values 0-100
localparam MAX_DATA_WIDTH = 14; // maximum possible node data width based on above (weight, address, reward, action)
localparam MAX_CONFIG_WIDTH = 14; // maximum possible config data width based on above (# nodes)

// helpers for parsing data values within a node
localparam PARENT_START = NODE_SIZE-1;
localparam PARENT_END = NODE_SIZE-1-W_ADDR;
localparam ACTION_START = PARENT_END-1;
localparam ACTION_END = PARENT_END-1-W_ACTION;
localparam REWARD_START = ACTION_END-1;
localparam REWARD_END = ACTION_END-1-W_REWARD;
localparam WEIGHT_START = REWARD_END-1;
localparam WEIGHT_END = REWARD_END-1-W_WEIGHT;

// define states for processing
localparam W_STATES = 2;
localparam PROCESS_START = 0;
localparam PROCESS_RUN = 0;
localparam PROCESS_DONE = 0;

// declare inputs and outputs
input reg clk,rst,mem_weight,mem_par,mem_rew,mem_act,conf_nodes;
input reg mem_addr[W_ADDR-1:0];
input reg mem_data[MAX_DATA_WIDTH-1:0];
input reg conf_data[MAX_CONFIG_WIDTH-1:0];
output reg exp_change;
output reg exp[W_REWARD-1:0];
output reg act[W_ACTION-1:0]

// internal state elements
reg current_state[W_STATES-1:0]; // current state determines what must happen in the given cycle
reg next_state[W_STATES-1:0]; // next state determines what current_state changes to
reg current_node[W_ADDR-1:0] = 1023; // track the current node we are processing
reg current_parent[W_ADDR-1:0]; // track the current parent node being processing
reg commit_parent[W_ADDR-1:0]; // track the parent node to commit to
reg num_nodes[MAX_NUM_NODES-1:0] = 1024; // track the total number of nodes in the tree
reg [MAX_NUM_NODES-1:0] node_buff [NODE_SIZE-1:0]; // buffer for all node data
reg [MAX_NUM_ACTIONS-1:0] act_buff [W_REWARD-1:0]; // accumulation buffer for expected rewards of all actions (for a given node)

// define drivers for outputs
exp = node_buff[0][REWARD_START:REWARD_END]; // always output root node's reward
act = node_buff[0][ACTION_START:ACTION_END]; // always output root node's action
exp_change = (current_node == num_nodes-1); // once we've cycled back to the final node, indicate that the expectation must have changed

// logic to update which node is being processed
always @(posedge clk) begin
    if (rst) begin // if reset, go back to final node
        current_node <= num_nodes-1;
    end
    else if (current_state == PROCESS_RUN) begin // when running, move to next node
        if (current_node == d'1) begin // don't actually process root node, go back to final node
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
        reg tmp = node_buff[current_node][PARENT_START-1:PARENT_END];
        if (~(tmp == current_parent)) begin // new parent, so need to finish up here
            commit_parent = current_parent; // must save current_parent for final commit
            next_state = PROCESS_END;
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
    current_parent <= node_buff[current_node][PARENT_START-1:PARENT_END];
end

// logic to handle state level processing
always @(posedge clk) begin
    if (current_state == PROCESS_START) begin // clear the action accumulation buffer
        ClearActionBuffer(); // TODO: track # of actions, pass this as arg
    end
    else if (current_state == PROCESS_COMPUTE) begin // push partial sum to action buffer
        ComputePartialSum(current_node);
    end
    else begin // find max expectation and commit to parent
        CommitMaxReward(commit_parent);
    end
end

// set values of all actions in the action buffer to max negative reward
// input: # of actions so we don't have to do extra work
task ClearActionBuffer () begin
    // TODO: implement
endtask

// multiply current_node's reward with its weight
// then add it to current_node's action's slot in accumulation buffer
// input: current_node's address
task ComputePartialSum (arg1) begin
    // TODO: implement
endtask

// find max expected reward in accumulation buffer
// then write it as the reward for the parent node
// inputs: parent node to commit to, # of actions
task CommitMaxReward (arg1, arg2) begin
    // TODO: implement
endtask

// capture inbound node values
// stagger with this actual processing
always @(negedge clk) begin
    if (mem_weight) begin
        mem_nodes[mem_addr][WEIGHT_START:WEIGHT_END] <= mem_data[6:0]; 
    end
    else if (mem_par) begin
        mem_nodes[mem_addr][PARENT_START:PARENT_END] <= mem_data[W_ADDR-1:0];
    end
    else if (mem_rew) begin
        mem_nodes[mem_addr][REWARD_START:REWARD_END] <= mem_data[W_REWARD-1:0];
    end
end

// capture inbound config values
// stagger with this actual processing
always @(negedge clk) begin
    if (conf_nodes) begin
        num_nodes <= conf_data;
    end
end

// process a single node
// by taking its current reward and weight, multiplying them, and adding the result to the parent's current reward
always @(posedge clk) begin
    reg p = mem_nodes[current_node][PARENT_START:PARENT_END]; // get current node's parent
    reg r = mem_nodes[current_node][REWARD_START:REWARD_END]; // get current node's reward
    reg w = mem_nodes[current_node][WEIGHT_START:WEIGHT_END]; // get current node's weight
    mem_nodes[p] = mem_nodes[p][REWARD_START:REWARD_END] + r * w; // add weighted reward to parent's reward
end

// special task to reset all rewards to 0
task ResetRewards () begin
    integer i=0;
    for (i; i<=num_nodes; i++) begin
        node_buff[i][REWARD_START:REWARD_END] = d'0;
    end
endtask

// special task to reset all actions to (MAX_NEG)
task ResetActions () begin
    integer i=0;
    for (i; i<MAX_NUM_ACTIONS; i++) begin
        mem_nodes[i][REWARD_START:REWARD_END] = d'0;
    end
endtask