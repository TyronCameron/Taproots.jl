using Taproots, Test

###########################################################################
# Set up structs that players might use
###########################################################################

struct MyType 
	values::Vector
end 
Taproots.children(x::MyType) = x.values

struct MoreFlexiTaproot
	data
	children
end
Taproots.children(x::MoreFlexiTaproot) = x.children

struct MyLeafType
	x
end 

###########################################################################
# Initialise variables
###########################################################################

expr = :(println("Taproot's favourite number = " * (29 + 13)))
child_dict = Dict(:x => 5, :y => "hello world")
dict = Dict(1 => child_dict, "y" => "dead end")
taproot = Taproot("The Root", [
	Taproot("First branch", [Taproot("Leaf 1", Taproot[])]),
	Taproot(2, [Taproot("Stubby", Taproot[])]),
	Taproot("Leaf at the top", Taproot[]),
])
my_type = MyType(["Something here", "Something else here", MyType([])])
my_complex_type = MyType([
	MoreFlexiTaproot(MyLeafType("Data can be stored here, but we'll iterate past it"), [MyLeafType("This will be iterated")]),
	MyLeafType("A stub"),
])

###########################################################################
# Run tests
###########################################################################

@testset "Children work as intended" begin

	@test all(children(expr) .== [:println, :("Taproot's favourite number = " * (29 + 13))])
	@test all(children(dict) .== [child_dict, "dead end"])
	@test begin 
		data = children(taproot) .|> x -> x.data
		all(data .== ["First branch", 2, "Leaf at the top"])
	end 
	@test all(isempty.(children.(children(my_type))) .== [true, true, true])
	@test all(typeof.(children(my_complex_type)) .<: [MoreFlexiTaproot, MyLeafType])

end

@testset "Flags work as intended" begin

	@testset "ischild" begin
		@test ischild(13, expr)
		@test ischild("Taproot's favourite number = ", expr)
		@test ischild(:println, expr)
		@test ischild("hello world", dict)
		@test !ischild([], taproot)
		@test ischild("Something here", my_type)
		@test ischild(MyLeafType("A stub"), my_complex_type)
	end

	@testset "isparent" begin
		@test !isparent(expr, "Something not there")
		@test isparent(my_complex_type, MyLeafType("A stub"))
		@test !isparent(taproot, [])
	end

	@testset "isleaf" begin
		@test !isleaf(expr)
		@test isleaf("Hello there")
		@test isleaf([])
		@test isleaf(MyLeafType(MyLeafType("some stuff here")))
		@test !isleaf(Taproot("data", [Taproot("nothing", Taproot[])]))
		@test isleaf(Taproot("data", Taproot[]))
	end

	@testset "isbranch" begin
		@test isbranch(expr)
		@test !isbranch("Hello there")
		@test !isbranch([])
		@test !isbranch(MyLeafType(MyLeafType("some stuff here")))
		@test isbranch(Taproot("data", [Taproot("nothing", Taproot[])]))
		@test !isbranch(Taproot("data", Taproot[]))
	end

end

@testset "Can traverse" begin
	
	@testset "preorder" begin
		expr_preorder_ans = [:(println("Taproot's favourite number = " * (29 + 13))), :println, :("Taproot's favourite number = " * (29 + 13)), :*, "Taproot's favourite number = ", :(29 + 13), :+, 29, 13]
		@test all(collect(preorder(expr)) .== expr_preorder_ans)
		for (i, value) in enumerate(preorder(expr))
			@test value == expr_preorder_ans[i]
		end
	end

	@testset "postorder" begin
		@test all(collect(postorder(expr)) .== [:println, :*, "Taproot's favourite number = ", :+, 29, 13, :(29 + 13), :("Taproot's favourite number = " * (29 + 13)), :(println("Taproot's favourite number = " * (29 + 13)))])
		for value in postorder(my_type)
			@test value == "Something here"
			break 
		end
		@test all(map(x -> x isa Int ? 111 : x, postorder(expr)) .== [:println, :*, "Taproot's favourite number = ", :+, 111, 111, :(29 + 13), :("Taproot's favourite number = " * (29 + 13)), :(println("Taproot's favourite number = " * (29 + 13)))])
	end

	@testset "topdown" begin
		@test all(collect(topdown(expr)) .== [:(println("Taproot's favourite number = " * (29 + 13))), :println, :("Taproot's favourite number = " * (29 + 13)), :*, "Taproot's favourite number = ", :(29 + 13), :+, 29, 13])
		@test first(topdown(my_complex_type)) == my_complex_type
	end

	@testset "bottomup" begin
		@test all(collect(bottomup(expr)) .== [13, 29, :+, :(29 + 13), "Taproot's favourite number = ", :*, :("Taproot's favourite number = " * (29 + 13)), :println, :(println("Taproot's favourite number = " * (29 + 13)))])
	end

	@testset "leaves" begin
		@test all(collect(leaves(expr)) .== [:println, :*, "Taproot's favourite number = ", :+, 29, 13])
		@test all(leaves(my_complex_type) .== Iterators.filter(isleaf, preorder(my_complex_type)))
	end

	@testset "branches" begin
		@test all(collect(branches(expr)) .== [:(println("Taproot's favourite number = " * (29 + 13))), :("Taproot's favourite number = " * (29 + 13)), :(29 + 13)])
	end

	@testset "lengths are correct" begin 
		@test length(collect(branches(my_complex_type))) + length(collect(leaves(my_complex_type))) == length(collect(postorder(my_complex_type)))
		@test begin 
			valid = true
			for taproot in (expr, dict, taproot, my_type, my_complex_type)
				lengths = []
				for iter in (preorder, postorder, topdown, bottomup)
					push!(lengths, length(collect(iter(taproot))))
				end
				valid = length(unique(lengths)) == 1
				if !valid break end
			end
			valid
		end 
	end

