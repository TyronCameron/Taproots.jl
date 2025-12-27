#─────────────────────────────────────────────────────────────────────────────#
# Iteration
#─────────────────────────────────────────────────────────────────────────────#
    # The core iteration functions


## Public facing API
##────────────────────────────────────────────────────────────────────────────#

"""
    preorder([children::Function], taproots...; kwargs...)

Args:

- `children::Function` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector::Function`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`

This creates a lazy iterator as a preorder depth-first search of your custom Taproot.
In this iterator, parents are always iterated on before their children.
Unlike usual preorder depth-first search, this one will iterate on rightmost children first before doing leftmost children.

# Example

```julia
for x in preorder(x)
    print(x)
end

collect(preorder(x)) <: Vector
```
"""
preorder(args...; kwargs...) = standardised_iterate_taproot(Preorder, args...; kwargs...)

"""
    postorder([children::Function], taproots...; kwargs...)

Args:

- `children::Function` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector::Function`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`

This creates a lazy iterator as a postorder depth-first search of your custom Taproot.
In this iterator, children are always iterated on before their parents. Parents will immediately follow their children (so some (possibly irrelevant) children may not be iterated before the parent above them).

# Usage
```julia
for x in postorder(x)
    print(x)
end

collect(postorder(x)) <: Vector
```
"""
postorder(args...; kwargs...) = standardised_iterate_taproot(Postorder, args...; kwargs...)

"""
    topdown([children::Function], taproots...; kwargs...)

Args:

- `children::Function` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector::Function`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`


This creates a lazy iterator as a topdown (level-order) breadth-first search of your custom Taproot.
The top parents are iterated first, and then the next level down, and so on. All parents are guaranteed to be iterated on before the leaves.

# Usage
```julia
for x in topdown(x)
    print(x)
end

collect(topdown(x)) <: Vector
```
"""
topdown(args...; kwargs...) = standardised_iterate_taproot(Topdown, args...; kwargs...)

"""
    bottomup([children::Function], taproots...; kwargs...)

Args:

- `children::Function` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector::Function`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`

This creates an eager iterator as a bottomup (reverse level-order) breadth-first search of your custom Taproot. This is topological order.
The bottom children are iterated first, and then the next layer up and so on. Leaves are not technically guaranteed to be iterated on first, before parents.
While the other iterators are lazy, this one is eager. This iterator is, of course, not capable of running on taproots which are cyclical (and it will abandon the cycles automatically).

# Usage
```julia
for x in bottomup(x)
    print(x)
end

collect(bottomup(x)) <: Vector
```
"""
bottomup(args...; kwargs...) = standardised_iterate_taproot(Bottomup, args...; kwargs...)

"""
    leaves([children,] taproot; kwargs...)

Shorthand for `Iterators.filter(isleaf, preorder([children,] taproot; kwargs...))`. 
Only works for `eltype = Node`. 

"""
leaves(args...; kwargs...) = Iterators.filter(isleaf, preorder(args...; kwargs...))

"""
    branches([children,] taproot; kwargs...)

Shorthand for `Iterators.filter(isbranch, preorder([children,] taproot; kwargs...))`.
Only works for `eltype = Node`.
"""
branches(args...; kwargs...) = Iterators.filter(isbranch, preorder(args...; kwargs...))

"""
    traces([children,] taproot; kwargs...)

Shorthand for `preorder(args...; kwargs..., eltype = Trace)`.
"""
traces(args...; kwargs...) = preorder(args...; kwargs..., eltype = Trace)

"""
    tracepairs([children,] taproot; kwargs...)

Shorthand for `preorder(args...; kwargs..., eltype = (Trace, Node))`.
"""
tracepairs(args...; kwargs...) = preorder(args...; kwargs..., eltype = (Trace, Node))


## Standardise args and multi taproots
##────────────────────────────────────────────────────────────────────────────#

function standardised_iterate_taproot(walk_order::Type{<:WalkOrder}, taproots...; kwargs...) # no children function
    standardised_iterate_taproot(walk_order, children, taproots...; kwargs...)
end 

function standardised_iterate_taproot( # Allow passing the `children` function
    walk_order::Type{<:WalkOrder},
    children::Function, 
    taproots...; 
    connector::Function = (node, child) -> true, 
    pathset::Type{<:PathSet} = OncePerNode, 
    eltype::Union{Type{<:Shoot}, Tuple} = Node
)
    iterate_multi_taproot(
        walk_order,
        children,
        taproots; 
        connector = connector, 
        pathset = pathset, 
        eltype = eltype
    )
end 

# For a set of Taproots, I think just create a single parent which has all the listed taproots as children
# That way, all nodes are iterated over in the correct order, even bottomup and topdown
# The MultiTaproot just can't be part of the final result
struct MultiTaproot
    children 
