"""
Taproots is a library for traversing nested data structures.
"""
module Taproots
using Plots.RecipesBase, GraphRecipes, AbstractTrees, Term.Trees
export Taproot, tapin, tapout,
    eachfield,
    children, data, setchildren!, setdata!,
    ischild, isparent, isleaf, isbranch,
    preorder, postorder, topdown, bottomup, leaves, branches, traces, tracepairs,
    adjacencymatrix,
    tapmap!, tapmap, tapmapif!, tapmapif, leafmap!, leafmap, branchmap!, branchmap, prune!, prune, leafprune!, leafprune, branchprune!, branchprune,
    findtrace, findtraces, pluck, graft!, getatkeys, setatkeys!, uproot,
    @sprout, bloom, @bloom

###########################################################################
# Taproot sink
###########################################################################

"""
A Taproot is a single node that that can contain other Taproots. It can itself be contained in a parent Taproot.
It is not the main point of this package, but provides a convenience to persist structure when doing maps or other transformations.
It is also useful if you simply wish to build a data structure which already obeys everything in `Taproots.jl`.

You can construct a Taproot either by:
- `Taproot(data, children)` where `data` is anything that you'd like to store in this node, and `children` is an iterable list of children
- `Taproot(node)` where `node` is some value that has `Taproots.children` and `Taproots.data` defined on it. This will recurvisely sink your object into a `Taproots.Taproot`

"""
mutable struct Taproot
    data
    children::Vector{Taproot}
end
Taproot(node) = Taproot(data(node), Taproot[Taproot(child) for child in children(node)])

function Base.show(io::IO, taproot::Taproot)
    second = if isleaf(taproot)
        " (leaf)"
    elseif length(taproot.children) == 1
        "+(1 child)"
    else
        "+($(length(taproot.children)) children)"
    end
    print(io, "Taproot(", taproot.data, ")", second)
end

"""
    tapin(node)

The standard way to access the recursive Taproot constructor.
Requires `Taproots.data` and `Taproots.children` to work.
"""
tapin(node) = Taproot(node)

"""
    tapout(sink::Function, taproot::Taproot)

This allows you to transform a `Taproots.Taproot` struct back into one of your own structs. The `sink` function needs to be able to transform a single node of a `Taproot` into a node in your struct.
The sink follows the following structure:
    sink(data, children) which returns whatever type you want.

As a simple example, let's say we have

```julia
struct YourType
    printable_name::String
    id::UUID
    data
    children::Vector{YourType}
end
Taproots.children(x::YourType) = x.children
Taproots.data(x::YourType) = (x.printable_name, x.id, x.data)
```

Then you can convert that to a `Taproots.Taproot` as follows:

```julia
your_type = ... # nest your stuff here as much as you want.
your_taproot = tapin(your_type)
your_modified_type = tapout((data, children) -> YourType(data.printable_name, data.id, data.data, children), modified_taproot)
```

In case you have multiple types in your struct chain, you should take that into account in your sink. For example, you can do different things in case your `Taproot` has `String` type leaves.

```julia
function sink(data, children)
    if data isa String
        return data
    else
        return YourType(data.printable_name, data.id, data.data, children)
    end
end
```

"""
tapout(sink::Function, taproot::Taproot) = sink(data(taproot), tapout.(sink, children(taproot)))

###########################################################################
# Abstract API
###########################################################################

"""
    children(node)

Gets the children nodes in a Taproot DAG (if defined) of `node`. This function is meant to be overridden to access `Taproot.jl` functionality on your own types.

By default, `children(node)` will return an empty array, meaning `Taproot.jl` considers `node` to be a graph with a singular node (unless you overload this function.)

# Overriding this function

Simply define `Taproots.children(node::MyType) = ...`
Where the `...` returns a vector of the things you want to traverse.

"""
children(node) = []
children(expr::Expr) = expr.args
children(node::Dict) = values(node) |> collect
children(node::Vector) = node
children(node::Taproot) = node.children

"""
    eachfield(x)

Returns a tuple of the values in each field in a struct. Nice for if you have a known number of children.

"""
eachfield(x) = getfield.([x], fieldnames(typeof(x)))

