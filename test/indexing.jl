@testset "Indexing is nice" begin
	@testset "Get trace" begin
		@test all(findtrace(13, expr) .== [2, 3, 3])
		@test findtrace(25, expr) === nothing
	end

	@testset "Plucking works" begin
		@test pluck(expr, findtrace(13, expr)) == 13
		@test pluck(expr, 2, 3, 3) == 13
	end

	@testset "Grafting works" begin
		@test graft!(deepcopy(dict), [2], child_dict)["y"] == child_dict
	end

	@testset "Getatkeys works" begin
		@test getatkeys(dict, (1, :x)) == 5
		@test isnothing(getatkeys(dict, (1, 1, 1, 1, 1)))
		@test getatkeys(dict, (1, 1, 1, 1, 1); default = 0) == 0
	end

	@testset "Setatkeys works" begin
		dict_copy = deepcopy(dict)
		setatkeys!(dict_copy, (1, :x), 10)
		@test getatkeys(dict_copy, (1, :x)) == 10
	end

	@testset "Uproot works" begin
		new_root = uproot(collider, pluck(collider, 1, 1))
		@test pluck(new_root, 2, 1).data == "The top"
		@test length(collect(postorder(new_root))) == 4
		@test length(collect(postorder(collider))) == 5
	end
end