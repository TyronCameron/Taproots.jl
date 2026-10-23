#─────────────────────────────────────────────────────────────────────────────#
# Pathsets
#─────────────────────────────────────────────────────────────────────────────#

"""
    PathSet

Decides which paths a walk may follow (all paths, no cycles, once per edge, once per node) by tracking what has been visited.
Each pathset implements:

- `initpathset(::Type{<:PathSet}[, ::Type{N}]; sizeguess)`: create a tracker, optionally with storage typed for node type `N` and preallocated for about `sizeguess` nodes
- `tracknode!(pathset, node, level)`: record `node` so that it is not visited again
- `visitnode(pathset, node, level)`: whether to visit `node`
- `visitchild(pathset, node, child)`: whether to follow the edge to `child`
"""
abstract type PathSet end

## AllPaths
##────────────────────────────────────────────────────────────────────────────#

"""
    AllPaths

A `pathset` that follows every path, so a node reached by several paths is visited once per path.
The fastest option, since nothing is tracked. Never finishes on a cyclic taproot.
"""
struct AllPaths <: PathSet end

initpathset(::Type{AllPaths}; sizeguess::Int = 256) = AllPaths()
initpathset(::Type{AllPaths}, ::Type; sizeguess::Int = 256) = AllPaths()
tracknode!(::AllPaths, node, level) = nothing
visitnode(::AllPaths, node, level) = true
visitchild(::AllPaths, node, child) = true

## NoCycles
##────────────────────────────────────────────────────────────────────────────#

"""
    NoCycles

A `pathset` that follows every path but never revisits a node's own ancestors, so cycles are cut.
Same as `AllPaths` on an acyclic taproot.
"""
mutable struct NoCycles{T} <: PathSet
    parents::Set{T}
    latest::Vector{T}
end

initpathset(::Type{NoCycles{T}}; sizeguess::Int = 8) where T = NoCycles(sizehint!(Set{T}(), sizeguess), sizehint!(T[], sizeguess))
initpathset(::Type{NoCycles}; sizeguess::Int = 8) = initpathset(NoCycles{Any}; sizeguess)
initpathset(::Type{NoCycles}, ::Type{N}; sizeguess::Int = 8) where N = initpathset(NoCycles{N}; sizeguess)
initpathset(::Type{NoCycles{T}}, ::Type; sizeguess::Int = 8) where T = initpathset(NoCycles{T}; sizeguess)
function tracknode!(t::NoCycles, node, level)
    push!(t.parents, node)
    push!(t.latest, node)
end
function visitnode(t::NoCycles, node, level)
    while length(t.latest) > level
        delete!(t.parents, pop!(t.latest))
    end
    return node ∉ t.parents
end
visitchild(t::NoCycles, node, child) = true

## OncePerEdge
##────────────────────────────────────────────────────────────────────────────#

"""
    OncePerEdge

A `pathset` that crosses each parent-child edge once, so a node is visited once per parent.
"""
struct OncePerEdge{T} <: PathSet
    visited::Set{T}
end

initpathset(::Type{OncePerEdge{T}}; sizeguess::Int = 256) where T = OncePerEdge(sizehint!(Set{T}(), sizeguess))
initpathset(::Type{OncePerEdge}; sizeguess::Int = 256) = initpathset(OncePerEdge{Any}; sizeguess)
initpathset(::Type{OncePerEdge}, ::Type{N}; sizeguess::Int = 256) where N = initpathset(OncePerEdge{N}; sizeguess)
initpathset(::Type{OncePerEdge{T}}, ::Type; sizeguess::Int = 256) where T = initpathset(OncePerEdge{T}; sizeguess)
tracknode!(t::OncePerEdge, node, level) = push!(t.visited, node)
visitnode(t::OncePerEdge, node, level) = true
visitchild(t::OncePerEdge, node, child) = node ∉ t.visited

## OncePerNode
##────────────────────────────────────────────────────────────────────────────#

"""
    OncePerNode

The default `pathset`: visits each node exactly once, however many paths lead to it.
"""
struct OncePerNode{T} <: PathSet
    visited::Set{T}
end

initpathset(::Type{OncePerNode{T}}; sizeguess::Int = 256) where T = OncePerNode(sizehint!(Set{T}(), sizeguess))
initpathset(::Type{OncePerNode}; sizeguess::Int = 256) = initpathset(OncePerNode{Any}; sizeguess)
initpathset(::Type{OncePerNode}, ::Type{N}; sizeguess::Int = 256) where N = initpathset(OncePerNode{N}; sizeguess)
initpathset(::Type{OncePerNode{T}}, ::Type; sizeguess::Int = 256) where T = initpathset(OncePerNode{T}; sizeguess)
tracknode!(t::OncePerNode, node, level) = push!(t.visited, node)
visitnode(t::OncePerNode, node, level) = node ∉ t.visited
visitchild(t::OncePerNode, node, child) = true
