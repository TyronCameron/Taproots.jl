function create_lattice(depth, width = 2)
    layer = [Taproot(i, Taproot[]) for i in 1:width]
    for _ in 1:depth
        layer = [Taproot(i, copy(layer)) for i in 1:width]
    end
    return Taproot("Root", layer)
end

leafbatches_lattice() = create_lattice(16)
