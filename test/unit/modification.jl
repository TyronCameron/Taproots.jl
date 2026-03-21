
nums = 1:100
ans = [1,4,9,16,25,36,49,64,81,100,8,27]

@testset "Modification" begin

	@testset "Reduction and leaf map" begin 
		tappy = Taproot("Hello", [Taproot("Something Else", Taproot[]), Taproot("Another", [Taproot("Yet another one", Taproot[])])])
		@test reduce((a, b) -> a * b.data, preorder(tappy), init = "") == "HelloAnotherYet another oneSomething Else"

		orig_dict = deepcopy(dict)
		mapped_dict = leafmap!(x -> x isa String ? uppercase(x) : x*2, orig_dict)
		@test all(leaves(mapped_dict) |> collect |> Set .== Set([10, "HELLO WORLD", "DEAD END"]))
	end 

	@testset "AST" begin
		expr = :(append!(map(x -> sqrt(x) == floor(sqrt(x)), nums), map(x -> x^(1/3) == floor(x^(1/3)), nums)) |> unique!)
		cop = deepcopy(expr)

		e1 = cop
		leafmap!(x -> x == :map ? :filter : x, e1)
		res = eval(e1)

		@test all(res .== ans)
		@test occursin("filter", string(cop)) # modifies in place

		e2 = leafmap(x -> x == :map ? :filter : x, expr)
		res = eval(e2)

		@test all(res .== ans)
		@test !occursin("filter", string(expr)) # does not modify in place
	end

end



