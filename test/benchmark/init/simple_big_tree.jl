function create_chain(n)
    root = Taproot(1, Taproot[])
    current = root
    for i in 2:n
        child = Taproot(i, Taproot[])
        current.children = [child]
        current = child
    end
    return root
end

simple_big_tree() = create_chain(1_000_000)