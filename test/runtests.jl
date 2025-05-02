using Taproots, Test

include(joinpath(@__DIR__, "examples.jl"))

###########################################################################
# Run tests
###########################################################################

include(joinpath(@__DIR__, "taproot.jl"))
include(joinpath(@__DIR__, "traversal.jl"))
include(joinpath(@__DIR__, "children.jl"))
include(joinpath(@__DIR__, "flags.jl"))
include(joinpath(@__DIR__, "indexing.jl"))
include(joinpath(@__DIR__, "adjacency.jl"))

@testset "Can call functional things" begin
	tappy = Taproot("Hello", [Taproot("Something Else", Taproot[]), Taproot("Another", [Taproot("Yet another one", Taproot[])])])
	@test reduce((a, b) -> a * b.data, preorder(tappy), init = "") == "HelloAnotherYet another oneSomething Else"

	orig_dict = deepcopy(dict)
	mapped_dict = leafmap!(x -> x isa String ? uppercase(x) : x*2, orig_dict)

	# for (k,v) in mapped_dict
	# 	@test orig_dict[k] == v
	# end

	@test all(leaves(mapped_dict) |> collect |> Set .== Set([10, "HELLO WORLD", "DEAD END"]))

	# tapmap!, tapmap, tapmapif!, tapmapif, leafmap!, leafmap, branchmap!, branchmap, prune!, prune, leafprune!, leafprune, branchprune!, branchprune, 
end

