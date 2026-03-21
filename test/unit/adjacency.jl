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