"""
    data(x)

Gets the data of a single node in a Taproot DAG (if defined) of x. This function is optional (recommended) to override and can neaten up your life.
This function separates the idea of data that a node holds versus the children of your taproot.

By default, `data(x)` will return x, meaning `Taproots.jl` considers `x` (i.e. the entire node) to be perfectly valid data in and of itself.
However, this is sometimes dangerous, because editing `x` can destroy the link to `x`'s children. Override it to get rid of this danger.

Whatever you define `data(x)` to be needs to be consistent with `setdata!()

# Overriding this function

Simply define `Taproots.data(x::MyType) = ...`
Where the `...` returns whatever data is not already included in the `Taproots.children` function.

"""
data(x) = x
data(expr::Expr) = expr.head
data(x::Taproot) = x.data

"""
    setchildren!(node, children::Vector)::typeof(node)

Sets the children of your node. This is required for the following functionality:

- `prune!` (and `prune` variants)
- `tapmap!` (and `tapmap` variants)
- `graft!`
- `uproot`

Should return the entire node once completed.

You will need to define this in such a way that the following should do nothing:

`setchildren!(node, children(node))`

"""
function setchildren!(node, child_list::Vector)
    if isempty(children(node)) && isempty(child_list)
        return node
    end
    error("Taproots.setchildren!(node::$(typeof(node)), children) not implemented!")
    return node
end
setchildren!(node::Expr, children::Vector) = (node.args = children; node)
setchildren!(node::Vector, children::Vector) = (empty!(node); append!(node, children); node)
function setchildren!(dict::Dict, children::Vector)
    newdict = Dict()
    for (i, key) in enumerate(keys(dict))
        i <= length(children) && push!(newdict, key => children[i])
    end
    empty!(dict)
    merge!(dict, newdict)
    return dict
end
setchildren!(node::Taproot, children::Vector) = (node.children = children; node)

"""
    setdata!(node, data)::typeof(node)

Sets the data of your node. Useful if you want to be able to `tapmap!` your taproot without messing up your children.

You need to keep this consistent with whatever you defined for `Taproots.data`. In other words, it should be the case that the following does nothing.
`setdata!(node, data(node))`

It MUST return the entire node once done (and is allowed to simply return data without modifying the node in place).

This is required to be implemented for the following functionality:

- `tapmap!` (and `tapmap` and variants)
- `graft!`

# Example

```julia
Taproots.setdata!(node::MyDataStructure, data) = (node.data = data; node)
```

"""
setdata!(node, data) = error("Taproots.setdata!(node::$(typeof(node)), data) not implemented! It is intended that you implement this function -- it has downtrack implications for Taproots functionality.")
setdata!(node::Symbol, data) = data
setdata!(node::Expr, data) = node
setdata!(node::LineNumberNode, data) = node
setdata!(node::Vector, data) = setchildren!(node, data)
setdata!(node::Number, data) = data
setdata!(node::AbstractString, data) = data
setdata!(node::AbstractChar, data) = data
setdata!(node::Taproot, data) = (node.data = data; node)
function setdata!(dict::Dict, data)
    if data === dict return dict end
    empty!(dict)
    merge!(dict, data)
end

"""
    ischild(potential_child, parent)::Bool

Tells you whether `potential_child` is a child of `parent`. This function acts recursively and is not the same as doing `potential_child ∈ children(parent)`.
Time complexity of this is ~linear in the number of edges in your DAG underneath the `parent`, so use with care for large DAGs.
"""
function ischild(potential_child, parent)
    nodes = preorder(parent)
    take!(nodes)
    for child in nodes
        if potential_child == child return true end
    end
    return false
end

"""
    isparent(potential_parent, child)::Bool

Tells you whether `potential_parent` is a parent of `child`. This function acts recursively.
Time complexity of this is ~linear in the number of edges in your DAG underneath the `potential_parent`, so use with care for large DAGs.

"""
isparent(potential_parent, child) = ischild(child, potential_parent)

"""
    isleaf(node)::Bool

Tells you whether this `node` is a leaf node (i.e. it has no children).

"""
isleaf(node) = isempty(children(node))

