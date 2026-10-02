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

@testset "Parallel tapmap" begin

	tree() = Taproot(1, [Taproot(2, [Taproot(4), Taproot(5)]), Taproot(3, [Taproot(6), Taproot(7, [Taproot(8)])])])

	@test [x.data for x in preorder(paralleltapmap(x -> 10x, tree()))] == [x.data for x in preorder(tapmap(x -> 10x, tree()))]
	t = tree()
	@test paralleltapmap!(x -> 10x, t) === t
	@test sort([x.data for x in preorder(t)]) == 10 .* (1:8)

	# a parent only starts once all of its children are done
	finished = zeros(Int, 8)
	counter = Threads.Atomic{Int}(0)
	t = tree()
	paralleltapmap!(t) do d
		sleep(0.01 * rand())
		finished[d] = Threads.atomic_add!(counter, 1) + 1
		d
	end
	@test all(finished[c.data] < finished[n.data] for n in preorder(t) for c in children(n))

	# a node shared by several parents is only mapped once
	shared = Taproot(0, Taproot[])
	dag = Taproot(1, [Taproot(2, [shared]), Taproot(3, [shared])])
	calls = Threads.Atomic{Int}(0)
	paralleltapmap!(d -> (Threads.atomic_add!(calls, 1); d + 100), dag)
	@test calls[] == 4
	@test shared.data == 100

	@test_throws ErrorException paralleltapmap!(d -> d == 5 ? error("boom") : d, tree())

end
