module Taproots
using Plots.RecipesBase, GraphRecipes, AbstractTrees
export Taproot, children, ischild, isparent, isleaf, isbranch, preorder, postorder, topdown, bottomup, leaves, branches, adjacencymatrix, leafmap!, leafmap, branchmap!, branchmap, prune!, prune, leafprune!, leafprune, branchprune!, branchprune,
tapin, tapout, doubletap, gettrace, followtrace, @taptotree

###########################################################################
# Taproot sink
###########################################################################

"""
A Taproot is a single node that that can contain other Taproots. It can itself be contained in a parent Taproot.
It is not the main point of this package, but provides a convenience to persist structure when doing maps or other transformations.

You can construct a Taproot either by: 
- Taproot(data, children) where `data` is anything that you'd like to store in this node, and `children` is an iterable list of children 
- Taproot(node) where `node` is some value that has Taproot.children defined on it. This will recurvisely sink your object into a Taproot

"""
mutable struct Taproot
    data
    children::Vector{Taproot}
end
Taproot(node) = Taproot(node, Taproot[Taproot(child) for child in children(node)])

"""
    tapin(sink::Function, node)

Another way to access the recursive Taproot constructor, using a custom sink to collect data and children.
The sink must follow the following structure:
    sink(one_of_your_nodes)
It must return a data value that you'd like to store. The children will be automatically inferred from the `Taproots.children` function.
If you don't provide a sink, it treats it as the identity function. 
"""
tapin(sink::Function, node) = Taproot(sink(node), Taproot[tapin(sink, child) for child in children(node)])
tapin(node) = tapin(x -> x, node)

function maphelper!(f, taproot::Taproot, iter)
    for node in iter(taproot)
        node.data = f(node.data)
    end
    return taproot
end

Base.map!(f::Function, taproot::Taproot) = maphelper!(f, taproot, preorder)
Base.map(f::Function, taproot::Taproot) = map!(f, deepcopy(taproot))

"""
    leafmap!(f::Function, taproot::Taproot)

Modify the leaves of a Taproot in place. 
"""
leafmap!(f::Function, taproot::Taproot) = maphelper!(f, taproot, leaves)

"""
    leafmap(f::Function, taproot::Taproot)

Deepcopy a Taproot and then modify its leaves in place. 
"""
leafmap(f::Function, taproot::Taproot) = leafmap!(f, deepcopy(taproot))


"""
    branchmap!(f::Function, taproot::Taproot)

Modify the branches of a Taproot in place without destroying links to children.
"""
branchmap!(f::Function, taproot::Taproot) = maphelper!(f, taproot, branches)

"""
    branchmap(f::Function, taproot::Taproot)

Deepcopy a Taproot and then modify its branches in place without destroying links to children.
"""
branchmap(f::Function, taproot::Taproot) = branchmap!(f, deepcopy(taproot))

function prunehelper!(f, taproot::Taproot, condition)
    deleteat!(taproot.children, findall(x -> !f(x) && condition(x), taproot.children))
    for child in taproot.children prunehelper!(f, child, condition) end
    return taproot
end

"""
    prune!(f::Function, taproot::Taproot)

This removes any children who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that child. This is similar to `filter`
"""
prune!(f::Function, taproot::Taproot) = prunehelper!(f, taproot, x -> true)

"""
    prune(f::Function, taproot::Taproot)

This deepcopies the taproot and then removes any children who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that child. This is similar to `filter`
"""
prune(f::Function, taproot::Taproot) = prune!(f, deepcopy(taproot))

"""
    leafprune!(f::Function, taproot::Taproot)

This removes any leaves of the taproot who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`
"""
leafprune!(f::Function, taproot::Taproot) = prunehelper!(f, taproot, isleaf)

"""
    prune(f::Function, taproot::Taproot)

This deepcopies the taproot and then removes any leaves who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`
"""
leafprune(f::Function, taproot::Taproot) = leafprune!(f, deepcopy(taproot))

"""
    branchprune!(f::Function, taproot::Taproot)

This removes any leaves of the taproot who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`
"""
branchprune!(f::Function, taproot::Taproot) = prunehelper!(f, taproot, isbranch)

"""
    prune(f::Function, taproot::Taproot)

This deepcopies the taproot and then removes any leaves who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`
"""
branchprune(f::Function, taproot::Taproot) = branchprune!(f, deepcopy(taproot))

"""
    tapout(sink::Function, taproot::Taproot)

This allows you to transform a Taproots.Taproot struct back into one of your own structs. The `sink` function needs to be able to transform a single node of a Taproot into a node in your struct. 
The sink follows the following structure:
    sink(data, children)::YourType

As a simple example, let's say we have

struct YourType 
    printable_name::String
    id::UUID
    data
    children::Vector{YourType}
end
Taproots.children(x::YourType) = x.children

Then you can convert that to a taproot as follows:

your_type = ... 
your_taproot = Taproot(your_type)
modified_taproot = prune(x -> !isempty(x.data) && 1 <= length(printable_name) <= 100, your_taproot)
your_modified_type = tapout((data, children) -> YourType(data.printable_name, data.id, data.data, children), modified_taproot)
"""
tapout(sink::Function, taproot::Taproot) = sink(taproot.data, tapout.(sink, taproot.children))

