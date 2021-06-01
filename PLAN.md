# REINFORCE Accelerator

The goal of this document is to plan out the implementation of a hardware-based reinforcement learning system/agent that implements plan based learning.

## High-Level Components

* __Controller__ => Component that takes executes an action, computes the next state, and determines the reward associated with that action.
* __Planner__ => Component that is given a policy and computes the next action to take.
* __Trainer__ => Component that is given a policy and computes the next action to take.
* __Policy Generator__ => Component that is given a current state and computes a policy.

### Controller

This component will be implemented in software running on a traditional CPU. This is because the reward function and next state computation can be arbitrarily complex (ex: depends on sensing of the physical environment). In that sense, we are defining more of an API that wraps specific functional computations (detailed below):

#### API Method: Take Action

This method is given the current state of the system and an action to take and takes it. For example, place an X in the top left square in Tic-Tac-Toe.

#### API Method: Compute Next State

This method is given the current state of the system and the result of the action and determines the next state. For example, capture the opponent's next move in Tic-Tac-Toe and update the board.

This method also involves potentially updating the planner with a new tree structure. Also passing the new state to the inferrer.

#### API Method: Compute Reward

This method evaluates the prior state transition and determines the actual reward associated with the prior action (if possible). For example, if the prior move in Tic-Tac-Toe resulted in the opponent having a winning move, the reward computed might be -Infinity.

This method also involves potentially passing the new label (reward-action-state) to the trainer.

#### Controller Communication Interface

As there are other hardware modules in the system, the controller must have a mechanism to communicate with them. This communication can include:
* Updating the planner with a new tree structure/weight-reward distribution.
* Updating the inferrer with a new state for inference.
* Updating the trainer with a new label (state-action-reward tuple).

We will likely use something like AXI at the physical level to facilitate communication via memory-mapped registers in the target components.

#### Open Questions

* (1) What is our motivating application? How does that translate to states, actions, and a reward function?
* (2) How are we going to test this implementation? Doubt we will have time to put this all together on an FPGA (maybe Microblaze?).

### Planner

This piece we will implement as a novel hardware accelerator. This module effectively performs backpropagation through a decision tree to compute the action with the highest expected reward based on the probability distribution provided by the Policy Generator. We will need to implement this in hardware and design a software interface to extract information from it.

The interface will be in the form of a controller. This controller implements one side of the AXI communication. The software should be able to send commands. The command format will be as follows:
value<sub>63-0</sub> =  command<sub>1-0</sub> || data<sub>61-0</sub>

The controller will also need to generate an interrupt when it is done running the computation. This allows for the software side to read the result (which will be placed in a memory-mapped register).

#### Commands

The planner will support the following commands:
* 00: Run computation.
* 01: Set node data.
* 10: Set config data.

#### Data Associated with Commands

Running the computation does not require any subsequent data, so the data field can be treated as if it were all x.

Setting the data of a node requires the following data format:
data<sub>61-0</sub> = address<sub>9-0</sub> || type<sub>1-0</sub> || val<sub>49-0</sub>

Setting config data requires the following data format:
data<sub>61-0</sub> = type<sub>1-0</sub> || val<sub>59-0</sub>

##### Types and Values for Node Data

We support the following types for node data:
* 00: Parent address.
* 01: Action.
* 10: Reward.
* 11: Weight.

The controller will parse the LSb's of the val field appropriately to extract the desired value based on type.

##### Types and Values for Config Data

We support the following types for config data:
* 00: Number of nodes.

The controller will parse the LSb's of the val field appropriately to extract the desired value based on type.

#### Open Questions

* (1) Do we want to support larger transfers so there aren't as many commands necessary?
* (2) Module has a fixed max number of actions and nodes. Multiple copies allows for # of nodes to scale arbitrarily but doesn't solve the action scalability problem. 

### Inferrer (Policy Generator)

For our purposes, we will assume this is a deep neural network (DNN). In our system, we will assume that we have a DNN inference accelerator that we can treat as a blacx box as there has been plenty of good work on DNN inference acceleration (ex: DianNao). For our purposes, we will just implement a DNN emulator in hardware such that the interface exists to plug into the remainder of the system.

The interface/controller needs to:
* Accept a new state (and tree structure?).
* Return reward-weight probability distribution.

In addition, periodically, the inferrer must be updated with new weights based on the results of the trainer. This is also done by the software.

#### Open Questions

* (1) How much of this do we actually want to implement?

### Trainer (Inference Updates)

For our purposes, we will assume this is a deep neural network (DNN). In our system, we will assume that we have a DNN training accelerator that we can treat as a blacx box as there has been plenty of good work on DNN inference acceleration (ex: TODO). For our purposes, we will just implement a DNN emulator in hardware such that the interface exists to plug into the remainder of the system.

The interface/controller needs to:
* Accept a new label (datapoint).
* Return a set of weights for the inferrer.

#### Open Questions

* (1) How much of this do we actually want to implement?

## References

* [DianNao](http://novel.ict.ac.cn/ychen/pdf/DianNao.pdf)
* [REINFORCE](https://medium.com/@thechrisyoon/deriving-policy-gradients-and-implementing-reinforce-f887949bd63)
* [AXI](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface)