"""
    isbranch(node)::Bool

Tells you whether this `node` is a branch node (i.e. it has children).

"""
isbranch(node) = !isleaf(node)

function visited!(node, visited::Set, revisit = false)
    if revisit return false end
    if node ∈ visited return true end
    push!(visited, node)
    return false
end

function walk_preorder(ch, root, revisit = false)
    stack = Any[root]
    visited = Set()
    while !isempty(stack)
        node = pop!(stack)
        if visited!(node, visited, revisit) continue end
        put!(ch, node)
        push!.([stack], children(node))
    end
end

function walk_postorder(ch, root, revisit = false)
    stack = Tuple{Any, Bool}[(root, false)]
    visited = Set()
    while !isempty(stack)
        node, seen = pop!(stack)
        if seen
            put!(ch, node)
        else
            if visited!(node, visited, revisit) continue end
            push!(stack, (node, true))
            for child in children(node)
                push!(stack, (child, false))
            end
        end
    end
end

function walk_topdown(ch, root, revisit = false)
    queue = Any[root]
    visited = Set()
    while !isempty(queue)
        node = popfirst!(queue)
        if visited!(node, visited, revisit) continue end
        put!(ch, node)
        append!(queue, children(node))
    end
end

function walk_bottomup(ch, root, revisit = false)
    leaves = filter(x -> isleaf(x[end]), tracepairs(root; revisit = revisit) |> collect)
    tracequeue = map(x -> x[begin], leaves)
    visited = Set()
    visitedtraces = Set()
    while !isempty(tracequeue)
        orig_trace = popfirst!(tracequeue)
        node = pluck(root, orig_trace)
        trace = copy(orig_trace)
        if !isempty(trace)
            pop!(trace)
            push!(tracequeue, trace)
        end
        if visited!(node, visited, revisit) || visited!(orig_trace, visitedtraces) continue end
        put!(ch, node)
    end
end

function walk_traces(ch, root, revisit = false)
    stack = Tuple{Vector{Int}, Any}[(Int[], root)]
    visited = Set()
    while !isempty(stack)
        path, node = pop!(stack)
        if visited!(node, visited, revisit) continue end
        put!(ch, path)
        for (i,child) in enumerate(children(node))
            push!(stack, (push!(copy(path), i), child))
        end
    end
end

function walk_tracepairs(ch, root, revisit = false)
    stack = Tuple{Vector{Int}, Any}[(Int[], root)]
    visited = Set()
    while !isempty(stack)
        path, node = pop!(stack)
        if visited!(node, visited, revisit) continue end
        put!(ch, (path, node))
        for (i,child) in enumerate(children(node))
            push!(stack, (push!(copy(path), i), child))
        end
    end
end

"""
    preorder(x)

This creates a lazy iterator as a preorder depth-first search of your custom Taproot.
In this iterator, parents are always iterated on before their children.
Unlike usual preorder depth-first search, this one will iterate on rightmost children first before doing leftmost children.

# Usage

for x in preorder(x)
    print(x)
end

collect(preorder(x)) <: Vector

"""
preorder(taproot; revisit = false) = Channel(ch -> walk_preorder(ch, taproot, revisit))

"""
    postorder(x)

This creates a lazy iterator as a postorder depth-first search of your custom Taproot.
In this iterator, children are always iterated on before their parents. Parents will immediately follow their children (so some (possibly irrelevant) children may not be iterated before the parent above them).

# Usage

for x in postorder(x)
    print(x)
end

collect(postorder(x)) <: Vector

"""
postorder(taproot; revisit = false) = Channel(ch -> walk_postorder(ch, taproot, revisit))

"""
    topdown(x)

This creates a lazy iterator as a topdown (level-order) breadth-first search of your custom Taproot.
The top parents are iterated first, and then the next level down, and so on. All parents are guaranteed to be iterated on before the leaves.

# Usage

for x in topdown(x)
    print(x)
end

collect(topdown(x)) <: Vector

"""
topdown(taproot; revisit = false) = Channel(ch -> walk_topdown(ch, taproot, revisit))


