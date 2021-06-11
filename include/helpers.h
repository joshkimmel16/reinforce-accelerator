#include "node.h"
#include <string>
#include "json.hpp"
using json = nlohmann::json;

Node* create_subtree(json node);
void create_subtree_hw(json node, int parent_id, int num_nodes);
Node* generate(std::string json_path);
void generate_hw(std::string json_path);
float treeval(Node *root);
