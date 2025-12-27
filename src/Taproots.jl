"""
Taproots is a library for traversing nested data structures.
"""
module Taproots
using Plots.RecipesBase, GraphRecipes, AbstractTrees, Term.Trees, ResumableFunctions
export Taproot, tapin, tapout,
    eachfield,
    children, data, setchildren!, setdata!,
    ischild, isparent, isleaf, isbranch,
    preorder, postorder, topdown, bottomup, leaves, branches, traces, tracepairs,
    AllPaths, NoCycles, OncePerNode, OncePerEdge,
    Trace, Level, Node,
    adjacencymatrix,
    tapmap!, tapmap, tapmapif!, tapmapif, leafmap!, leafmap, branchmap!, branchmap, prune!, prune, leafprune!, leafprune, branchprune!, branchprune,
    findtrace, findtraces, pluck, graft!, getatkeys, setatkeys!, uproot,
    @sprout, bloom, @bloom

include(joinpath(@__DIR__, "Taproot.jl"))
include(joinpath(@__DIR__, "AbstractAPI.jl"))
include(joinpath(@__DIR__, "BinaryNodeProperties.jl"))

include(joinpath(@__DIR__, "Shoots.jl"))
include(joinpath(@__DIR__, "Frontiers.jl"))
include(joinpath(@__DIR__, "Pathsets.jl"))

include(joinpath(@__DIR__, "PluckGraft.jl"))

include(joinpath(@__DIR__, "Iteration.jl"))
include(joinpath(@__DIR__, "Adjacency.jl"))
include(joinpath(@__DIR__, "Functionals.jl"))
include(joinpath(@__DIR__, "Visualisation.jl"))

end  # module Taproots