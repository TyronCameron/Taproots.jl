
using BenchmarkTools
using Taproots
using DataFrames
using PrettyTables
using Profile
using JET

implementations::Tuple = (:naive, :taproots)
situations::Tuple = (
    :preorder_simple_small_tree,
    :postorder_simple_small_tree,
    :topdown_simple_small_tree,
    :bottomup_simple_small_tree,
    :simple_big_tree,
    :cycle,
    :expensive_tree,
)

module InitFunctions 
    using Taproots
    using Random
    for file in readdir(joinpath(@__DIR__, "init"), join = true)
        include(file)
    end
end 
import .InitFunctions

module NaiveFunctions 
    using Taproots
    for file in readdir(joinpath(@__DIR__, "naive"), join = true)
        include(file)
    end
end 
import .NaiveFunctions

module TaprootFunctions
    using Taproots
    for file in readdir(joinpath(@__DIR__, "taproots"), join = true)
        include(file)
    end
end 
import .TaprootFunctions

function get_func(implementation, situation)
    if implementation == :init 
        @eval InitFunctions.$situation
    elseif implementation == :naive 
        @eval NaiveFunctions.$situation
    elseif implementation == :taproots 
        @eval TaprootFunctions.$situation
    else 
        @assert false "No known functions for $implementation"
    end 
end

loc(implementation, situation) = length(readlines(joinpath(@__DIR__, string(implementation), string(situation) * ".jl")))

function setup_benchmarkable(situation)
    example = get_func(:init, situation)()
    @info "Example $situation: has length $(length(collect(preorder(example))))"
    map(implementations) do implementation
        func = get_func(implementation, situation)
        implementation => @benchmarkable $func($example)
    end |> splat(Dict) 
end

default_results(implementation, situation) = (
    loc = loc(implementation, situation),
    time = Inf,
    memory = Inf,
    gctime = Inf,
    allocs = Inf,
)

function run_benchmarkable(situation, benchmarkable)
    results = Dict()
    for (implementation, bench) in benchmarkable
        try 
            trial = median(run(bench))
            results[(implementation, situation)] = (
                loc = loc(implementation, situation),
                time = trial.time,
                memory = trial.memory,
                gctime = trial.gctime,
                allocs = trial.allocs,
            )
        catch e 
            results[(implementation, situation)] = default_results(implementation, situation)
        end 
    end 
    return results 
end

function setup_and_run_benchmarkable(situation)
    benchmarkable = setup_benchmarkable(situation)
    run_benchmarkable(situation, benchmarkable)
end

function setup_and_run_all_benchmarks()
    all_results = Dict()
    for situation in situations
        @info "Starting $situation. Results:"
        for (key, results) in setup_and_run_benchmarkable(situation)
            @info "\t$key:\n$results"
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
    df = select(innerjoin(
        df[df.implementation .== :naive, :],
        df[df.implementation .== :taproots, :],
        on = :benchmark,
        renamecols = "_naive" => "_taproots"
    ), Not(r".*implem.*"))
    order = Dict(s => i for (i, s) in enumerate(situations))
    sort!(df, by = x -> get(order, x, Inf))
end 

function table_to_markdown(df)
    pretty_table(String, df, backend=:markdown)
end

results = setup_and_run_all_benchmarks()
df = results_to_table(results)
mark = unpivot_table(df) |> table_to_markdown

open(joinpath(@__DIR__, "results.md"), "w") do f
    write(f, mark)
end

function profile_test(n, f, example)
    try 
        for i in 1:n
            f(example)    
        end
    catch e 
        #nothing
    end 
end


function single_flame_graph(impl, sit, n = 100_000)
    example = get_func(:init, sit)()
    func = get_func(impl, sit)
    profile_test(10, func, example)
    @profview profile_test(n, func, example)
end

single_flame_graph(:taproots, :preorder_simple_small_tree)

@report_opt 
