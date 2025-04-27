using Documenter
using Taproots

push!(LOAD_PATH,"../src/")

makedocs(
    sitename = "Taproots",
    format = Documenter.HTML(),
    modules = [Taproots],
    pages = [
        "Taproots" => "main.md",
        "API" => "api.md"
    ],
    strict = false
)

deploydocs(
    repo = "github.com/TyronCameron/Taproots.jl.git",
    devbranch = "main"
)
