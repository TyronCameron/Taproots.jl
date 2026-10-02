#─────────────────────────────────────────────────────────────────────────────#
# Functionals
#─────────────────────────────────────────────────────────────────────────────#
    # This file contains ways of mapping, filtering and accumulating Taproots 

# One day will be moved to reconstruct(x)
function _copy_or_reconstruct(x)
    if hasmethod(copy, Tuple{typeof(x)})
        return copy(x)
    elseif x isa String
        return x
    elseif x isa Number
        return x
    elseif x isa Bool
        return x
    elseif x isa Symbol
        return x
    elseif ismutable(x)
        fieldvals = getfield.(Ref(x), 1:fieldcount(typeof(x)))
        try
            return typeof(x)(fieldvals...)
        catch
            @warn """
                No public constructor for $(typeof(x)); using Base.unsafe_copy as fallback.
                To make this warning go away, please implement `Base.copy(x::$(typeof(x)))`.
                Alternatively, use `deepcopy` and then `prune!` or `tapmap` or similar.
            """
            return Base.unsafe_copy(x)
        end
    else
        return x
    end
end

_apply(condition, f, node) = condition(node) ? setdata!(node, f(data(node))) : node # conditionally apply f

function _applyif!(condition, f, node, visited)
    if ismutable(node) && node ∈ visited return node end # don't do the same thing to a mutable struct twice
    push!(visited, node)
    return _apply(condition, f, node)
end

# Builds the same node => g(node) map as the sequential passes, but runs g on many threads.
# Works off the bottomup frontier, so g only starts on a node once all of its children are done.
function parallelnodemap(g, taproot)
    shoots = Node()
    frontier = initfrontier(Bottomup, sprouttype(shoots, childtypes(taproot)), shoots, children, alwaysconnect, taproot)
    node_map = Dict()
    started = Dict{Any, Base.Event}() # a DAG node has one sprout per path; the first runs g, the rest wait on it
    cond = Threads.Condition()
    inflight = 0
    failure = Ref{Any}(nothing)
    function worker()
        while true
            k, owner, done = lock(cond) do
                while isempty(frontier) && inflight > 0 && failure[] === nothing
                    wait(cond)
                end
                if isempty(frontier) || failure[] !== nothing return (0, false, Base.Event()) end
                inflight += 1
                taken = take!(frontier)
                isnew = !haskey(started, nodeof(frontier.states[taken]))
                (taken, isnew, get!(Base.Event, started, nodeof(frontier.states[taken])))
            end
            if k == 0 return end
            node = nodeof(frontier.states[k])
            if owner
                try
                    result = g(node)
                    lock(() -> node_map[node] = result, cond)
                catch err
                    lock(cond) do
                        if failure[] === nothing failure[] = err end
                        notify(cond)
                    end
                    return
                finally
                    notify(done)
                end
            else
                wait(done)
            end
            lock(cond) do
                release!(frontier, k)
                inflight -= 1
                notify(cond)
            end
        end
    end
    foreach(wait, [Threads.@spawn worker() for _ in 1:Threads.nthreads()])
    if failure[] !== nothing throw(failure[]) end
    return node_map
end

function maphelper!(condition, f, taproot, parallel = false)
    visited = Set()
    post = collect(postorder(taproot))
    node_map = if parallel
        parallelnodemap(node -> _apply(condition, f, node), taproot)
    else
        foldl(post; init = Dict()) do acc, node
            get!(acc, node, _applyif!(condition, f, node, visited))
            acc
        end
    end
    for node in post
        new_node = get!(node_map, node, node)
        new_children = map(child -> get!(node_map, child, child), children(node))
        setchildren!(new_node, new_children)
    end
    return get!(node_map, taproot, taproot)
end

function maphelper(condition, f, taproot, parallel = false) 
    visited = Set()
    post = collect(postorder(taproot))
    node_map = if parallel
        parallelnodemap(node -> _apply(condition, f, _copy_or_reconstruct(node)), taproot)
    else
        foldl(post; init = Dict()) do acc, node
            get!(acc, node, _applyif!(condition, f, _copy_or_reconstruct(node), visited))
            acc
        end
    end
    for node in post
        new_node = get!(node_map, node, node)
        new_children = map(child -> get!(node_map, child, child), children(node))
        setchildren!(new_node, new_children)
    end
    return get!(node_map, taproot, taproot)
