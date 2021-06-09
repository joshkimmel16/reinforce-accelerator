// define local parameters
localparam MAX_NUM_NODES = 1024; // statically define this
localparam MAX_NUM_ACTIONS = 8; // constrain # of actions
localparam NODE_SIZE = 32; // statitcally defined this
localparam W_ADDR = 10; // based on MAX_NUM_NODES
localparam W_WEIGHT = 8; // need 8 bits to represent values 0-128
localparam MAX_DATA_WIDTH = 10; // maximum possible node data width based on above (weight, address, reward, action)
localparam MAX_CONFIG_WIDTH = 10; // maximum possible config data width based on above (# nodes)
localparam W_ACTION = 3; // limit the # of distinct actions that can be taken (for now...)
localparam W_REWARD = 10; // 10 remaining bits for reward
localparam W_STRAT = 1; // 1 bit used to determine the strategy (max vs. min)

// helpers for parsing data values within a node
localparam PARENT_START = NODE_SIZE-1;
localparam PARENT_END = NODE_SIZE-W_ADDR;
localparam ACTION_START = PARENT_END-1;
localparam ACTION_END = PARENT_END-W_ACTION;
localparam STRAT_START = ACTION_END-1;
localparam STRAT_END = ACTION_END-W_STRAT;
localparam REWARD_START = STRAT_END-1;
localparam REWARD_END = STRAT_END-W_REWARD;
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
    input logic clk, // clock 
    input logic rst, // reset
    input logic mem_weight, // data on mem_data line should be read and is a weight 
    input logic mem_par, // data on mem_data line should be read and is a parent
    input logic mem_rew, // data on mem_data line should be read and is a reward
    input logic mem_act, // data on mem_data line should be read and is an action
    input logic [W_ADDR-1:0] mem_addr, // data on mem_data corresponds to which node
    input logic [MAX_DATA_WIDTH-1:0] mem_data, // node-specific data to capture
    input logic conf_nodes, // data on conf_data line should be read and is the node count
    input logic [MAX_CONFIG_WIDTH-1:0] conf_data, // config-specific data to capture
    output logic exp_change, // pulse to indicate new expectation computed
    output logic signed [W_REWARD-1:0] exp, // computed expectation value
    output logic [W_ACTION-1:0] act // action to take
);

// internal state elements
logic [W_STATES-1:0] current_state; // current state determines what must happen in the given cycle
logic [W_STATES-1:0] next_state; // next state determines what current_state changes to
logic [W_ADDR-1:0] current_node = 1023; // track the current node we are processing
logic [W_ADDR-1:0] current_parent; // track the current parent node being processing
logic [W_ADDR-1:0] next_parent; // track the next parent node being processing
logic [W_ADDR-1:0] commit_parent; // track the parent node to commit to
logic [MAX_NUM_NODES-1:0] num_nodes = 1024; // track the total number of nodes in the tree
logic [MAX_NUM_NODES-1:0][NODE_SIZE-1:0] node_buff; // buffer for all node data
logic signed [MAX_NUM_ACTIONS-1:0][W_REWARD-1:0] act_buff; // accumulation buffer for expected rewards of all actions (for a given node)
logic [MAX_NUM_ACTIONS-1:0] num_acts; // track # of actions for the given node

// define drivers for outputs
assign exp = node_buff[0][REWARD_START:REWARD_END]; // always output root node's reward
assign act = node_buff[0][ACTION_START:ACTION_END]; // always output root node's action
assign exp_change = (current_node == num_nodes-1 && current_state == PROCESS_START); // once we've cycled back to the final node, indicate that the expectation must have changed

// initialize root node values that need to be initialized
initial begin
    node_buff[0][PARENT_START:PARENT_END] = 10'b1111111111; // initalize root's parent to max node value so it can't match any other parent
    node_buff[0][WEIGHT_START:WEIGHT_END] = 8'b00000000; // initalize root's weight to anything known
end

// logic to update which node is being processed
always @(posedge clk) begin
    if (rst) begin // if reset, go back to final node
        current_node <= num_nodes-1;
    end
    else if ((current_state == PROCESS_COMPUTE && next_state == PROCESS_COMPUTE) || (current_state == PROCESS_DONE && next_state == PROCESS_START)) begin // when running, move to next node
        if (current_node == 1) begin // don't actually process root node, go back to final node
            current_node <= num_nodes-1;
        end
        else begin // decrement node counter
            current_node <= current_node-1;
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

