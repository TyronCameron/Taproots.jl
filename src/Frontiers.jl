
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

mutable struct QueueFrontier{S} <: Frontier
    next::Vector{S}
    currentidx::Int
end

put!(frontier::QueueFrontier, shoot) = push!(frontier.next, shoot)

function take!(frontier::QueueFrontier)
    shoot = frontier.next[frontier.currentidx]
    frontier.currentidx += 1
    return shoot
end

peek(frontier::QueueFrontier) = frontier.next[frontier.currentidx]
Base.isempty(frontier::QueueFrontier) = frontier.currentidx > length(frontier.next)


# Bottomup Frontier
#─────────────────────────────────────────────────────────────────────────────

"""
    BottomupFrontier

Holds every sprout of the taproot in preorder. A sprout is either one unique path from the root, or (when walking `OncePerNode`) a whole node.
The queue works purely on indices into `states`. Each sprout keeps a linked list of edges up to its parents:
`firstparent[k]` is its first edge (0 for none), `edgeparent[e]` is where edge `e` leads and `nextedge[e]` is the next edge in the same list.
`pending[k]` counts how many of sprout `k`'s connected children have not yet been taken; a sprout enters the queue exactly once, when its count reaches zero (Kahn's algorithm).
Cycles never reach zero, so they are abandoned.
"""
mutable struct BottomupFrontier{S} <: Frontier
    states::Vector{S}
    pending::Vector{Int}
    firstparent::Vector{Int}
    edgeparent::Vector{Int}
    nextedge::Vector{Int}
    queue::Vector{Int}
    currentidx::Int
end

function BottomupFrontier(states::Vector{S}, children, connector, pathset) where S
    n = length(states)
    frontier = BottomupFrontier{S}(states, zeros(Int, n), zeros(Int, n), sizehint!(Int[], n), sizehint!(Int[], n), sizehint!(Int[], n), 1)
    linkparents!(frontier, pathset, children, connector)
    for (k, count) in enumerate(frontier.pending)
        if count == 0 put!(frontier, k) end
    end
    return frontier
end

function addedge!(frontier::BottomupFrontier, child::Int, parent::Int)
    push!(frontier.edgeparent, parent)
    push!(frontier.nextedge, frontier.firstparent[child])
    frontier.firstparent[child] = length(frontier.edgeparent)
end

"""
    linkparents!(frontier::BottomupFrontier, pathset, children, connector)

Links each sprout to its parents and counts its pending children.
When sprouts are paths, each has one parent: the latest sprout one level up, which preorder guarantees.
Children on cycle edges never became sprouts, but still count towards `pending`.
With `OncePerNode`, sprouts are whole nodes and each is linked to every parent it has.
"""
function linkparents!(frontier::BottomupFrontier, ::Type{<:PathSet}, children, connector)
    ancestors = Int[]
    for (k, sprout) in enumerate(frontier.states)
        level = levelof(sprout)
        resize!(ancestors, level)
        if level > 0 addedge!(frontier, k, ancestors[level]) end
        push!(ancestors, k)
        node = nodeof(sprout)
        frontier.pending[k] = count(child -> connector(node, child), children(node))
    end
end

function linkparents!(frontier::BottomupFrontier, ::Type{<:OncePerNode}, children, connector)
    index = Dict(nodeof(sprout) => k for (k, sprout) in enumerate(frontier.states))
    for (k, sprout) in enumerate(frontier.states)
        node = nodeof(sprout)
        for child in children(node)
            if !connector(node, child) continue end
            addedge!(frontier, index[child], k)
            frontier.pending[k] += 1
        end
    end
end

put!(frontier::BottomupFrontier, k::Int) = push!(frontier.queue, k)

function take!(frontier::BottomupFrontier)
    k = frontier.queue[frontier.currentidx]
    frontier.currentidx += 1
    foreachparent(frontier, k) do parent
        frontier.pending[parent] -= 1
        if frontier.pending[parent] == 0 put!(frontier, parent) end
    end
    return frontier.states[k]
end

function foreachparent(f, frontier::BottomupFrontier, k::Int)
    edge = frontier.firstparent[k]
    while edge != 0
        f(frontier.edgeparent[edge])
        edge = frontier.nextedge[edge]
    end
end

peek(frontier::BottomupFrontier) = frontier.states[frontier.queue[frontier.currentidx]]
readycount(frontier::BottomupFrontier) = length(frontier.queue) - frontier.currentidx + 1
takebatch!(frontier::BottomupFrontier) = [take!(frontier) for _ in 1:readycount(frontier)]

Base.isempty(frontier::BottomupFrontier) = frontier.currentidx > length(frontier.queue)


# Live Frontier for Leafbatches
#─────────────────────────────────────────────────────────────────────────────

"""
    LiveFrontier

Holds the same sprouts as `BottomupFrontier`, but asks the `connector` which of them are leaves every time a batch is taken, so the `connector` may change its answers between batches.
`candidates` starts as the leaves. After that, only parents of taken sprouts become candidates, so a walk climbs at most one parent per batch.
A candidate stays one until it is a leaf, and `reached[k]` makes sure sprout `k` only becomes a candidate once.
"""
mutable struct LiveFrontier{S, C, K} <: Frontier
    sprouts::BottomupFrontier{S}
    children::C
    connector::K
    candidates::Vector{Int}
    reached::Vector{Bool}
end

function LiveFrontier(sprouts::BottomupFrontier, children, connector)
    reached = fill(false, length(sprouts.states))
    reached[sprouts.queue] .= true
    return LiveFrontier(sprouts, children, connector, copy(sprouts.queue), reached)
end

function takebatch!(frontier::LiveFrontier)
    sprouts, children, connector = frontier.sprouts, frontier.children, frontier.connector
    ready, waiting = Int[], Int[]
    for k in frontier.candidates
        push!(isleaf(children, nodeof(sprouts.states[k]); connector) ? ready : waiting, k)
    end
    for k in ready
        foreachparent(sprouts, k) do parent
            if frontier.reached[parent] return end
            frontier.reached[parent] = true
            push!(waiting, parent)
        end
    end
    frontier.candidates = waiting
    return sprouts.states[ready]
end

Base.isempty(frontier::LiveFrontier) = isempty(frontier.candidates)
