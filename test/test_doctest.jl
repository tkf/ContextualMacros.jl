module TestDoctest

import ContextualMacros
using Documenter: doctest
using Test

@testset "doctest" begin
    doctest(ContextualMacros; manual = false)
end

end  # module
