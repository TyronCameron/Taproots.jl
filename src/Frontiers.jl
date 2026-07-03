
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
    # (0 for the root), so stepping to a parent is O(1). The walk's mutable
    # state (completed paths, visited nodes) lives here too, so that the
    # @resumable state machine only carries one concretely typed frontier.

mutable struct BottomupFrontier{S, N} <: Frontier
    states::Vector{S}
    parentidx::Vector{Int}
    queue::Vector{Int}
    currentidx::Int
    completed::Vector{Bool}
    visited::Set{N}
end

function BottomupFrontier(states::Vector{S}, queue::Vector{Int}, sizeguess::Int) where S
    parentidx = Vector{Int}(undef, length(states))
    ancestors = Int[] # preorder guarantees a sprout's parent is the latest sprout one level up
    for (k, state) in enumerate(states)
        level = levelof(state)
        resize!(ancestors, level)
        parentidx[k] = level == 0 ? 0 : ancestors[level]
        push!(ancestors, k)
    end
    N = nodetypeof(S)
    visited = sizehint!(Set{N}(), sizeguess)
    return BottomupFrontier{S, N}(states, parentidx, queue, 1, fill(false, length(states)), visited)
end

put!(frontier::BottomupFrontier, k::Int) = push!(frontier.queue, k)

function take!(frontier::BottomupFrontier)
    k = frontier.queue[frontier.currentidx]
    frontier.currentidx += 1
    return (k, frontier.states[k], frontier.parentidx[k])
end

function peek(frontier::BottomupFrontier)
    k = frontier.queue[frontier.currentidx]
    return (k, frontier.states[k], frontier.parentidx[k])
end

Base.isempty(frontier::BottomupFrontier) = frontier.currentidx > length(frontier.queue)
