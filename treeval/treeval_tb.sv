// testbench for treeval

`timescale 1 ns / 100 ps

module treeval_tb;

localparam CLOCK = 10; // 100 MHz
localparam W_ADDR = 10;
localparam W_N_DATA = 12;
localparam W_C_DATA = 10;
localparam W_REWARD = 12;
localparam W_ACTION = 3;

localparam ACT_PLAY = 3'b001;
localparam ACT_NO_PLAY = 3'b000;

reg clk;
reg rst;

// inputs
reg mem_weight;
reg mem_par;
reg mem_rew;
reg mem_act;
reg [W_ADDR-1:0] mem_addr;
reg [W_N_DATA-1:0] mem_data;
reg conf_nodes;
reg [W_C_DATA-1:0] conf_data;

// outputs
wire exp_change;
wire [W_REWARD-1: 0] exp;
wire [W_ACTION-1:0] act;

treeval DUT (
    .clk(clk),
    .rst(rst),  
    .mem_weight(mem_weight),
    .mem_par(mem_par),
    .mem_rew(mem_rew),
    .mem_act(mem_act),
    .mem_addr(mem_addr),
    .mem_data(mem_data),
    .conf_nodes(conf_nodes),
    .conf_data(conf_data),
    .exp_change(exp_change),
    .exp(exp),
    .act(act)
);

integer i;
integer nErr; // number of errors
integer out;

always 
begin
    #(CLOCK/2) clk=~clk;
end

initial begin
    clk = 1;
    rst = 0;
    mem_weight = 0;
    mem_par = 0;
    mem_rew = 0;
    mem_act = 0;
    conf_nodes = 0;
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
    tskVerifyOutput(); // verify the output based on configured tree

    #(CLOCK) $display("%d ... finishing, number of errors = %d",
                     $stime, nErr);
    
    $finish;   // end of simulation
end

task tskConfNodes;
    begin
        conf_nodes = 1;
        conf_data = 10'b0000000111; // 7 nodes
        #(CLOCK);
        conf_nodes = 0;
        conf_data = 0;
    end
endtask

task tskTreeStruct;
    begin
        mem_par = 1;
        mem_addr = 10'b0000000001; // node 1
        mem_data = 12'b000000000000; // node 0 is parent
        #(CLOCK);
        mem_addr = 10'b0000000010; // node 2
        mem_data = 12'b000000000000; // node 0 is parent
        #(CLOCK);
        mem_addr = 10'b0000000011; // node 3
        mem_data = 12'b000000000000; // node 0 is parent
        #(CLOCK);
        mem_addr = 10'b0000000100; // node 4
        mem_data = 12'b000000000001; // node 1 is parent
        #(CLOCK);
        mem_addr = 10'b0000000101; // node 5
        mem_data = 12'b000000000001; // node 1 is parent
        #(CLOCK);
        mem_addr = 10'b0000000110; // node 6
        mem_data = 12'b000000000001; // node 1 is parent
        #(CLOCK);
        mem_par = 0;
        mem_addr = 10'b0000000000;
        mem_data = 12'b000000000000;
    end
endtask

task tskSetRewards;
    begin
        mem_rew = 1;
        mem_addr = 10'b0000000010; // node 2 = leaf
        mem_data = 12'b111111110110; // reward = -10 (2's complement)
        #(CLOCK);
        mem_addr = 10'b0000000011; // node 3 = leaf
        mem_data = 12'b000000000000; // reward = 0
        #(CLOCK);
        mem_addr = 10'b0000000100; // node 4 = leaf
        mem_data = 12'b000001100100; // reward = 100
        #(CLOCK);
        mem_addr = 10'b0000000101; // node 5 = leaf
        mem_data = 12'b111111001110; // reward = -50 (2's complement)
        #(CLOCK);
        mem_addr = 10'b0000000110; // node 6 = leaf
        mem_data = 12'b000000001010; // reward = 10
        #(CLOCK);
        mem_rew = 0;
        mem_addr = 10'b0000000000;
        mem_data = 12'b000000000000;
    end
endtask


task tskSetActions;
    begin
        mem_act = 1;
        mem_addr = 10'b0000000001; // node 1
        mem_data = ACT_PLAY; // action = play
        #(CLOCK);
        mem_addr = 10'b0000000010; // node 2
        mem_data = ACT_PLAY; // action = play
        #(CLOCK);
        mem_addr = 10'b0000000011; // node 3
        mem_data = ACT_NO_PLAY; // action = no play
        #(CLOCK);
        mem_addr = 10'b0000000100; // node 4
        mem_data = ACT_PLAY; // action = play
        #(CLOCK);
        mem_addr = 10'b0000000101; // node 5
        mem_data = ACT_PLAY; // action = play
        #(CLOCK);
        mem_addr = 10'b0000000110; // node 6
        mem_data = ACT_NO_PLAY; // action = no play
        #(CLOCK);
        mem_act = 0;
        mem_addr = 10'b0000000000;
        mem_data = 12'b000000000000;
    end
endtask

task tskSetTreeWeights;
    begin
        mem_weight = 1;
        mem_addr = 10'b0000000001; // node 1
        mem_data = 12'b000001000000; // weight = .5 = 64
        #(CLOCK);
        mem_addr = 10'b0000000010; // node 2
        mem_data = 12'b000001000000; // weight = .5 = 64
        #(CLOCK);
        mem_addr = 10'b0000000011; // node 3
        mem_data = 12'b000001100100; // weight = 100
        #(CLOCK);
        mem_addr = 10'b0000000100; // node 4
        mem_data = 12'b000001000000; // weight = .5 = 64
        #(CLOCK);
        mem_addr = 10'b0000000101; // node 5
        mem_data = 12'b000001000000; // weight = .5 = 64
        #(CLOCK);
        mem_addr = 10'b0000000110; // node 6
        mem_data = 12'b000001111111; // weight = 1 = 127 TODO: is this good enough?
        #(CLOCK);
        mem_weight = 0;
        mem_addr = 10'b0000000000;
        mem_data = 12'b000000000000;
    end
endtask

task tskVerifyOutput;
    begin
       rst = 1;
       #(CLOCK);
       rst = 0;
       #(10*CLOCK); // TODO: how long should this be?? (1 + 3 + 1)*2
       if (~(exp_change == 1 && act == ACT_PLAY)) begin
           logError("Simple", "output_check");
       end
       // TODO: check exp?
    end
endtask

task logError;
    input reg[30*8:0] testName;
    input reg[100*8:0] msg;
    begin
        $display ("%d ... Failed test %s: %s", 
                    $stime, testName, msg);
        $fwrite (out, "%d ... Failed test %s: %s", 
                    $stime, testName, msg);
        nErr = nErr + 1;
    end
endtask

endmodule