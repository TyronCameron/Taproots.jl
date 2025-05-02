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