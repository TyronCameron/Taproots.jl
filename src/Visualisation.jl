
#─────────────────────────────────────────────────────────────────────────────#
# Visualisation
#─────────────────────────────────────────────────────────────────────────────#

@userplot PlotTree

@recipe function f(x::PlotTree)
    t = x.args[1]
    adj = treeadjacency(t)
    names --> sprint.(show, topdown(t))
    method := :buchheim
    root --> :top
    arrow --> true
    fontsize --> 12
    nodeshape --> :ellipse
    nodecolor --> :steelblue2
    shorten --> 0.05
    edgewidth --> (s,d,w) -> 1.75
    GraphRecipes.GraphPlot((adj,))
end

@userplot PlotDag

@recipe function f(x::PlotDag)
    t = x.args[1]
    adj = dagadjacency(t)
    names --> sprint.(show, topdown(t))
    arrow --> true
    fontsize --> 12
    nodecolor --> :steelblue2
    shorten --> 0.05
    edgewidth --> (s,d,w) -> 1.75
    GraphRecipes.GraphPlot((adj,))
end

"""
    @sprout YourType

This just sets AbstractTrees.children(x::YourType) = Taproots.children(x::YourType). Must be used before you can bloom or @bloom.
"""
macro sprout(my_type)
    my_type_esc = esc(my_type)
    quote AbstractTrees.children(x::$(my_type_esc)) = children(x) end
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