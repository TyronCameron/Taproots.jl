#─────────────────────────────────────────────────────────────────────────────#
# Iteration
#─────────────────────────────────────────────────────────────────────────────#


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
Base.@constprop :aggressive preorder(args...; kwargs...) = standardised_iterate_taproot(Preorder, args...; kwargs...)

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
Base.@constprop :aggressive postorder(args...; kwargs...) = standardised_iterate_taproot(Postorder, args...; kwargs...)

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
Base.@constprop :aggressive topdown(args...; kwargs...) = standardised_iterate_taproot(Topdown, args...; kwargs...)

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
Base.@constprop :aggressive bottomup(args...; kwargs...) = standardised_iterate_taproot(Bottomup, args...; kwargs...)

"""
    leafbatches([children], taproots...; kwargs...)

Args:

- `children` is an optional function taking in a taproot and returning an iterator of children taproots. If supplied, this iterator will not revert to using the `Taproots.children` function. 
- `taproots` are the root nodes we'd like to iterate through 

Supports `kwargs` include:

- `connector`, this is a function which takes in the current `node` and a `child` node and if it resolves to `true`, you will visit that child node
- `pathset::Type{<:PathSet}`, this is a selection of how many times to visit each node / edge. Options include: `AllPaths`, `NoCycles`, `OncePerNode`, `OncePerEdge`
- `eltype::Union{Type{<:Shoot}, Tuple}`, this determines what each batch holds. Options include: `Node`, `Level`, `Trace`, or combinations such as `(Node, Level, Trace)`
- `sizeguess::Int = 256`, a guess of how many nodes the taproot holds, used to preallocate internal tracking structures

This creates an eager iterator of batches (vectors) of nodes. The first batch is `leaves(taproots...)`.
Each later batch holds the nodes whose connected children all sit in earlier batches: the leaves you would get if you plucked off every batch before it.
Flattening the batches gives exactly `bottomup`, so a node lands in the batch numbered by its height above the leaves.

Nothing within a batch depends on anything else in that batch, so each batch can be processed in parallel.
Like `bottomup`, this abandons cycles (and everything above them), and the `connector` is evaluated once per edge, up front.

# Usage
```julia
for batch in leafbatches(x; connector = (node, child) -> !isdone(child))
    Threads.@threads for node in batch
        process!(node)
    end
end
```
"""
Base.@constprop :aggressive leafbatches(args...; kwargs...) = standardised_iterate_taproot(Leafbatches, args...; kwargs...)

"""
    leaves([children,] taproot; kwargs...)

Like `preorder([children,] taproot; kwargs...)`, but only yields the nodes for which `isleaf([children,] node; connector)` holds.
"""
Base.@constprop :aggressive leaves(args...; kwargs...) = filterwalk(isleaf, args...; kwargs...)

"""
    branches([children,] taproot; kwargs...)

Like `preorder([children,] taproot; kwargs...)`, but only yields the nodes for which `isbranch([children,] node; connector)` holds.
"""
Base.@constprop :aggressive branches(args...; kwargs...) = filterwalk(isbranch, args...; kwargs...)

"""
    traces([children,] taproot; kwargs...)

Shorthand for `preorder(args...; kwargs..., eltype = Trace)`.
"""
Base.@constprop :aggressive traces(args...; kwargs...) = preorder(args...; kwargs..., eltype = Trace)

"""
    tracepairs([children,] taproot; kwargs...)

Shorthand for `preorder(args...; kwargs..., eltype = (Trace, Node))`.
"""
Base.@constprop :aggressive tracepairs(args...; kwargs...) = preorder(args...; kwargs..., eltype = (Trace, Node))


## Standardise args and multi taproots
##────────────────────────────────────────────────────────────────────────────#

alwaysconnect(node, child) = true

Base.@constprop :aggressive function standardised_iterate_taproot(walk_order::Type{<:WalkOrder}, taproot, taproots...; kwargs...)
    standardised_iterate_taproot(walk_order, children, taproot, taproots...; kwargs...)
end

