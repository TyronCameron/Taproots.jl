
#─────────────────────────────────────────────────────────────────────────────#
# Abstract API
#─────────────────────────────────────────────────────────────────────────────#
    # This file contains the things that the user would normally override

"""
    children(node)

Gets the children nodes in a Taproot DAG (if defined) of `node`. This function is meant to be overridden to access `Taproot.jl` functionality on your own types.

By default, `children(node)` will return an empty array, meaning `Taproot.jl` considers `node` to be a graph with a singular node (unless you overload this function.)

# Overriding this function

Simply define `Taproots.children(node::MyType) = ...`
Where the `...` returns a vector of the things you want to traverse.

"""
children(node) = ()
children(expr::Expr) = expr.args
children(node::Dict) = values(node) |> collect
children(node::Vector) = node
children(node::Taproot) = node.children

"""
    eachfield(x)

Returns a tuple of the values in each field in a struct. Nice for if you have a known number of children.

"""
eachfield(x) = (getfield(x, f) for f in fieldnames(typeof(x)))

"""
    data(x)

Gets the data of a single node in a Taproot DAG (if defined) of x. This function is optional (recommended) to override and can neaten up your life.
This function separates the idea of data that a node holds versus the children of your taproot.

By default, `data(x)` will return x, meaning `Taproots.jl` considers `x` (i.e. the entire node) to be perfectly valid data in and of itself.
However, this is sometimes dangerous, because editing `x` can destroy the link to `x`'s children. Override it to get rid of this danger.

Whatever you define `data(x)` to be needs to be consistent with `setdata!()

# Overriding this function

Simply define `Taproots.data(x::MyType) = ...`
Where the `...` returns whatever data is not already included in the `Taproots.children` function.

"""
data(x) = x
data(expr::Expr) = expr.head
data(x::Taproot) = x.data

"""
    setchildren!(node, children::Vector)::typeof(node)

Sets the children of your node. This is required for the following functionality:

- `prune!` (and `prune` variants)
- `tapmap!` (and `tapmap` variants)
- `graft!`
- `uproot`

Should return the entire node once completed.

You will need to define this in such a way that the following should do nothing:

`setchildren!(node, children(node))`

"""
function setchildren!(node, child_list)
    if isempty(children(node)) && isempty(child_list)
        return node
    end
    error("Taproots.setchildren!(node::$(typeof(node)), children) not implemented!")
    return node
end
setchildren!(node::Expr, children) = (node.args = children; node)
setchildren!(node::Vector, children) = (empty!(node); append!(node, children); node)
function setchildren!(dict::Dict, children)
    newdict = Dict()
    for (i, key) in enumerate(keys(dict))
        i <= length(children) && push!(newdict, key => children[i])
    end
    empty!(dict)
    merge!(dict, newdict)
    return dict
end
setchildren!(node::Taproot, children) = (node.children = children; node)

"""
    setdata!(node, data)::typeof(node)

Sets the data of your node. Useful if you want to be able to `tapmap!` your taproot without messing up your children.

You need to keep this consistent with whatever you defined for `Taproots.data`. In other words, it should be the case that the following does nothing.
`setdata!(node, data(node))`

It MUST return the entire node once done (and is allowed to simply return data without modifying the node in place).

This is required to be implemented for the following functionality:

- `tapmap!` (and `tapmap` and variants)
- `graft!`

# Example

```julia
Taproots.setdata!(node::MyDataStructure, data) = (node.data = data; node)
```
"""
setdata!(node, data) = error("Taproots.setdata!(node::$(typeof(node)), data) not implemented! It is intended that you implement this function -- it has downtrack implications for Taproots functionality.")
setdata!(node::Symbol, data) = data
setdata!(node::Expr, data) = node
setdata!(node::LineNumberNode, data) = node
setdata!(node::Vector, data) = setchildren!(node, data)
setdata!(node::Number, data) = data
setdata!(node::AbstractString, data) = data
setdata!(node::AbstractChar, data) = data
setdata!(node::Taproot, data) = (node.data = data; node)
function setdata!(dict::Dict, data)
    if data === dict return dict end
    empty!(dict)
    merge!(dict, data)
end