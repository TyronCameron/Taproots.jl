#─────────────────────────────────────────────────────────────────────────────#
# Pathsets
#─────────────────────────────────────────────────────────────────────────────#
    # Properties about the paths that are allowed (all paths, no cycles, once per edge, once per node)
    # Pathsets themselves are trackers and require the following functions 
        # initpathset(::Type{<:Pathset}) -- create a default version
        # tracknode!(pathset::PathSet, node, level) -- tracks the node so that we don't visit it again
        # visitnode(pathset::PathSet, node) -- should we visit this next node? 
        # visitchild(pathset::PathSet, node, child) -- should we visit the child? Useful for edges

abstract type PathSet end 

## AllPaths
##────────────────────────────────────────────────────────────────────────────#
    # Goes through every permutation of edges 

struct AllPaths <: PathSet end 

initpathset(::Type{AllPaths}) = AllPaths()
tracknode!(::AllPaths, node, level) = nothing 
visitnode(::AllPaths, node) = true
visitchild(::AllPaths, node, child) = true

## NoCycles
##────────────────────────────────────────────────────────────────────────────#
    # Stops when it sees cycles

mutable struct NoCycles{T} <: PathSet 
    parents::Set{T}
    latest::Union{T, Nothing}
    current_level::Int
end 

initpathset(::Type{NoCycles{T}}) where T = NoCycles(Set{T}(), nothing, -1)
initpathset(::Type{NoCycles}) = initpathset(NoCycles{Any})
function tracknode!(t::NoCycles, node, level)
    if level <= t.current_level && t.latest ∈ t.parents pop!(t.parents, t.latest) end # remove latest one (important to stay in this order), possible to stay at this level
    if level >= t.current_level push!(t.parents, node) end # go down one level
    t.latest = node
    t.current_level = level
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
tracknode!(t::OncePerNode, node, level) = push!(t.visited, node)
visitnode(t::OncePerNode, node) = node ∉ t.visited
visitchild(t::OncePerNode, node, child) = true
