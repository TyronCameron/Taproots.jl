#─────────────────────────────────────────────────────────────────────────────#
# Binary Node Properties
#─────────────────────────────────────────────────────────────────────────────#
    # Contains traits / properties to check relationships between different items


"""
    ischild(potential_child, parent)::Bool

Tells you whether `potential_child` is a child of `parent`. This function acts recursively and is not the same as doing `potential_child ∈ children(parent)`.
Time complexity of this is ~linear in the number of edges in your DAG underneath the `parent`, so use with care for large DAGs.
"""
function ischild(potential_child, parent)
    for child in Iterators.drop(preorder(parent), 1)
        if potential_child == child return true end
    end
    return false
end

"""
    isparent(potential_parent, child)::Bool

Tells you whether `potential_parent` is a parent of `child`. This function acts recursively.
Time complexity of this is ~linear in the number of edges in your DAG underneath the `potential_parent`, so use with care for large DAGs.

"""
isparent(potential_parent, child) = ischild(child, potential_parent)

"""
    isleaf(node)::Bool

Tells you whether this `node` is a leaf node (i.e. it has no children).

"""
isleaf(node) = isempty(children(node))

"""
    isbranch(node)::Bool

Tells you whether this `node` is a branch node (i.e. it has children).

"""
isbranch(node) = !isleaf(node)
