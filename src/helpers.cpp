#include "helpers.h"
#include <iostream>
Node* generate(){

}

float treeval(Node *root){
    if(root->children.empty()) {
        return root->val * root->p;
    }
    float ev = 0;
    for (auto node : root->children) {
        ev += treeval(node);
    }
    return ev * root->p;
}
