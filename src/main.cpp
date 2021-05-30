#include "node.h"
#include "helpers.h"
#include <iostream>
#include <chrono>

int main(int argc, char* argv[]) {
    // Generate Tree
    Node node_0 = Node();
    Node node_1 = Node(0, 64);
    Node node_2 = Node(-10, 64);
    Node node_3 = Node(0, 128);
    Node node_4 = Node(100, 64);
    Node node_5 = Node(-50, 64);
    Node node_6 = Node(10, 128);
    node_0.children.push_back(&node_1);
    node_0.children.push_back(&node_2);
    node_0.children.push_back(&node_3);
    node_1.children.push_back(&node_4);
    node_1.children.push_back(&node_5);
    node_1.children.push_back(&node_6);

    //Node *root = generate();
    
    // Time the ru
    auto start = std::chrono::high_resolution_clock::now();
    int a = treeval(&node_0);
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(stop - start);
    std::cout << duration.count() << std::endl;
}    
