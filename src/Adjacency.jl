#─────────────────────────────────────────────────────────────────────────────#
# Adjacency
#─────────────────────────────────────────────────────────────────────────────#
    # This file contains adjacency matrix calculations
    # TODO: allow these to take multiple taproots at a time

function treeadjacency(t)
    top = topdown(t) |> collect
    adj = convert(Array{Int}, zeros(length(top), length(top)))
    start = 2
    for (i,x) in enumerate(top)
        stop = start + length(children(x)) - 1
        if start < stop adj[i, start:stop] .= 1 end
        start = stop + 1
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
