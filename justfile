set quiet 

default:
    @just --list

instantiate:
    julia --project=. -e 'using Pkg; Pkg.instantiate()'

test:
    julia --project=. -e 'using Pkg; Pkg.test()'

[working-directory('test/benchmark')]
benchmark:
    julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
    julia --project=. benchmark.jl

register:
    julia --project=. -e 'using LocalRegistry; register(registry = "/home/tyronc/.julia/registries/TyPackages.jl/")'

full-test:
    #!/usr/bin/env bash
    set +e
    sudo act pull_request --secret-file .secrets --bind \
        --env JULIA_DEPOT_PATH=/home/tyronc/.julia \
        --matrix julia-version:1 \
        --matrix os:ubuntu-latest 
    find . -name "*.cov" -delete
    rm -f lcov.info
