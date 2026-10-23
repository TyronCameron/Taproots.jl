
iters = (preorder, postorder, topdown, bottomup, traces, tracepairs)	

function leafbatches_markingdone(root; connector = (node, child) -> true, done = Set(), kwargs...)
	batches = []
	for batch in leafbatches(root; connector = (node, child) -> connector(node, child) && child ∉ done, kwargs...)
		union!(done, batch)
		push!(batches, batch)
	end
	return batches
end

@testset "Traversal exact answers" begin

	to_compare = vec -> map(x -> x isa MoreFlexiTaproot ? x.data : x, collect(vec))

	@testset "preorder" begin
		collider_preorder_ans = ["The top", "Go right", "Collider", "Go left", "Loner"]
		@test all(preorder(collider) |> to_compare .== collider_preorder_ans)
	end

	@testset "postorder" begin
		collider_postorder_ans = ["Collider", "Go right", "Loner", "Go left", "The top"]
		@test all(postorder(collider) |> to_compare .== collider_postorder_ans)
	end

	@testset "topdown" begin
		collider_topdown_ans = ["The top", "Go left", "Go right", "Collider", "Loner"]
		@test all(topdown(collider) |> to_compare .== collider_topdown_ans)
	end

	@testset "bottomup" begin
		collider_bottomup_ans = ["Collider", "Loner", "Go right",  "Go left", "The top"]
		@debug bottomup(collider) |> to_compare
		@test all(bottomup(collider) |> to_compare .== collider_bottomup_ans)

		different_heights_ans = ["B", "Leaf", "A", "Top"]
		@debug "-------------------------------------------------------------"
		@debug "Left hand side = $(bottomup(different_heights) |> to_compare)"
		@debug "Right hand side = $(different_heights_ans)"
		@debug "-------------------------------------------------------------"
		@test all(bottomup(different_heights) |> to_compare .== different_heights_ans)

		b = Taproot("B", Taproot[])
		a = Taproot("A", [b])
		r = Taproot("R", [b, a])
		@test map(x -> x.data, collect(bottomup(r))) == ["B", "A", "R"]
	end

	@testset "leaves" begin
		collider_leaves_ans = ["Collider", "Loner"]
		@test all(leaves(collider) |> to_compare .== collider_leaves_ans)
	end

	@testset "branches" begin
		collider_branches_ans = ["The top", "Go right", "Go left"]
		@test all(branches(collider) |> to_compare .== collider_branches_ans)
	end

	@testset "leaves and branches respect the connector" begin
		no_right = (node, child) -> !(child isa MoreFlexiTaproot && child.data == "Go right")
		@test leaves(collider; connector = no_right) |> to_compare == ["Loner", "Collider"]
		@test branches(collider; connector = no_right) |> to_compare == ["The top", "Go left"]
		stop_left = (node, child) -> node.data != "Go left"
		@test leaves(collider; connector = stop_left) |> to_compare == ["Collider", "Go left"]
		@test branches(collider; connector = stop_left) |> to_compare == ["The top", "Go right"]
		@test leaves(node -> node isa MoreFlexiTaproot ? node.children[1:1] : (), collider) |> to_compare == ["Collider"]
	end

	@testset "leaves and branches take any eltype" begin
		@test collect(leaves(collider; eltype = Trace)) == [(2, 1), (1, 2)]
		@test collect(branches(collider; eltype = (Trace, Level))) == [((), 0), ((2,), 1), ((1,), 1)]
	end

	@testset "leafbatches" begin
		batches = vec -> map(b -> to_compare(b), collect(vec))
		@test batches(leafbatches(collider)) == [["Collider", "Loner"], ["Go right", "Go left"], ["The top"]]
		@test batches(leafbatches(different_heights)) == [["B", "Leaf"], ["A"], ["Top"]]
		@test batches(leafbatches(collider; pathset = AllPaths)) == [["Collider", "Loner", "Collider"], ["Go right", "Go left"], ["The top"]]
		@test collect(leafbatches(collider; eltype = Trace)) == [[(2, 1), (1, 2)], [(2,), (1,)], [()]]
		@test batches(leafbatches(collider.children...)) == [["Collider", "Loner"], ["Go right", "Go left"]]

		@test batches(leafbatches_markingdone(collider; done = Set{Any}([collider.children[1]]))) == [["Collider"], ["Go right"], ["The top"]]

		@test eltype(leafbatches(collider)) == Vector{Any}
		@test collect(leafbatches(cycle)) == [[nothing]]
		@test length(collect(leafbatches(deepdag))) == 20002
	end

	@testset "traces" begin
		collider_traces_ans = [(), (2,), (2, 1), (1,), (1, 2)]
		@test all(traces(collider) |> to_compare .== collider_traces_ans)
	end

	@testset "tracepairs" begin
		collider_tracepairs_ans = zip(traces(collider), preorder(collider)) |> collect
		@test all(tracepairs(collider) |> to_compare .== collider_tracepairs_ans)
	end

end 

