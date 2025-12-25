
#─────────────────────────────────────────────────────────────────────────────#
# Taproot
#─────────────────────────────────────────────────────────────────────────────#
    # Provides a generic Taproot structure as well as sink functions 

"""
A Taproot is a single node that that can contain other Taproots. It can itself be contained in a parent Taproot.
It is not the main point of this package, but provides a convenience to persist structure when doing maps or other transformations.
It is also useful if you simply wish to build a data structure which already obeys everything in `Taproots.jl`.

You can construct a Taproot either by:
- `Taproot(data, children)` where `data` is anything that you'd like to store in this node, and `children` is an iterable list of children
- `Taproot(node)` where `node` is some value that has `Taproots.children` and `Taproots.data` defined on it. This will recurvisely sink your object into a `Taproots.Taproot`

"""
mutable struct Taproot
    data
    children::Vector{Taproot}
end
Taproot(node) = Taproot(data(node), Taproot[Taproot(child) for child in children(node)])

function Base.show(io::IO, taproot::Taproot)
    second = if isleaf(taproot)
        " (leaf)"
    elseif length(taproot.children) == 1
        "+(1 child)"
    else
        "+($(length(taproot.children)) children)"
    end
    print(io, "Taproot(", taproot.data, ")", second)
end

"""
    tapin(node)

The standard way to access the recursive Taproot constructor.
Requires `Taproots.data` and `Taproots.children` to work.
"""
tapin(node) = Taproot(node)

"""
    tapout(sink::Function, taproot::Taproot)

This allows you to transform a `Taproots.Taproot` struct back into one of your own structs. The `sink` function needs to be able to transform a single node of a `Taproot` into a node in your struct.
The sink follows the following structure:
    sink(data, children) which returns whatever type you want.

As a simple example, let's say we have

```julia
struct YourType
    printable_name::String
    id::UUID
    data
    children::Vector{YourType}
end
Taproots.children(x::YourType) = x.children
Taproots.data(x::YourType) = (x.printable_name, x.id, x.data)
```

Then you can convert that to a `Taproots.Taproot` as follows:

```julia
your_type = ... # nest your stuff here as much as you want.
your_taproot = tapin(your_type)
your_modified_type = tapout((data, children) -> YourType(data.printable_name, data.id, data.data, children), modified_taproot)
```

In case you have multiple types in your struct chain, you should take that into account in your sink. For example, you can do different things in case your `Taproot` has `String` type leaves.

```julia
function sink(data, children)
    if data isa String
        return data
    else
        return YourType(data.printable_name, data.id, data.data, children)
    end
end
```

"""
tapout(sink::Function, taproot::Taproot) = sink(data(taproot), tapout.(sink, children(taproot)))
