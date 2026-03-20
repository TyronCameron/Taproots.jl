function postorder_simple_small_tree(tree, v = Taproot[])
    for child in children(tree) postorder_simple_small_tree(child, v) end 
    push!(v, tree)
    return v
end
