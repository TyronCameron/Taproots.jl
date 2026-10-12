function preorder_simple_small_tree_with_tracking(tree, v = Taproot[], seen = Set())
    if tree ∈ seen return v end 
    push!(seen, tree)
    push!(v, tree)
    for child in children(tree) preorder_simple_small_tree_with_tracking(child, v, seen) end 
    return v
end