end 
children(x::MultiTaproot) = x.children

function iterate_multi_taproot( 
    walk_order,
    children,
    taproots; 
    connector = (node, child) -> true, 
    pathset = AllPaths, 
    eltype = Node
)
    if length(taproots) == 1
        return walk(walk_order, initpathset(pathset), eltype, children, connector, taproots[begin])
    end 
    return Iterators.drop(walk(walk_order, initpathset(pathset), eltype, children, connector, MultiTaproot(collect(taproots))), 1)
end

## Walk in different orders
##────────────────────────────────────────────────────────────────────────────#

### Preorder

@resumable function walk(::Type{Preorder}, pathset, eltype, children, connector, root)
    stack = StackFrontier{NamedTuple}([initshoot(eltype, root)])
    while !isempty(stack)
        shoot, node, level = take!(stack)
        if !visitnode(pathset, node) continue end 
        @yield takeshoot(eltype, shoot)
        for (i, child) in enumerate(children(node))
            if !connector(node, child) || !visitchild(pathset, node, child) continue end 
            put!(stack, putshoot(eltype, shoot, (node = child, levelincrement = 1, i = i))) 
        end 
        tracknode!(pathset, node, level)
    end
end

### Postorder

@resumable function walk(::Type{Postorder}, pathset, eltype, children, connector, root)
    stack = PostorderStackFrontier{NamedTuple}([initshoot(eltype, root)], [false])
    while !isempty(stack)
        shoot, node, level, seen = take!(stack)
        if seen
            @yield takeshoot(eltype, shoot)
        else
            if !visitnode(pathset, node) continue end
            put!(stack, (shoot, true))
            for (i, child) in enumerate(children(node))
                if !connector(node, child) || !visitchild(pathset, node, child) continue end 
                put!(stack, (putshoot(eltype, shoot, (node = child, levelincrement = 1, i = i)), false))
            end
            tracknode!(pathset, node, level)
        end
    end
end

### Topdown

@resumable function walk(::Type{Topdown}, pathset, eltype, children, connector, root)
    queue = QueueFrontier{Union{<:NamedTuple, Nothing}}([initshoot(eltype, root)], 1)
    while !isempty(queue)
        shoot, node, level = take!(queue)
        if !visitnode(pathset, node) continue end 
        @yield takeshoot(eltype, shoot)
        for (i, child) in enumerate(children(node))
            if !connector(node, child) || !visitchild(pathset, node, child) continue end 
            put!(queue, putshoot(eltype, shoot, (node = child, levelincrement = 1, i = i))) 
        end 
        tracknode!(pathset, node, level)
    end
end

### Bottomup 

@resumable function walk(::Type{Bottomup}, pathset, eltype, children, connector, root)
    leaves = filter(x -> isleaf(x[end]), preorder(children, root; pathset = NoCycles, connector = connector, eltype = (Trace, Node)) |> collect)
    tracequeue = BottomupFrontier(root, map(x -> x[begin], leaves))
    tracepathset = initpathset(OncePerNode)
    childrenvisited = Set()
    while !isempty(tracequeue)
        node, trace, level = take!(tracequeue)
        if !isempty(trace) put!(tracequeue, trace[begin:end-1]) end
        if any(child -> connector(node, child) && child ∉ childrenvisited, children(node)) continue end # leave node for later if any connected unvisited child
        should_visit_node = visitnode(pathset, node)
        tracknode!(pathset, node, level)
        should_visit_trace = visitnode(tracepathset, trace)
        tracknode!(tracepathset, trace, level)
        if !should_visit_node || !should_visit_trace continue end # Must be separate to track 
        push!(childrenvisited, node)
        @yield takeshoot(eltype, (level = level, trace = trace, node = node))
    end
end

function walk_bottomup(ch, root; revisit = false, connector = x -> true)
    leaves = filter(x -> isleaf(x[end]), tracepairs(root; revisit = true, connector = x -> !ischild(x, x; revisit = true) && connector(x)) |> collect)
    tracequeue = map(x -> x[begin], leaves)
    visited = Set()
    visitedtraces = Set()
    childrenvisited = Set()
    while !isempty(tracequeue)
        orig_trace = popfirst!(tracequeue)
        node = pluck(root, orig_trace)
        trace = copy(orig_trace)
        if !isempty(trace)
            pop!(trace)
            push!(tracequeue, trace)
        end
        if any(child -> child ∉ childrenvisited, children(connector, node)) continue end 
        node_visited = visited!(node, visited, revisit)
        trace_visited = visited!(orig_trace, visitedtraces)
        if node_visited || trace_visited continue end # list separately so we don't shortcircuit
        push!(childrenvisited, node)
        put!(ch, node)
    end
end