"""
    bottomup(x)

This creates an eager iterator as a bottomup (reverse level-order) breadth-first search of your custom Taproot. This is topological order.
The bottom children are iterated first, and then the next layer up and so on. Leaves are not technically guaranteed to be iterated on first, before parents.
While the other iterators are lazy, this one is eager, and will actually return a vector.

# Usage

for x in bottomup(x)
    print(x)
end

bottomup(x) <: Vector
collect(bottomup(x)) <: Vector

"""
bottomup(taproot; revisit = false) = Channel(ch -> walk_bottomup(ch, taproot, revisit))

"""
    leaves(x)

This creates a lazy iterator for the leaves (those nodes which have no children) of your custom Taproot.

# Usage

for x in leaves(x)
    print(x)
end

collect(leaves(x)) <: Vector

"""
leaves(taproot; revisit = false) = Iterators.filter(isleaf, postorder(taproot; revisit = revisit))

"""
    branches(x)

This creates a lazy iterator for the branches (those nodes which have children) of your custom Taproot.

# Usage

for x in branches(x)
    print(x)
end

collect(branches(x)) <: Vector

"""
branches(taproot; revisit = false) = Iterators.filter(isbranch, preorder(taproot; revisit = revisit))

"""
    traces(x)

This creates a lazy iterator for all the traces (vectors of indices) needed to get from the root to one of the children.
This will always be in the preorder (depth-first search).
"""
traces(taproot; revisit = false) = Channel(ch -> walk_traces(ch, taproot, revisit))

"""
    tracepairs(x)

This creates a lazy iterator for all the traces and nodes of a taproot.
This will always be in the preorder (depth-first search).
"""
tracepairs(taproot; revisit = false) = Channel(ch -> walk_tracepairs(ch, taproot, revisit))

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
    for (trace, node) in tracepairs(parent; revisit = true)
        if matcher(node) push!(traces, trace) end
    end
    return traces
end
findtraces(child, parent) = findtraces(x -> x == child, parent)

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

# One day will be moved to reconstruct(x)
function _copy_or_reconstruct(x)
    if hasmethod(copy, Tuple{typeof(x)})
        return copy(x)
    elseif x isa String
        return x
    elseif x isa Number
        return x
    elseif x isa Bool
        return x
    elseif ismutable(x)
        fieldvals = getfield.(Ref(x), 1:fieldcount(typeof(x)))
        try
            return typeof(x)(fieldvals...)
        catch
            @warn """
                No public constructor for $(typeof(x)); using Base.unsafe_copy as fallback.
                To make this warning go away, please implement `Base.copy(x::$(typeof(x)))`.
                Alternatively, use `deepcopy` and then `prune!` or `tapmap` or similar.
            """
            return Base.unsafe_copy(x)
        end
    else
        return x
    end
end

function _localupd!(condition, f, node, visited, modify)
    if modify && ismutable(node) && node ∈ visited return node end
    if modify push!(visited, node) end
    if !modify node = _copy_or_reconstruct(node) end
    return condition(node) ? setdata!(node, f(data(node))) : node
end

function maphelper!(condition, f, taproot, modify = true)
    visited = Set()
    for node in postorder(taproot)
        setchildren!(node, _localupd!.(condition, f, children(node), [visited], modify))
    end
    return _localupd!(condition, f, taproot, visited, modify)
end
maphelper(f, taproot, condition) = maphelper!(condition, f, taproot, false)

"""
    tapmap!(f::Function, taproot)

Modify all the data of every node in a taproot in place. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmap!(f::Function, taproot) = maphelper!(f, taproot, x -> true)

"""
    tapmap(f::Function, taproot)

Deepcopy a taproot and then modify its nodes in place. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmap(f::Function, taproot) = maphelper(f, taproot, x -> true)

"""
    tapmapif!(condition::Function, f::Function, taproot)

Modifies nodes in place if the entire node satisfies `condition`. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmapif!(condition::Function, f::Function, taproot) = maphelper!(f, taproot, condition)

"""
    tapmapif(condition::Function, f::Function, taproot)

Deepcopy a taproot and then modify its nodes in place if they satisfy `condition`. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmapif(condition::Function, f::Function, taproot) = maphelper!(f, taproot, condition)

