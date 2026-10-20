
<p align="center">
  <img src="docs/src/assets/taproots.png" width="150" />
</p>

<h1 align="center">Taproots.jl</h1>

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://tyroncameron.github.io/Taproots.jl/dev/)
[![Test workflow status](https://github.com/TyronCameron/Taproots.jl/actions/workflows/test.yml/badge.svg)](https://github.com/TyronCameron/Taproots.jl/actions/workflows/test.yml)
[![Coverage](https://codecov.io/gh/TyronCameron/Taproots.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/TyronCameron/Taproots.jl)
[![Docs workflow Status](https://github.com/TyronCameron/Taproots.jl/actions/workflows/doc.yml/badge.svg)](https://github.com/TyronCameron/Taproots.jl/actions/workflows/doc.yml)
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Traverse nested structs and data (including your own custom ones) in easy peasy ways. No graph object, no adjacency matrix, no hand-rolled recursion: tell Taproots how to find a node's children and start walking.

Inspired by `AbstractTrees.jl`, with node tracking on top, so shared children and cycles are handled for you. Walks are lazy, won't stack overflow on deep data, and run about as fast as a quick-and-easy recursion.

Many things are taproots: file and folder structures, nested JSON/YAML/`Dict`s, `Expr`s, or a response variable with all its causally-related covariates.

## Installation

In the Julia REPL, type `]` and then `add Taproots`.

## How to use

Tell Taproots how to find your struct's children:

```julia
using Taproots

mutable struct MyType
	some_data
	children
end

Taproots.children(x::MyType) = x.children
Base.show(io::IO, x::MyType) = print(io, x.some_data)
```

That's it. Let's build a small DAG, where `F`, `G` and `H` each have more than one parent:

```julia
H = MyType("H", []); E = MyType("E", []); I = MyType("I", [])
F = MyType("F", [H]); G = MyType("G", [H, I])
B = MyType("B", [E, F]); C = MyType("C", [F, G]); D = MyType("D", [G])
A = MyType("A", [B, C, D])
```

And walk it:

```julia
preorder(A)     # A D G I H C F B E   (parents before children)
postorder(A)    # I H G D F C E B A   (children before parents)
topdown(A)      # A B C D E F G H I   (level by level)
bottomup(A)     # I H E F G B C D A   (a topological sort)
leaves(A)       # I H E
leafbatches(A)  # [I, H, E], [F, G], [B, C, D], [A]   (parallelisable batches)
```

<p align="center">
  <img src="docs/src/assets/depthfirst.gif" alt="preorder and postorder walking the example DAG one node at a time" width="600" />
</p>

Every walk is a lazy iterator, so you can loop over it or call `map`, `Iterators.filter`, `first` or `collect` on it. Each node is visited once by default; ask for `pathset = OncePerEdge`, `NoCycles` or `AllPaths` if you want more. Need the path to each node, or its depth, too? Pass `eltype = (Trace, Level, Node)`:

```julia
for (trace, level, node) in preorder(A; eltype = (Trace, Level, Node))
	println("  "^level, node, "  ", trace)
end
# A  ()
#   D  (3,)
#     G  (3, 1)
#       I  (3, 1, 2)
# ...
```

No interface? Pass a `children` function on the spot:

```julia
preorder(n -> reverse(n.children), A)  # A B E F H C G I D
```

Check out the [docs](https://tyroncameron.github.io/Taproots.jl/dev/) for the rest: connectors, modifying taproots in place, searching, built-in taproots and visualisation.

*Heads up: I made this library for my own use, so expect a few changes along the way.*
