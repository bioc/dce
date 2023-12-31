#' Create graph from dataframe
#' @param df_graph Dataframe with source and target columns
#' @param edge_weight Edge weight (function)
#' @noRd
create_graph_from_dataframe <- function(
    df_graph,
    edge_weight = function() runif(1, 0.5, 2)
) {
    g <- tidygraph::as_tbl_graph(df_graph)
    ig <- igraph::as.igraph(g)
    graph <- igraph::igraph.to.graphNEL(ig)

    w <- graph@edgeData@data
    for (i in seq_len(length(w))) {
        w[[i]]$weight <- edge_weight()
    }
    graph@edgeData@data <- w

    return(graph)
}


#' @noRd
graph_union_two <- function(graph1, graph2) {
    # create union
    graph_m <- igraph::union(
        igraph::igraph.from.graphNEL(graph1),
        igraph::igraph.from.graphNEL(graph2)
    )

    # merge edge weight attributes (if needed)
    if (is.null(igraph::get.edge.attribute(graph_m, "weight"))) {
        attr1 <- igraph::get.edge.attribute(graph_m, "weight_1")
        attr2 <- igraph::get.edge.attribute(graph_m, "weight_2")
        tmp <- igraph::set.edge.attribute(
            graph_m, "weight",
            value = ifelse(is.na(attr1), attr2, attr1)
        )

        # remove superfluous weight attributes
        # (may cause errors on later conversions)
        tmp <- igraph::remove.edge.attribute(tmp, "weight_1")
        tmp <- igraph::remove.edge.attribute(tmp, "weight_2")
    } else {
        tmp <- graph_m
    }

    # return result
    gn <- igraph::igraph.to.graphNEL(tmp)
    return(gn)
}


#' Graph union
#'
#' Create union of multiple graphs
#' @param graph_list List of graphs
#' @return graph union
#' @export
#' @examples
#' dag <- create_random_DAG(30, 0.2)
#' dag2 <- create_random_DAG(30, 0.2)
#' graph_union(list(g1=dag,g2=dag2))
graph_union <- function(graph_list) {
    Reduce(graph_union_two, graph_list)
}

#' Remove non-gene nodes from pathway and reconnect nodes
#' @param graph Biological pathway
#' @export
#' @return graph with only genes as nodes
#' @import logger
#' @examples
#' dag <- create_random_DAG(30, 0.2)
#' propagate_gene_edges(dag)
propagate_gene_edges <- function(graph) {
    # propagate edges
    ig <- igraph::igraph.from.graphNEL(graph)
    vertex_names <- igraph::vertex_attr(ig, "name")

    for (source_idx in igraph::V(ig)) {
        for (target_idx in igraph::neighbors(ig, source_idx, mode = "out")) {
            target <- vertex_names[target_idx]

            if (substr(target, start = 0, stop = 3) != "hsa") {
                # source is not connected to gene

                for (bridge_idx in igraph::neighbors(
                    ig, target_idx, mode = "out"
                )) {
                    bridge <- vertex_names[bridge_idx]

                    if (substr(bridge, start = 0, stop = 3) == "hsa") {
                        if (!igraph::are.connected(
                            ig, source_idx, bridge_idx
                        )) {
                            ig <- igraph::add.edges(
                                ig, c(source_idx, bridge_idx),
                                weight = 1
                            )
                        }
                    } else {
                        source <- vertex_names[source_idx]  # nolint
                        logger::log_warn(paste(
                            "{bridge} is not a valid extension",
                            "for edge {source}->{target}"
                        ))
                    }
                }
            }
        }
    }

    graph_prop <- igraph::igraph.to.graphNEL(ig)

    # remove non-gene nodes
    hsa_nodes <- Filter(
        function(x) substr(x, 0, 3) == "hsa",
        graph::nodes(graph_prop)
    )
    graph_filter <- graph::subGraph(hsa_nodes, graph_prop)

    return(graph_filter)
}

#' Graph to data frame
#'
#' Convert graph object to dataframe with source and target columns
#' @param graph Network
#' @export
#' @importFrom dplyr rename
#' @importFrom rlang .data
#' @return data frame
#' @examples
#' dag <- create_random_DAG(30, 0.2)
#' graph2df(dag)
graph2df <- function(graph) {
    graph %>%
        igraph::igraph.from.graphNEL() %>%  # nolint
        igraph::get.edgelist() %>%  # nolint
        as.data.frame() %>%
        dplyr::rename(source = .data$V1, sink = .data$V2)
}

#' Topological ordering
#'
#' Order rows/columns of a adjacency matrix topologically
#' @param adja_mat Adjacency matrix of network
#' @param alt Use igraph implementation
#' @export
#' @return topologically ordered matrix
#' @examples
#' adj <- matrix(c(0,1,0,0,0,1,0,0,0),3,3)
#' topologically_ordering(adj)
topologically_ordering <- function(adja_mat, alt = FALSE) {
    if (alt) {
        graph <- igraph::graph_from_adjacency_matrix(adja_mat)
        stopifnot(igraph::is_dag(graph))

        nodes_sorted <- igraph::topo_sort(graph)
        return(adja_mat[nodes_sorted, nodes_sorted])
    } else {
        adja_org <- adja_mat
        adja_mat[adja_mat != 0] <- 1
        adja_mat <- mnem::transitive.closure(adja_mat)
        ord <- order(
            apply(adja_mat, 1, sum) - apply(adja_mat, 2, sum),
            decreasing = TRUE
        )
        return(adja_org[ord, ord])
    }
}
