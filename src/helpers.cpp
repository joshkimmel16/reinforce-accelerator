#include "helpers.h"
#include "treeval_accelerator.h"
#include <algorithm>
#include <fstream>
#include <chrono>
#include <iostream>

Node* create_subtree(json node)
{
  Node* pNode = new Node(node["id"], node["val"], node["weight"]);
  for (auto child: node["children"])
  {
    pNode->children.push_back(create_subtree(child["node"]));
  }
  return pNode;
}

Node* generate(std::string json_path)
{
  auto read_start = std::chrono::high_resolution_clock::now();
  std::ifstream i(json_path.c_str());
  json j;
  i >> j;
  auto read = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - read_start);
  auto generate_start = std::chrono::high_resolution_clock::now();
  Node* root = create_subtree(j["node"]);
  auto generate = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - generate_start);
  std::cout<< "Reading json file: " << read.count() << std::endl;
  std::cout<< "Building Tree: " << generate.count() << std::endl;
  return root;
}

void create_subtree_hw(json node, int parent_id, int num_nodes) {
  configure_nodes(num_nodes);
  add_node(node["id"], parent_id);
  set_reward(node["id"], node["val"]);
  set_action(node["id"], true, node["id"]);
  set_weight(node["id"], node["weight"]);
  for (auto child: node["children"])
  {
    num_nodes += 1;
    create_subtree_hw(child["node"], node["id"], num_nodes);
  }
} 

void generate_hw(std::string json_path) {
  auto read_start = std::chrono::high_resolution_clock::now();
  std::ifstream i(json_path.c_str());
  json j;
  i >> j;
  auto read = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - read_start);
  auto generate_start = std::chrono::high_resolution_clock::now();
  create_subtree_hw(j["node"], 0, 1);
  auto generate = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - generate_start);
  std::cout<< "Reading json file: " << read.count() << std::endl;
  std::cout<< "Building Tree: " << generate.count() << std::endl;
}

float treeval(Node *root){
    if(root->children.empty()) {
        return root->val * root->weight;
    }
    for (auto node : root->children) {
        root->actionEV[node->actionId] += treeval(node);
    }
    /*std::map<int, float>::iterator ev = std::max_element(root->actionEV.begin(), root->actionEV.end(),
		    [](const std::pair<int, float>& p1, const std::pair<int, float>& p2) {
		    return p1.second < p2.second; });*/
    float ev = 0;
    for (std::map<int, float>::iterator it = root->actionEV.begin(); it != root->actionEV.end(); it++) {
        if (ev < it->second) {
            ev = it->second;
	}
    }
    return ev * root->weight;
}
