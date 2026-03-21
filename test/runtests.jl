using Taproots, Test, Aqua 

#─────────────────────────────────────────────────────────────────────────────#
# Run tests
#─────────────────────────────────────────────────────────────────────────────#

include(joinpath(@__DIR__, "unit", "examples.jl"))

include(joinpath(@__DIR__, "unit", "taproot.jl"))
include(joinpath(@__DIR__, "unit", "traversal.jl"))
include(joinpath(@__DIR__, "unit", "children.jl"))
include(joinpath(@__DIR__, "unit", "flags.jl"))
include(joinpath(@__DIR__, "unit", "indexing.jl"))
include(joinpath(@__DIR__, "unit", "adjacency.jl"))
include(joinpath(@__DIR__, "unit", "modification.jl"))

Aqua.test_all(Taproots)
