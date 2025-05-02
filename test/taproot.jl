@testset "Taproot conversion is nice" begin

	my_type = MyType(["Something here", "Something else here", MyType([])])
	tappy = tapin(my_type)

	@test tappy isa Taproot

	newtappy = deepcopy(tappy)
	@test prune!(x -> false, newtappy) == newtappy
	@test tapmap(x -> "New data", newtappy).data == "New data"
	@test isempty(tapout((data, children) -> MyType(children), newtappy).values)

	my_type_sink_out = (data, children) -> children isa Vector && !isempty(children) ? MyType(children) : data
	orig_value = tapout(my_type_sink_out, tappy)

	@test orig_value isa MyType
	@test length(collect(preorder(orig_value))) == length(collect(preorder(my_type)))
	
end