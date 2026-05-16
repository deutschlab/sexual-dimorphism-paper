"""
Connectivity analysis and visualization utilities for dsx/fru neuron networks.

This module provides:
    - Directed connectivity graph visualization
    - Connectivity heatmap generation
    - Hierarchical clustering of neuron subtypes
    - Cytoscape-compatible network export
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import matplotlib.pyplot as plt
import networkx as nx
import netgraph as ng
import numpy as np
import radialtree as rt
import scipy.cluster.hierarchy as sch
import seaborn as sns

from matplotlib.colors import TwoSlopeNorm
from matplotlib.lines import Line2D
from scipy.cluster.hierarchy import fcluster


# =============================================================================
# Configuration
# =============================================================================

DEFAULT_OUTPUT_DIR = Path("outputs")

MAX_LAYOUT_OPTIMIZATION_ITERATIONS = 5000

DEFAULT_NODE_SIZE = 250
DEFAULT_SPECIAL_NODE_SIZE = 400

DEFAULT_EDGE_WIDTH = 25
DEFAULT_NODE_EDGE_WIDTH = 8

DEFAULT_LAYER_SPACING = 150

HEATMAP_CMAP = "RdBu_r"

# Example color palette.
# Replace with publication-specific colors if needed.
COLORS = {
    "Visual": "#4C72B0",
    "Auditory": "#55A868",
    "Gustatory": "#C44E52",
    "Olfactory": "#8172B2",
    "DNs": "#CCB974",
    "Central": "#64B5CD",
}


# =============================================================================
# Data structures
# =============================================================================

@dataclass(frozen=True)
class Connection:
    """
    Directed weighted connection between neuron types.
    """

    source: str
    target: str
    weight: float


@dataclass
class ConnectivityEdge:
    """
    Connectivity edge with normalized fractions.
    """

    source: str
    target: str
    fraction_out: float
    fraction_in: float


# =============================================================================
# Utility functions
# =============================================================================

def ensure_output_dir(path: Path) -> None:
    """
    Create output directory if it does not already exist.
    """
    path.mkdir(parents=True, exist_ok=True)


def weighted_jaccard(
    a: dict[str, float],
    b: dict[str, float],
) -> float:
    """
    Compute weighted Jaccard similarity between sparse vectors.
    """
    keys = set(a) | set(b)

    numerator = sum(min(a.get(k, 0), b.get(k, 0)) for k in keys)
    denominator = sum(max(a.get(k, 0), b.get(k, 0)) for k in keys)

    if denominator == 0:
        return 0.0

    return numerator / denominator


def node_label(name: str) -> str:
    """
    Format node labels for visualization.
    """
    parts = name.replace("-", "_").split("_")
    return "\n".join(parts)


def legend_handles(color_mapping: dict[str, str]) -> list[Line2D]:
    """
    Construct legend handles from a color mapping.
    """
    return [
        Line2D(
            [0],
            [0],
            marker="o",
            color=color,
            label=label,
            lw=0,
            markerfacecolor=color,
            markersize=14,
        )
        for label, color in color_mapping.items()
    ]


# =============================================================================
# Graph layout
# =============================================================================

def assign_layers_by_connectivity(
    connections: Iterable[Connection],
    max_layers: int = 200,
    max_layer_width: int = 200,
) -> dict[str, int]:
    """
    Assign graph layers by minimizing edge penalties.

    The optimization attempts to:
        - reduce backward edges
        - reduce long edges
        - avoid excessively wide layers

    Returns
    -------
    dict
        Mapping node -> layer index.
    """

    nodes = sorted(
        set(c.source for c in connections)
        | set(c.target for c in connections)
    )

    layers = {node: max_layers // 2 for node in nodes}

    def connection_penalty(conn: Connection) -> float:
        delta = layers[conn.target] - layers[conn.source]

        if delta == 0:
            return 150.0

        if delta > 0:
            return (4 * delta) ** 3

        return (-delta) ** 1.5

    def position_penalty(node: str) -> float:
        layer_width = sum(
            1 for v in layers.values()
            if v == layers[node]
        )

        width_penalty = (
            1000 if layer_width > max_layer_width else 0
        )

        edge_penalty = sum(
            connection_penalty(c)
            for c in connections
            if c.source == node or c.target == node
        )

        return width_penalty + edge_penalty

    for _ in range(1000):

        updated = False

        for node in nodes:

            current_layer = layers[node]
            best_layer = current_layer
            best_penalty = position_penalty(node)

            for layer in range(max_layers):

                layers[node] = layer
                penalty = position_penalty(node)

                if penalty < best_penalty:
                    best_penalty = penalty
                    best_layer = layer

            layers[node] = best_layer

            if best_layer != current_layer:
                updated = True

        if not updated:
            break

    return layers


def compute_node_positions(
    layer_to_nodes: dict[int, list[str]],
    spacing: int = DEFAULT_LAYER_SPACING,
) -> dict[str, tuple[float, float]]:
    """
    Compute deterministic node positions.
    """

    positions = {}

    for layer, nodes in sorted(layer_to_nodes.items()):

        if not nodes:
            continue

        nodes = sorted(nodes)

        horizontal_spacing = spacing / len(nodes)

        for idx, node in enumerate(nodes):
            positions[node] = (
                (idx + 0.5) * horizontal_spacing,
                layer,
            )

    return positions


# =============================================================================
# Graph visualization
# =============================================================================

def draw_connectivity_graph(
    connections: Iterable[Connection],
    node_colors: dict[str, str],
    special_nodes: set[str] | None = None,
    output_path: Path | None = None,
    title: str | None = None,
) -> None:
    """
    Draw directed connectivity graph.
    """

    special_nodes = special_nodes or set()

    graph = nx.DiGraph()

    for conn in connections:
        graph.add_edge(
            conn.source,
            conn.target,
            weight=conn.weight,
        )

    layers = assign_layers_by_connectivity(connections)

    layer_to_nodes = defaultdict(list)

    for node, layer in layers.items():
        layer_to_nodes[layer].append(node)

    layout = compute_node_positions(layer_to_nodes)

    fig, ax = plt.subplots(figsize=(18, 12))

    if title:
        fig.suptitle(title, fontsize=20)

    ng.Graph(
        graph,
        ax=ax,
        node_layout={
            node: (x, 15 * y)
            for node, (x, y) in layout.items()
        },
        node_size={
            node: (
                DEFAULT_SPECIAL_NODE_SIZE
                if node in special_nodes
                else DEFAULT_NODE_SIZE
            )
            for node in graph.nodes
        },
        node_edge_color={
            node: node_colors.get(node, "black")
            for node in graph.nodes
        },
        node_edge_width=DEFAULT_NODE_EDGE_WIDTH,
        node_labels={
            node: node_label(node)
            for node in graph.nodes
        },
        edge_width=DEFAULT_EDGE_WIDTH,
        arrows=True,
    )

    ax.legend(
        handles=legend_handles(node_colors),
        loc="upper right",
    )

    plt.tight_layout()

    if output_path:
        ensure_output_dir(output_path.parent)
        fig.savefig(output_path, dpi=300)

    plt.close(fig)


# =============================================================================
# Connectivity matrices
# =============================================================================

def build_connectivity_matrix(
    edges: list[ConnectivityEdge],
    direction: str,
) -> tuple[np.ndarray, list[str]]:
    """
    Construct connectivity matrix.

    Parameters
    ----------
    direction:
        Either "input" or "output".
    """

    if direction not in {"input", "output"}:
        raise ValueError(
            "direction must be 'input' or 'output'"
        )

    labels = sorted(
        set(e.source for e in edges)
        | set(e.target for e in edges)
    )

    index = {
        label: idx
        for idx, label in enumerate(labels)
    }

    matrix = np.zeros((len(labels), len(labels)))

    for edge in edges:

        i = index[edge.source]
        j = index[edge.target]

        value = (
            edge.fraction_out
            if direction == "output"
            else edge.fraction_in
        )

        matrix[i, j] = value

    return matrix, labels


# =============================================================================
# Heatmaps
# =============================================================================

def plot_connectivity_heatmap(
    matrix: np.ndarray,
    labels: list[str],
    output_path: Path | None = None,
    title: str = "",
    figsize: tuple[int, int] = (14, 12),
) -> None:
    """
    Plot connectivity heatmap.
    """

    fig, ax = plt.subplots(figsize=figsize)

    norm = TwoSlopeNorm(
        vmin=-0.2,
        vcenter=0,
        vmax=0.1,
    )

    sns.heatmap(
        matrix,
        cmap=HEATMAP_CMAP,
        norm=norm,
        xticklabels=labels,
        yticklabels=labels,
        square=True,
        linewidths=0.5,
        ax=ax,
    )

    ax.set_xlabel("Target type")
    ax.set_ylabel("Source type")

    ax.tick_params(axis="x", rotation=90)
    ax.tick_params(axis="y", rotation=0)

    ax.set_title(title)

    plt.tight_layout()

    if output_path:
        ensure_output_dir(output_path.parent)
        fig.savefig(output_path, dpi=300)

    plt.close(fig)


# =============================================================================
# Clustering
# =============================================================================

def compute_distance_matrix(
    feature_vectors: dict[str, dict[str, float]],
) -> tuple[np.ndarray, list[str]]:
    """
    Compute condensed distance matrix from sparse feature vectors.
    """

    labels = sorted(feature_vectors)

    distances = []

    for i in range(len(labels)):

        for j in range(i + 1, len(labels)):

            similarity = weighted_jaccard(
                feature_vectors[labels[i]],
                feature_vectors[labels[j]],
            )

            distance = 1 - np.sqrt(np.sqrt(similarity))

            distances.append(distance)

    return np.array(distances), labels


def hierarchical_clustering(
    feature_vectors: dict[str, dict[str, float]],
    threshold: float = 0.7,
):
    """
    Perform hierarchical clustering.
    """

    dist_matrix, labels = compute_distance_matrix(
        feature_vectors
    )

    linkage_matrix = sch.linkage(
        dist_matrix,
        method="average",
    )

    cluster_ids = fcluster(
        linkage_matrix,
        t=threshold,
        criterion="distance",
    )

    clusters = defaultdict(list)

    for cluster_id, label in zip(cluster_ids, labels):
        clusters[cluster_id].append(label)

    return linkage_matrix, dict(clusters)


def plot_dendrogram(
    linkage_matrix,
    labels: list[str],
    output_path: Path | None = None,
    title: str = "Hierarchical clustering",
) -> None:
    """
    Plot dendrogram.
    """

    fig, ax = plt.subplots(figsize=(14, 14))

    dendrogram = sch.dendrogram(
        linkage_matrix,
        labels=np.array(labels),
        orientation="left",
        leaf_rotation=0,
        ax=ax,
    )

    rt.plot(
        dendrogram,
        figsize=(14, 14),
    )

    ax.set_title(title)

    plt.tight_layout()

    if output_path:
        ensure_output_dir(output_path.parent)
        fig.savefig(output_path, dpi=300)

    plt.close(fig)


# =============================================================================
# Cytoscape export
# =============================================================================

def export_edge_table(
    edges: Iterable[Connection],
    output_csv: Path,
) -> None:
    """
    Export edge table for Cytoscape.
    """

    ensure_output_dir(output_csv.parent)

    with open(output_csv, "w") as f:

        f.write("source,target,weight\n")

        for edge in edges:
            f.write(
                f"{edge.source},{edge.target},{edge.weight}\n"
            )


def export_node_table(
    node_attributes: dict[str, dict[str, str | int | float]],
    output_csv: Path,
) -> None:
    """
    Export node attribute table for Cytoscape.
    """

    ensure_output_dir(output_csv.parent)

    if not node_attributes:
        return

    columns = sorted(
        next(iter(node_attributes.values())).keys()
    )

    with open(output_csv, "w") as f:

        f.write("node," + ",".join(columns) + "\n")

        for node, attrs in sorted(node_attributes.items()):

            row = [str(attrs[col]) for col in columns]

            f.write(
                node + "," + ",".join(row) + "\n"
            )


# =============================================================================
# Example pipeline
# =============================================================================

def example_pipeline() -> None:
    """
    Minimal reproducible example.
    """

    np.random.seed(0)

    connections = [
        Connection("Visual", "Central", 0.6),
        Connection("Auditory", "Central", 0.4),
        Connection("Central", "DNs", 0.8),
        Connection("Olfactory", "Central", 0.7),
    ]

    node_colors = {
        node: COLORS.get(node, "gray")
        for node in {
            c.source for c in connections
        } | {
            c.target for c in connections
        }
    }

    output_dir = DEFAULT_OUTPUT_DIR

    draw_connectivity_graph(
        connections=connections,
        node_colors=node_colors,
        special_nodes={"DNs"},
        title="Example connectivity graph",
        output_path=output_dir / "graph.png",
    )

    edges = [
        ConnectivityEdge(
            source="Visual",
            target="Central",
            fraction_out=0.6,
            fraction_in=0.3,
        ),
        ConnectivityEdge(
            source="Auditory",
            target="Central",
            fraction_out=0.4,
            fraction_in=0.2,
        ),
        ConnectivityEdge(
            source="Central",
            target="DNs",
            fraction_out=0.8,
            fraction_in=0.7,
        ),
    ]

    matrix, labels = build_connectivity_matrix(
        edges,
        direction="output",
    )

    plot_connectivity_heatmap(
        matrix,
        labels,
        title="Connectivity heatmap",
        output_path=output_dir / "heatmap.png",
    )

    feature_vectors = {
        "A": {"x": 1.0, "y": 2.0},
        "B": {"x": 1.2, "y": 1.9},
        "C": {"z": 4.0},
    }

    linkage_matrix, clusters = hierarchical_clustering(
        feature_vectors
    )

    plot_dendrogram(
        linkage_matrix,
        labels=sorted(feature_vectors),
        output_path=output_dir / "dendrogram.png",
    )

    export_edge_table(
        connections,
        output_dir / "edges.csv",
    )

    export_node_table(
        {
            "Visual": {"group": "sensory"},
            "Central": {"group": "central"},
            "DNs": {"group": "descending"},
        },
        output_dir / "nodes.csv",
    )

    print("Generated outputs:")
    print(f"  {output_dir.resolve()}")


if __name__ == "__main__":
    example_pipeline()