end

@testset "Indexing is nice" begin
	@testset "Get trace" begin
		@test all(findtrace(13, expr) .== [2, 3, 3])
		@test findtrace(25, expr) === nothing
	end

	@testset "Follow trace" begin
		@test followtrace(expr, findtrace(13, expr)) == 13
	end
end

@testset "adjacencymatrix" begin
	@test all(adjacencymatrix(expr) .== [
		0 1 1 0 0 0 0 0 0;
		0 0 0 0 0 0 0 0 0;
		0 0 0 1 1 1 0 0 0;
		0 0 0 0 0 0 0 0 0;
		0 0 0 0 0 0 0 0 0;
		0 0 0 0 0 0 1 1 1;
		0 0 0 0 0 0 0 0 0;
		0 0 0 0 0 0 0 0 0;
		0 0 0 0 0 0 0 0 0;			
	])
end

@testset "Can call functional things" begin
	tappy = Taproot("Hello", [Taproot("Something Else", Taproot[]), Taproot("Another", [Taproot("Yet another one", Taproot[])])])
	@test reduce((a, b) -> a * b.data, preorder(tappy), init = "") == "HelloSomething ElseAnotherYet another one"

	orig_dict = deepcopy(dict)
	mapped_dict = leafmap!(x -> x isa String ? uppercase(x) : x*2, orig_dict)

	for (k,v) in mapped_dict
		@test orig_dict[k] == v
	end

	@test all(leaves(mapped_dict) |> collect |> Set .== Set([10, "HELLO WORLD", "DEAD END"]))
	
end


# @testset "Taproot conversion is nice" begin

# 	tappy = tapin(deepcopy(my_complex_type))
# 	@test tappy isa Taproot
# 	@test prune!(x -> false, tappy) == tappy
# 	@test map!(x -> "New data", tappy).data == "New data"
# 	@test isempty(tapout((data, children) -> MyType(children), tappy).values)

# 	my_type_sink_out = (data, children) -> children isa Vector && !isempty(children) ? MyType(children) : data
# 	check_helper = x -> x isa MyType ? x.values : x

# 	@test begin 
# 		orig_values = collect(leaves(my_type))
# 		id_values = doubletap(my_type_sink_out, my_type) do taproot
# 			taproot
# 		end |> leaves |> collect 
# 		all(id_values .|> check_helper .== orig_values .|> check_helper)
# 	end

# 	@test begin 
# 		new_tappy = doubletap((data, children) -> MoreFlexiTaproot(data, children), dict) do taproot
# 			leafmap!(taproot) do x 
# 				if x isa String 
# 					uppercase(x) 
# 				elseif x isa Number 
# 					x^2
# 				end
# 			end 
# 		end 
# 		new_values = new_tappy |> leaves |> collect .|> x -> x.data
# 		should_be = [25, "HELLO WORLD", "DEAD END"] 
# 		all(Set(new_values) .== Set(should_be))
# 	end 

# 	@test begin 
# 		new_tappy = doubletap((data, children) -> MyType(children), my_type) do taproot
# 			prune(x -> false, taproot)
# 		end  
# 		len = new_tappy |> leaves |> collect |> length 
# 		len == 1
# 	end 

# 	@test begin 
# 		pruned_tappy = doubletap((data, children) -> MyType(children), my_type) do taproot
# 			leafprune(x -> false, taproot)
# 		end 
# 		len = pruned_tappy |> postorder |> collect |> length
# 		len == length(postorder(my_type) |> collect) - length(leaves(my_type) |> collect)
# 	end
# end
