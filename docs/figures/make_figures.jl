# Regenerates the images in docs/src/assets. Run from the repository root:
#   julia --project=docs/figures -e 'using Pkg; Pkg.instantiate()'
#   GKSwstype=100 julia --project=docs/figures docs/figures/make_figures.jl

using Plots, GraphRecipes, Taproots

const ASSETS = joinpath(@__DIR__, "..", "src", "assets")

# Palette
const BACKGROUND = colorant"#0d1117"
const NODE = colorant"#4cc9f0"      # lightning blue: not yet visited
const ROOT = colorant"#4895ef"
const CURRENT = colorant"#ffb703"   # the node being visited, and the path to it
const VISITED = colorant"#9aa5b4"
const EDGE = colorant"#3d4b5e"
const TEXT = colorant"#e6edf3"
const MUTED = colorant"#4a5568"

mutable struct MyType
    some_data
    children
end
Taproots.children(x::MyType) = x.children
Base.show(io::IO, x::MyType) = print(io, x.some_data)

# The example DAG from index.md
H = MyType("H", []); E = MyType("E", []); I = MyType("I", [])
F = MyType("F", [H]); G = MyType("G", [H, I])
B = MyType("B", [E, F]); C = MyType("C", [F, G]); D = MyType("D", [G])
A = MyType("A", [B, C, D])

# Same numbering plotdag uses
const NODES = collect(topdown(A))
const INDEX = Dict(node => i for (i, node) in enumerate(NODES))
const EDGES = [(INDEX[n], INDEX[c]) for n in NODES for c in Taproots.children(n)]

style(; kwargs...) = (;
    background_color = BACKGROUND, nodestrokewidth = 3, annotationcolor = BACKGROUND,
    fontsize = 14, nodesize = 0.32, shorten = 0.0, titlefontcolor = TEXT, titlefontsize = 16,
    kwargs...
)

# Edges along `trace`, walked down from the root
function pathedges(trace)
    edges, node = Tuple{Int, Int}[], A
    for i in trace
        child = Taproots.children(node)[i]
        push!(edges, (INDEX[node], INDEX[child]))
        node = child
    end
    return edges
end

# The walk's order along the bottom: visited letters bright, current amber, the rest muted
function annotateorder!(p, order, step)
    n = length(order)
    for (k, node) in enumerate(order)
        colour = k < step ? TEXT : k == step ? CURRENT : MUTED
        annotate!(p, (k - (n + 1) / 2) * 0.11, -1.22, text(string(node), 15, colour, :center))
    end
    return p
end

# One panel: `walk` holds (node, trace) pairs and the first `step` of them have been visited
function walkpanel(name, walk, step)
    current = step == 0 ? Set{Int}() : Set(pathedges(last(walk[step])))
    visited = Set(INDEX[first(w)] for w in walk[1:max(step - 1, 0)])
    onpath = step == 0 ? Set{Int}() : Set(Iterators.flatten(current))
    nodecolor = map(eachindex(NODES)) do i
        step > 0 && i == INDEX[first(walk[step])] ? CURRENT : i in visited ? VISITED : NODE
    end
    nodestrokecolor = [i in onpath ? CURRENT : BACKGROUND for i in eachindex(NODES)]
    edgecolor = Dict(e => e in current ? CURRENT : EDGE for e in EDGES)
    edgewidth = (s, d, w) -> (s, d) in current ? 5 : 2.5
    p = plotdag(A; style(; nodecolor, nodestrokecolor, edgecolor, edgewidth, title = name)...)
    ylims!(p, -1.35, 0.15)
    return annotateorder!(p, first.(walk), step)
end

function walkgif(file, walks)
    steps = length(first(last(walks)))
    frames = [0:steps; fill(steps, 2)] # hold the finished walk for a moment
    anim = @animate for step in frames
        plot((walkpanel(name, walk, step) for (name, walk) in walks)...;
            layout = (1, length(walks)), size = (1100, 580), top_margin = 6Plots.mm, background_color = BACKGROUND)
    end
    gif(anim, joinpath(ASSETS, file); fps = 1.2)
end

# 1. Intro: three roots feeding a shared web of nodes
web = [MyType("", []) for _ in 1:3]
mid = [MyType("", web[[1]]), MyType("", web[[1, 2]]), MyType("", web[[2]]), MyType("", web[[2, 3]]), MyType("", web[[3]])]
roots = [MyType("", mid[[1, 2]]), MyType("", mid[[2, 3, 4]]), MyType("", mid[[4, 5]])]
intro = collect(topdown(roots...))
savefig(plotdag(roots...; style(;
    names = String[], nodesize = 0.11, size = (700, 400), dpi = 150,
    nodecolor = [n in roots ? ROOT : NODE for n in intro], nodestrokecolor = BACKGROUND,
    edgecolor = (s, d, w) -> EDGE, edgewidth = (s, d, w) -> 2.5,
)...), joinpath(ASSETS, "intro_dag.png"))

# 2. The example DAG
savefig(plotdag(A; style(;
    size = (600, 520), dpi = 150, nodecolor = NODE, nodestrokecolor = BACKGROUND,
    edgecolor = (s, d, w) -> EDGE, edgewidth = (s, d, w) -> 2.5,
)...), joinpath(ASSETS, "example_dag.png"))

# 3. Walks, one step per frame
walk(f) = collect(f(A; eltype = (Node, Trace)))
walkgif("depthfirst.gif", ["preorder" => walk(preorder), "postorder" => walk(postorder)])
walkgif("breadthfirst.gif", ["topdown" => walk(topdown), "bottomup" => walk(bottomup)])

# 4. Leaves and branches
function selectionpanel(name, selection)
    chosen = Set(INDEX[n] for n in selection)
    p = plotdag(A; style(;
        title = name, nodecolor = [i in chosen ? CURRENT : NODE for i in eachindex(NODES)],
        nodestrokecolor = BACKGROUND, edgecolor = (s, d, w) -> EDGE, edgewidth = (s, d, w) -> 2.5,
    )...)
    ylims!(p, -1.35, 0.15)
    return annotateorder!(p, selection, length(selection) + 1)
end
savefig(plot(selectionpanel("leaves", collect(leaves(A))), selectionpanel("branches", collect(branches(A)));
    layout = (1, 2), size = (1100, 580), top_margin = 6Plots.mm, dpi = 150, background_color = BACKGROUND), joinpath(ASSETS, "leaves_branches.png"))