// logic block to control the value of current_parent
// need to look ahead by 1 because of sequential logic
always @(posedge clk) begin
    if (rst) begin // if reset, go back to final node
        current_parent <= node_buff[num_nodes-1][PARENT_START:PARENT_END];
        next_parent <= node_buff[num_nodes-2][PARENT_START:PARENT_END];
    end
    else if (current_state == PROCESS_COMPUTE) begin // when running, move to next node
        if (current_node == 1) begin // don't actually process root node, go back to final node
            current_parent <= node_buff[num_nodes-1][PARENT_START:PARENT_END];
            next_parent <= node_buff[num_nodes-2][PARENT_START:PARENT_END];
        end
        else begin // decrement node counter
            current_parent <= node_buff[current_node-1][PARENT_START:PARENT_END];
            next_parent <= node_buff[current_node-2][PARENT_START:PARENT_END];
        end
    end
end

// logic to control the value of next_state
// this block is also the driver of commit_parent
always_comb begin
    if (rst) begin
        next_state = PROCESS_START;
    end
    else if (current_state == PROCESS_START) begin // assume start takes 1 cycle
        commit_parent = current_parent;
        next_state = PROCESS_COMPUTE;
    end
    else if (current_state == PROCESS_COMPUTE) begin // compare the current parent to the prior
        if (~(next_parent == current_parent)) begin // new parent, so need to finish up here
            // must save current_parent for final commit
            commit_parent = current_parent;
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

// logic to handle state level processing
// also handle conf/node updates so as to encapsulate all updates of node/action buffers in 1 block
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
    else if (mem_act) begin // multiplex strategy with action as they are related
        node_buff[mem_addr][STRAT_START:STRAT_END] <= mem_data[W_ACTION+W_STRAT:W_ACTION];
        node_buff[mem_addr][ACTION_START:ACTION_END] <= mem_data[W_ACTION-1:0];
    end
    
    // can safely ignore processing b/c a reset will be necessary anyways...
    else if (current_state == PROCESS_START) begin // clear the action accumulation buffer
        ClearActionBuffer(current_parent);
    end
    else if (current_state == PROCESS_COMPUTE) begin // push partial sum to action buffer
        ComputePartialSum(current_node);
    end
    else begin // find optimal expectation and commit to parent
        CommitOptimalReward(commit_parent);
    end
end

/*
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
    else if (mem_act) begin // multiplex strategy with action as they are related
        node_buff[mem_addr][STRAT_START:STRAT_END] <= mem_data[W_ACTION+W_STRAT:W_ACTION];
        node_buff[mem_addr][ACTION_START:ACTION_END] <= mem_data[W_ACTION-1:0];
    end
end
*/

// capture inbound config values
// this is a sideband interface of sorts
always @(posedge clk) begin
    if (conf_nodes) begin
        num_nodes <= conf_data;
    end
end

// set values of all actions in the action buffer to 0 or max negative reward
// 0 for used actions, max positive/negative value for unused actions (depending on parent strategy)
// for now, explicitly overwrite each entry => want this to happen in 1 cycle so keep things small
// TODO: fix hardcoding when we scale up # of actions
task ClearActionBuffer; 
    input logic [W_ADDR-1:0] par;
    logic [W_STRAT-1:0] strat = node_buff[par][STRAT_START:STRAT_END];
    begin
        num_acts <= 0; // must have at least 1 action
        act_buff[0] <= 0;
        if (strat) begin // strat == maximize, so defaults are max negative
            act_buff[1] <= 10'b1000000000;
            act_buff[2] <= 10'b1000000000;
            act_buff[3] <= 10'b1000000000;
            act_buff[4] <= 10'b1000000000;
            act_buff[5] <= 10'b1000000000;
            act_buff[6] <= 10'b1000000000;
            act_buff[7] <= 10'b1000000000;
        end
        else begin // strat == minimize, so defaults are max positive
            act_buff[1] <= 10'b0111111111;
            act_buff[2] <= 10'b0111111111;
            act_buff[3] <= 10'b0111111111;
            act_buff[4] <= 10'b0111111111;
            act_buff[5] <= 10'b0111111111;
            act_buff[6] <= 10'b0111111111;
            act_buff[7] <= 10'b0111111111;
        end
    end
endtask

