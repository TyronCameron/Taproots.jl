
using BenchmarkTools
using Taproots

include(joinpath(@__DIR__, "simple_small_tree.jl"))

implementations = (:base, :taproots)
situations = (:simple_small_tree,)

function setup_benchmarks(implementations, situations)
    benchmarkables = Dict()
    for situation in situations
        init_name = Symbol("init_$(situation)")
        example = @eval $init_name()
        for implementation in implementations
            func_name = Symbol("$(string(implementation))_$(situation)")
            benchmarkables[func_name] = @benchmarkable $func_name($example, $(rand(100_000)))
        end 
    end 
    return benchmarkables
end

function loc(f)
    file = @which f
    countlines(String(file.file))
end

function run_benchmarks(benchmarkables)
    results = Dict()
    for (name, bench) in benchmarkables
        trial = run(bench)
        results[name] = (
            time = median(trial).time,
            allocs = median(trial).allocs,
            memory = median(trial).memory,
            loc = loc(eval(name))
        )
    end 
    return results 
end

function to_markdown(results)
    md = """
| Scenario | Impl | Time (ns) | Allocs | Memory | LOC |
|----------|------|----------:|-------:|-------:|----:|
"""
    for (scenario, impls) in results
        for (name, r) in impls
            md *= "| $scenario | $name | $(r.time) | $(r.allocs) | $(r.memory) | $(r.loc) |\n"
        end
    end
    return md
end

open("benchmark/results.md", "w") do io
    write(io, to_markdown(results))
end

# Implementations
    # Base 
    # Taproots.jl

# Situations 
    # Simple small tree structure
    # NoCycles 
    # Large case with repeated nodes 
    # StackOverFlow example 

# Measures 
    # Lines of code 
    # Median time 
    # Heap allocations




