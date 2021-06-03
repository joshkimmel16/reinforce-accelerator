#include "node.h"

Node::Node() : actionId(0), val(0), weight(1) {
    for(int i = 0; i < 8; i++) {
        actionEV.insert({i, 0});
    }
}

Node::Node(int id, int val, float weight) : actionId(id), val(val), weight(weight) {
    for(int i = 0; i < 8; i++) {
        actionEV.insert({i, 0});
    }
}
