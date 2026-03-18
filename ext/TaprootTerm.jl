module TaprootTerm 
using Taproots 
using AbstractTrees
using Term.Trees: Tree 
export @sprout, bloom, @bloom

"""
    @sprout YourType

This just sets AbstractTrees.children(x::YourType) = Taproots.children(x::YourType). Must be used before you can bloom or @bloom.
"""
macro sprout(my_type)
    my_type_esc = esc(my_type)
    quote AbstractTrees.children(x::$(my_type_esc)) = Taproots.children(x) end
end

"""
    bloom(io::IO, taproot)

Pretty print a taproot. Requires you to have used @sprout YourType for it to work.
"""
function bloom(io::IO, taproot)
    println(io, Tree(taproot))
end
bloom(taproot) = bloom(stdout, taproot)

macro bloom(taproot)
    tappy = esc(taproot)
    quote bloom($(tappy)) end
end

@sprout Taproot

end 