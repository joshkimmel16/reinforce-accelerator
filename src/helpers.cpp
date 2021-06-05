#include "helpers.h"
#include <algorithm>
#include <fstream>

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
  std::ifstream i(json_path.c_str());
  json j;
  i >> j;
  return create_subtree(j["node"]);
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
