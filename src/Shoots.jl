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
standardisedshoot(::Type{S}) where {S <: Shoot} = S()
standardisedshoot(shoots::Tuple) = map(standardisedshoot, shoots)

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

## Sprouts
##────────────────────────────────────────────────────────────────────────────#
    # The state carried through a walk for each node. Compulsory parts (node,
    # level) are plain fields; the optional trace is a sum type, so that the
    # traceless case is a dataless singleton (NoTrace) and costs nothing.
    # Keeping the compulsory parts out of the variants matters: a union of
    # pointer-carrying variants cannot be stored unboxed, which would cost one
    # heap allocation per node. @cases never appears inside @resumable bodies
    # -- it is confined to the small helpers below.

@sum_type SproutTrace begin
    NoTrace
    WithTrace(trace::TraceState)
end

struct Sprout{N}
    node::N
    level::Int
    trace::SproutTrace
end

nodeof(s::Sprout) = s.node
levelof(s::Sprout) = s.level

traceof(s::Sprout) = @cases s.trace begin
    NoTrace => error("this sprout does not track traces")
    WithTrace(trace) => trace
end

growtrace(sprouttrace::SproutTrace, i) = @cases sprouttrace begin
    NoTrace => NoTrace
    WithTrace(trace) => WithTrace(TraceLinks(i, trace))
end

nodetypeof(::Type{Sprout{N}}) where N = N

sprouttype(shoots, ::Type{N}) where N = Sprout{N}

initsprout(shoots, ::Type{N}, root) where N = Sprout{N}(root, 0, hastrace(shoots) ? WithTrace(()) : NoTrace)

putsprout(s::Sprout{N}, child, i) where N = Sprout{N}(child, s.level + 1, growtrace(s.trace, i))

takeshoot(shoots::Tuple, s::Sprout) = map(sh -> takeshoot(sh, s), shoots)
takeshoot(::Node, s::Sprout) = nodeof(s)
takeshoot(::Trace, s::Sprout) = totuple(traceof(s))
takeshoot(::Level, s::Sprout) = levelof(s)

yieldtype(shoots::Tuple, ::Type{S}) where {S <: Sprout} = Tuple{map(sh -> yieldtype(sh, S), shoots)...}
yieldtype(::Node, ::Type{Sprout{N}}) where N = N
yieldtype(::Trace, ::Type{<:Sprout}) = Tuple{Vararg{Int}}
yieldtype(::Level, ::Type{<:Sprout}) = Int
