#─────────────────────────────────────────────────────────────────────────────#
# Pathsets
#─────────────────────────────────────────────────────────────────────────────#
    # Properties about the paths that are allowed (all paths, no cycles, once per edge, once per node)
    # Pathsets themselves are trackers and require the following functions
        # initpathset(::Type{<:Pathset}[, ::Type{N}]; sizeguess) -- create a default version (optionally with typed storage for node type N, preallocated for ~sizeguess nodes)
        # tracknode!(pathset::PathSet, node, level) -- tracks the node so that we don't visit it again
        # visitnode(pathset::PathSet, node) -- should we visit this next node?
        # visitchild(pathset::PathSet, node, child) -- should we visit the child? Useful for edges

abstract type PathSet end

## AllPaths
##────────────────────────────────────────────────────────────────────────────#
    # Goes through every permutation of edges

struct AllPaths <: PathSet end

initpathset(::Type{AllPaths}; sizeguess::Int = 256) = AllPaths()
initpathset(::Type{AllPaths}, ::Type; sizeguess::Int = 256) = AllPaths()
tracknode!(::AllPaths, node, level) = nothing
visitnode(::AllPaths, node) = true
visitchild(::AllPaths, node, child) = true

## NoCycles
##────────────────────────────────────────────────────────────────────────────#
    # Stops when it sees cycles

mutable struct NoCycles{T} <: PathSet
    parents::Set{T}
    latest::Vector{T}
end

initpathset(::Type{NoCycles{T}}; sizeguess::Int = 8) where T = NoCycles(sizehint!(Set{T}(), sizeguess), sizehint!(T[], sizeguess))
initpathset(::Type{NoCycles}; sizeguess::Int = 8) = initpathset(NoCycles{Any}; sizeguess)
initpathset(::Type{NoCycles}, ::Type{N}; sizeguess::Int = 8) where N = initpathset(NoCycles{N}; sizeguess)
initpathset(::Type{NoCycles{T}}, ::Type; sizeguess::Int = 8) where T = initpathset(NoCycles{T}; sizeguess)
function tracknode!(t::NoCycles, node, level)
    while length(t.latest) > level # truncate the parent stack down to this node's ancestors
        delete!(t.parents, pop!(t.latest))
    end
    push!(t.parents, node)
    push!(t.latest, node)
end
visitnode(t::NoCycles, node) = node ∉ t.parents
visitchild(t::NoCycles, node, child) = true

## OncePerEdge
##────────────────────────────────────────────────────────────────────────────#
    # Stops when it sees the same combo of node and parent

struct OncePerEdge{T} <: PathSet
    visited::Set{T}
end

initpathset(::Type{OncePerEdge{T}}; sizeguess::Int = 256) where T = OncePerEdge(sizehint!(Set{T}(), sizeguess))
initpathset(::Type{OncePerEdge}; sizeguess::Int = 256) = initpathset(OncePerEdge{Any}; sizeguess)
initpathset(::Type{OncePerEdge}, ::Type{N}; sizeguess::Int = 256) where N = initpathset(OncePerEdge{N}; sizeguess)
initpathset(::Type{OncePerEdge{T}}, ::Type; sizeguess::Int = 256) where T = initpathset(OncePerEdge{T}; sizeguess)
tracknode!(t::OncePerEdge, node, level) = push!(t.visited, node)
visitnode(t::OncePerEdge, node) = true
visitchild(t::OncePerEdge, node, child) = node ∉ t.visited

## OncePerNode
##────────────────────────────────────────────────────────────────────────────#
    # Stops when it sees the same node it's already visited

struct OncePerNode{T} <: PathSet
    visited::Set{T}
end

initpathset(::Type{OncePerNode{T}}; sizeguess::Int = 256) where T = OncePerNode(sizehint!(Set{T}(), sizeguess))
initpathset(::Type{OncePerNode}; sizeguess::Int = 256) = initpathset(OncePerNode{Any}; sizeguess)
initpathset(::Type{OncePerNode}, ::Type{N}; sizeguess::Int = 256) where N = initpathset(OncePerNode{N}; sizeguess)
initpathset(::Type{OncePerNode{T}}, ::Type; sizeguess::Int = 256) where T = initpathset(OncePerNode{T}; sizeguess)
tracknode!(t::OncePerNode, node, level) = push!(t.visited, node)
visitnode(t::OncePerNode, node) = node ∉ t.visited
visitchild(t::OncePerNode, node, child) = true
