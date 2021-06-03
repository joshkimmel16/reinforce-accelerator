#ifndef NODE_H
#define NODE_H
#include <vector>
#include <map>

struct Node {
    int val;
    float weight;
    int actionId;
    std::vector<Node *> children;
    std::map<int, float> actionEV;
    Node();
    Node(int id, int val, float weight);
};

#endif
