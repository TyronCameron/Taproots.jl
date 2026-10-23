
using Plots, GraphRecipes, Taproots

const ASSETS = joinpath(@__DIR__, "..", "src", "assets")

const BACKGROUND = colorant"#0d1117"
const NODE = colorant"#4cc9f0"
const ROOT = colorant"#4895ef"
const CURRENT = colorant"#ffb703"
const VISITED = colorant"#5b6675"
const FILL = colorant"#111c2b"
const CURRENTFILL = colorant"#3a2c0a"
const EDGE = colorant"#3d4b5e"
const TEXT = colorant"#e6edf3"
const MUTED = colorant"#4a5568"

mutable struct MyType
    some_data
    children
end
Taproots.children(x::MyType) = x.children
Base.show(io::IO, x::MyType) = print(io, x.some_data)

H = MyType("H", []); E = MyType("E", []); I = MyType("I", [])
F = MyType("F", [H]); G = MyType("G", [H, I])
B = MyType("B", [E, F]); C = MyType("C", [F, G]); D = MyType("D", [G])
A = MyType("A", [B, C, D])

const NODES = collect(topdown(A))
const INDEX = Dict(node => i for (i, node) in enumerate(NODES))
const EDGES = [(INDEX[n], INDEX[c]) for n in NODES for c in Taproots.children(n)]

const EXT = Base.get_extension(Taproots, :TaprootPlots)
const XS, YS = let (_, index, adj) = EXT.dagparts((A,))
    EXT.daglayout(EXT.dagdepths((A,), index, adj), adj)
end

style(; kwargs...) = (;
    background_color = BACKGROUND, nodestrokewidth = 3, fontsize = 14, nodesize = 0.28, shorten = 0.0,
    titlefontcolor = TEXT, titlefontsize = 16, kwargs...
)

function ringdag(; ring, highlighted = Set{Int}(), edgecolor = (s, d, w) -> EDGE, edgewidth = (s, d, w) -> 2.5, kwargs...)
    p = plot(; background_color = BACKGROUND)
    for (size, alpha) in ((70, 0.05), (56, 0.09), (44, 0.14)), i in highlighted
        scatter!(p, [XS[i]], [YS[i]]; markersize = size, markercolor = CURRENT, markeralpha = alpha, markerstrokewidth = 0)
    end
    nodecolor = [i in highlighted ? CURRENTFILL : FILL for i in eachindex(NODES)]
    plotdag!(p, A; style(; names = String[], nodesize = 0.48, nodecolor, nodestrokecolor = ring, edgecolor, edgewidth, kwargs...)...)
    for (i, node) in enumerate(NODES)
        annotate!(p, XS[i], YS[i], text(string(node), "helvetica bold", 14, colorant"#ffffff", :center))
    end
    xlims!(p, -0.6, 0.6)
    return p
end

function pathedges(trace)
    edges, node = Tuple{Int, Int}[], A
    for i in trace
        child = Taproots.children(node)[i]
        push!(edges, (INDEX[node], INDEX[child]))
        node = child
    end
    return edges
end

function annotateorder!(p, order, step)
    n = length(order)
    for (k, node) in enumerate(order)
        colour = k < step ? TEXT : k == step ? CURRENT : MUTED
        annotate!(p, (k - (n + 1) / 2) * 0.11, -1.22, text(string(node), 15, colour, :center))
    end
    xlims!(p, -0.6, 0.6)
    return p
end

function walkpanel(name, walk, step)
    current = step == 0 ? Set{Int}() : Set(pathedges(last(walk[step])))
    visited = Set(INDEX[first(w)] for w in walk[1:max(step - 1, 0)])
    onpath = step == 0 ? Set{Int}() : Set(Iterators.flatten(current))
    highlighted = step == 0 ? Set{Int}() : Set(INDEX[first(walk[step])])
    ring = [i in onpath || i in highlighted ? CURRENT : i in visited ? VISITED : NODE for i in eachindex(NODES)]
    edgecolor = Dict(e => e in current ? CURRENT : EDGE for e in EDGES)
    edgewidth = (s, d, w) -> (s, d) in current ? 4.5 : 2.5
    p = ringdag(; ring, highlighted, edgecolor, edgewidth, title = name)
    ylims!(p, -1.35, 0.25); xlims!(p, -0.6, 0.6)
    return annotateorder!(p, first.(walk), step)
end

function walkgif(file, walks)
    steps = maximum(length ∘ last, walks)
    frames = [0:steps; fill(steps, 2)]
    anim = @animate for step in frames
        plot((walkpanel(name, walk, step) for (name, walk) in walks)...;
            layout = (1, length(walks)), size = (1100, 580), top_margin = 6Plots.mm, dpi = 150, background_color = BACKGROUND)
    end
    gif(anim, joinpath(ASSETS, file); fps = 1.2)
end

web = [MyType("", []) for _ in 1:3]
mid = [MyType("", web[[1]]), MyType("", web[[1, 2]]), MyType("", web[[2]]), MyType("", web[[2, 3]]), MyType("", web[[3]])]
roots = [MyType("", mid[[1, 2]]), MyType("", mid[[2, 3, 4]]), MyType("", mid[[4, 5]])]
intro = collect(topdown(roots...))
savefig(plotdag(roots...; style(;
    names = String[], nodesize = 0.11, size = (700, 400), dpi = 150,
    nodecolor = [n in roots ? ROOT : NODE for n in intro], nodestrokecolor = BACKGROUND,
    edgecolor = (s, d, w) -> EDGE, edgewidth = (s, d, w) -> 2.5,
)...), joinpath(ASSETS, "intro_dag.png"))

savefig(ringdag(; ring = NODE, size = (600, 520), dpi = 150), joinpath(ASSETS, "example_dag.png"))

walk(f) = collect(f(A; eltype = (Node, Trace)))
walkgif("depthfirst.gif", ["preorder" => walk(preorder), "postorder" => walk(postorder)])
walkgif("breadthfirst.gif", ["topdown" => walk(topdown), "bottomup" => walk(bottomup)])

function selectionpanel(name, selection)
    chosen = Set(INDEX[n] for n in selection)
    p = ringdag(; ring = [i in chosen ? CURRENT : NODE for i in eachindex(NODES)], highlighted = chosen, title = name)
    ylims!(p, -1.35, 0.25); xlims!(p, -0.6, 0.6)
    return annotateorder!(p, selection, length(selection) + 1)
end
savefig(plot(selectionpanel("leaves", collect(leaves(A))), selectionpanel("branches", collect(branches(A)));
    layout = (1, 2), size = (1100, 580), top_margin = 6Plots.mm, dpi = 150, background_color = BACKGROUND), joinpath(ASSETS, "leaves_branches.png"))
