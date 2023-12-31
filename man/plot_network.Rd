% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plotting.R
\name{plot_network}
\alias{plot_network}
\title{Plot network adjacency matrix}
\usage{
plot_network(
  adja_matrix,
  nodename_map = NULL,
  edgescale_limits = NULL,
  nodesize = 17,
  labelsize = 3,
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
)
}
\arguments{
\item{adja_matrix}{Adjacency matrix of network}

\item{nodename_map}{node names}

\item{edgescale_limits}{Limits for scale_edge_color_gradient2
(should contain 0). Useful to make plot comparable to others}

\item{nodesize}{Node sizes}

\item{labelsize}{Node label sizes}

\item{node_color}{Which color to plot nodes in}

\item{node_border_size}{Thickness of node's border stroke}

\item{arrow_size}{Size of edge arrows}

\item{scale_edge_width_max}{Max range for `scale_edge_width`}

\item{show_edge_labels}{Whether to show edge labels (DCEs)}

\item{visualize_edge_weights}{Whether to change edge color/width/alpha
relative to edge weight}

\item{use_symlog}{Scale edge colors using dce::symlog}

\item{highlighted_nodes}{List of nodes to highlight}

\item{legend_title}{Title of edge weight legend}

\item{value_matrix}{Optional matrix of edge weights if different
from adjacency matrix}

\item{shadowtext}{Draw white outline around node labels}

\item{...}{additional parameters}
}
\value{
plot of dag and dces
}
\description{
Generic function which plots any adjacency matrix (assumes DAG)
}
\examples{
adj <- matrix(c(0,0,0,1,0,0,0,1,0),3,3)
plot_network(adj)
}
\author{
Martin Pirkl, Kim Philipp Jablonski
}