end 

"""
    tapmap!(f::Function, taproot)

Modify all the data of every node in a taproot in place. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmap!(f::Function, taproot) = maphelper!(x -> true, f, taproot)

"""
    tapmap(f::Function, taproot)

Deepcopy a taproot and then modify its nodes in place. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmap(f::Function, taproot) = maphelper(x -> true, f, taproot)

"""
    paralleltapmap!(f::Function, taproot)

Same as `tapmap!`, but runs `f` on many threads (`Threads.nthreads()`). All leaves start straight away, and each parent 
becomes available as soon as its last child is done, so `f` never runs on a node before it has run on all of that node's children.
Each unique node is only mapped once, even if it is shared by several parents.

Only worth it when `f` is expensive. Nodes on a cycle (and their ancestors) are left unmapped, as with `bottomup`.
"""
paralleltapmap!(f::Function, taproot) = maphelper!(x -> true, f, taproot, true)

"""
    paralleltapmap(f::Function, taproot)

Same as `tapmap`, but runs `f` on many threads. See `paralleltapmap!`.
"""
paralleltapmap(f::Function, taproot) = maphelper(x -> true, f, taproot, true)

"""
    tapmapif!(condition::Function, f::Function, taproot)

Modifies nodes in place if the entire node satisfies `condition`. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmapif!(condition::Function, f::Function, taproot) = maphelper!(condition, f, taproot)

"""
    tapmapif(condition::Function, f::Function, taproot)

Deepcopy a taproot and then modify its nodes in place if they satisfy `condition`. `f` only acts on the data in each node.
This can handle mutable and immutable trees.
"""
tapmapif(condition::Function, f::Function, taproot) = maphelper(condition, f, taproot)

"""
    leafmap!(f::Function, taproot)

Modify the leaves of a taproot in place.
"""
leafmap!(f::Function, taproot) = maphelper!(isleaf, f, taproot)

"""
    leafmap(f::Function, taproot)

Deepcopy a taproot and then modify its leaves in place.
"""
leafmap(f::Function, taproot) = maphelper(isleaf, f, taproot)


"""
    branchmap!(f::Function, taproot)

Modify the branches of a taproot in place without destroying links to children.
"""
branchmap!(f::Function, taproot) = maphelper!(isbranch, f, taproot)

"""
    branchmap(f::Function, taproot)

Deepcopy a taproot and then modify its branches in place without destroying links to children.
"""
branchmap(f::Function, taproot) = maphelper(isbranch, f, taproot)


function prunehelper!(condition, f, taproot)
    for node in preorder(taproot)
        setchildren!(node,
            deleteat!(children(taproot), findall(x -> !f(x) && condition(x), children(node)))
        )
    end
    return taproot
end

function prunehelper(condition, f, taproot)
    main_node = _copy_or_reconstruct(taproot)
    for node in preorder(main_node)
        setchildren!(node,
            deleteat!(_copy_or_reconstruct.(children(taproot)), findall(x -> !f(x) && condition(x), children(node)))
        )
    end
    return main_node
end


"""
    prune!(f::Function, taproot)

This removes any children who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that child. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
prune!(f::Function, taproot) = prunehelper!(x -> true, f, taproot)

"""
    prune(f::Function, taproot)

This deepcopies the taproot and then removes any children who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that child. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
prune(f::Function, taproot) = prunehelper(x -> true, f, taproot)

"""
    leafprune!(f::Function, taproot)

This removes any leaves of the taproot who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
leafprune!(f::Function, taproot) = prunehelper!(isleaf, f, taproot)

"""
    prune(f::Function, taproot)

This deepcopies the taproot and then removes any leaves who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
leafprune(f::Function, taproot) = prunehelper(isleaf, f, taproot)

"""
    branchprune!(f::Function, taproot)

This removes any leaves of the taproot who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
branchprune!(f::Function, taproot) = prunehelper!(isbranch, f, taproot)

"""
    prune(f::Function, taproot)

This deepcopies the taproot and then removes any leaves who do not satisfy the criteria given by `f` in place. `f` evaluating to true will keep that leaf. This is similar to `filter`.
However, you cannot prune the root of a taproot.
"""
branchprune(f::Function, taproot) = prunehelper(isbranch, f, taproot)
