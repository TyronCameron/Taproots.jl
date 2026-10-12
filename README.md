

<p align="center">
  <img src="docs/src/assets/taproots.png" width="150" />
</p>

<h1 align="center">Taproots.jl</h1>

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://tyroncameron.github.io/Taproots.jl/dev/)
[![Test workflow status](https://github.com/TyronCameron/Taproots.jl/actions/workflows/test.yml/badge.svg)](https://github.com/TyronCameron/Taproots.jl/actions/workflows/test.yml)
[![Coverage](https://codecov.io/gh/TyronCameron/Taproots.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/TyronCameron/Taproots.jl)
[![Docs workflow Status](https://github.com/TyronCameron/Taproots.jl/actions/workflows/doc.yml/badge.svg)](https://github.com/TyronCameron/Taproots.jl/actions/workflows/doc.yml)
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Welcome to `Taproots.jl`, the library made for recursing through nested data. 

I made this library for my own use, and so just be aware that future modification and dev is very likely. 

Inspired by `AbstractTrees.jl`, and adding on the ability to track previous nodes, this library gives you iteration capabilities to visit nodes in your DAGs. 

This package has the following benefits over other packages: 

- It is ergonomic to iterate. It doesn't require a graph object or adjacency matrix. Any struct will do. You can define `children` for your struct in general (or indeed for one traversal) without first laying out your data in an adjacency matrix. 
- It has powerful tracking, allowing you to iterate in multiple ways (`preorder`, `postorder`, `topdown`, `bottomup`), and traverse the graph `OncePerNode` or `OncePerEdge` or visiting `AllPaths` or all paths excluding cycles (`NoCycles`). 
- The iterators it provides are fully lazy (except for `bottomup` which frontloads some of the work).
- It can iterate infinitely even at depths which would otherwise stack overflow. 
- It is reasonably fast. Allocation is unavoidable in this package (due to tracking nodes), but it is minimised. Type inference is prioritised at each step. Benchmarks suggest it is a similar speed to writing out a quick-and-easy recursion. 

Check out the [docs](https://tyroncameron.github.io/Taproots.jl/dev/) for more info. 

## Example: I have my own data, how do I traverse it?

Let's say you defined your own type. 

```julia
struct TerniaryTree
	node_name::String
	left_option::Union{TerniaryTree, Nothing}
	middle_option::Union{TerniaryTree, Nothing}
	right_option::Union{TerniaryTree, Nothing}
end 
Base.show(io::IO, node::TerniaryTree) = print(io, node.node_name)
```

Get access to all the traversal functionality in this package very easily!

```julia
Taproots.children(node::TerniaryTree) = (node.left_option, node.middle_option, node.right_option)
```

Now we can traverse the `TerniaryTree`

```julia
for node in postorder(deeply_nested_terniary_tree) 
	println(node)
end 
```

That will work even if `deeply_nested_terniary_tree` is deeper than recursion allows, or if `deeply_nested_terniary_tree` has cycles in it. 

Get access to additional modification functionality by optionally implementing `Taproots.data`, `Taproots.setchildren!`, `Taproots.setdata!`. 

## Example: change all the data in a dict

Let's say we've got a nested `Dict`, and we want to change all the text in the edge values to uppercase. 

```julia
dict = Dict(
	:a => Dict(
		:b => "nonsense_data",
		:c => "more_data",
	),
	:d => "final_data"
)
leafmap(uppercase, dict)
```

This gives us something that looks like this: 

```julia 
Dict(
	:a => Dict(
		:b => "NONSENSE_DATA",
		:c => "MORE_DATA",
	),
	:d => "FINAL_DATA"
)
```

## Example: want to replace a function call in a meta expression 

Let's say we've got some code, and we want to replace every single reference to `map` with `filter`. 

We can do something like this:

```julia
expr = :(append!(map(x -> sqrt(x) == floor(sqrt(x)), nums), map(x -> x^(1/3) == floor(x^(1/3)), nums)) |> unique!)
leafmap!(x -> x == :map ? :filter : x, expr)

nums = 1:100
eval(expr)
```

That replaced every `map` function call to instead call `filter`. 
