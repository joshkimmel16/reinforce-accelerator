# REINFORCE Accelerator

The goal of this document is to plan out the implementation of a hardware-based reinforcement learning system/agent that implements the REINFORCE training algorithm.

## High-Level Components

* __Environment__ => Component that is given a current state and action and compute the reward for that action and next state.
* __Trainer__ => Component that is given a policy and computes the next action to take.
* __Policy Generator__ => Component that is given a current state and computes a policy.

### Environment

We will implement this component in software that runs on a traditional CPU. The software will compute a reward and next state based on a pre-defined context (i.e., application) that we will decide on. For example, maybe something to do with robotics. We should definitely have a motivating explicit use case so that we have something real to implement.

#### Open Questions

* (1) What is our motivating application? How does that translate to states, actions, and a reward function?
* (2) What do we need to implement to talk to our accelerators? Probably some memory-mapped I/O?


### Trainer

This piece we will implement as a novel hardware accelerator based on the REINFORCE algorithm. This algorithm effectively performs backpropagation through a decision tree to compute the action with the highest expected reward based on the probability distribution provided by the Policy Generator. We will need to implement this in hardware and design a software interface to extract information from it.

#### Open Questions

* (1) How does this component know the structure of the tree that it backpropagates through? How many nodes? How are those nodes connected? What are the rewards associated with those nodes? Do these change over time or are they initialized once?
* (2) Based on the answers to the above, what would be considered "enough" storage to represent the general form of this computation? Max number of nodes/rewards? Max number of connections? Max number of probabilities from policy?

### Policy Generator

For our purposes, we will assume this is a deep neural network (DNN). In our system, we will assume that we have a DNN inference accelerator that we can treat as a blacx box as there has been plenty of good work on DNN inference acceleration (ex: DianNao). For our purposes, we will just implement a DNN emulator in hardware such that the interface exists to plug into the remainder of the system.

#### Open Questions

* (1) What does the interface look like? What are the inputs to the DNN? What are the outputs?
* (2) Should the outputs feed directly into the Trainer? Or should the environment act as an intermediary?


## References

* [DianNao](http://novel.ict.ac.cn/ychen/pdf/DianNao.pdf)
* [REINFORCE](https://medium.com/@thechrisyoon/deriving-policy-gradients-and-implementing-reinforce-f887949bd63)

