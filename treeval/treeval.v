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
    mem_addr, // data on mem_data corresponds to which node
    mem_data, // node-specific data to capture
    conf_nodes, // data on conf_data line should be read and is the node count
    conf_data, // config-specific data to capture
    exp_change, // pulse to indicate new expectation computed
    exp, // computed expectation value
    act // action to take
);

// define parameters
parameter W_ADDR = 10; // width of mem_addr
parameter W_M_DATA = 10; // max width of data value for a node
parameter W_C_DATA = 10; // max width of data value for config
parameter W_C_DATA = 10; // max width of data value for config
parameter W_REWARD = 8; // max width of a reward value (signed)
parameter W_ACTION = 10; // max width of an action

integer NODE_SIZE = W_ADDR + W_REWARD + 7; // parent address + reward + weight (7 bits), 0-indexed
integer WEIGHT_START = 6; // weight MSb
integer WEIGHT_END = 0; // weight LSb
integer PARENT_START = NODE_SIZE-1; // parent address MSb
integer PARENT_END = NODE_SIZE-W_ADDR-1; // parent address LSb
integer REWARD_START = PARENT_END-1; // parent address MSb
integer REWARD_END = WEIGHT_START+1; // parent address LSb
integer MAX_NUM_NODES = 1023; // max number of nodes (0-indexed)

// declare inputs and outputs
input reg clk,rst,mem_weight,mem_par,mem_rew,conf_nodes;
input reg mem_addr[W_ADDR-1:0];
input reg mem_data[W_M_DATA-1:0];
input reg conf_data[W_C_DATA-1:0];
output reg exp_change;
output reg exp[W_REWARD-1:0];
output reg act[W_ACTION-1:0]

// internal state elements
reg current_node[W_ADDR-1:0];
reg num_nodes[W_C_DATA-1:0] = d'1023;
reg [MAX_NUM_NODES-1:0] mem_nodes [NODE_SIZE-1:0];

// define drivers for outputs
exp = mem_nodes[0][REWARD_START:REWARD_END]; // always output root node's reward
exp_change = (current_node == num_nodes);

// when a reset is asserted
// reset all of the reward values
always @(posedge clk) begin
    if (rst) begin
        ResetRewards();
    end
end

// update node being processed every clock cycle
// align this with actual processing (rising edge)
always @(posedge clk) begin
    if (current_node == d'1) begin
        current_node <= num_nodes;
    end
    else begin
        current_node <= current_node - 1;
    end
end

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
        mem_nodes[i][REWARD_START:REWARD_END] = d'0;
    end
endtask