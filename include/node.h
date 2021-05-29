#ifndef NODE_H
#define NODE_H
#include <vector>

struct Node {
    int val;
    float p;
    std::vector<Node *> children;
    Node();
    Node(int val, float p);
};

#endif
