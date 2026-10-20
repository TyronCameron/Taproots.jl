module TaprootPlots
using Taproots: Taproots, topdown, bottomup
using RecipesBase: @recipe
using GraphRecipes: GraphRecipes
using Plots: Plots
import Taproots: plotdag, plotdag!, plottree, plottree!

struct PlotTree
    args
end

struct PlotDag
    args
end

plottree(args...; kwargs...) = Plots.plot(PlotTree(args); kwargs...)
plottree!(args...; kwargs...) = Plots.plot!(PlotTree(args); kwargs...)
plotdag(args...; kwargs...) = Plots.plot(PlotDag(args); kwargs...)
plotdag!(args...; kwargs...) = Plots.plot!(PlotDag(args); kwargs...)
plottree!(p::Plots.AbstractPlot, args...; kwargs...) = Plots.plot!(p, PlotTree(args); kwargs...)
plotdag!(p::Plots.AbstractPlot, args...; kwargs...) = Plots.plot!(p, PlotDag(args); kwargs...)

# Each node once, numbered in topdown order, with an edge from every parent to each child
function dagparts(roots)
    nodes = collect(topdown(roots...))
    index = Dict(node => i for (i, node) in enumerate(nodes))
    adj = zeros(Int, length(nodes), length(nodes))
    for (i, node) in enumerate(nodes), child in Taproots.children(node)
        haskey(index, child) && (adj[i, index[child]] = 1)
    end
    return nodes, index, adj
end

# A node's layer is its longest path from a root, so every arrow points down
function dagdepths(roots, index, adj)
    depth = zeros(Int, size(adj, 1))
    for node in Iterators.reverse(collect(bottomup(roots...))) # parents before children
        i = index[node]
        for j in findall(!iszero, adj[i, :])
            depth[j] = max(depth[j], depth[i] + 1)
        end
    end
    return depth
end

# Orders each layer by the mean position of its neighbours (a few up and down sweeps to untangle crossings)
function daglayout(depth, adj)
    layers = [findall(==(d), depth) for d in 0:maximum(depth)]
    rank = zeros(Float64, length(depth))
    for layer in layers, (r, i) in enumerate(layer) rank[i] = r - (length(layer) + 1) / 2 end
    parents(i) = findall(!iszero, adj[:, i])
    kids(i) = findall(!iszero, adj[i, :])
    barycentre(i, neighbours) = isempty(neighbours) ? rank[i] : sum(rank[neighbours]) / length(neighbours)
    for _ in 1:8, (sweep, neighbours) in ((2:length(layers), parents), ((length(layers) - 1):-1:1, kids))
        for l in sweep
            layer = layers[l]
            sort!(layer; by = i -> barycentre(i, neighbours(i)))
            for (r, i) in enumerate(layer) rank[i] = r - (length(layer) + 1) / 2 end
        end
    end
    scale = max(maximum(length, layers) - 1, length(layers) - 1, 1)
    return rank ./ scale, -depth ./ scale
end

@recipe function f(x::PlotTree)
    nodes, _ = Taproots.treewalk(x.args[1])
    names --> sprint.(show, nodes)
    method := :buchheim
    root --> :top
    fontsize --> 12
    nodeshape --> :ellipse
    nodecolor --> :steelblue2
    shorten --> 0.05
    edgewidth --> (s,d,w) -> 1.75
    GraphRecipes.GraphPlot((Taproots.treeadjacency(x.args[1]),))
end

@recipe function f(x::PlotDag)
    roots = x.args
    nodes, index, adj = dagparts(roots)
    xs, ys = daglayout(dagdepths(roots, index, adj), adj)
    names --> sprint.(show, nodes)
    x --> xs
    y --> ys
    curves --> false
    arrow --> true
    fontsize --> 12
    nodeshape --> :circle
    nodecolor --> :steelblue2
    shorten --> 0.05
    edgewidth --> (s,d,w) -> 1.75
    GraphRecipes.GraphPlot((adj,))
end

end
