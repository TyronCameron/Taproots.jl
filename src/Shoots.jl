#─────────────────────────────────────────────────────────────────────────────#
# Shoots
#─────────────────────────────────────────────────────────────────────────────#

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

standardisedshoot(::Type{S}) where {S <: Shoot} = S()
standardisedshoot(shoots::Tuple) = map(standardisedshoot, shoots)

hastrace(::Node) = false
hastrace(::Level) = false
hastrace(::Trace) = true
hastrace(shoots::Tuple) = any(hastrace, shoots)

struct TraceLinks
    i::Int
    parent::Union{Tuple{}, TraceLinks}
end
const TraceState = Union{Tuple{}, TraceLinks}

totuple(trace::Tuple) = trace
function totuple(trace::TraceLinks)
    depth = 0
    link = trace
    while link isa TraceLinks
        depth += 1
        link = link.parent
    end
    indices = Vector{Int}(undef, depth)
    link = trace
    while link isa TraceLinks
        indices[depth] = link.i
        depth -= 1
        link = link.parent
    end
    return ntuple(i -> @inbounds(indices[i]), length(indices))
end

#─────────────────────────────────────────────────────────────────────────────#
# Sprouts
#─────────────────────────────────────────────────────────────────────────────#

"""
    AbstractSprout

A node held by a walk, together with its level. `Sprout` is the traceless variant; `TracedSprout` additionally carries the path of child indices.
"""
abstract type AbstractSprout end 

struct Sprout{N} <: AbstractSprout
    node::N
    level::Int
end

struct TracedSprout{N} <: AbstractSprout
    node::N
    level::Int
    trace::TraceState
end

nodeof(s::AbstractSprout) = s.node
levelof(s::AbstractSprout) = s.level
traceof(s::TracedSprout) = s.trace

nodetypeof(::Type{Sprout{N}}) where N = N
nodetypeof(::Type{TracedSprout{N}}) where N = N

sprouttype(shoots, ::Type{N}) where N = hastrace(shoots) ? TracedSprout{N} : Sprout{N}

initsprout(::Type{Sprout{N}}, root) where N = Sprout{N}(root, 0)
initsprout(::Type{TracedSprout{N}}, root) where N = TracedSprout{N}(root, 0, ())

putsprout(s::Sprout{N}, child, i) where N = Sprout{N}(child, s.level + 1)
putsprout(s::TracedSprout{N}, child, i) where N = TracedSprout{N}(child, s.level + 1, TraceLinks(i, s.trace))

takeshoot(shoots::Tuple, s::AbstractSprout) = map(sh -> takeshoot(sh, s), shoots)
takeshoot(::Node, s::AbstractSprout) = nodeof(s)
takeshoot(::Trace, s::TracedSprout) = totuple(traceof(s))
takeshoot(::Level, s::AbstractSprout) = levelof(s)

yieldtype(shoots::Tuple, ::Type{S}) where {S <: AbstractSprout} = Tuple{map(sh -> yieldtype(sh, S), shoots)...}
yieldtype(::Node, ::Type{S}) where {S <: AbstractSprout} = nodetypeof(S)
yieldtype(::Trace, ::Type{<:AbstractSprout}) = Tuple{Vararg{Int}}
yieldtype(::Level, ::Type{<:AbstractSprout}) = Int
