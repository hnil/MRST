#include "preprocess.h"
#include "make_edge_conformal.hpp"
#include <iostream>
void fix_edges_at_top(const struct processed_grid& grid,
                      std::vector<int>& nodes;
                      std::vector<int>& nodePos){
    for(int cell=0; cell < grid.number_of_cells; ++cell){
        // process a cells
        for(int dir = 1; dir < 4; ++dir){
            // process each vertical direction
            // find all oriented edges in each direction
            std::vector<std::array<int,2>> egdes;
            for(int hface = cell_facePos(cell); hface < cell_facePos(cell+1); ++hface){
                if(grid.cell_face[2*hface+1] == dir){
                    std::vector<std::array<int,2>> face_egdes;
                    int face = grid.cell_face[2*hface];
                    for(int nodePos = grid.face_ptr[face]; nodePos < grid.face_ptr[face+1]-1; ++nodePos){
                        std::array<int,2> new_edge ={grid.face_nodes[nodePos],grid.face_nodes[nodePos+1]};
                        face_edges.push_back( new_edge);
                    }
                    std::array<int,2> last_edge ={grid.face_nodes[grid.face_ptr[face+1]-1]],
                        grid.face_nodes[grid.face_ptr[face]];
                    face_edges.push_back( last_edge);
                    if(cell == grid.faceneighbors[2*face+ 0]){
                        // reverte edges
                        for(std::array<int,2>& edge; face_edges){
                            int tmp = edge[0];
                            face_nodes[face].push_back(tmp);// just fill face_nodes her should be same as in processed grid;
                            edge[0] = edge[1];
                            edge[1] = tmp;
                        }

                    }
                    edges.append(face_edges);

            }
            struct less_than_key {
                inline bool operator() (const std::array<int,2>& edge1,const std::array<int,2>& edge2){
                    std::array<int,2> sedge1 = edge1;
                    std::array<int,2> sedge2 = edge2;
                    std::sort(sedge1.begin(),sedge1.end());
                    std::sort(sedge2.begin(),sedge2.end());
                    if(sedge1[0]<sedge2<[0]){
                        return true;
                    }else if(sedge1[0]==sedge2<[0]){
                        if(sedge1[1]<sedge<[1]){
                            return true;
                        }else{
                            return false;
                        }
                    }else{
                        return false;
                    }
                    assert(false);
                }
            };
            struct oposite {
                inline bool operator() (const std::array<int,2>& edge1,const std::array<int,2>& edge2){
                    if((edge1[0] == edge2[1]) && (edge1[1] == edge2[0])){
                        return true;
                    }else{
                        return false;
                    }
                }
            };
            // sort so intenal edges is after each other
            std::sort(edges.begin(),edges.end(),less_than_key());
            // remove internal edges
            auto iter = edges.begin();
            auto iternext = iter;
            ++iternext;
            for(; iternext != edges.end(); ){
                if(oposite(*iter,*iternext)){
                    //remove oposite edges
                    iter=edges.erase(iter);
                    iter=edges.erase(iternext);
                    iternext = iter;
                    ++iternext;
                }else{
                    ++iter;
                    ++iternext;
                }
            }
            // now edges should only contain oriented outer edges
            std::vector<std::array<int,2>> sedges = edges;
            sedge.push_back(*edges.begin());
            edges.erase(edges.begin());
            while(edges.size()>0){
                struct next{
                    inline bool operator== (const std::array<int,2>& left,const std::array<int,2>& right){
                        return left[1] == right[0];
                    }
                };
                auto cedges = *sedges.end();
                auto next = std::find(edges.begin(), edges.end(), cedges, next());
                sedges.push_back(*next);
                edges.erase(next);
            }
            // now sedge should be orient orderd list of edges
            // find top/bottom edge to be considered
            std::array<int,2> bedge;
            for(int tb=5; tb<7; ++tb){


            struct pos{
                inline bool operator== (const std::array<int,2>& left,const int& right){
                    return left[0] == right;
                }
            };
            std::vector<int> newedge;
            auto ind2 = find(sedges.begin(),sedges.end(), bedge[0],pos());
            auto ind1 = find(sedges.begin(),sedges.end(), bedge[0], pos());
            int addnode = 0;
            if( (ind1 == (sedge.back()) && (ind2 == sedge.begin())){
                addnode = 0;
            }else if( ind2 < ind1){
                newedges.insert(newedges.end(),ind2,sedges.end());
                newedges.insert(newedges.end(),sedges.begin(),ind1);
                addnode = newedges.size() -2;
            }else{
                newedges.insert(newedges.end(), ind1, ind2+1);
                addnode = newedges.size() -2;
            }
                // ett possibly modified nodes
            std::vector<int> bfnodes = bface_nodes[bface];
            if( addnode > 0 ){
                if(changesign){
                    std::revert(newedges.begin(),newedges.end());
                }
                // iterator to start and end of new nodes
                auto iterstart = newedge.begin();
                ++iterstart;
                auto iterend = newedge.end();
                --iterend;
                auto node2 = std::find(bfnodes.begin(), bfnodes.end(), *(newedge.end()+1));
                auto node1 = std::find(bfnodes.begin(), bfnodes.end(), *(newedge.begin()));
                if(node1 == bfnodes.back() &&  node2 == bfnodes.begin()){
                    bfnodes.insert(bfnodes.end(),iterstart,iterend)
                }else if( node2 - node1 == 1){
                    bfnodes.insert(node1,iterstart, iterend);
                }else{
                    // nodes should al readdy be added
                    auto node_end = node2;
                    auto it1 = node1;
                    ++it1;
                    auto it2 = iterstart;
                    for(it1 != node_end){
                        assert(*it1 == *it2);
                        ++it1;++it2;
                    }
                    addnode = 0;
                }

            }
            face_nodes[bface] = bfnodes;
                }
        }
    }
}



void make_edge_conformal(struct processed_grid* grid){
    std::cout << "Fixing edge grid to be edge conformal" << std::endl;
    std::vector<int> nodes;
    std::vector<int> nodePos;
    fix_edges_at_top(grdecl, nodes, nodePos);
    return 0;
}
