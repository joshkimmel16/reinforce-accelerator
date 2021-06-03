// define local parameters
localparam W_ADDR = 10; // based on MAX_NUM_NODES
localparam MAX_DATA_WIDTH = 10; // maximum possible node data width based on above (weight, address, reward, action)
localparam MAX_CONFIG_WIDTH = 10; // maximum possible config data width based on above (# nodes)
localparam W_ACTION = 3; // limit the # of distinct actions that can be taken (for now...)
localparam W_REWARD = 10; // 10 remaining bits for reward
localparam W_STRAT = 1; // 1 bit used to determine the strategy (max vs. min)

// define states
localparam W_STATES = 2;
localparam IDLE = 0;
localparam PROCESS_MSG = 1;
localparam WAIT_COMP = 2;
localparam WRITE_RESULT = 3;

// define command types
localparam W_MSG = 64;
localparam W_CMD = 2;
localparam W_CMD_DATA = W_MSG - W_CMD;

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
localparam NODE_CMD_REWARD = 1;
localparam NODE_CMD_ACTION = 2;
localparam NODE_CMD_WEIGHT = 3;

// treeval_controller drives the treeval execution module.
// software commands are written to a 64-bit command register.
// after treeval execution is complete, treeval_controller will generate an interrupt.
module treeval_controller (
    input logic clk, // clock
    input logic rst, // reset
    
    // ACK's
    input logic out_msg_ack, // ack from outside that msg was received
    output logic in_msg_ack, // ack to outside that msg was received

    // RDY'S
    input logic in_msg_rdy, // a new msg from outside is ready
    output logic out_msg_rdy, // a new msg is ready to be consumed by the outside

    // DATA
    input logic [W_MSG-1:0] in_msg, // new msg from outside
    output logic [W_MSG-1:0] out_msg // new msg to be consumed by outside
);

// internal signals for AXI ("inside" direction)
logic i_in_msg_ack;
logic i_out_msg_ack;
logic i_in_msg_rdy;
logic i_out_msg_rdy;
logic i_in_msg;
logic i_out_msg;

logic [W_MSG-1:0] curr_msg; // hold current message to process

logic [W_STATES-1:0] current_state; // current state determines what must happen in the given cycle
logic [W_STATES-1:0] next_state; // next state determines what current_state changes to

// elements for internal treeval
logic treeval_rst;
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

// instantiate AXI instance to interface w/ outside world
axi_fifo_dummy axi (
    .clk(clk),
    .rst(rst),  
    .i_in_msg_ack(i_in_msg_ack),
    .o_out_msg_ack(out_msg_ack),
    .i_out_msg_ack(i_out_msg_ack),
    .o_in_msg_ack(in_msg_ack),
    .i_out_msg_rdy(i_out_msg_rdy),
    .o_in_msg_rdy(in_msg_rdy),
    .i_in_msg_rdy(i_in_msg_rdy),
    .o_out_msg_rdy(out_msg_rdy),
    .i_out_msg(i_out_msg),
    .o_in_msg(in_msg),
    .i_in_msg(i_in_msg),
    .o_out_msg(out_msg)
);

