#ifndef NODE_H
#define NODE_H
#include <vector>

struct Node {
    int val;
    int weight;
    std::vector<Node *> children;
    Node();
    Node(int val, int weight);
};

#endif
