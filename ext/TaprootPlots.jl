
module TaprootPlots
using Taproots, RecipesBase, GraphRecipes

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

end 