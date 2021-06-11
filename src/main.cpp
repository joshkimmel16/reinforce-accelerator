#include "node.h"
#include "helpers.h"
#include <iostream>
#include <chrono>

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "Please provide path to game tree json file" << std::endl;
	exit(1);
    }
    std::cout<< "---------Software---------" << std::endl;
    Node* root = generate(argv[1]);
    auto treeval_start = std::chrono::high_resolution_clock::now();
    float maxEV = treeval(root);
    auto treeval_duration = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - treeval_start);
    std::cout << "Tree Evaluation Time: " << treeval_duration.count() << std::endl;
    std::cout << "Maximum Expected Value: " << maxEV << std::endl;
    std::cout<< "--------------------------" << std::endl;

    std::cout<< "---------Hardware---------" << std::endl;
    generate_hw(argv[1]);
    std::cout<< "--------------------------" << std::endl;
}
