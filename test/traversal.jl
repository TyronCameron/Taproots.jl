
iters = (preorder, postorder, topdown, bottomup, traces, tracepairs)	

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
		@test all(bottomup(collider) |> to_compare .== collider_bottomup_ans)
	end

	@testset "leaves" begin
		collider_leaves_ans = ["Collider", "Loner"]
		@test all(leaves(collider) |> to_compare .== collider_leaves_ans)
	end

	@testset "branches" begin
		collider_branches_ans = ["The top", "Go right", "Go left"]
		@test all(branches(collider) |> to_compare .== collider_branches_ans)
	end

	@testset "traces" begin
		collider_traces_ans = [Int[], [2], [2, 1], [1], [1, 2]]
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

	@testset "Revisit lengths are the same" begin 
		@test length(collect(branches(my_complex_type; revisit = true))) + length(collect(leaves(my_complex_type; revisit = true))) == length(collect(postorder(my_complex_type; revisit = true)))
		@test begin 
			valid = true
			for taproot in fast_examples
				lengths = []
				for iter in iters
					push!(lengths, length(collect(iter(taproot; revisit = true))))
				end
				valid = length(unique(lengths)) == 1
				@debug "------------------------------------"
				@debug "Revisit is set off explicitly. Taproot = $taproot"
				@debug "Lengths = $(zip(iters, lengths) |> collect)"
				@debug "------------------------------------"
				if !valid break end
			end
			valid
		end 
	end
end

@testset "Traversal has nice properties" begin
	
	@testset "No stackoverflow" begin
		ans = 20000 * 2 + 2 + 1
		@test length(preorder(deepdag) |> collect)	== ans
	end

	@debug "Starting cycles. If the program hangs, that's a problem"
	@testset "Can handle cycles" begin 
		for iter in iters
			value = 0
			for (i, v) in enumerate(iter(cycle))
				value = i
				if i > 10000 break end
			end 
			@test 0 < value <= 100
		end
	end

	@testset "Can iterate infinitely through cycles if desired" begin
		value = 0
		for (i, node) in enumerate(preorder(cycle; revisit = true))
			value = i
			if i >= 10 break end
			if i > 10000 break end
		end
		@test value == 10
	end

end