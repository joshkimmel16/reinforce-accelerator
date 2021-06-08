// mock up of interface to AXI IP
// can send/receive P2P messages from other components in NoC

#ifndef AXI_FIFO_DUMMY_H
#define AXI_FIFO_DUMMY_H

// We assume these work!!
// Returns 0 if successful, else -1.
int send_msg(uint64_t msg) { return 0; }
int get_msg(uint64_t* msg) { return 0; }

// ACK signals
bool i_in_msg_ack();  // ack from inside that msg (top of in_fifo) received
bool o_out_msg_ack(); // ack from outside that msg (top of out_fifo) received
void i_out_msg_ack(); // ack to inside that that msg (placed at bottom of out_fifo) received
void o_in_msg_ack();  // ack to outside that msg (placed at bottom of in_fifo) received

// READY signals
bool i_out_msg_rdy(); // new msg from inside ready to be placed at the bottom of out_fifo
bool o_in_msg_rdy();  // new msg from outside ready to be placed at bottom of in_fifo
void i_in_msg_rdy();  // top of in_fifo ready to be consumed by inside
void o_out_msg_rdy(); // top of out_fifo ready to be consumed by outside

// DATA signals
void i_out_msg(char* msg);  // new msg from inside to be placed at bottom of out_fifo
void o_in_msg(char* msg);   // new msg from outside to be placed at bottom of in_fifo
char* i_in_msg();           // top of in_fifo
char* o_out_msg();          // top of out_fifo

#endif
