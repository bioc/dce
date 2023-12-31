#' Plot network adjacency matrix
#'
#' Generic function which plots any adjacency matrix (assumes DAG)
#' @param adja_matrix Adjacency matrix of network
#' @param nodename_map node names
#' @param edgescale_limits Limits for scale_edge_color_gradient2
#'        (should contain 0). Useful to make plot comparable to others
#' @param nodesize Node sizes
#' @param labelsize Node label sizes
#' @param node_color Which color to plot nodes in
#' @param node_border_size Thickness of node's border stroke
#' @param arrow_size Size of edge arrows
#' @param scale_edge_width_max Max range for `scale_edge_width`
#' @param show_edge_labels Whether to show edge labels (DCEs)
#' @param visualize_edge_weights Whether to change edge color/width/alpha
#'        relative to edge weight
#' @param use_symlog Scale edge colors using dce::symlog
#' @param highlighted_nodes List of nodes to highlight
#' @param legend_title Title of edge weight legend
#' @param value_matrix Optional matrix of edge weights if different
#'        from adjacency matrix
#' @param shadowtext Draw white outline around node labels
#' @param ... additional parameters
#' @author Martin Pirkl, Kim Philipp Jablonski
#' @return plot of dag and dces
#' @export
#' @import tidyverse ggraph purrr
#' @importFrom glue glue
#' @importFrom ggplot2 aes theme element_rect arrow unit
#'             coord_fixed scale_fill_manual waiver
#' @importFrom tidygraph as_tbl_graph activate mutate .N
#' @importFrom rlang .data
#' @importFrom igraph graph_from_adjacency_matrix
#' @importFrom Rgraphviz agopen
#' @importFrom shadowtext geom_shadowtext
#' @importFrom magrittr %T>%
#' @examples
#' adj <- matrix(c(0,0,0,1,0,0,0,1,0),3,3)
#' plot_network(adj)
plot_network <- function(
    adja_matrix,
    nodename_map = NULL, edgescale_limits = NULL,
    nodesize = 17, labelsize = 3,
    node_color = "white",
    node_border_size = 0.5,
    arrow_size = 0.05,
    scale_edge_width_max = 1,
    show_edge_labels = FALSE,
    visualize_edge_weights = TRUE,
    use_symlog = FALSE,
    highlighted_nodes = c(),
    legend_title = "edge weight",
    value_matrix = NULL,
    shadowtext = FALSE,
    ...
) {
    # sanitize input
    if (is.null(value_matrix)) {
        value_matrix <- adja_matrix
    }

    if (is.null(rownames(adja_matrix)) || is.null(colnames(adja_matrix))) {
        warning(
            "No nodenames set, using dummy names...",
            call. = FALSE
        )

        node_names <- seq_len(dim(adja_matrix)[[1]])
        rownames(adja_matrix) <- colnames(adja_matrix) <- node_names
    }

    # compute node coordinates
    tmp <- adja_matrix
    tmp[tmp != 0] <- 1

    coords_dot <- purrr::map_dfr(
        Rgraphviz::agopen(
            as(tmp, "graphNEL"),
            name = "foo",
            layoutType = "dot"
        )@AgNode,
        function(node) {
            data.frame(x = node@center@x, y = node@center@y)
        }
    )

    # handle scale setup
    if (is.null(edgescale_limits)) {
        edgescale_limits <- c(
            -max(abs(value_matrix), na.rm = TRUE),
            max(abs(value_matrix), na.rm = TRUE)
        )
    }

    custom_breaks <- function(limits) {
        if (any(is.infinite(limits))) {
            return(ggplot2::waiver())
        }

        # without this offset the outer breaks are somtetimes not shown
        eps <- min(abs(limits)) / 100
        breaks <- seq(limits[[1]] + eps, limits[[2]] - eps, length.out = 5)

        if (min(abs(limits)) < 1) {
            return(breaks)
        } else {
            return(round(breaks, 1))
        }
    }

    # handle shadowtext
    if (shadowtext) {
        geom_custom_labels <- function(...) {
            geom_shadowtext(..., bg.color = "white")
        }
    } else {
        geom_custom_labels <- geom_node_text
    }

    # create plot
    p <- as_tbl_graph(igraph::graph_from_adjacency_matrix(  # nolint
        adja_matrix, weighted = TRUE
    )) %>%
        activate(nodes) %>%
        mutate(
            label = if (is.null(nodename_map)) {
                .data$name
            } else {
                nodename_map[.data$name]  # nolint
            },
            nodesize = nodesize,
            is.highlighted = .data$label %in% highlighted_nodes
        ) %T>%
        with({
            label_list <- as.data.frame(.)$label  # nolint
            extra_nodes <- setdiff(highlighted_nodes, label_list)

            if (length(extra_nodes) > 0) {
                label_str <- glue::glue_collapse(extra_nodes, sep = ", ")  # nolint
                warning(
                    glue::glue("Invalid highlighted nodes: {label_str}"),
                    call. = FALSE
                )
            }
        }) %>%
        activate(edges) %>%
        mutate(
            dce = pmap_dbl(
                list(.data$from, .data$to),
                function(from_id, to_id) {
                    if (is.null(rownames(value_matrix))) {
                        return(value_matrix[from_id, to_id])
                    } else {
                        from_name <- .N()$name[from_id]
                        to_name <- .N()$name[to_id]

                        if (
                            !(from_name %in% rownames(value_matrix)) ||
                            !(to_name %in% colnames(value_matrix))
                        ) {
                            stop(paste0(
                                "Edge ", from_name, "->", to_name,
                                " has no weight in value matrix."
                            ))
                        }

                        return(value_matrix[from_name, to_name])
                    }
                }
            ),
            dce.symlog = symlog(dce),
            label = .data$dce %>% round(2) %>% as.character
        ) %>%
    ggraph(layout = coords_dot) + # "sugiyama"
        geom_node_circle(
            aes(r = .data$nodesize, fill = .data$is.highlighted),
            size = node_border_size
        ) +
        geom_edge_diagonal(
            aes(
                color = if (visualize_edge_weights) {
                    if (use_symlog) {
                        .data$dce.symlog
                    } else {
                        .data$dce
                    }
                } else {
                    NULL
                },
                alpha = if (visualize_edge_weights) abs(.data$dce) else NULL,
                width = if (visualize_edge_weights) abs(.data$dce) else NULL,
                label = if (show_edge_labels) .data$label else NULL,
                linetype = is.na(.data$dce),
                start_cap = circle(.data$node1.nodesize, unit = "native"),
                end_cap = circle(.data$node2.nodesize, unit = "native")
            ),
            strength = 0.5,
            arrow = arrow(
                type = "closed",
                length = unit(arrow_size, "native")
            )
        ) +
        geom_custom_labels(
            aes(label = .data$label, x = .data$x, y = .data$y),
            size = labelsize,
            color = "black"
        ) +
        coord_fixed() +
        scale_fill_manual(
            values = c("FALSE" = node_color, "TRUE" = "red"), guide = "none"
        ) +
        scale_edge_color_gradient2(
            low = "red", mid = "grey", high = "blue", midpoint = 0,
            limits = if (use_symlog) {
                symlog(edgescale_limits)
            } else {
                edgescale_limits
            },  # nolint
            breaks = custom_breaks,
            name = if (use_symlog) {
                glue("symlog({legend_title})")
            } else {
                legend_title
            },  # nolint
            na.value = "black",
            guide = ggraph::guide_edge_colorbar()
        ) +
        scale_edge_width(
            range = c(0.1, scale_edge_width_max),
            limits = c(0, edgescale_limits[[2]]),
            guide = "none"
        ) +
        scale_edge_alpha(
            range = c(.5, 1), limits = c(0, edgescale_limits[[2]]),
            na.value = 1,
            guide = "none"
        ) +
        scale_edge_linetype_manual(
            values = c("FALSE" = "solid", "TRUE" = "dashed"),
            guide = "none"
        ) +
        theme(
            panel.background = element_rect(fill = "white")
        )

    if (!visualize_edge_weights) {
        p <- p + theme(legend.position = "none")
    }

    p
}


#' Plot dce object
#'
#' This function takes a differential causal effects object and plots
#' the dag with the dces
#' @param x dce object
#' @param ... Parameters passed to dce::plot_network
#' @author Martin Pirkl, Kim Philipp Jablonski
#' @method plot dce
#' @return plot of dag and dces
#' @export
#' @examples
#' dag <- create_random_DAG(30, 0.2)
#' X.wt <- simulate_data(dag)
#' dag.mt <- resample_edge_weights(dag)
#' X.mt <- simulate_data(dag)
#' dce.list <- dce(dag,X.wt,X.mt)
#' plot(dce.list)
plot.dce <- function(x, ...) {
    plot_network(x$graph, value_matrix = x$dce, legend_title = "DCE", ...)
}


#' Linear transform if under logarithmic transform is over threshold
#' @param x Value to transform
#' @param base Base of logarithm
#' @param threshold Linearity threshold
#' @noRd
symlog <- function(x, base = 10, threshold = 1) {
    if (is.null(x)) {
        return(NULL)
    }

    ifelse(
        abs(x) < threshold,
        x,
        sign(x) * (threshold + log(sign(x) * x / threshold, base))
    )
}
