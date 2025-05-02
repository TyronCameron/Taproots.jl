@testset "Indexing is nice" begin
	@testset "Get trace" begin
		@test all(findtrace(13, expr) .== [2, 3, 3])
		@test findtrace(25, expr) === nothing
	end

	@testset "Follow trace" begin
		@test pluck(expr, findtrace(13, expr)) == 13
		@test pluck(expr, 2, 3, 3) == 13
	end
end