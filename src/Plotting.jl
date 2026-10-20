#─────────────────────────────────────────────────────────────────────────────#
# Plotting
#─────────────────────────────────────────────────────────────────────────────#
    # Stubs for the Plots.jl extension (loaded with `using Plots, GraphRecipes`)

"""
    plotdag(taproot; kwargs...)

Plots `taproot` as a DAG: each node appears once, laid out in layers so every arrow points down.
Requires `using Plots, GraphRecipes`. Any `GraphRecipes.graphplot` keyword can be passed through.
Nodes are numbered in `topdown(taproot)` order, which is the order `names`, `nodecolor` and `edgecolor` (keyed by `(parent, child)` indices) follow.
"""
function plotdag end

"""
    plotdag!(taproot; kwargs...)

Like `plotdag`, but plots into the current plot.
"""
function plotdag! end

"""
    plottree(taproot; kwargs...)

Plots `taproot` as a tree: a node reached by several paths is drawn once per path.
Requires `using Plots, GraphRecipes`. Any `GraphRecipes.graphplot` keyword can be passed through.
"""
function plottree end

"""
    plottree!(taproot; kwargs...)

Like `plottree`, but plots into the current plot.
"""
function plottree! end
