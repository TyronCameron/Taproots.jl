#─────────────────────────────────────────────────────────────────────────────#
# Adjacency
#─────────────────────────────────────────────────────────────────────────────#
    # This file contains adjacency matrix calculations
    # TODO: allow these to take multiple taproots at a time

# Shared nodes are repeated once per path, so the result is always a tree (cycles are cut)
function treewalk(t)
    walk = collect(topdown(t; pathset = NoCycles, eltype = (Node, Trace)))
    return first.(walk), last.(walk)
end

function treeadjacency(t)
    nodes, traces = treewalk(t)
    index = Dict(trace => i for (i, trace) in enumerate(traces))
    adj = zeros(Int, length(nodes), length(nodes))
    for (i, trace) in enumerate(traces)
        isempty(trace) || (adj[index[trace[begin:(end - 1)]], i] = 1)
    end
    return adj
end

function dagadjacency(t)
    top = topdown(t) |> collect
    adj = []
    for x in top
        append!(adj, map(y -> y in children(x), top))
    end
    return convert(Array{Int, 2}, reshape(adj, (length(top), length(top)))) |> transpose |> copy
end

"""
    adjacencymatrix(taproot)

Returns an adjacency matrix for this taproot and all its children. If two nodes are equivalent they will only appear once here.
"""
adjacencymatrix(taproot) = dagadjacency(taproot)
