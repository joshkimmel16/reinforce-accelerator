#include "node.h"
#include "helpers.h"
#include <iostream>
#include <chrono>

int main(int argc, char* argv[]) {
    // Generate Tree

    auto treegen_start = std::chrono::high_resolution_clock::now();
    /*
    Node node_0 = Node();
    Node node_1 = Node(0, 0, 0.5);
    Node node_2 = Node(0, -10, 0.5);
    Node node_3 = Node(1, 0, 1);
    Node node_4 = Node(0, 100, 0.5);
    Node node_5 = Node(0, -50, 0.5);
    Node node_6 = Node(1, 10, 1);
    node_0.children.push_back(&node_1);
    node_0.children.push_back(&node_2);
    node_0.children.push_back(&node_3);
    node_1.children.push_back(&node_4);
    node_1.children.push_back(&node_5);
    node_1.children.push_back(&node_6);
    */
    Node* root = generate("../src/bet.json");

    auto treeval_start = std::chrono::high_resolution_clock::now();
    float maxEV = treeval(root);
    auto stop = std::chrono::high_resolution_clock::now();
    auto treegen_duration = std::chrono::duration_cast<std::chrono::nanoseconds>(stop - treegen_start);
    auto treeval_duration = std::chrono::duration_cast<std::chrono::nanoseconds>(stop - treeval_start);
    std::cout << "Time with Tree Generation: " << treegen_duration.count() << std::endl;
    std::cout << "Time with Tree Evaluation: " << treeval_duration.count() << std::endl;
    std::cout << "Maximum Expected Value: " << maxEV << std::endl;
}
