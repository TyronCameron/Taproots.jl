#─────────────────────────────────────────────────────────────────────────────#
# Iteration
#─────────────────────────────────────────────────────────────────────────────#
    # The core iteration functions


## Public facing API
##────────────────────────────────────────────────────────────────────────────#

"""
    preorder([children], taproots...; kwargs...)

Args:

- `children` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`
- `sizeguess::Int = 256`, a guess of how many nodes the taproot holds, used to preallocate internal tracking structures

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
    postorder([children], taproots...; kwargs...)

Args:

- `children` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`
- `sizeguess::Int = 256`, a guess of how many nodes the taproot holds, used to preallocate internal tracking structures

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
    topdown([children], taproots...; kwargs...)

Args:

- `children` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`
- `sizeguess::Int = 256`, a guess of how many nodes the taproot holds, used to preallocate internal tracking structures


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
    bottomup([children], taproots...; kwargs...)

Args:

- `children` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what output you want. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`
- `sizeguess::Int = 256`, a guess of how many nodes the taproot holds, used to preallocate internal tracking structures

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

alwaysconnect(node, child) = true

function standardised_iterate_taproot(walk_order::Type{<:WalkOrder}, taproot, taproots...; kwargs...) # no children function
    standardised_iterate_taproot(walk_order, children, taproot, taproots...; kwargs...)
end

function standardised_iterate_taproot( # Allow passing the `children` function
    walk_order::Type{<:WalkOrder},
    children::Union{Function, Type},
    taproot,
    taproots...;
    connector = alwaysconnect,
    pathset::Type{<:PathSet} = OncePerNode,
    eltype::Union{Type{<:Shoot}, Tuple} = Node,
    sizeguess::Int = 256
)
    iterate_multi_taproot(
        walk_order,
        children,
        taproot,
        taproots;
        connector = connector,
        pathset = pathset,
        eltype = eltype,
        sizeguess = sizeguess
    )
end

# For a set of Taproots, I think just create a single parent which has all the listed taproots as children
# That way, all nodes are iterated over in the correct order, even bottomup and topdown
# The MultiTaproot just can't be part of the final result
struct MultiTaproot{T}
    children::T
end
children(x::MultiTaproot) = x.children

shouldyield(shoots, node) = !(node isa MultiTaproot) # single-root walks: constant-folds to true

function iterate_multi_taproot(
    walk_order,
    children,
    taproot,
    taproots;
    connector = alwaysconnect,
    pathset = AllPaths,
    eltype = Node,
    sizeguess = 256
)
    shoots = standardisedshoot(eltype)
    if length(taproots) == 0
        return buildwalk(walk_order, shoots, children, connector, pathset, taproot; sizeguess)
    end
    return buildwalk(walk_order, shoots, children, connector, pathset, MultiTaproot((taproot, taproots...)); sizeguess)
end

## Typed walk construction
##────────────────────────────────────────────────────────────────────────────#
    # Function barrier: compute the node type, the concrete sprout type, the
    # frontier and the typed pathset *before* entering the @resumable walk, so
    # that the state machine's fields are all concretely inferred. The FSM is
    # wrapped in a TypedWalk purely to give the iterator a concrete eltype.

struct TypedWalk{T, I}
    fsm::I
end
TypedWalk{T}(fsm) where T = TypedWalk{T, typeof(fsm)}(fsm)

Base.eltype(::Type{TypedWalk{T, I}}) where {T, I} = T
Base.IteratorSize(::Type{<:TypedWalk}) = Base.SizeUnknown()

function Base.iterate(w::TypedWalk{T}, state = nothing) where T
    result = iterate(w.fsm, state)
    result === nothing && return nothing
    return (first(result)::T, nothing)
end

function buildwalk(walk_order, shoots, children, connector, pathset, root; sizeguess = 256)
    N = childtypes(root)
    S = sprouttype(shoots, N)
    frontier = initfrontier(walk_order, S, shoots, children, connector, root, sizeguess)
    fsm = walk(walk_order, frontier, initpathset(pathset, N; sizeguess), shoots, children, connector)
    return TypedWalk{yieldtype(shoots, S)}(fsm)
end

const FRONTIER_SIZEGUESS = 8 # frontiers hold a "row" of the taproot at a time, so stay small

firstsprout(::Type{S}, shoots, root) where S = sizehint!(S[initsprout(shoots, nodetypeof(S), root)], FRONTIER_SIZEGUESS)

initfrontier(::Type{Preorder}, ::Type{S}, shoots, children, connector, root, sizeguess) where S = StackFrontier{S}(firstsprout(S, shoots, root))
initfrontier(::Type{Postorder}, ::Type{S}, shoots, children, connector, root, sizeguess) where S = PostorderStackFrontier{S}(firstsprout(S, shoots, root), sizehint!([false], FRONTIER_SIZEGUESS))
initfrontier(::Type{Topdown}, ::Type{S}, shoots, children, connector, root, sizeguess) where S = QueueFrontier{S}(firstsprout(S, shoots, root), 1)

function initfrontier(::Type{Bottomup}, ::Type{S}, shoots, children, connector, root, sizeguess) where S # eagerly map out the taproot in preorder
    states = allsprouts(S, shoots, children, connector, root, sizeguess)
    return BottomupFrontier(states, [k for (k, state) in enumerate(states) if isleaf(nodeof(state))], sizeguess)
end

# The eager twin of `walk(Preorder, ...)`: identical traversal, but pushes every
# sprout (incl. any synthetic multi-root parent) into a vector instead of
# yielding. Bottomup is eager anyway, and pushing eagerly avoids the state
# machine boxing each yielded sprout.
function allsprouts(::Type{S}, shoots, children, connector, root, sizeguess) where S
    stack = initfrontier(Preorder, S, shoots, children, connector, root, sizeguess)
    pathset = initpathset(NoCycles, nodetypeof(S); sizeguess)
    states = sizehint!(S[], sizeguess)
    while !isempty(stack)
        sprout = take!(stack)
        node = nodeof(sprout)
        if !visitnode(pathset, node) continue end
        push!(states, sprout)
        for (i, child) in enumerate(children(node))
            if !connector(node, child) || !visitchild(pathset, node, child) continue end
            put!(stack, putsprout(sprout, child, i))
        end
        tracknode!(pathset, node, levelof(sprout))
    end
    return states
end

## Walk in different orders
##────────────────────────────────────────────────────────────────────────────#

### Preorder

@resumable function walk(::Type{Preorder}, stack, pathset, shoots, children, connector)
    while !isempty(stack)
        sprout = take!(stack)
        node = nodeof(sprout)
        if !visitnode(pathset, node) continue end
        if shouldyield(shoots, node)
            @yield takeshoot(shoots, sprout)
        end
        for (i, child) in enumerate(children(node))
            if !connector(node, child) || !visitchild(pathset, node, child) continue end
            put!(stack, putsprout(sprout, child, i))
        end
        tracknode!(pathset, node, levelof(sprout))
    end
end

### Postorder

@resumable function walk(::Type{Postorder}, stack, pathset, shoots, children, connector)
    while !isempty(stack)
        sprout, seen = take!(stack)
        if seen
            if shouldyield(shoots, nodeof(sprout))
                @yield takeshoot(shoots, sprout)
            end
        else
            node = nodeof(sprout)
            if !visitnode(pathset, node) continue end
            put!(stack, sprout, true)
            for (i, child) in enumerate(children(node))
                if !connector(node, child) || !visitchild(pathset, node, child) continue end
                put!(stack, putsprout(sprout, child, i), false)
            end
            tracknode!(pathset, node, levelof(sprout))
        end
    end
end

### Topdown

@resumable function walk(::Type{Topdown}, queue, pathset, shoots, children, connector)
    while !isempty(queue)
        sprout = take!(queue)
        node = nodeof(sprout)
        if !visitnode(pathset, node) continue end
        if shouldyield(shoots, node)
            @yield takeshoot(shoots, sprout)
        end
        for (i, child) in enumerate(children(node))
            if !connector(node, child) || !visitchild(pathset, node, child) continue end
            put!(queue, putsprout(sprout, child, i))
        end
        tracknode!(pathset, node, levelof(sprout))
    end
end

### Bottomup

@resumable function walk(::Type{Bottomup}, frontier, pathset, shoots, children, connector)
    while !isempty(frontier)
        k, sprout, parent = take!(frontier)
        if frontier.completed[k] continue end # this path already completed via an earlier take
        node = nodeof(sprout)
        ready = true # only take this node once every connected child has been visited
        for child in children(node)
            if connector(node, child) && child ∉ frontier.visited
                ready = false
                break
            end
        end
        if !ready continue end # leave node for later; completing children re-enqueue this path
        frontier.completed[k] = true
        if parent != 0 put!(frontier, parent) end # node is done, so its parent becomes eligible
        should_visit_node = visitnode(pathset, node)
        tracknode!(pathset, node, levelof(sprout))
        if !should_visit_node continue end
        push!(frontier.visited, node)
        if shouldyield(shoots, node)
            @yield takeshoot(shoots, sprout)
        end
    end
end