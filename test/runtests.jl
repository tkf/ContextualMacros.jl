module TestContextualMacros
using Test

@testset "$file" for file in sort([
    file for file in readdir(@__DIR__) if match(r"^test_.*\.jl$", file) !== nothing
])
    if file == "test_doctest.jl"
        if lowercase(get(ENV, "JULIA_PKGEVAL", "false")) == "true"
            @info "Skipping doctests on PkgEval."
            continue
        end
    end

    include(file)
end
end  # module
