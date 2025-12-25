[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://tyroncameron.github.io/Taproots.jl/dev/)

# Taproots.jl

I made this library for personal use but I was getting annoyed with not being able to `Pkg.add("Taproots")`. So now you can use it too, if you want. 

Just be aware that future modification and dev is very likely. 

This library helps you traverse your own nested structs and data in easy peasy ways! 
This library is inspired by `AbstractTrees.jl`. 

Check out the [docs](https://tyroncameron.github.io/Taproots.jl/dev/) for more info. 

Here's a quick tldr with a few examples.

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

Did you see what that does? It replaced every `map` function call to instead call `filter`. 

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

Get access to modification functionality by optionally implementing `Taproots.data`, `Taproots.setchildren!`, `Taproots.setdata!`. It's worth it! 

## Bonus: Get free visualisation set up for your types

```julia
@sprout TerniaryTree # set up @bloom for this type
@bloom deeply_nested_terniary_tree
```

```julia
using Plots
plotdag(deeply_nested_terniary_tree) 
plottree(deeply_nested_terniary_tree) 
```

## Bonus: Index into nested data in a nice way!

```julia
getatkeys(dict, (:a, :b); default = "Nothing found") == "nonsense_data"
```

For this and more, check out the [docs](https://tyroncameron.github.io/Taproots.jl/dev/)! 
