#include "node.h"
#include <string>
#include "json.hpp"
using json = nlohmann::json;

Node* create_subtree(json node);
Node* generate(std::string json_path);
float treeval(Node *root);
