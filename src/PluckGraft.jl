#─────────────────────────────────────────────────────────────────────────────#
# Grafting and Plucking
#─────────────────────────────────────────────────────────────────────────────#
    # Helpful getters, setters, and transformers on taproots

"""
    pluck(parent, trace[, default = nothing])

This gets the node which matches a trace. A trace is simply an iterable set of children indices.
"""
pluck(parent, trace::AbstractVector; default = nothing) = try foldl((current, idx) -> children(current)[idx], trace; init = parent) catch default end
pluck(parent, trace::Tuple; default = nothing) = pluck(parent, collect(trace); default = default)
pluck(parent, trace...; default = nothing) = pluck(parent, collect(trace); default = default)

"""
    graft!(parent, trace, value)

This sets the node which matches a trace. A trace is simply an iterable set of children indices.
"""
function graft!(parent, trace::AbstractVector, value)
    trace = collect(trace)
    current_parent = pluck(parent, trace[begin:(end - 1)])
    current_children = copy(children(current_parent))
    current_children[trace[end]] = value
    setchildren!(current_parent, current_children)
    return parent
end

function parents(root, child)
    traces = filter(x -> !isempty(x), findtraces(child, root))
    parent_traces = map(t -> t[begin:(end - 1)], traces)
    return pluck.([root], parent_traces) |> unique!
end


"""
    findtrace(f, parent)

This is a slower (~linear) algorithm to find the first value where `f` returns true. It returns a vector which can be used to index into a nested data struct.
You can index into your nested data structure using pluck.
"""
function findtrace(matcher::Function, parent)
    for (trace, node) in tracepairs(parent)
        if matcher(node) return trace end
    end
    return nothing
end
findtrace(child, parent) = findtrace(x -> x == child, parent)


"""
    findtraces(f, parent)

This is a slower (~linear) algorithm to find all values where `f` returns true. It returns a vector which can be used to index into a nested data struct.
You can index into your nested data structure using pluck.
"""
function findtraces(matcher::Function, parent)
    traces = []
    for (trace, node) in tracepairs(parent; pathset = AllPaths)
        if matcher(node) push!(traces, trace) end
    end
    return traces
end
findtraces(child, parent) = findtraces(x -> x == child, parent)

mutable struct UprootHelper
    parent
    node
    children
    mapped 
end
Base.hash(a::UprootHelper, h::UInt) = hash(a.node, h)
Base.isequal(a::UprootHelper, b::UprootHelper) = a.node == b.node
uproothelper(parent, node) = UprootHelper(parent, node, [], false)
function children(node::UprootHelper) 
    if !node.mapped # cache results
        node.children = uproothelper.([node.parent], parents(node.parent, node.node))
        node.mapped = true
    end 
    return node.children
end 

"""
    uproot(parent, child)

Gets a child in a taproot, and slices it and all parents out of the taproot, then reverses directions of all the arrows. This is the only way to reverse arrows in `Taproots.jl`.
This can be a bit slow for the moment for large taproots.
"""
function uproot(parent, child)
    root = uproothelper(parent, child)
    post = collect(postorder(root)) # map out the structure early
    node_map = foldl(post; init=Dict()) do acc, node
        acc[node.node] = _copy_or_reconstruct(node.node)
        acc
    end
    for node in post
        new_node = node_map[node.node]
        setchildren!(new_node, map(c -> node_map[c.node], children(node)))
    end
    return node_map[root.node]
end

"""
    getatkeys(indexable_struct, trace, default_value)

This is just a convenience function to index into a nest object (potentially not a taproot in any way) by some iterable value of keys.

# Example

dict = Dict(1 => Dict(:a => Dict(1 => Dict(:a => "Finally here"))))

getatkeys(dict, (1,:a,1,:a)) == "Finally here"

"""
function getatkeys(parent, trace::Vector; default = nothing)
    try
        return foldl((current, idx) -> current[idx], trace; init = parent)
    catch
        return default
    end
end
getatkeys(parent, trace::Tuple; default = nothing) = getatkeys(parent, collect(trace); default = default)
getatkeys(parent, trace...; default = nothing) = getatkeys(parent, collect(trace); default = default)

"""
    setatkeys!(indexable_struct, trace, value)

This is just a convenience function to index into a nest object (potentially not a taproot in any way) by some iterable value of keys.
"""
function setatkeys!(indexable_struct, trace, value)
    trace = collect(trace)
    current_parent = getatkeys(indexable_struct, trace[begin:(end - 1)])
    current_parent[trace[end]] = value
    return indexable_struct
end
