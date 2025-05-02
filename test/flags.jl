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