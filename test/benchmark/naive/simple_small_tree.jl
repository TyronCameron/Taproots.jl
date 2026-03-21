

function simple_small_tree(tree, v = Taproot[])
    push!(v, tree)
    for child in children(tree) simple_small_tree(child, v) end 
    return v
end
