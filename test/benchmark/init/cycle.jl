function cycle()
    a = Taproot("Top level", Taproot[
        Taproot("Second level A", Taproot[]),
        Taproot("Second level B", Taproot[])
    ])
    a.children[2].children = Taproot[a]
    return a 
end