[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://tyroncameron.github.io/Taproots.jl/dev/)
[![Test workflow status](https://github.com/TyronCameron/Taproots.jl/actions/workflows/test.yml/badge.svg)](https://github.com/TyronCameron/Taproots.jl/actions/workflows/test.yml)
[![Coverage](https://codecov.io/gh/TyronCameron/Taproots.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/TyronCameron/Taproots.jl)
[![Docs workflow Status](https://github.com/TyronCameron/Taproots.jl/actions/workflows/doc.yml/badge.svg)](https://github.com/TyronCameron/Taproots.jl/actions/workflows/doc.yml)
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

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

## Benchmarks 

|      **benchmark**<br>`Symbol` | **loc\_naive**<br>`Int64` | **time\_naive**<br>`Float64` | **memory\_naive**<br>`Float64` | **gctime\_naive**<br>`Float64` | **allocs\_naive**<br>`Float64` | **loc\_taproots**<br>`Int64` | **time\_taproots**<br>`Float64` | **memory\_taproots**<br>`Float64` | **gctime\_taproots**<br>`Float64` | **allocs\_taproots**<br>`Float64` |
|-------------------------------:|--------------------------:|-----------------------------:|-------------------------------:|-------------------------------:|-------------------------------:|-----------------------------:|--------------------------------:|----------------------------------:|----------------------------------:|----------------------------------:|
|  preorder\_simple\_small\_tree |                         5 |                       5100.0 |                        16960.0 |                            0.0 |                            9.0 |                            1 |                           972.0 |                             256.0 |                               0.0 |                               5.0 |
| postorder\_simple\_small\_tree |                         5 |                       5390.0 |                        16960.0 |                            0.0 |                            9.0 |                            1 |                          1062.0 |                             272.0 |                               0.0 |                               5.0 |
|   topdown\_simple\_small\_tree |                         7 |                       4478.0 |                        20952.0 |                            0.0 |                           11.0 |                            1 |                           991.0 |                             256.0 |                               0.0 |                               5.0 |
|  bottomup\_simple\_small\_tree |                         3 |                       5260.0 |                        25032.0 |                            0.0 |                           12.0 |                            1 |                          1072.0 |                             272.0 |                               0.0 |                               5.0 |
|              simple\_big\_tree |                         7 |                          Inf |                            Inf |                            Inf |                            Inf |                            1 |                       3.23357e8 |                         2.69665e8 |                          4.3589e7 |                         7.99952e6 |
|                          cycle |                         6 |                          Inf |                            Inf |                            Inf |                            Inf |                            1 |                            20.0 |                             192.0 |                               0.0 |                               2.0 |
|                expensive\_tree |                         5 |                    1.30063e6 |                      5.51398e6 |                            0.0 |                           25.0 |                            1 |                       3.15128e6 |                         3.48716e6 |                               0.0 |                          116443.0 |