"""
    doubletap(f, sink_in::Function, sink_out::Function, my_type)
    doubletap(f, sink_out::Function, my_type)
    
A convenience function that does tapin and tapout for you in one go.
Use it as follows
my_modified_tree = doubletap(sink_out, my_type) do taproot
    map!(x -> x.data^2, taproot)
    prune!(x -> x < 25, taproot)
end

`sink_out` is a function that takes in `data` and `children` and needs to map to an object of the variety you want to get out. 
"""
doubletap(f, sink_in::Function, sink_out::Function, my_type) = tapout(sink_out, f(tapin(sink_in, my_type)))
doubletap(f, sink_out::Function, my_type) = doubletap(f, x -> x, sink_out, my_type)


###########################################################################
# Abstract API
###########################################################################

"""
    children(x)

Gets the children nodes in a Taproot DAG (if defined) of x. This function is meant to be overridden to access Taproot functionality on your own types. 

By default, children(x) will return an empty array, meaning Taproot considers x to be a graph with a singular node (unless you overload this function.) 

# Overriding this function

Simply define Taproot.children(x::MyType) = ... 
Where the ... returns a vector of the things you want to traverse.

"""
children(x) = []
children(expr::Expr) = expr.args
children(x::NamedTuple) = [x[y] for y in fieldnames(typeof(x))]
children(x::Dict) = values(x) |> collect
children(x::Vector) = x
children(x::Taproot) = x.children

"""
    ischild(potential_child, parent)::Bool

Tells you whether `potential_child` is a child of `parent`. This function acts recursively and is not the same as doing `potential_child ∈ children(parent)`. 
Time complexity of this is ~linear in the number of edges in your DAG underneath the `parent`, so use with care for large DAGs.

"""
function ischild(potential_child, parent)  
    for child in children(parent)
        if potential_child == child || ischild(potential_child, child)
            return true
        end
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


function walk_preorder(ch, node)
    put!(ch, node)
    walk_preorder.([ch], children(node))
end

function walk_postorder(ch, node)
    walk_postorder.([ch], children(node))
    put!(ch, node)
end

function unvisited!(node, visited)
    if node ∈ visited return false end
    push!(visited, node)
    return true
end

function walk_topdown(ch, node, visited = Set{Any}())
    unvisited!(node, visited) && put!(ch, node)
    unvisited = filter(child -> unvisited!(child, visited), children(node))
    put!.([ch], unvisited)
    for child in unvisited walk_topdown(ch, child, visited) end
end

function walk_leaves(ch, node)
    isleaf(node) && put!(ch, node)
    walk_leaves.([ch], children(node))
end

function walk_branches(ch, node)
    isbranch(node) && put!(ch, node)
    walk_branches.([ch], children(node))
end

"""
    preorder(x)

This creates a lazy iterator as a preorder depth-first search of your custom Taproot.
In this iterator, parents are always iterated on before their children.

# Usage

for x in preorder(x)
    print(x)
end 

collect(preorder(x)) <: Vector

"""
preorder(taproot) = Channel(ch -> walk_preorder(ch, taproot)) 

"""
    postorder(x)

This creates a lazy iterator as a postorder depth-first search of your custom Taproot. This is topological order and most of the time, you're looking for this. 
In this iterator, children are always iterated on before their parents. Parents will immediately follow their children (so some (possibly irrelevant) children may not be iterated before the parent above them).

# Usage

for x in postorder(x)
    print(x)
end 

collect(postorder(x)) <: Vector

"""
postorder(taproot) = Channel(ch -> walk_postorder(ch, taproot)) 

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
topdown(taproot) = Channel(ch -> walk_topdown(ch, taproot)) 


"""
    bottomup(x)

This creates an eager iterator as a bottomup (reverse level-order) breadth-first search of your custom Taproot.
The bottom children are iterated first, and then the next layer up and so on. Leaves are not technically guaranteed to be iterated on first, before parents. 
While the other iterators are lazy, this one is eager, and will actually return a vector. 

# Usage

for x in bottomup(x)
    print(x)
end 

bottomup(x) <: Vector
collect(bottomup(x)) <: Vector

"""
bottomup(taproot) = reverse(collect(topdown(taproot)))

"""
    leaves(x)

This creates a lazy iterator for the leaves (those nodes which have no children) of your custom Taproot.

# Usage

for x in leaves(x)
    print(x)
end 

collect(leaves(x)) <: Vector

"""
leaves(taproot) = Channel(ch -> walk_leaves(ch, taproot)) 

"""
    branches(x)

This creates a lazy iterator for the branches (those nodes which have children) of your custom Taproot.

# Usage

for x in branches(x)
    print(x)
end 

collect(branches(x)) <: Vector

"""
branches(taproot) = Channel(ch -> walk_branches(ch, taproot)) 

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
    gettrace(f, parent)

This is a slower (~linear) algorithm to find the first value where `f` returns true. It returns a vector which can be used to index into a nested data struct.
You can index into your nested data structure using followtrace.
"""
function gettrace(matcher::Function, parent; trace = Int[])
    if matcher(parent) return trace end
    for (i, child) in enumerate(children(parent))
        new_trace = gettrace(matcher, child; trace = push!(copy(trace), i))
        if new_trace !== nothing return new_trace end
    end
    return nothing 
end
gettrace(child, parent) = gettrace(x -> x == child, parent)

"""
    followtrace(parent, trace)

This is a faster algorithm to get the node which matches a trace. A trace is simply an iterable set of indices.
"""
followtrace(parent, trace) = foldl((current, idx) -> children(current)[idx], trace; init = parent)

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

macro taptotree(my_type)
    my_type_esc = esc(my_type)
    Base.@eval import AbstractTrees
    quote AbstractTrees.children(x::$(my_type_esc)) = children(x) end
end

end  # module Taproots