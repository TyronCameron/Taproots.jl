function expensive_tree()
    a = create_tree(10_000, rng = MersenneTwister(42)) 
    return Taproot("Header", [a for i in 1:20])
end