"""
    leafmap!(f::Function, taproot)

Modify the leaves of a taproot in place.
"""
leafmap!(f::Function, taproot) = maphelper!(f, taproot, isleaf)

"""
    leafmap(f::Function, taproot)

Deepcopy a taproot and then modify its leaves in place.
"""
leafmap(f::Function, taproot) = leafmap!(f, deepcopy(taproot))


"""
    branchmap!(f::Function, taproot)

Modify the branches of a taproot in place without destroying links to children.
"""
branchmap!(f::Function, taproot) = maphelper!(f, taproot, isbranch)

"""
    branchmap(f::Function, taproot)

Deepcopy a taproot and then modify its branches in place without destroying links to children.
"""
branchmap(f::Function, taproot) = branchmap!(f, deepcopy(taproot))


function prunehelper!(condition, f, taproot)
    for node in preorder(taproot)
        setchildren!(node,
            deleteat!(children(taproot), findall(x -> !f(x) && condition(x), children(taproot)))
        )
    end
    return taproot
end

function prunehelper(condition, f, taproot)
    main_node = _copy_or_reconstruct(taproot)
    for node in preorder(main_node)
        setchildren!(node,
            deleteat!(_copy_or_reconstruct.(children(taproot)), findall(x -> !f(x) && condition(x), children(taproot)))
        )
    end
    return main_node
end


"""
    prune!(f::Function, taproot)

This removes any children who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that child. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
prune!(f::Function, taproot) = prunehelper!(f, taproot, x -> true)

"""
    prune(f::Function, taproot)

This deepcopies the taproot and then removes any children who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that child. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
prune(f::Function, taproot) = prunehelper(f, taproot, x -> true)

"""
    leafprune!(f::Function, taproot)

This removes any leaves of the taproot who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
leafprune!(f::Function, taproot) = prunehelper!(f, taproot, isleaf)

"""
    prune(f::Function, taproot)

This deepcopies the taproot and then removes any leaves who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
leafprune(f::Function, taproot) = prunehelper(f, taproot, isleaf)

"""
    branchprune!(f::Function, taproot)

This removes any leaves of the taproot who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
branchprune!(f::Function, taproot) = prunehelper!(f, taproot, isbranch)

"""
    prune(f::Function, taproot)

This deepcopies the taproot and then removes any leaves who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
branchprune(f::Function, taproot) = prunehelper(f, taproot, isbranch)

###########################################################################
# Visualisation
###########################################################################

@userplot PlotTree

@recipe function f(x::PlotTree)
    t = x.args[1]
    adj = treeadjacency(t)
    names --> sprint.(show, topdown(t))
    method := :buchheim
    root --> :top
    arrow --> true
    fontsize --> 12
    nodeshape --> :ellipse
    nodecolor --> :steelblue2
    shorten --> 0.05
    edgewidth --> (s,d,w) -> 1.75
    GraphRecipes.GraphPlot((adj,))
end

@userplot PlotDag

@recipe function f(x::PlotDag)
    t = x.args[1]
    adj = dagadjacency(t)
    names --> sprint.(show, topdown(t))
    arrow --> true
    fontsize --> 12
    nodecolor --> :steelblue2
    shorten --> 0.05
    edgewidth --> (s,d,w) -> 1.75
    GraphRecipes.GraphPlot((adj,))
end

"""
    @sprout YourType

This just sets AbstractTrees.children(x::YourType) = Taproots.children(x::YourType). Must be used before you can bloom or @bloom.
"""
macro sprout(my_type)
    my_type_esc = esc(my_type)
    quote AbstractTrees.children(x::$(my_type_esc)) = children(x) end
end

"""
    bloom(io::IO, taproot)

Pretty print a taproot. Requires you to have used @sprout YourType for it to work.
"""
function bloom(io::IO, taproot)
    println(io, Tree(taproot))
end
bloom(taproot) = bloom(stdout, taproot)

macro bloom(taproot)
    tappy = esc(taproot)
    quote bloom($(tappy)) end
end

@sprout Taproot

end  # module Taproots