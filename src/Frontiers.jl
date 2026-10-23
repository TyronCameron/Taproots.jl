
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
    # The queue never forgets a sprout, so `parent[k]` (the index of the sprout
    # that queued sprout k, 0 for the root) lets us walk any sprout's ancestors.

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

# Is `node` one of the ancestors of the sprout just taken?
function onpath(frontier::QueueFrontier, node)
    k = frontier.parent[frontier.currentidx - 1]
    while k != 0
        isequal(nodeof(frontier.next[k]), node) && return true
        k = frontier.parent[k]
    end
    return false
end


# Bottomup Frontier
#─────────────────────────────────────────────────────────────────────────────
    # Holds every sprout of the taproot, mapped up front in one preorder pass.
    # The pathset decides what a sprout is: one cycle-free path from the root
    # (AllPaths, NoCycles, OncePerEdge) or one whole node (OncePerNode). The queue
    # works purely on indices into that vector. Each sprout keeps a linked list of
    # edges up to the sprouts waiting on it: `firstparent[k]` is its first edge (0
    # for none), `edgeparent[e]` is where edge `e` leads and `nextedge[e]` is the
    # next edge in the same list. `pending[k]` counts what sprout k still waits on
    # (its connected children); a sprout enters the queue exactly once, when its
    # count reaches zero (Kahn's algorithm). Cycles never reach zero, so they are
    # abandoned. A taken sprout normally lets go of its parents straight away;
    # leafbatches can instead hold them in `waiting` until the connector lets go.

mutable struct BottomupFrontier{S} <: Frontier
    states::Vector{S}
    pending::Vector{Int}
    firstparent::Vector{Int}
    edgeparent::Vector{Int}
    nextedge::Vector{Int}
    queue::Vector{Int}
    currentidx::Int
    waiting::Vector{Int}
end

function BottomupFrontier{S}(children, connector, pathset, root; sizeguess = 256) where S
    frontier = BottomupFrontier{S}(sizehint!(S[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Int[], sizeguess), sizehint!(Int[], sizeguess), 1, Int[])
    seen = initmapping(pathset, nodetypeof(S); sizeguess)
    stack = [(initsprout(S, root), 0)] # each sprout with the index of the sprout waiting on it
    while !isempty(stack)
        sprout, parent = pop!(stack)
        k, expand = mapsprout!(frontier, seen, sprout)
        if k == 0 continue end # a cycle edge: its parent waits on it forever
        if parent != 0 addedge!(frontier, k, parent) end
        if !expand continue end
        node = nodeof(sprout)
        for (i, child) in enumerate(children(node))
            if !connector(node, child) continue end
            frontier.pending[k] += 1
            push!(stack, (putsprout(sprout, child, i), k))
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

function addedge!(frontier::BottomupFrontier, child::Int, parent::Int)
    push!(frontier.edgeparent, parent)
    push!(frontier.nextedge, frontier.firstparent[child])
    frontier.firstparent[child] = length(frontier.edgeparent)
end

# `mapsprout!(frontier, seen, sprout)` gives the sprout's index (0 to cut it) and whether to map its children.

# AllPaths and NoCycles: every cycle-free path is its own sprout.
initmapping(::Type{<:PathSet}, ::Type{N}; sizeguess = 256) where N = initpathset(NoCycles, N)
function mapsprout!(frontier::BottomupFrontier, seen::NoCycles, sprout)
    node, level = nodeof(sprout), levelof(sprout)
    if !visitnode(seen, node, level) return 0, false end
    tracknode!(seen, node, level)
    return newsprout!(frontier, sprout), true
end

# OncePerNode and OncePerEdge remember the first sprout of every node.
struct FirstSprouts{P <: PathSet, N}
    index::Dict{N, Int}
end
initmapping(::Type{P}, ::Type{N}; sizeguess = 256) where {P <: Union{OncePerNode, OncePerEdge}, N} = FirstSprouts{P <: OncePerNode ? OncePerNode : OncePerEdge, N}(sizehint!(Dict{N, Int}(), sizeguess))

# OncePerNode: every node is one sprout, waited on by all of its parents.
function mapsprout!(frontier::BottomupFrontier, seen::FirstSprouts{OncePerNode}, sprout)
    n = length(frontier.states)
    k = get!(() -> newsprout!(frontier, sprout), seen.index, nodeof(sprout))
    return k, k > n
end

# OncePerEdge: a node is a sprout once per edge into it, but only its first sprout maps its children.
# The later ones wait on the first (through a negative edge), so they stay above everything below it.
function mapsprout!(frontier::BottomupFrontier, seen::FirstSprouts{OncePerEdge}, sprout)
    first = get(seen.index, nodeof(sprout), 0)
    k = newsprout!(frontier, sprout)
    if first == 0
        seen.index[nodeof(sprout)] = k
        return k, true
    end
    addedge!(frontier, first, -k) # negative: not a real edge, so no connector to wait on
    frontier.pending[k] = 1
    return k, false
end

put!(frontier::BottomupFrontier, k::Int) = push!(frontier.queue, k)

# Taking a sprout brings each of its parents one child closer to ready.
# Holding it instead parks it in `waiting`, for `recheck!` to let go of later.
function take!(frontier::BottomupFrontier, hold::Bool = false)
    k = frontier.queue[frontier.currentidx]
    frontier.currentidx += 1
    if hold
        if frontier.firstparent[k] != 0 push!(frontier.waiting, k) end
    else
        letgo!(parent -> false, frontier, k)
    end
    return frontier.states[k]
end

# Lets go of every held edge the connector no longer connects, keeping the rest waiting.
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

# Unlinks each of sprout k's edges unless `holds(parent)`, releasing that parent once it waits on nothing else.
# Returns whether any edges are still held.
function letgo!(holds, frontier::BottomupFrontier, k::Int)
    previous, edge = 0, frontier.firstparent[k]
    while edge != 0
        next = frontier.nextedge[edge]
        parent = frontier.edgeparent[edge]
        if parent > 0 && holds(parent)
            previous = edge
        else
            parent = abs(parent)
            frontier.pending[parent] -= 1
            if frontier.pending[parent] == 0 put!(frontier, parent) end
            if previous == 0 frontier.firstparent[k] = next else frontier.nextedge[previous] = next end
        end
        edge = next
    end
    return frontier.firstparent[k] != 0
end

peek(frontier::BottomupFrontier) = frontier.states[frontier.queue[frontier.currentidx]]
readycount(frontier::BottomupFrontier) = length(frontier.queue) - frontier.currentidx + 1

Base.isempty(frontier::BottomupFrontier) = frontier.currentidx > length(frontier.queue)
