[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://tyroncameron.github.io/Taproots.jl/dev/)

# Taproots.jl

This library helps you traverse your own nested structs and data in easy peasy ways! 
This library is inspired by AbstractTrees.jl. 

For the purposes of this package, we'll consider *any* struct a taproot if:

- It has nested data which can be accessed from the struct in some way (whether by using keys or by actually holding that data)
- That nested data forms a Directed Acyclic Graph (DAG) (warning, this package can't handle cycles -- you'll get stackoverflow)
- "Distance" between nodes is not something we need to consider (unless it can be held in data of some kind).

That's right, no need to use some struct I created. You can use your own and traverse it a bunch of ways. 

Worth a quick note that a Taproot is not quite as general as a DAG -- with the main difference being that a Taproot has only one root node, and all other nodes eventually point inwards to that root node. Obviously DAGs can also have a distance between nodes -- but we're not interested in that. We're only interested to see if a node can or cannot be reached by another one. 

That being said, many structures in the world form Taproots:

- File and folder structures (pls ignore symlinks)
- Nested data structures such as JSON, YAML, and so on. Nested Julia Dicts also do this
- A response variable with all its causally-related covariates. 

## Installation 

In the julia REPL, type ] and the `add Taproots`.

## How to use

You can turn your own structs into Taproots very quickly!

```julia
using Taproots

mutable struct MyType 
	some_data
	children
end

Taproots.children(x::MyType) = x.children 
```

We're done! You now have access to (almost) all the functionality in Taproots.jl. 

Now let's say you create some nastily nested structure: 

```julia
my_data = MyType("The Root", [
	MyType("Some other data", []),
	MyType("I can nest data here", [
		MyType("Such nested, much wow", [])
	]),
	"I don't even need to stick to one type ... but obviously a string has no children",
	Dict(
		:x => "Taproots.children is already implemented on dicts",
		:y => :("As well as " * " other types")
	)
])
```

Now you might wish to traverse ALL that data in a lazy, speedy way:

```julia 
for nested_data in postorder(my_data)
	println(nested_data)
end
```

Or just the things at the edges (which is what I care about most of the time):

```julia 
for nested_data in leaves(my_data)
	println(nested_data)
end
```

Similar other options exist as well:

```julia
preorder(my_data) # a preorder depth-first search 
postorder(my_data) # this is topological order (or postorder depth-first search)
topdown(my_data) # a unique level-order breadth-first search
bottomup(my_data) # this is just the reverse of topdown. Warning, this one isn't lazy, and it produces a vector to remind you of that. 

leaves(my_data) # only look at the data that doesn't have children
branches(my_data) # only look at the data that does have children

traces(my_data) # get all traces (tace = a simple vector of indices in order) so that you can index into a particular child later
tracepairs(my_data) # get all traces along with values so that you can index into a particular child or just use that information right away
```

