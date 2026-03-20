function expensive_tree(tree, v = Taproot[])
    push!(v, tree)
    for child in children(tree) expensive_tree(child, v) end 
    return v
end
