# Taproots.jl

This library is to help you traverse your own nested structs and data in easy peasy ways! 
Technically, this is a DAG library (and it's inspired by AbstractTrees.jl). 

For the purposes of this package, we'll consider any struct a Taproot if:

- It has nested data which can be accessed from the struct in some way
- That nested data forms a Directed Acyclic Graph (DAG) (warning, this package can't handle cycles)
- "Distance" between nodes is not something we need to consider. 

That's right, no need to use some struct I created. You can use your own and traverse it a bunch of ways. 

Worth a quick note that a Taproot is not quite as general as a DAG -- with the main difference being that a Taproot has only one root node, and all other nodes eventually point inwards to that root node. Obviously DAGs can also have a distance between nodes -- but we're not interested in that. We're only interested to see if a node can or cannot be reached by another one. 

That being said, many structures in the world form Taproots:

- File and folder structures (pls ignore symlinks)
- Nested data structures such as JSON, YAML, and so on. Nested Julia Dicts also do this
- A response variable with all its causally-related covariates. 

## How to use

You can turn your own structs into Taproots very quickly!

```julia
using Taproots

struct MyType 
	some_data
	children
end

Taproots.children(x::MyType) = x.children 
```

We're done! You already have access now to all the functionality in Taproots.jl. 

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

Or just the things which aren't wrappers:
```julia 
for nested_data in leaves(my_data)
	println(nested_data)
end
```

Similar other options exist as well:

```julia
preorder(my_data) # a preorder depth-first search 
postorder(my_data) # this is topological order (or postorder depth-first search)
topdown(my_data) # a level-order breadth-first search
bottomup(my_data) # this is just the reverse of topdown. Warning, this one isn't lazy, but it can be nice too. 

leaves(my_data) # only look at the data that doesn't have children
branches(my_data) # only look at the data that does have children
```

Each of those functions returns a Julia Channel, so you can use it like any iterator, using `map`, `reduce`, and `Iterators.filter`. Obviously you can just `collect` that into a vector if you prefer.

```julia
my_data_in_a_vec = my_data |> postorder |> collect
println(my_data_in_a_vec)


Iterators.filter(x -> x isa String, leaves(my_data)) |> first # gives us the only string in the data structure ... "I don't even need to stick to one type ... but obviously a string has no children"
```

Packages like this one are nice but you may be worried about interoperability with other nice (potentially more expansive) packages. So to make it all work out nicely, you can grab an adjacency matrix of your taproot whenever you want.

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
gettrace(matcher, my_data) # gets you an index trace of the first node for which matcher(node) evaluates to true. Can be slow if your Taproot is big.
gettrace(child, my_data) # gets you an index trace of the first node which is equal to child. Can be slow if your Taproot is big.
followtrace(my_data, trace) # follows the index down to the pits to get you back whatever is in that index spot
```

## Seeing the structure of your DAGs

This package is interoperable with Term.jl for a CLI view and adds two very nice graph recipes to Plots.jl.  

### Terminal visualisation

```julia
using Term.Trees, AbstractTrees, Taproots

AbstractTrees.children(x::MyType) = Taproots.children(x::MyType)

print(Tree(my_data))
```

### Plotting
```julia
using Plots

plottree(my_data)
plotdag(my_data)
```

# Modification of data and structure

Now there comes a time in every Taprootian's life when they yearn to modify their Taproots in place. And this is a dangerous topic because if you modify a Taproot in place, you might destroy the links to the children inadvertently. So for this purpose, I created a sink to help out. 

Now don't freak out. No need to learn a whole new framework and seven different structs. The point of a Taproot is to temporarily give you access to safe modification without destroying your own Taproot. 
Of course, if you're comfortable enough with using the iterators above, you won't even need this section. I just think it's handy once in a while. 

```julia
taprootius = Taproot(my_data)
map!(x -> x isa String ? uppercase(x) : x, taprootius)
```
There are similar handy functions such as:

```julia
map!(f, taprootius) # modify all nodes in place
map(f, taprootius) # deepcopy and then modify all nodes in place

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

All those functions work with the preorder so data at the top will be modified before data at the bottom. This is natural for something like pruning (to try and keep things efficient). There is obviously no `reduce` function, because you can just use the iterators above for that! `reduce(f, preorder(taprootius))`. 

When you're done, you can convert `taprootius` back to your own struct using `tapout`. But you will need to tell it how.

```julia
back_to_the_future = tapout((data, children) -> MyType(data, children), taprootius)
```

In the example above, the children will automatically be coverted to `MyType` because the `sink` function we provided gets called recursively. 

To show the awesome power of this, let's just tapin, do some stuff, and then tapout again, knowing the our structures (children links) are safe and sound while we prune and modify data.
Worth noting that this is not the world's most efficient algorithm, but I think it's good enough for most purposes.

```julia
taprootius_the_second = tapin(x -> x isa MyType ? x.some_data : x, deepcopy(my_data))
node_of_interest = followtrace(taprootius_the_second, gettrace(x -> x.data == "Such nested, much wow", taprootius_the_second))
prune!(x -> isparent(x, node_of_interest) || x == node_of_interest, taprootius_the_second)
map!(uppercase, taprootius_the_second)
back_to_my_type = tapout((data, children) -> MyType(data, children), taprootius_the_second)
```

There is also a shortcut, of course. 

```julia
sink_in = x -> x isa MyType ? x.some_data : x
sink_out = (data, children) -> MyType(data, children)

in_and_out = doubletap(sink_in, sink_out, my_data) do taproot
	prune!(x -> isparent(x, node_of_interest) || x == node_of_interest, taproot)
	map!(uppercase, taproot)
end

println(my_data)
println(in_and_out)
```
