#─────────────────────────────────────────────────────────────────────────────#
# Shoots
#─────────────────────────────────────────────────────────────────────────────#
    # Information about nodes as we're iterating through them. 

"""
    Shoot 

A selector when iterating. For use in iterator functions such `preorder(taproot; eltype = (Node, Level, Trace))`
"""
abstract type Shoot end 

"""
    Node 

Selects nodes only when iterating. For use in iterator functions such `preorder(taproot; eltype = Node)`
"""
struct Node <: Shoot end 

"""
    Trace 

Selects traces (tuples containing the indices of children nodes to get to this same position) only when iterating. For use in iterator functions such `preorder(taproot; eltype = Trace)`
"""
struct Trace <: Shoot end 

"""
    Level 

Selects levels only when iterating. For use in iterator functions such `preorder(taproot; eltype = Level)`
"""
struct Level <: Shoot end 

# prev: (node = taproot, level = 8, trace = (1, 2, 7))
# new: (node = taproot, levelincrement = 1, i = 12)

putshoot(shoots::Tuple, prev, new) = merge(map(s -> putshoot(s, prev, new), shoots)...)
putshoot(::Type{Node}, prev, new) = (node = node(prev, new), level = level(prev, new))
putshoot(::Type{Trace}, prev, new) = (trace = trace(prev, new), level = level(prev, new), node = node(prev, new))
putshoot(::Type{Level}, prev, new) = (level = level(prev, new), node = node(prev, new))

node(prev, new) = new.node
trace(prev, new) = new.i == 0 ? prev.trace : (prev.trace..., new.i)
level(prev, new) = prev.level + new.levelincrement

takeshoot(shoots::Tuple, prev) = map(sh -> takeshoot(sh, prev), shoots)
takeshoot(::Type{Node}, prev) = prev.node
takeshoot(::Type{Trace}, prev) = prev.trace
takeshoot(::Type{Level}, prev) = prev.level

initshoot(shoot, root) = putshoot(shoot, (node = nothing, level = 0, trace = ()), (node = root, levelincrement = 0, i = 0))
