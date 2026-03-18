
using BenchmarkTools
using Taproots
using DataFrames
using PrettyTables

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

implementations::Tuple = (:base, :taproots)
situations::Tuple = (:simple_small_tree,)

module InitFunctions 
    for file in readdir(joinpath(@__DIR__, "init"), join = true)
        include(file)
    end
end 

module BaseFunctions 
    for file in readdir(joinpath(@__DIR__, "base"), join = true)
        include(file)
    end
end 

module TaprootFunctions
    for file in readdir(joinpath(@__DIR__, "taproots"), join = true)
        include(file)
    end
end 

function get_func(implementation, situation)
    if implementation == :init 
        @eval InitFunctions.$situation
    elseif implementation == :base 
        @eval BaseFunctions.$situation
    else 
        @eval TaprootFunctions.$situation
    end 
end

loc(implementation, situation) = length(readlines(joinpath(@__DIR__, string(implementation), string(situation) * ".jl")))

function setup_benchmarkable(situation)
    example = get_func(:init, situation)()
    map(implementations) do implementation
        func = get_func(implementation, situation)
        implementation => @benchmarkable $func($example)
    end |> splat(Dict) 
end

function setup_and_run_benchmarkable(situation)
    results = Dict()
    benchmarkable = setup_benchmarkable(situation)
    for (implementation, bench) in benchmarkable
        trial = median(run(bench))
        results[(implementation, situation)] = (
            loc = loc(implementation, situation),
            time = trial.time,
            memory = trial.memory,
            gctime = trial.gctime,
            allocs = trial.allocs,
        )
    end 
    return results 
end

function setup_and_run_all_benchmarks()
    all_results = Dict()
    for situation in situations
        for (key, results) in setup_and_run_benchmarkable(situation)
            all_results[key] = results
        end 
    end
    return all_results
end

results_to_table(results) = reduce(implementations, init = DataFrame()) do acc, implementation
    impl_keys = collect(filter(k -> k[1] == implementation, keys(results)))
    df = reduce(impl_keys, init = []) do vec, key 
        push!(vec, (benchmark = last(key), implementation = first(key), results[key]...))
    end |> DataFrame
    append!(acc, df)
end 

function unpivot_table(df)
    select(innerjoin(
        df[df.implementation .== :base, :],
        df[df.implementation .== :taproots, :],
        on = :benchmark,
        renamecols = "_base" => "_taproots"
    ), Not(r".*implem.*"))
end 

function table_to_markdown(df)
    pretty_table(String, df, backend=:markdown)
end

results = setup_and_run_all_benchmarks()
df = results_to_table(results)
mark = unpivot_table(df) |> table_to_markdown

open(joinpath(@__DIR__, "results.md"), "w") do io
    write(io, mark)
end




