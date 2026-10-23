"""
Taproots is a library for traversing nested data structures.
"""
module Taproots
using PrecompileTools: @setup_workload, @compile_workload
export Taproot, tapin, tapout, NotImplementedError,
    eachfield,
    children, childtype, childtypes, data, setchildren!, setdata!,
    ischild, isparent, isleaf, isbranch,
    preorder, postorder, topdown, bottomup, leafbatches, leaves, branches, traces, tracepairs,
    AllPaths, NoCycles, OncePerNode, OncePerEdge,
    Trace, Level, Node,
    adjacencymatrix, plotdag, plotdag!, plottree, plottree!,
    tapmap!, tapmap, tapmapif!, tapmapif, leafmap!, leafmap, branchmap!, branchmap, prune!, prune, leafprune!, leafprune, branchprune!, branchprune,
    findtrace, findtraces, pluck, graft!, getatkeys, setatkeys!, uproot

include("Taproot.jl")
include("AbstractAPI.jl")
include("BinaryNodeProperties.jl")

include("Shoots.jl")
include("Pathsets.jl")
include("Frontiers.jl")

include("PluckGraft.jl")

include("Iteration.jl")
include("Adjacency.jl")
include("Plotting.jl")
include("Functionals.jl")

include("Precompile.jl")

end