Each of those functions returns a Julia Channel, so you can use it like any iterator, using `map`, `reduce`, and `Iterators.filter`. Obviously you can just `collect` that into a vector if you prefer (and you don't need the laziness benefits).

```julia
my_data_in_a_vec = my_data |> postorder |> collect
println(my_data_in_a_vec)


Iterators.filter(x -> x isa String, leaves(my_data)) |> first # gives us the only string in the data structure ... "I don't even need to stick to one type ... but obviously a string has no children"
```

Packages like this one are nice but you may be worried about interoperability with other (potentially more expansive) packages. So to make it all work out plainly, you can grab an adjacency matrix of your taproot whenever you want.

```julia
adjacencymatrix(my_data) # gives us an adjacency matrix of 1s and 0s
```

You are now able to shove the structure of your DAG into another graph-specific utility. But don't be too hasty; check out the cool things Taproots.jl can do first!

There are also other handy functions to help you flag certain nodes so you know what they look like in your structure:

```julia
ischild(potential_child, parent) # true if the potential child is recursively a child of the parent. This can be slow if your Taproot is big.
isparent(potential_parent, child) # true if the potential parent is recursively a parent of the child. This can be slow if your Taproot is big.
isleaf(node) # true if the node has no children
isbranch(node) # true if the node has any children
```

There are handy functions to help you find nodes as well! 

```julia
findtrace(matcher, my_data) # gets you an index trace of the first node for which matcher(node) evaluates to true. 
findtrace(child, my_data) # gets you an index trace of the first node which is equal to child. 
findtraces(matcher, my_data) # gets you every index trace of the nodes for which matcher(node) evaluates to true.
findtraces(child, my_data) # gets you every index trace of the nodes for which node == child. 
followtrace(my_data, trace) # follows the index down to the pits to get you back whatever is in that index spot
```


## Modification of data and structure

Now there comes a time in every Taprootian's life when they yearn to modify their Taproots in place. And this is a dangerous topic because if you modify a Taproot in place, you might destroy the links to the children inadvertently. So for this purpose, you would need to add a few more functions. 

```julia
Taproots.data(node::MyType) = node.some_data # provide a way to get any auxiliary data (other than children) that your node might contain. Can simply return `node` or nothing at all. Doing this will unlock sinking your type to a Taproots.Taproot. 
Taproots.setdata!(node::MyType, data) = (node.some_data = data; node) # provide a way to set data in your node, if any. It can also do nothing. Once done, it must return `node`. This one as well as the next unlocks `tapmap` and variants.
Taproots.setchildren!(node::MyType, children::Vector) = (node.children = children; node) # provide a way to set children in your node. Once done, it must return `node`. This one unlocks `prune` and variants. 
````

Now we get the *good* stuff. We can map every node's data while keeping the structure sparkly. 

```julia
tapmap(x -> x isa String ? uppercase(x) : x, my_data) # x comes straight from Taproots.data(node). Warning! x itself is not a node, and as such the strings inside MyType also get converted. Pretty awesome, but be careful!
```

We can also get rid of all the nodes we don't like (... except the root, topmost node. Prune won't get rid of that one, and for good reason.)

```julia
prune(x -> x isa MyType, my_data) # x is the entire node
```

There are similar handy functions such as:

```julia
tapmap!(f, taprootius) # modify all nodes in place
tapmap(f, taprootius) # deepcopy and then modify all nodes in place

tapmapif!(condition, f, taprootius) # modify nodes in place if they satisfy `condition`. Very handy if your tree has multiple different types. 
tapmapif(condition, f, taprootius) # deepcopy and then modify nodes in place if they satisfy `condition`. Very handy if your tree has multiple different types. 

leafmap!(f, taprootius) # modify all leaves in place
leafmap(f, taprootius) # deepcopy and then modify all leaves in place

branchmap!(f, taprootius) # modify all branches in place
branchmap(f, taprootius) # deepcopy and then modify all branches in place

prune!(f, taprootius) # get rid of children which do not satisfy f in place
prune(f, taprootius) # deepcopy and then get rid of children which do not satisfy f in place

leafprune!(f, taprootius) # get rid of leaves which do not satisfy f in place
leafprune(f, taprootius) # deepcopy and then get rid of leaves which do not satisfy f in place

branchprune!(f, taprootius) # get rid of branches which do not satisfy f in place
branchprune(f, taprootius) # deepcopy and then get rid of branches which do not satisfy f in place
```

Now from time to time you may not be able to `setdata!` or `setchildren!` because you're dealing with an immutable struct. In that case, just make `setdata!` and `setchildren!` reconstruct your immutable type. 


## Built-in taproots

It's not the point of this package, but there is a minimal (but fully functional) mutable struct called Taproot which this package exports. You can use this to store data if you couldn't be bothered with nesting things in your own struct.
Taproots, however, don't allow arbitrary children types.

```julia
Taproot(data::Any, children::Vector{Taproot})
```

Alternatively, you can convert your type to a Taproots.Taproot. 

```julia
taprootius = tapin(my_data)
```

You can get back out again simply by providing some kind of sink. 

```julia
back_to_the_future = tapout((data, children) -> MyType(data, children), taprootius)
```

In the example above, the children will automatically be coverted to `MyType` because the `sink` function we provided gets called recursively. 

Taproots.jl also treats many base types like `Dict`, `Vector`, and `Expr` as taproots, and all other types as leaves.
So you can do something like this 

```julia
dict = Dict(
		:a => Dict(
			:b => "nonsense_data",
			:c => "more_data",
		),
		:d => "final_data"
	)
leafmap!(uppercase, dict)
```

Here's another usecase: metaprogramming. 

```julia
nums = 1:100
expr = :(append!(map(x -> sqrt(x) == floor(sqrt(x)), nums), map(x -> x^(1/3) == floor(x^(1/3)), nums)) |> unique!)
leafmap!(x -> x == :map ? :filter : x, expr)
eval(expr)
```

This last bit here is absolute raw power. Code expressions are abstract syntax trees, and so they are taproots as well.

You might be wondering at this stage, "Is every struct actually a taproot". Of course they are ... 

```julia
struct FourLeggedStruct 
	a
	b
	c
	d
end 
```

Can we just define the children to be `(a,b,c,d)`? Yes, we can, and it's easy. But sometimes it's better not to think of them that way, and that's why this isn't the default behaviour of Taproots.jl. But should you want to, you can just do this 

```julia
Taproots.children(x::FourLeggedStruct) = eachfield(x)
```

Or if you just want to traverse a ton of stuff:

```julia
Taproots.children(x) = eachfield(x) # now everything will do this by default (unless more specifically defined). 
```

There is also one more thing this package does which I think it pretty handy and which is related to the main concepts that Taproot deals with, but does not actually a require a taproot. It requires nested data with keys. 
```julia
dict = Dict(1 => Dict(:a => Dict(1 => Dict(:a => "Finally here"))))
followindexes(dict, (1,:a,1,:a)) == "Finally here"
```


## Seeing the structure of your DAGs

This package is interoperable with Term.jl for a CLI view and adds two very nice graph recipes to Plots.jl.  
The data inside these can get cluttered, so it's recommended that you just overload `Base.show` for your custom types.

### Terminal visualisation

```julia
@sprout MyType # sets up AbstractTrees.jl and Term.jl so that you can call bloom if you want
@bloom my_data # shows the data nicely
```

### Plotting
```julia
using Plots

plottree(my_data)
plotdag(my_data)
```

## FAQ

### Why do I need to define `children` and `data` and `setchildren!` and `setdata!`. Why not just `children` and `setchildren!`? 

So that you don't accidentally lose the children by calling `tapmap!`, and you don't accidentally modify data with `prune!`.

### Why is `tapmap` not as speedy as `tapmap!` (and similar)?

`tapmap` deepcopies before it calls `tapmap!`. That is expensive, but a neat way of ensuring we don't modify the wrong data. 

### How can I improve the speed of `tapmap!` (and similar)? 

Use `tapmapif!(condition, f, taproot)`. This will only execute `f` and set data and so on if the condition is satisfied. 

### What if my struct is immutable? 

If your `Taproots.data` is immutable, that's fine. You just need `Taproots.setdata!` to return the entire node (as always). I catered for that in `tapmap!` because this is so common with leaf nodes. 
`tapmap!` will automatically reconstruct the children in a nice way for you -- but, warning, it calls `Taproots.setchildren!`. 
If your children are immutable, I haven't catered for that nicely, and neither `tapmap!` nor `prune!` (and variants) will work. 

