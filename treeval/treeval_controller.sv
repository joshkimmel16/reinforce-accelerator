// define local parameters
localparam W_ADDR = 10; // based on MAX_NUM_NODES
localparam MAX_DATA_WIDTH = 11; // maximum possible node data width based on above (weight, address, reward, action)
localparam MAX_CONFIG_WIDTH = 10; // maximum possible config data width based on above (# nodes)
localparam W_ACTION = 3; // limit the # of distinct actions that can be taken (for now...)
localparam W_REWARD = 11; // 11 remaining bits for reward

// define states
localparam W_STATES = 2;
localparam CONTROLLER_START = 0;
localparam CONTROLLER_UPDATE = 1;
localparam CONTROLLER_WAIT = 2;
localparam CONTROLLER_DONE = 3;

// define command types
localparam W_CMD_TYPE = 2;
localparam CMD_RUN_COMPUTATION = 0;
localparam CMD_SET_NODE_DATA = 1;
localparam CMD_SET_CONFIG_DATA = 2;

// treeval_controller drives the treeval execution module.
// software commands are written to a 64-bit command register.
// after treeval execution is complete, treeval_controller will generate an interrupt.
module treeval_controller (
    input logic clk, // clock
    input logic rst, // reset
    input logic [63:0] command, // software command
    output logic signed [W_REWARD-1:0] exp, // computed expectation value
    output logic [W_ACTION-1:0] act, // action to take
    output logic valid // whether exp and act registers are valid
);

// internal state elements
logic [W_STATES-1:0] current_state; // current state determines what must happen in the given cycle
logic [W_STATES-1:0] next_state; // next state determines what current_state changes to
logic [W_CMD_TYPE-1:0] command_type; // the type of software command
logic [61:0] command_data; // the data in the software command
logic start_computation; // whether the treeval module should be executed

// elements for internal treeval
logic treeval_mem_weight;
logic treeval_mem_par;
logic treeval_mem_rew;
logic treeval_mem_act;
logic [W_ADDR-1:0] treeval_mem_addr;
logic [MAX_DATA_WIDTH-1:0] treeval_mem_data;
logic treeval_conf_nodes;
logic [MAX_CONFIG_WIDTH-1:0] treeval_conf_data;
logic treeval_exp_change;
logic signed [W_REWARD-1:0] treeval_exp;
logic [W_ACTION-1:0] treeval_act;

treeval execution_unit (
    .clk(clk),
    .rst(rst),
    .mem_weight(treeval_mem_weight),
    .mem_par(treeval_mem_par),
    .mem_rew(treeval_mem_rew),
    .mem_act(treeval_mem_act),
    .mem_addr(treeval_mem_addr),
    .mem_data(treeval_mem_data),
    .conf_nodes(treeval_conf_nodes),
    .conf_data(treeval_conf_data),
    .exp_change(treeval_exp_change),
    .exp(treeval_exp),
    .act(treeval_act)
);

// define drivers for outputs
assign exp = treeval_exp[W_REWARD-1:0]
assign act = treeval_act[W_ACTION-1:0]
assign valid = (current_state == CONTROLLER_DONE)

// initialize any values that need to be initialized
initial begin
    treeval_mem_weight = 0;
    treeval_mem_par = 0;
    treeval_mem_rew = 0;
    treeval_mem_act = 0;
    treeval_conf_nodes = 0;
    current_state = CONTROLLER_START;
    command_data = 0;
    start_computation = 0;
end

// logic to control the update of current_state
always @(posedge clk) begin
    if (rst) begin
        current_state <= CONTROLLER_START;
    end
    else begin
        current_state <= next_state;
    end
end

// logic to control the value of next_state
always_comb begin
    if (rst) begin
        next_state = CONTROLLER_START;
    end
    else if (current_state == CONTROLLER_START) begin
        next_state = CONTROLLER_UPDATE;
    end
    else if (current_state == CONTROLLER_UPDATE) begin
        if (start_computation) begin // if computation has started
            next_state = CONTROLLER_WAIT; // wait for execution
        end
        else begin // if computation has not started
            next_state = CONTROLLER_START; // read new command
        end
    end
    else if (current_state == CONTROLLER_WAIT) begin
        if (treeval_exp_change) begin // if computation is done
            next_state = CONTROLLER_DONE;
        end
        else begin
            next_state = CONTROLLER_WAIT;
        end
    end
    else begin
        next_state = CONTROLLER_START;
    end
end

// logic to handle state level processing
always @(posedge clk) begin
    if (current_state == CONTROLLER_START) begin // decode command
        DecodeCommand();
    end
    else if (current_state == CONTROLLER_UPDATE) begin // execute command
        if (command == CMD_SET_NODE_DATA) begin // update node data
            UpdateNodeData();
        end
        else if (command == CMD_SET_CONFIG_DATA) begin // update config data
            UpdateConfigData();
        end
        else if (command == CMD_RUN_COMPUTATION) begin // start treeval computation
            // NOP
        end
    end
    else if (current_state == CONTROLLER_WAIT) begin // wait for treeval computation
        // NOP
    end
    else begin // generate interrupt
        GenerateInterrupt();
    end
end

task DecodeCommand;
    begin
        command_type = command[63:62];
        if (command == CMD_RUN_COMPUTATION) begin
            start_computation = 1;
        end
        else if (command == CMD_SET_NODE_DATA) begin
            start_computation = 0;
            command_data[61:0] = command[61:0];
        end
        else if (command == CMD_SET_CONFIG_DATA) begin
            start_computation = 0;
            start_computation = 0;
            command_data[61:0] = command[61:0];
    end
endtask

// node_data[61:0] = addr[61:52] || type[51:50] || val[49:0]
task UpdateNodeData;
    logic [9:0] node_data_addr;
    logic [1:0] node_data_type;
    logic [49:0] node_data_val;
    begin
        node_data_addr[9:0] = command_data[61:52];
        node_data_type[1:0] = command_data[51:50];
        node_data_val[49:0] = command_data[49:0];

        // set address of which node to update
        treeval_mem_addr = node_data_addr[W_ADDR-1:0];

        // set data for field being updated
        treeval_mem_data = node_data_val[MAX_DATA_WIDTH-1:0];

        // decode which field of node is being updated
        // one-hot encode the data line indicating the field
        if (node_data_type == 2'b00) begin
            treeval_mem_par = 1; // parent field
            treeval_mem_act = 0;
            treeval_mem_rew = 0;
            treeval_mem_weight = 0;
        end
        else if (node_data_type == 2'b01) begin
            treeval_mem_par = 0;
            treeval_mem_act = 1; // action field
            treeval_mem_rew = 0;
            treeval_mem_weight = 0;
        end
        else if (node_data_type == 2'b10) begin
            treeval_mem_par = 0;
            treeval_mem_act = 0;
            treeval_mem_rew = 1; // reward field
            treeval_mem_weight = 0;
        end
        else begin
            treeval_mem_par = 0;
            treeval_mem_act = 0;
            treeval_mem_rew = 0;
            treeval_mem_weight = 1; // weight field
        end
    end
endtask

// conf_data[61:0] = type[61:60] || val[59:0]
task UpdateConfigData;
    logic [1:0] conf_data_type;
    logic [59:0] conf_data_val;
    begin
        conf_data_type[1:0] = command_data[61:60];
        conf_data_val[59:0] = command_data[59:0];

        if (conf_data_type == 2'b00) begin
            treeval_conf_nodes = 1;
            treeval_conf_data = conf_data_val[MAX_CONFIG_WIDTH-1:0];
        end
    end
endtask

task GenerateInterrupt;
    begin
        // TODO
    end
endtask

endmodule