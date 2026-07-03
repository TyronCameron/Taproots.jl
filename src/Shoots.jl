#─────────────────────────────────────────────────────────────────────────────#
# Shoots
#─────────────────────────────────────────────────────────────────────────────#
    # Information about nodes as we're iterating through them.

"""
    Shoot

A selector when iterating. For use in iterator functions such `preorder(taproot; eltype = (Node, Level, Trace))`
"""
abstract type Shoot end

"""
    Node

Selects nodes only when iterating. For use in iterator functions such `preorder(taproot; eltype = Node)`
"""
struct Node <: Shoot end

"""
    Trace

Selects traces (tuples containing the indices of children nodes to get to this same position) only when iterating. For use in iterator functions such `preorder(taproot; eltype = Trace)`
"""
struct Trace <: Shoot end

"""
    Level

Selects levels only when iterating. For use in iterator functions such `preorder(taproot; eltype = Level)`
"""
struct Level <: Shoot end

# Standardisation
canonicalshoot(::Type{S}) where {S <: Shoot} = S()
canonicalshoot(shoots::Tuple) = map(canonicalshoot, shoots)

# Separation of traces
hastrace(::Node) = false
hastrace(::Level) = false
hastrace(::Trace) = true
hastrace(shoots::Tuple) = any(hastrace, shoots)

# TraceLinks 
struct TraceLinks
    i::Int
    parent::Union{Tuple{}, TraceLinks}
end
const TraceState = Union{Tuple{}, TraceLinks}

# Convert TraceLinks back to tuple 
totuple(trace::Tuple) = trace
function totuple(trace::TraceLinks)
    indices = Int[]
    while trace isa TraceLinks
        push!(indices, trace.i)
        trace = trace.parent
    end
    return Tuple(reverse!(indices))
end

# Add on a Trace 
growtrace(::Nothing, i) = nothing
growtrace(trace::TraceState, i) = TraceLinks(i, trace)


## Shoot state
##────────────────────────────────────────────────────────────────────────────#
    # The state carried through a walk for each node: the node itself, its
    # level, and (only if requested) its trace.

struct ShootState{N, T}
    node::N
    level::Int
    trace::T
end

Base.convert(::Type{ShootState{N, T}}, s::ShootState) where {N, T} = ShootState{N, T}(s.node, s.level, s.trace)

nodetypeof(::Type{ShootState{N, T}}) where {N, T} = N

shoottype(shoots, ::Type{N}) where N = ShootState{N, hastrace(shoots) ? TraceState : Nothing}

initshoot(shoots, root) = ShootState(root, 0, hastrace(shoots) ? () : nothing)
putshoot(s::ShootState, child, i) = ShootState(child, s.level + 1, growtrace(s.trace, i))

takeshoot(shoots::Tuple, s::ShootState) = map(sh -> takeshoot(sh, s), shoots)
takeshoot(::Node, s::ShootState) = s.node
takeshoot(::Trace, s::ShootState) = totuple(s.trace)
takeshoot(::Level, s::ShootState) = s.level

struct RawShoot{Sh} # internal: yields the entire ShootState, while tracking traces only if the wrapped shoots need them
    shoots::Sh
end
hastrace(raw::RawShoot) = hastrace(raw.shoots)
takeshoot(::RawShoot, s::ShootState) = s

yieldtype(shoots::Tuple, ::Type{S}) where {S <: ShootState} = Tuple{map(sh -> yieldtype(sh, S), shoots)...}
yieldtype(::Node, ::Type{ShootState{N, T}}) where {N, T} = N
yieldtype(::Trace, ::Type{<:ShootState}) = Tuple{Vararg{Int}}
yieldtype(::Level, ::Type{<:ShootState}) = Int
