#─────────────────────────────────────────────────────────────────────────────#
# Pathsets
#─────────────────────────────────────────────────────────────────────────────#
    # Properties about the paths that are allowed (all paths, no cycles, once per edge, once per node)
    # Pathsets themselves are trackers and require the following functions
        # initpathset(::Type{<:Pathset}[, ::Type{N}]) -- create a default version (optionally with typed storage for node type N)
        # tracknode!(pathset::PathSet, node, level) -- tracks the node so that we don't visit it again
        # visitnode(pathset::PathSet, node) -- should we visit this next node?
        # visitchild(pathset::PathSet, node, child) -- should we visit the child? Useful for edges

abstract type PathSet end

## AllPaths
##────────────────────────────────────────────────────────────────────────────#
    # Goes through every permutation of edges

struct AllPaths <: PathSet end

initpathset(::Type{AllPaths}) = AllPaths()
initpathset(::Type{AllPaths}, ::Type) = AllPaths()
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

initpathset(::Type{NoCycles{T}}) where T = NoCycles(Set{T}(), T[])
initpathset(::Type{NoCycles}) = initpathset(NoCycles{Any})
initpathset(::Type{NoCycles}, ::Type{N}) where N = initpathset(NoCycles{N})
initpathset(::Type{NoCycles{T}}, ::Type) where T = initpathset(NoCycles{T})
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

initpathset(::Type{OncePerEdge{T}}) where T = OncePerEdge(Set{T}())
initpathset(::Type{OncePerEdge}) = initpathset(OncePerEdge{Any})
initpathset(::Type{OncePerEdge}, ::Type{N}) where N = initpathset(OncePerEdge{N})
initpathset(::Type{OncePerEdge{T}}, ::Type) where T = initpathset(OncePerEdge{T})
tracknode!(t::OncePerEdge, node, level) = push!(t.visited, node)
visitnode(t::OncePerEdge, node) = true
visitchild(t::OncePerEdge, node, child) = node ∉ t.visited

## OncePerNode
##────────────────────────────────────────────────────────────────────────────#
    # Stops when it sees the same node it's already visited

struct OncePerNode{T} <: PathSet
    visited::Set{T}
end

initpathset(::Type{OncePerNode{T}}) where T = OncePerNode(Set{T}())
initpathset(::Type{OncePerNode}) = initpathset(OncePerNode{Any})
initpathset(::Type{OncePerNode}, ::Type{N}) where N = initpathset(OncePerNode{N})
initpathset(::Type{OncePerNode{T}}, ::Type) where T = initpathset(OncePerNode{T})
tracknode!(t::OncePerNode, node, level) = push!(t.visited, node)
visitnode(t::OncePerNode, node) = node ∉ t.visited
visitchild(t::OncePerNode, node, child) = true
