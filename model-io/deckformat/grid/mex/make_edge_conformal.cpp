#include "preprocess.h"
#include "make_edge_conformal.hpp"
#include <iostream>
void fix_edges_at_top(const struct grdecl& grdecl,
                      std::vector<int>& nodes;
                      std::vector<int>& nodePos){
}



void make_edge_conformal(struct grdecl* grdecl){
    std::cout << "Fixing edge grid to be edge conformal" << std::endl;
    std::vector<int> nodes;
    std::vector<int> nodePos;
    fix_edges_at_top(grdecl, nodes, nodePos);
    return 0;
}
