
#─────────────────────────────────────────────────────────────────────────────#
# Frontiers
#─────────────────────────────────────────────────────────────────────────────#
    # A Frontier is an incremental way of getting the "next" nodes.
    # Frontiers are parametrized by the concrete shoot type they store, so that
    # walks stay type stable. It must implement the following:
        # A constructor (aligns 1 to 1 with WalkOrder so not really important to define the mapping here)
        # put!(frontier, shoot) -- puts this into the queue so that it will be seen next
        # take!(frontier, shoot) -- pulls the next shoot out of the queue
        # peek(frontier) -- see what is next in the queue without popping it
        # isempty(frontier) -- check to see if there is anything next

abstract type WalkOrder end
struct Preorder <: WalkOrder end
struct Postorder <: WalkOrder end
struct Topdown <: WalkOrder end
struct Bottomup <: WalkOrder end
struct Leafbatches <: WalkOrder end

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
    # Holds every sprout of the taproot in preorder. A sprout is either one unique
    # path from the root, or (when walking OncePerNode) a whole node. The queue
    # works purely on indices into that vector. Each sprout keeps a linked list of
    # edges up to its parents: `firstparent[k]` is its first edge (0 for none),
    # `edgeparent[e]` is where edge `e` leads and `nextedge[e]` is the next edge in
    # the same list. `pending[k]` counts how many of sprout k's connected children
    # have not yet been taken; a sprout enters the queue exactly once, when its
    # count reaches zero (Kahn's algorithm). Cycles never reach zero, so they are
    # abandoned.

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

# Sprouts are paths: each has one parent, the latest sprout one level up (preorder guarantees it).
# Children on cycle edges never became sprouts, but still count towards `pending`.
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

# Sprouts are whole nodes: link each one to every parent it has.
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

function take!(frontier::BottomupFrontier) # taking a sprout brings each of its parents one child closer to ready
    k = frontier.queue[frontier.currentidx]
    frontier.currentidx += 1
    edge = frontier.firstparent[k]
    while edge != 0
        parent = frontier.edgeparent[edge]
        frontier.pending[parent] -= 1
        if frontier.pending[parent] == 0 put!(frontier, parent) end
        edge = frontier.nextedge[edge]
    end
    return frontier.states[k]
end

peek(frontier::BottomupFrontier) = frontier.states[frontier.queue[frontier.currentidx]]
readycount(frontier::BottomupFrontier) = length(frontier.queue) - frontier.currentidx + 1

Base.isempty(frontier::BottomupFrontier) = frontier.currentidx > length(frontier.queue)
