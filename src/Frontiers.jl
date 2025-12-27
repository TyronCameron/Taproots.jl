
#─────────────────────────────────────────────────────────────────────────────#
# Frontiers
#─────────────────────────────────────────────────────────────────────────────#
    # A Frontier is an incremental way of getting the "next" nodes. 
    # It must implement the following: 
        # A constructor (aligns 1 to 1 with WalkOrder so not really important to define the mapping here)
        # put!(frontier, shoot) -- puts this into the queue so that it will be seen next 
        # take!(frontier, shoot) -- pulls this out of the queue. Must return the entire shoot, the node (for internal use) and the level (for internal use)
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

mutable struct StackFrontier{T} <: Frontier 
    next::Vector{T}
end 

put!(frontier::StackFrontier, shoot) = push!(frontier.next, shoot)  
take!(frontier::StackFrontier) = (s = pop!(frontier.next); (s, s.node, s.level))
peek(frontier::StackFrontier) = (s = last(frontier.next); (s, s.node, s.level))
Base.isempty(frontier::StackFrontier) = isempty(frontier.next)


# Stack for Postorder
#─────────────────────────────────────────────────────────────────────────────

mutable struct PostorderStackFrontier{T} <: Frontier 
    next::Vector{T}
    seen::Vector{Bool}
end 

function put!(frontier::PostorderStackFrontier, tuple) 
    push!(frontier.next, tuple[begin])
    push!(frontier.seen, tuple[end]) 
end 

function take!(frontier::PostorderStackFrontier) 
    s = pop!(frontier.next); 
    return (s, s.node, s.level, pop!(frontier.seen))
end 

function peek(frontier::PostorderStackFrontier) 
    s = last(frontier.next); 
    return (s, s.node, s.level, last(frontier.seen))
end 

Base.isempty(frontier::PostorderStackFrontier) = isempty(frontier.next)


# Minimal Queue 
#─────────────────────────────────────────────────────────────────────────────

mutable struct QueueFrontier{T} <: Frontier 
    next::Vector{T}
    currentidx::Int
end

function put!(frontier::QueueFrontier, shoot)
    push!(frontier.next, shoot)
end

function take!(frontier::QueueFrontier)
    current_shoot = frontier.next[frontier.currentidx]
    entire_return = (current_shoot, current_shoot.node, current_shoot.level)
    frontier.next[frontier.currentidx] = nothing 
    frontier.currentidx = frontier.currentidx + 1
    return entire_return
end

function peek(frontier::QueueFrontier)
    current_shoot = frontier.next[frontier.currentidx]
    return (current_shoot, current_shoot.node, current_shoot.level)
end

Base.isempty(frontier::QueueFrontier) = frontier.currentidx > length(frontier.next)


# Bottomup Frontier 
#─────────────────────────────────────────────────────────────────────────────

mutable struct BottomupFrontier <: Frontier 
    root
    traces::Vector{Tuple}
    currentidx::Int
end 

function BottomupFrontier(root, traces)
    BottomupFrontier(root, traces, 1)
end 

put!(frontier::BottomupFrontier, trace) = push!(frontier.traces, trace)

function take!(frontier::BottomupFrontier) 
    current_trace = frontier.traces[frontier.currentidx]
    entire_return = (pluck(frontier.root, current_trace), current_trace, length(current_trace))
    frontier.traces[frontier.currentidx] = () 
    frontier.currentidx = frontier.currentidx + 1
    return entire_return
end 

function peek(frontier::BottomupFrontier) 
    current_trace = last(frontier.traces) 
    return (pluck(frontier.root, current_trace), current_trace, length(current_trace))
end 

Base.isempty(frontier::BottomupFrontier) = frontier.currentidx > length(frontier.traces) 