@testset "Check lengths" begin 
	@testset "No revisit lengths are the same" begin 
		@test length(collect(branches(my_complex_type))) + length(collect(leaves(my_complex_type))) == length(collect(postorder(my_complex_type)))
		@test begin 
			valid = true
			for taproot in fast_examples
				lengths = []
				for iter in iters
					push!(lengths, length(collect(iter(taproot))))
				end
				valid = length(unique(lengths)) == 1
				@debug "------------------------------------"
				@debug "Taproot = $taproot"
				@debug "Lengths = $(zip(iters, lengths) |> collect)"
				@debug "------------------------------------"
				if !valid break end
			end
			valid
		end 
	end

	@testset "AllPaths (revisiting) lengths are the same" begin 
		@test length(collect(branches(my_complex_type; pathset = AllPaths))) + length(collect(leaves(my_complex_type; pathset = AllPaths))) == length(collect(postorder(my_complex_type; pathset = AllPaths)))
		@test begin 
			valid = true
			for taproot in fast_examples
				lengths = []
				for iter in iters
					push!(lengths, length(collect(iter(taproot; pathset = AllPaths))))
				end
				valid = length(unique(lengths)) == 1
				@debug "------------------------------------"
				@debug "All paths being visited. Taproot = $taproot"
				@debug "Lengths = $(zip(iters, lengths) |> collect)"
				@debug "------------------------------------"
				if !valid break end
			end
			valid
		end
	end

	@testset "Every pathset gives the same length in every iterator" begin
		x = Taproot("X", [Taproot("Y", Taproot[])])
		x_at_two_depths = Taproot("R", [Taproot("A", [Taproot("B", [x])]), x])
		for taproot in (fast_examples..., x_at_two_depths), pathset in (AllPaths, NoCycles, OncePerEdge, OncePerNode)
			lengths = [length(collect(iter(taproot; pathset))) for iter in (preorder, postorder, topdown, bottomup)]
			@test allequal(lengths)
		end
	end
end

@testset "bottomup keeps children before parents for every pathset" begin
	x = Taproot("X", [Taproot("Y", Taproot[])])
	shortcut = Taproot("R", [Taproot("A", [Taproot("B", [x])]), x])
	@test map(n -> n.data, collect(bottomup(shortcut; pathset = NoCycles))) == ["Y", "Y", "X", "X", "B", "A", "R"]
	@test map(n -> n.data, collect(bottomup(shortcut; pathset = OncePerEdge))) == ["Y", "X", "X", "B", "A", "R"]
	@test map(n -> n.data, collect(topdown(shortcut; pathset = NoCycles))) == ["R", "A", "X", "B", "Y", "X", "Y"]
end

function naive_leafbatches(root; connector = (node, child) -> true, pathset = OncePerNode)
	done = Set()
	batches = []
	while true
		notdone = (node, child) -> connector(node, child) && child ∉ done
		batch = [x for x in leaves(root; connector = notdone, pathset) if x ∉ done]
		isempty(batch) && return batches
		union!(done, batch)
		push!(batches, batch)
	end
end

@testset "leafbatches agrees with naive leafbatches and bottomup" begin
	samebatch(a, b) = length(a) == length(b) && Set(a) == Set(b)
	connectors = ((node, child) -> true, (node, child) -> !(child isa String), (node, child) -> child != final_collider)
	for taproot in fast_examples, pathset in (OncePerNode, AllPaths), connector in connectors
		ours = leafbatches_markingdone(taproot; pathset, connector)
		theirs = naive_leafbatches(taproot; pathset, connector)
		@test length(ours) == length(theirs) && all(samebatch.(ours, theirs))
		@test reduce(vcat, ours; init = Any[]) == collect(bottomup(taproot; pathset, connector))
	end
end

@testset "leafbatches waits for the connector to let go" begin
	y = Taproot("Y", Taproot[]); x = Taproot("X", [y]); z = Taproot("Z", Taproot[])
	r = Taproot("R", [x, z])
	names = batch -> map(n -> n.data, batch)

	@testset "a parent waits until its children are done" begin
		done = Set{Taproot}()
		walk = leafbatches(r; connector = (node, child) -> child ∉ done)
		batch, state = iterate(walk)
		@test names(batch) == ["Z", "Y"]
		push!(done, z)
		batch, state = iterate(walk, state)
		@test isempty(batch)
		batch, state = iterate(walk, state)
		@test isempty(batch)
		push!(done, y)
		batch, state = iterate(walk, state)
		@test names(batch) == ["X"]
		push!(done, x)
		batch, state = iterate(walk, state)
		@test names(batch) == ["R"]
		@test iterate(walk, state) === nothing
	end

	@testset "children done before the walk are never yielded" begin
		@test map(names, leafbatches_markingdone(r; done = Set{Any}([z]))) == [["Y"], ["X"], ["R"]]
	end

	@testset "without a connector, a child lets go once it is yielded" begin
		@test map(names, collect(leafbatches(r))) == [["Z", "Y"], ["X"], ["R"]]
	end
end

@testset "bottomup and leafbatches visit shared nodes once, not once per path" begin
	layer = [Taproot(i, Taproot[]) for i in 1:2]
	for _ in 1:40
		layer = [Taproot(i, copy(layer)) for i in 1:2]
	end
	lattice = Taproot("Root", layer)
	@test length(collect(bottomup(lattice))) == 83
	@test map(length, collect(leafbatches(lattice))) == [fill(2, 41); 1]
	@test map(Set, collect(leafbatches(lattice))) == map(Set, naive_leafbatches(lattice))
end

@testset "Traversal has nice properties" begin
	
	@testset "No stackoverflow" begin
		ans = 20000 * 2 + 2 + 1
		@test length(preorder(deepdag) |> collect)	== ans
	end

	@info "Starting cycles. If the program hangs, that's a problem"
	@testset "Can handle cycles" begin 
		for iter in iters
			@info "Testing $iter"
			value = 0
			for (i, v) in enumerate(iter(cycle))
				value = i
				if i > 10000 break end
			end 
			@test 0 <= value <= 100
		end
		@test length(collect(leafbatches(cycle; pathset = AllPaths))) <= 100
	end

	@testset "Can iterate infinitely through cycles if desired" begin
		value = 0
		for (i, node) in enumerate(preorder(cycle; pathset = AllPaths))
			value = i
			if i >= 10 break end
			if i > 10000 break end
		end
		@test value == 10
	end

end