Base.@constprop :aggressive function standardised_iterate_taproot(
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

"""
    filterwalk(keep, [children], taproots...; kwargs...)

A preorder walk keeping only the nodes for which `keep(children, node; connector)` holds.
The node rides along with the requested shoots, so any `eltype` works.
"""
Base.@constprop :aggressive filterwalk(keep, taproot, taproots...; kwargs...) = filterwalk(keep, children, taproot, taproots...; kwargs...)
Base.@constprop :aggressive function filterwalk(keep, children::Union{Function, Type}, taproot, taproots...; connector = alwaysconnect, eltype = Node, kwargs...)
    walk = preorder(children, taproot, taproots...; connector, eltype = (Node, eltype), kwargs...)
    return (shoot for (node, shoot) in walk if keep(children, node; connector))
end

"""
    MultiTaproot(children)

A synthetic parent of several taproots, so that walking it visits all of their nodes in the correct order, even bottomup and topdown.
It is never yielded itself.
"""
struct MultiTaproot{T}
    children::T
end
children(x::MultiTaproot) = x.children

shouldyield(shoots, node) = !(node isa MultiTaproot)
shouldyield(::WholeSprout, node) = true

Base.@constprop :aggressive function iterate_multi_taproot(
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

const FRESH = 0x00
const SUSPENDED = 0x01
const FINISHED = 0x02

"""
    Walk

A lightweight coroutine. `walk!` runs a walk's loop until it hits `@yield`, which parks the current sprout and the yielded value in the `Walk` and returns.
The next `walk!` call starts with `@resume`, which jumps straight back to just after that `@yield`, so the loop carries on exactly where it left off.
Every field is concretely typed, so walks are type stable and yielding a tuple or struct never allocates.

- `sprout`: the sprout held at the last `@yield`, the only local still needed after a yield
- `value`: the last yielded value
- `state`: `FRESH`, `SUSPENDED` or `FINISHED`
"""
mutable struct Walk{O <: WalkOrder, T, F, P, Sh, C, K, S}
    frontier::F
    pathset::P
    shoots::Sh
    children::C
    connector::K
    sprout::S
    value::T
    state::UInt8
    function Walk{O, T}(frontier::F, pathset::P, shoots::Sh, children::C, connector::K, sprout::S) where {O, T, F, P, Sh, C, K, S}
        walker = new{O, T, F, P, Sh, C, K, S}(frontier, pathset, shoots, children, connector, sprout)
        walker.state = FRESH
        return walker
    end
end

Base.eltype(::Type{<:Walk{O, T}}) where {O, T} = T
Base.IteratorSize(::Type{<:Walk}) = Base.SizeUnknown()
@inline Base.iterate(walker::Walk, state = nothing) = walk!(walker) ? (walker.value, nothing) : nothing

function Base.collect(walker::Walk{O, T}) where {O, T}
    out = T[]
    if walker.state === FRESH
        walk!(walker, x -> push!(out, x))
    else
        for x in walker push!(out, x) end
    end
    return out
end

walkparts(walker::Walk) = (walker.frontier, walker.pathset, walker.shoots, walker.children, walker.connector)
finish!(walker::Walk) = (walker.state = FINISHED; false)

"""
    @yield value

Inside `walk!(walker, sink)`: hands `value` out of the walk, remembering `sprout`. The matching `@resume` jumps back to the label right after this.
With a `sink`, the walk runs eagerly instead: `value` goes to `sink` and the loop carries on.
"""
macro yield(value)
    esc(quote
        if sink === nothing
            walker.value = $value
            walker.sprout = sprout
            walker.state = $SUSPENDED
            return true
            @label resume
        else
            sink($value)
        end
    end)
end

"""
    @resume walker

The first line of `walk!(walker)`: carries on from the last `@yield`, if there was one.
"""
macro resume(walker)
    esc(quote
        $walker.state === $FINISHED && return false
        if sink === nothing && $walker.state === $SUSPENDED
            sprout = $walker.sprout
            node = nodeof(sprout)
            @goto resume
        end
    end)
end

function buildwalk(walk_order, shoots, children, connector, pathset, root; sizeguess = 256)
    N = childtypes(root)
    S = sprouttype(shoots, N)
    frontier = initfrontier(walk_order, S, shoots, children, connector, pathset, root, sizeguess)
    return Walk{walk_order, walkeltype(walk_order, yieldtype(shoots, S))}(frontier, initpathset(pathset, N; sizeguess), shoots, children, connector, initsprout(S, root))
end

walkeltype(walk_order, ::Type{T}) where T = T
walkeltype(::Type{Leafbatches}, ::Type{T}) where T = Vector{T}

firstsprout(::Type{S}, shoots, root, sizeguess = 8) where S = sizehint!(S[initsprout(S, root)], sizeguess)
initfrontier(::Type{Preorder}, ::Type{S}, shoots, children, connector, pathset, root, sizeguess = 8) where S = StackFrontier{S}(firstsprout(S, shoots, root))
initfrontier(::Type{Postorder}, ::Type{S}, shoots, children, connector, pathset, root, sizeguess = 8) where S = PostorderStackFrontier{S}(firstsprout(S, shoots, root), sizehint!([false], sizeguess))
initfrontier(::Type{Topdown}, ::Type{S}, shoots, children, connector, pathset, root, sizeguess = 8) where S = QueueFrontier{S}(firstsprout(S, shoots, root), 1)
function initfrontier(::Type{Bottomup}, ::Type{S}, shoots, children, connector, ::Type{P}, root, sizeguess = 8) where {S, P}
    mappath = P <: OncePerNode ? OncePerNode : NoCycles
    premap = buildwalk(Preorder, WholeSprout(shoots), children, connector, mappath, root; sizeguess)
    return BottomupFrontier(collect(premap), children, connector, mappath)
end
initfrontier(::Type{Leafbatches}, args...) = initfrontier(Bottomup, args...)

## Walk in different orders
##────────────────────────────────────────────────────────────────────────────#

### Preorder

function walk!(walker::Walk{Preorder}, sink = nothing)
    stack, pathset, shoots, children, connector = walkparts(walker)
    @resume walker
    while !isempty(stack)
        sprout = take!(stack)
        node = nodeof(sprout)
        if !visitnode(pathset, node, levelof(sprout)) continue end
        if shouldyield(shoots, node)
            @yield takeshoot(shoots, sprout)
        end
        for (i, child) in enumerate(children(node))
            if !connector(node, child) || !visitchild(pathset, node, child) continue end
            put!(stack, putsprout(sprout, child, i))
        end
        tracknode!(pathset, node, levelof(sprout))
    end
    return finish!(walker)
end

### Postorder

function walk!(walker::Walk{Postorder}, sink = nothing)
    stack, pathset, shoots, children, connector = walkparts(walker)
    @resume walker
    while !isempty(stack)
        sprout, seen = take!(stack)
        if seen
            if shouldyield(shoots, nodeof(sprout))
                @yield takeshoot(shoots, sprout)
            end
        else
            node = nodeof(sprout)
            if !visitnode(pathset, node, levelof(sprout)) continue end
            put!(stack, sprout, true)
            for (i, child) in enumerate(children(node))
                if !connector(node, child) || !visitchild(pathset, node, child) continue end
                put!(stack, putsprout(sprout, child, i), false)
            end
            tracknode!(pathset, node, levelof(sprout))
        end
    end
    return finish!(walker)
end

### Topdown

function walk!(walker::Walk{Topdown}, sink = nothing)
    queue, pathset, shoots, children, connector = walkparts(walker)
    @resume walker
    while !isempty(queue)
        sprout = take!(queue)
        node = nodeof(sprout)
        if !visitnode(pathset, node, levelof(sprout)) continue end
        if shouldyield(shoots, node)
            @yield takeshoot(shoots, sprout)
        end
        for (i, child) in enumerate(children(node))
            if !connector(node, child) || !visitchild(pathset, node, child) continue end
            put!(queue, putsprout(sprout, child, i))
        end
        tracknode!(pathset, node, levelof(sprout))
    end
    return finish!(walker)
end

### Bottomup

function walk!(walker::Walk{Bottomup}, sink = nothing)
    frontier, pathset, shoots, children, connector = walkparts(walker)
    @resume walker
    while !isempty(frontier)
        sprout = take!(frontier)
        node = nodeof(sprout)
        should_visit_node = visitnode(pathset, node, levelof(sprout))
        tracknode!(pathset, node, levelof(sprout))
        if !should_visit_node continue end
        if shouldyield(shoots, node)
            @yield takeshoot(shoots, sprout)
        end
    end
    return finish!(walker)
end

### Leafbatches

function walk!(walker::Walk{Leafbatches, Vector{T}}, sink = nothing) where T
    frontier, pathset, shoots, children, connector = walkparts(walker)
    sprout = walker.sprout
    @resume walker
    while !isempty(frontier)
        batch = T[]
        for _ in 1:readycount(frontier)
            sprout = take!(frontier)
            node = nodeof(sprout)
            should_visit_node = visitnode(pathset, node, levelof(sprout))
            tracknode!(pathset, node, levelof(sprout))
            if should_visit_node && shouldyield(shoots, node) push!(batch, takeshoot(shoots, sprout)) end
        end
        if !isempty(batch)
            @yield batch
        end
    end
    return finish!(walker)
end
