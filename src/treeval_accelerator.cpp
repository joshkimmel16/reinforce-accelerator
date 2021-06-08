#include <cstdint>
#include <cmath>
#include "axi_fifo_dummy.h"
#include "treeval_accelerator.h"

// command types, {CMD, 62'b(DATA)}
#define CMD_RUN_COMPUTATION     0
#define CMD_SET_NODE_DATA       1
#define CMD_SET_CONFIG_DATA     2

#define MASK_CMD_SHIFT          62
#define MASK_CMD                0xC000000000000000 // {2'b11, 62'b0}

// commands for config data, {2'b(CMD), 2'b(CFG_CMD), 60'b(DATA)}
#define CFG_CMD_NODES           0

#define MASK_CFG_CMD_SHIFT      60
#define MASK_CFG_CMD            0x3000000000000000 // {2'b00, 2'b11, 60'b00}

#define MASK_CONFIG_DATA_SHIFT  0
#define MASK_CONFIG_DATA        0x0FFFFFFFFFFFFFFF // {2'b00, 2'b00, 60'b(1..11)}


// commands for node data, {2'bCMD, 2'b(NODE_ID), 2'b(NODE_CMD), 50'b(DATA)}
#define MASK_NODE_ID_SHIFT      52
#define MASK_NODE_ID            0x3FF0000000000000 // {2'b00, 10'b(1..11), 2'b00, 50'b(0..00)}

#define NODE_CMD_PARENT         0
#define NODE_CMD_ACTION         1
#define NODE_CMD_REWARD         2
#define NODE_CMD_WEIGHT         3
#define MASK_NODE_CMD_SHIFT     50
#define MASK_NODE_CMD           0x000C000000000000 // {2'b00, 10'b(0..00), 2'b11, 50'b(0..00)}

#define MASK_NODE_DATA_SHIFT    0
#define MASK_NODE_DATA          0x0003FFFFFFFFFFFF // {2'b00, 10'b(0..00), 2'b00, 50'b(1..11)}

#define MASK_NODE_STRAT_SHIFT   3
#define MASK_NODE_STRAT         0x0000000000000008 // {2'b00, 10'b(0..00), 2'b00, 46'b(0..00), 1'b1, 3'b000}

#define MASK_NODE_ACTION_SHIFT  0
#define MASK_NODE_ACTION        0x0000000000000007 // {2'b00, 10'b(0..00), 2'b00, 46'b(0..00), 1'b0, 3'b111}

#define MASK_OUTPUT_ACTION      0x0000000000001C00 // {51'b0, 3'b(ACTION), 10'b(REWARD)}
#define MASK_OUTPUT_REWARD      0x00000000000003FF // {51'b0, 3'b(ACTION), 10'b(REWARD)}

// specifies the number of nodes in the tree
// can call this multiple times while constructing a tree to dynamically change
// assumes num_nodes >= 0
// returns 0 on success, -1 on failure
int configure_nodes(uint64_t num_nodes) {
  uint64_t msg;

  // msg = {CMD_SET_CONFIG_DATA, CFG_CMD_NODES, num_nodes}
  msg = (CMD_SET_CONFIG_DATA << MASK_CMD_SHIFT) & MASK_CMD;
  msg |= (CFG_CMD_NODES << MASK_CFG_CMD_SHIFT) & MASK_CFG_CMD;
  msg |= (num_nodes << MASK_CONFIG_DATA_SHIFT) & MASK_CONFIG_DATA;

  return send_msg(msg);
}

// adds a node to the tree
// assumes 0 <= node_identifier < 1024, since each node can have at most 1024 children
// returns 0 on success, -1 on failure
int add_node(uint64_t node, uint64_t parent) {
  uint64_t msg;

  // msg = {CMD_SET_NODE_DATA, node, NODE_CMD_PARENT, parent}
  msg = (CMD_SET_NODE_DATA << MASK_CMD_SHIFT) & MASK_CMD;
  msg |= (node << MASK_NODE_ID_SHIFT) & MASK_NODE_ID;
  msg |= (NODE_CMD_PARENT << MASK_NODE_CMD_SHIFT) & MASK_NODE_CMD;
  msg |= (parent << MASK_NODE_DATA_SHIFT) & MASK_NODE_DATA;

  return send_msg(msg);
}

// returns 0 on success, -1 on failure
int set_reward(uint64_t node, uint64_t reward) {
  uint64_t msg;

  // msg = {CMD_SET_NODE_DATA, node, NODE_CMD_REWARD, reward}
  msg = (CMD_SET_NODE_DATA << MASK_CMD_SHIFT) & MASK_CMD;
  msg |= (node << MASK_NODE_ID_SHIFT) & MASK_NODE_ID;
  msg |= (NODE_CMD_REWARD << MASK_NODE_CMD_SHIFT) & MASK_NODE_CMD;
  msg |= (reward << MASK_NODE_DATA_SHIFT) & MASK_NODE_DATA;

  return send_msg(msg);
}

// returns 0 on success, -1 on failure
int set_action(uint64_t node, bool maximize_node, uint64_t action) {
  uint64_t msg;

  // msg = {CMD_SET_NODE_DATA, node, NODE_CMD_ACTION, node_strat, action}
  msg = (CMD_SET_NODE_DATA << MASK_CMD_SHIFT) & MASK_CMD;
  msg |= (node << MASK_NODE_ID_SHIFT) & MASK_NODE_ID;
  msg |= (maximize_node ? (1 << MASK_NODE_STRAT_SHIFT) : 0) & MASK_NODE_STRAT;
  msg |= (action << MASK_NODE_DATA_SHIFT) & MASK_NODE_DATA;

  return send_msg(msg);
}

// returns 0 on success, -1 on failure
int set_weight(uint64_t node, uint64_t weight) {
  uint64_t msg;

  // msg = {CMD_SET_NODE_DATA, node, NODE_CMD_WEIGHT, weight}
  msg = (CMD_SET_NODE_DATA << MASK_CMD_SHIFT) & MASK_CMD;
  msg |= (node << MASK_NODE_ID_SHIFT) & MASK_NODE_ID;
  msg |= (NODE_CMD_WEIGHT << MASK_NODE_CMD_SHIFT) & MASK_NODE_CMD;
  msg |= (weight << MASK_NODE_DATA_SHIFT) & MASK_NODE_DATA;

  return send_msg(msg);
}

// returns 0 on success, -1 on failure
int start_computation() {
  uint64_t msg = (CMD_RUN_COMPUTATION << MASK_CMD_SHIFT) & MASK_CMD;

  return send_msg(msg);
}

// returns 0 on success, -1 on failure
int get_result(int* action, int* reward) {
  uint64_t msg;
  int status = get_msg(&msg);

  *action = msg & MASK_OUTPUT_ACTION;
  *reward = msg & MASK_OUTPUT_REWARD;

  return status;
}
