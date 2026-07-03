
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
    # Holds every sprout of the taproot in preorder (each sprout corresponds to
    # one unique path from the root). The queue works purely on indices into
    # that vector: `parentidx[k]` is the index of the sprout above sprout `k`
    # (0 for the root), so stepping to a parent is O(1). `pending[k]` counts how
    # many of sprout k's connected children have not yet been taken; a sprout
    # enters the queue exactly once, when its count reaches zero (Kahn's
    # algorithm). Children on cycle edges are pruned before ever reaching
    # `states`, so their parents' counts never reach zero and cycles are
    # abandoned.

mutable struct BottomupFrontier{S} <: Frontier
    states::Vector{S}
    parentidx::Vector{Int}
    pending::Vector{Int}
    queue::Vector{Int}
    currentidx::Int
end

function BottomupFrontier(states::Vector{S}, children, connector) where S
    n = length(states)
    parentidx = Vector{Int}(undef, n)
    pending = Vector{Int}(undef, n)
    ancestors = Int[] # preorder guarantees a sprout's parent is the latest sprout one level up
    for (k, sprout) in enumerate(states)
        level = levelof(sprout)
        resize!(ancestors, level)
        parentidx[k] = level == 0 ? 0 : ancestors[level]
        push!(ancestors, k)
        node = nodeof(sprout)
        connected = 0
        for child in children(node)
            if connector(node, child) connected += 1 end
        end
        pending[k] = connected
    end
    queue = sizehint!(Int[], n)
    for (k, count) in enumerate(pending)
        if count == 0 push!(queue, k) end
    end
    return BottomupFrontier{S}(states, parentidx, pending, queue, 1)
end

put!(frontier::BottomupFrontier, k::Int) = push!(frontier.queue, k)

function take!(frontier::BottomupFrontier) # returns the index; look up states/parentidx from it
    k = frontier.queue[frontier.currentidx]
    frontier.currentidx += 1
    return k
end

peek(frontier::BottomupFrontier) = frontier.queue[frontier.currentidx]

Base.isempty(frontier::BottomupFrontier) = frontier.currentidx > length(frontier.queue)
