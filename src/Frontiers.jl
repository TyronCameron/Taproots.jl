
#─────────────────────────────────────────────────────────────────────────────#
# Frontiers
#─────────────────────────────────────────────────────────────────────────────#

abstract type WalkOrder end
struct Preorder <: WalkOrder end
struct Postorder <: WalkOrder end
struct Topdown <: WalkOrder end
struct Bottomup <: WalkOrder end
struct Leafbatches <: WalkOrder end

"""
    Frontier

An incremental way of getting the next shoots of a walk, with one frontier per `WalkOrder`.
Each frontier is parametrised by the concrete shoot type it stores, so walks stay type stable, and implements:

- `put!(frontier, shoot)`: queue `shoot` so that it will be seen next
- `take!(frontier)`: pull the next shoot out of the queue
- `peek(frontier)`: see what is next without removing it
- `isempty(frontier)`: whether anything is left
"""
abstract type Frontier end

# Stack for Preorder
#─────────────────────────────────────────────────────────────────────────────

mutable struct StackFrontier{S} <: Frontier
    next::Vector{S}
end

put!(frontier::StackFrontier, shoot) = push!(frontier.next, shoot)
take!(frontier::StackFrontier) = pop!(frontier.next)
peek(frontier::StackFrontier) = last(frontier.next)
Base.isempty(frontier::StackFrontier) = isempty(frontier.next)


# Stack for Postorder
#─────────────────────────────────────────────────────────────────────────────

mutable struct PostorderStackFrontier{S} <: Frontier
    next::Vector{S}
    seen::Vector{Bool}
end

function put!(frontier::PostorderStackFrontier, shoot, seen::Bool)
    push!(frontier.next, shoot)
    push!(frontier.seen, seen)
end

take!(frontier::PostorderStackFrontier) = (pop!(frontier.next), pop!(frontier.seen))
peek(frontier::PostorderStackFrontier) = (last(frontier.next), last(frontier.seen))
Base.isempty(frontier::PostorderStackFrontier) = isempty(frontier.next)


# Minimal Queue
#─────────────────────────────────────────────────────────────────────────────

"""
    QueueFrontier

The first-in first-out queue for `Topdown`. It never forgets a sprout: `parent[k]` is the index of the sprout that queued sprout `k` (0 for the root),
so `isancestor` can walk the ancestors of any sprout.
"""
mutable struct QueueFrontier{S} <: Frontier
    next::Vector{S}
    parent::Vector{Int}
    currentidx::Int
end

function put!(frontier::QueueFrontier, shoot, parent::Int = frontier.currentidx - 1)
    push!(frontier.next, shoot)
    push!(frontier.parent, parent)
end

function take!(frontier::QueueFrontier)
    shoot = frontier.next[frontier.currentidx]
    frontier.currentidx += 1
    return shoot
end

peek(frontier::QueueFrontier) = frontier.next[frontier.currentidx]
Base.isempty(frontier::QueueFrontier) = frontier.currentidx > length(frontier.next)

"""
    isancestor(frontier::QueueFrontier, node)

Whether `node` is an ancestor of the sprout taken last.
"""
function isancestor(frontier::QueueFrontier, node)
    k = frontier.parent[frontier.currentidx - 1]
    while k != 0
        isequal(nodeof(frontier.next[k]), node) && return true
        k = frontier.parent[k]
    end
    return false
end


# Bottomup Frontier
#─────────────────────────────────────────────────────────────────────────────

"""
    BottomupFrontier

Holds every sprout of the taproot, mapped up front in one preorder pass by `mapsprout!`.
The pathset decides what a sprout is: one cycle-free path from the root, or (when walking `OncePerNode`) a whole node.
The queue works purely on indices into `states`. Each sprout keeps a linked list of edges up to the sprouts waiting on it:
`firstparent[k]` is its first edge (0 for none), `edgeparent[e]` is where edge `e` leads, `nextedge[e]` is the next edge in the same list,
and `byconnector[e]` is whether the edge stands for a connected child, which the `connector` may keep holding.
`pending[k]` counts what sprout `k` still waits on; a sprout enters the queue exactly once, when its count reaches zero (Kahn's algorithm).
Children on cycle edges never become sprouts but still count towards `pending`, so cycles never reach zero and are abandoned.
Sprouts taken with `hold` wait in `waiting` until `recheck!` lets go of them.
"""
mutable struct BottomupFrontier{S} <: Frontier
    states::Vector{S}
    pending::Vector{Int}
    firstparent::Vector{Int}
    edgeparent::Vector{Int}
    nextedge::Vector{Int}
    byconnector::Vector{Bool}
    queue::Vector{Int}
    currentidx::Int
    waiting::Vector{Int}
end

