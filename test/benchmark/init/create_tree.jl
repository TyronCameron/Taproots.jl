function create_tree(target_nodes = 1000; max_children=4, rng=Random.default_rng())
    count = 0

    function make_node(depth=0)
        count += 1
        if count >= target_nodes
            return Taproot(count, Taproot[])
        end

        n_children = rand(rng, 0:max_children)

        children = Taproot[]
        sizehint!(children, n_children)

        for _ in 1:n_children
            count >= target_nodes && break
            push!(children, make_node(depth + 1))
        end

        return Taproot(count, children)
    end

    return make_node()
end
