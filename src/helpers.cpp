#include "helpers.h"
#include <iostream>
Node* generate(){

}
int treeval(Node *root){
    if(root->children.empty()) {
        return root->val * root->weight;
    }
    int ev = 0;
    for (auto node : root->children) {
        ev += treeval(node);
    }
    return ev * root->weight;
}