// multiply current_node's reward with its weight
// then add it to current_node's action's slot in accumulation buffer
// input: current_node's address
// TODO: truncation is a problem => integer division can cause different rewards (for a fixed weight) to map to the same expectation...
task ComputePartialSum;
    input logic [W_ADDR-1:0] curr;
    logic signed [W_REWARD-1:0] r;
    logic signed [W_WEIGHT:0] w; 
    logic [W_ACTION-1:0] a;
    logic signed [W_REWARD+W_WEIGHT-1:0] tmp; // need this to be big enough s.t. overflow cannot occur
    begin
        // read relevent data for current node
        r = node_buff[curr][REWARD_START:REWARD_END];
        w = {1'b0, node_buff[curr][WEIGHT_START:WEIGHT_END]}; // must manually sign-extend the unsigned value
        a = node_buff[curr][ACTION_START:ACTION_END];

        // check if this is a new action
        // assumption is that action nodes are sequential and descending (relative to node address)
        tmp = (r*w) >>> (W_WEIGHT-1); // (W_WEIGHT-1) b/c need an extra bit for 128 case
        if (a > num_acts) begin
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
// inputs: parent node to commit to
// TODO: refactor when # of actions is variable/larger
task CommitOptimalReward;
    input logic [W_ADDR-1:0] par;
    logic signed [W_REWARD-1:0] t1; 
    logic signed [W_REWARD-1:0] t2; 
    logic signed [W_REWARD-1:0] t3;
    logic signed [W_REWARD-1:0] t4; 
    logic signed [W_REWARD-1:0] t5; 
    logic signed [W_REWARD-1:0] t6;
    logic signed [W_REWARD-1:0] t7;
    logic [W_ACTION-1:0] a1;
    logic [W_ACTION-1:0] a2;
    logic [W_ACTION-1:0] a3;
    logic [W_ACTION-1:0] a4;
    logic [W_ACTION-1:0] a5;
    logic [W_ACTION-1:0] a6;
    logic [W_ACTION-1:0] a7;
    logic [W_STRAT-1:0] strat = node_buff[par][STRAT_START:STRAT_END];
    begin
        // find max expected reward
        // TODO: truncate this giant if-else sequence somehow?
        if (act_buff[0] > act_buff[1]) begin
            if (strat) begin
                t1 = act_buff[0];
                a1 = 3'b000;
            end
            else begin
                t1 = act_buff[1];
                a1 = 3'b001;
            end
        end
        else begin
            if (strat) begin
                t1 = act_buff[1];
                a1 = 3'b001;
            end
            else begin
                t1 = act_buff[0];
                a1 = 3'b000;
            end
        end
        if (act_buff[2] > act_buff[3]) begin
            if (strat) begin
                t2 = act_buff[2];
                a2 = 3'b010;
            end
            else begin
                t2 = act_buff[3];
                a2 = 3'b011;
            end
        end
        else begin
            if (strat) begin
                t2 = act_buff[3];
                a2 = 3'b011;
            end
            else begin
                t2 = act_buff[2];
                a2 = 3'b010;
            end
        end
        if (act_buff[4] > act_buff[5]) begin
            if (strat) begin
                t3 = act_buff[4];
                a3 = 3'b100;
            end
            else begin
                t3 = act_buff[5];
                a3 = 3'b101;
            end
        end
        else begin
            if (strat) begin
                t3 = act_buff[5];
                a3 = 3'b101;
            end
            else begin
                t3 = act_buff[4];
                a3 = 3'b100;
            end
        end
        if (act_buff[6] > act_buff[7]) begin
            if (strat) begin
                t4 = act_buff[6];
                a4 = 3'b110;
            end
            else begin
                t4 = act_buff[7];
                a4 = 3'b111;
            end
        end
        else begin
            if (strat) begin
                t4 = act_buff[7];
                a4 = 3'b111;
            end
            else begin
                t4 = act_buff[6];
                a4 = 3'b110;
            end
        end
        if (t1 > t2) begin
            if (strat) begin
                t5 = t1;
                a5 = a1;
            end
            else begin
                t5 = t2;
                a5 = a2;
            end
        end
        else begin
            if (strat) begin
                t5 = t2;
                a5 = a2;
            end
            else begin
                t5 = t1;
                a5 = a1;
            end
        end
        if (t3 > t4) begin
            if (strat) begin
                t6 = t3;
                a6 = a3;
            end
            else begin
                t6 = t4;
                a6 = a4;
            end
        end
        else begin
            if (strat) begin
                t6 = t4;
                a6 = a4;
            end
            else begin
                t6 = t3;
                a6 = a3;
            end
        end
        if (t5 > t6) begin
            if (strat) begin
                t7 = t5;
                a7 = a5;
            end
            else begin
                t7 = t6;
                a7 = a6;
            end
        end
        else begin
            if (strat) begin
                t7 = t6;
                a7 = a6;
            end
            else begin
                t7 = t5;
                a7 = a5;
            end
        end
    
        // commit reward
        node_buff[par][REWARD_START:REWARD_END] = t7;

        // special case if parent == root
        // also need to commit optimal action
        if (par == 0) begin
            node_buff[0][ACTION_START:ACTION_END] = a7;
        end
    end
endtask

endmodule