function BottomupFrontier{S}(children, connector, pathset, root; sizeguess = 256) where S
    frontier = BottomupFrontier{S}(sizehint!(S[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Bool[], sizeguess), sizehint!(Int[], sizeguess), 1, Int[])
    seen = initmapping(pathset, nodetypeof(S); sizeguess)
    unmapped = [(initsprout(S, root), 0)]
    while !isempty(unmapped)
        sprout, parent = pop!(unmapped)
        k, expand = mapsprout!(frontier, seen, sprout)
        if k == 0 continue end
        if parent != 0 addedge!(frontier, k, parent) end
        if !expand continue end
        node = nodeof(sprout)
        for (i, child) in enumerate(children(node))
            if !connector(node, child) continue end
            frontier.pending[k] += 1
            push!(unmapped, (putsprout(sprout, child, i), k))
        end
    end
    for (k, count) in enumerate(frontier.pending)
        if count == 0 put!(frontier, k) end
    end
    return frontier
end

function newsprout!(frontier::BottomupFrontier, sprout)
    push!(frontier.states, sprout)
    push!(frontier.pending, 0)
    push!(frontier.firstparent, 0)
    return length(frontier.states)
end

function addedge!(frontier::BottomupFrontier, child::Int, parent::Int, byconnector::Bool = true)
    push!(frontier.edgeparent, parent)
    push!(frontier.nextedge, frontier.firstparent[child])
    push!(frontier.byconnector, byconnector)
    frontier.firstparent[child] = length(frontier.edgeparent)
end

"""
    FirstSprouts{P, N}

The index of the first sprout mapped for each node, when walking `OncePerNode` or `OncePerEdge`.
"""
struct FirstSprouts{P <: PathSet, N}
    index::Dict{N, Int}
end

initmapping(::Type{<:PathSet}, ::Type{N}; sizeguess = 256) where N = initpathset(NoCycles, N)
initmapping(::Type{<:OncePerNode}, ::Type{N}; sizeguess = 256) where N = FirstSprouts{OncePerNode, N}(sizehint!(Dict{N, Int}(), sizeguess))
initmapping(::Type{<:OncePerEdge}, ::Type{N}; sizeguess = 256) where N = FirstSprouts{OncePerEdge, N}(sizehint!(Dict{N, Int}(), sizeguess))

"""
    mapsprout!(frontier::BottomupFrontier, seen, sprout)

Maps `sprout` into `frontier`, returning its index (0 when it would close a cycle) and whether to map its children too.
`seen = initmapping(pathset, N)` decides what a sprout is:

- `AllPaths` and `NoCycles`: every cycle-free path is its own sprout.
- `OncePerNode`: every node is one sprout, waited on by all of its parents.
- `OncePerEdge`: a node is a sprout once per edge into it, but only its first sprout maps its children. The later ones wait on the first, so they stay above everything below it.
"""
function mapsprout!(frontier::BottomupFrontier, seen::NoCycles, sprout)
    node, level = nodeof(sprout), levelof(sprout)
    if !visitnode(seen, node, level) return 0, false end
    tracknode!(seen, node, level)
    return newsprout!(frontier, sprout), true
end

function mapsprout!(frontier::BottomupFrontier, seen::FirstSprouts{OncePerNode}, sprout)
    n = length(frontier.states)
    k = get!(() -> newsprout!(frontier, sprout), seen.index, nodeof(sprout))
    return k, k > n
end

function mapsprout!(frontier::BottomupFrontier, seen::FirstSprouts{OncePerEdge}, sprout)
    first = get(seen.index, nodeof(sprout), 0)
    k = newsprout!(frontier, sprout)
    if first == 0
        seen.index[nodeof(sprout)] = k
        return k, true
    end
    addedge!(frontier, first, k, false)
    frontier.pending[k] = 1
    return k, false
end

put!(frontier::BottomupFrontier, k::Int) = push!(frontier.queue, k)

"""
    take!(frontier::BottomupFrontier, hold = false)

Takes the next ready sprout, bringing each sprout waiting on it one step closer to ready.
With `hold`, it keeps its edges until `recheck!` finds the connector has let go of them.
"""
function take!(frontier::BottomupFrontier, hold::Bool = false)
    k = frontier.queue[frontier.currentidx]
    frontier.currentidx += 1
    if !hold
        letgo!(Returns(false), frontier, k)
    elseif hasparents(frontier, k)
        push!(frontier.waiting, k)
    end
    return frontier.states[k]
end

"""
    recheck!(frontier::BottomupFrontier, connector)

Lets go of every held edge that the `connector` no longer connects. Sprouts with edges still held keep waiting.
"""
function recheck!(frontier::BottomupFrontier, connector)
    kept = 0
    for k in frontier.waiting
        child = nodeof(frontier.states[k])
        if letgo!(parent -> connector(nodeof(frontier.states[parent]), child), frontier, k)
            frontier.waiting[kept += 1] = k
        end
    end
    resize!(frontier.waiting, kept)
end

"""
    letgo!(holds, frontier::BottomupFrontier, k)

Unlinks each of sprout `k`'s edges, except connected children for which `holds(parent)`, and releases every parent left waiting on nothing.
Returns whether any of `k`'s edges are still held.
"""
function letgo!(holds, frontier::BottomupFrontier, k::Int)
    previous, edge = 0, frontier.firstparent[k]
    while edge != 0
        next = frontier.nextedge[edge]
        parent = frontier.edgeparent[edge]
        if frontier.byconnector[edge] && holds(parent)
            previous = edge
        else
            release!(frontier, parent)
            if previous == 0 frontier.firstparent[k] = next else frontier.nextedge[previous] = next end
        end
        edge = next
    end
    return hasparents(frontier, k)
end

hasparents(frontier::BottomupFrontier, k::Int) = frontier.firstparent[k] != 0

function release!(frontier::BottomupFrontier, k::Int)
    frontier.pending[k] -= 1
    if frontier.pending[k] == 0 put!(frontier, k) end
end

peek(frontier::BottomupFrontier) = frontier.states[frontier.queue[frontier.currentidx]]
readycount(frontier::BottomupFrontier) = length(frontier.queue) - frontier.currentidx + 1

Base.isempty(frontier::BottomupFrontier) = frontier.currentidx > length(frontier.queue)
