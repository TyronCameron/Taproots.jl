function topdown_simple_small_tree(tree, v = Taproot[tree])
    for child in children(tree) 
        push!(v, child)
        topdown_simple_small_tree(child, v) 
    end 
    return v
end