// instantiate execution unit
treeval execution_unit (
    .clk(clk),
    .rst(treeval_rst),
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

// initialize any values that need to be initialized
initial begin
    i_in_msg_ack = 0;
    i_out_msg_rdy = 0;
    
    treeval_mem_weight = 0;
    treeval_mem_par = 0;
    treeval_mem_rew = 0;
    treeval_mem_act = 0;
    treeval_conf_nodes = 0;
    
    current_state = IDLE;
    next_state = IDLE;

end

// capture incoming messages from AXI
// only ack new message if we are IDLE
always @(posedge clk) begin
    if (i_in_msg_rdy && ~i_in_msg_ack && current_state == IDLE) begin
        curr_msg <= i_in_msg;
        i_in_msg_ack <= 1;
    end
    else begin
        i_in_msg_ack <= 0;
    end
end

// handle ack from AXI for outbound
always @(posedge clk) begin
    if (i_out_msg_ack) begin
        i_out_msg_rdy <= 0;
    end
end

// logic to control the update of current_state
always @(posedge clk) begin
    if (rst) begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

// logic to control the value of next_state
always_comb begin
    if (rst) begin
        next_state = IDLE;
    end
    else if (current_state == IDLE) begin
        if (i_in_msg_ack) begin // new message to process
            next_state = PROCESS_MSG
        end
        else begin
            next_state = IDLE;
        end
    end
    else if (current_state == PROCESS_MSG) begin
        // check curr_msg
        case (curr_msg[W_MSG-1:W_MSG-1-W_COMMAND]) begin
            CMD_RUN_COMPUTATION: next_state = START_COMP;
            default: next_state = IDLE;
        endcase
    end
    else if (current_state == WAIT_COMP) begin
        if (treeval_exp_change) begin // if computation is done
            next_state = WRITE_RESULT;
        end
        else begin
            next_state = WAIT_COMP;
        end
    end
    else begin // WRITE_RESULT
        next_state = IDLE;
    end
end

// logic to handle state level processing
always @(posedge clk) begin
    // TODO: need else clause?
    if (current_state == PROCESS_MSG) begin // execute command
        // TODO: default case necessary?
        case (curr_msg[W_MSG-1:W_MSG-1-W_COMMAND]) begin
            CMD_RUN_COMPUTATION: StartComputation(curr_msg[W_MSG-1-W_COMMAND:0]); 
            CMD_SET_CONFIG_DATA: SetConfigData(curr_msg[W_MSG-1-W_COMMAND:0]);
            CMD_SET_NODE_DATA: SetNodeData(curr_msg[W_MSG-1-W_COMMAND:0]);
        endcase
    end
    else if (current_state == WRITE_RESULT) begin // generate interrupt
        // TODO: concatenate some 0's in MSb's to get to message length
        WriteOutMsg({treeval_act, treeval_exp});
    end
end

// de-assert any signal that should only be asserted for 1 cycle in treeval
always @(posedge clk) begin
    if (treeval_rst) begin
        treeval_rst <= 0;
    end
    if (treeval_conf_nodes) begin
        treeval_conf_nodes <= 0;
    end
    if (treeval_mem_par) begin
        treeval_mem_par <= 0;
    end
    if (treeval_mem_rew) begin
        treeval_mem_rew <= 0;
    end
    if (treeval_mem_act) begin
        treeval_mem_act <= 0;
    end
    if (treeval_mem_weight) begin
        treeval_mem_weight <= 0;
    end
end

// to start a computation, simply reset the execution unit
task StartComputation;
    input [W_CMD_DATA-1:0] cmd;
    begin
        treeval_rst <= 1;
    end
endtask

// pass a config value to the execution unit
task SetConfigData;
    input [W_CMD_DATA-1:0] cmd;
    begin
        // TODO: default needed?
        case (cmd[W_CMD_DATA-1:W_MSG-1-W_COMMAND]) begin
            CFG_CMD_NODES: begin
                treeval_conf_nodes <= 1;
                treeval_conf_data <= cmd[MAX_CONFIG_WIDTH-1:0];
            end
        endcase
    end
endtask

// pass a node value to the execution unit
task SetNodeData;
    input [W_CMD_DATA-1:0] cmd;
    begin
        // TODO: default needed?
        case (cmd[W_CMD_DATA-1:W_MSG-1-W_COMMAND]) begin
            NODE_CMD_PARENT: begin
                treeval_mem_par <= 1;
                treeval_mem_addr <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
                treeval_mem_data <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
            end
            NODE_CMD_REWARD: begin
                treeval_mem_rew <= 1;
                treeval_mem_addr <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
                treeval_mem_data <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
            end
            NODE_CMD_ACTION: begin
                treeval_mem_act <= 1;
                treeval_mem_addr <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
                treeval_mem_data <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
            end
            NODE_CMD_WEIGHT: begin
                treeval_mem_weight <= 1;
                treeval_mem_addr <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
                treeval_mem_data <= cmd[MAX_DATA_WIDTH-1:0]; // TODO: fix
            end
        endcase
    end
endtask

// push outbound message to AXI
task WriteOutMsg;
    input logic [W_MSG-1:0] out_msg;
    begin
        i_out_msg_rdy <= 1;
        i_out_msg <= out_msg;
    end
endtask


/////////////////////////////////////////////////////////////////////////////

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



endmodule