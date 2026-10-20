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
@testset "treeadjacency repeats shared nodes" begin
	adj = Taproots.treeadjacency(collider) # "Collider" has two parents
	@test size(adj) == (6, 6)
	@test sum(adj) == 5
	@test all(sum(adj; dims = 1)[2:end] .== 1) # every node but the root has exactly one parent
end
