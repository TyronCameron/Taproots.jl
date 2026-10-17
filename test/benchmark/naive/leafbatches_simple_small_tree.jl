function leafbatches_simple_small_tree(tree, done = Set{Taproot}(), batches = Vector{Taproot}[])
    while true
        batch = [x for x in leaves(tree; connector = (node, child) -> child ∉ done) if x ∉ done]
        isempty(batch) && return batches
        union!(done, batch)
        push!(batches, batch)
    end
end
