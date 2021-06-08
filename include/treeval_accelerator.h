#ifndef TREEVAL_ACCELERATOR_H
#define TREEVAL_ACCELERATOR_H

// sets the number of nodes in the tree
// @num_nodes: specifies the number of nodes in the tree
// can be called multiple times while constructing a tree to dynamically change it
// returns: 0 on success, -1 on failure
int configure_nodes(uint64_t num_nodes);

// adds a node to the tree
// @node: node added to the tree, value in [0, 1024)
// @parent: parent of @node, value in [0, 1024)
// identifiers of @node and @parent in [0, 1024) because a node can have at most 1024 children
// returns: 0 on success, -1 on failure
int add_node(uint64_t node, uint64_t parent);

// updates the reward of a node
// @node: existing node updated in the tree
// @reward: the reward value of @node
// returns: 0 on success, -1 on failure
int set_reward(uint64_t node, uint64_t reward);

// updates the action of a node
// @node: existing node updated in the tree
// @maximize_node: true if the expected reward of @node should be maximized,
//                 false if the expected reward of @node should be minmized.
// @action: the action of @node, value in [0, 8)
// value of @action in [0, 8) because there are a maximum of 8 unique actions
// returns 0 on success, -1 on failure
int set_action(uint64_t node, bool maximize_node, uint64_t action);

// updates the weight of a node
// @node: existing node updated in the tree
// @weight: the weight value of @node
// returns 0 on success, -1 on failure
int set_weight(uint64_t node, uint64_t weight);

// launches the treeval computation
// returns 0 on success, -1 on failure
int start_computation();

// retrieves the result of the treeval computation when it is done
// @action: set to the optimal action to take at the root of the tree
// @reward: set to the expected reward of the treeval computation
// returns 0 on success, -1 on failure
int get_result(int* action, int* reward);

#endif
