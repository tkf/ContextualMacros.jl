module TestShare

using Test

module PkgA
export @f
using ContextualMacros
ContextualMacros.@def @f
macro context(ex)
    ContextualMacros.expandwith(__module__, ex; f = ctx -> Expr(:call, :+, ctx.args...))
end
end

module PkgB
export @f
using ContextualMacros
ContextualMacros.@def @f
macro context(ex)
    ContextualMacros.expandwith(__module__, ex; f = ctx -> Expr(:call, :*, ctx.args...))
end
end

using .PkgA
using .PkgB

name = Symbol("@f")
@test (@eval $name) === (@eval PkgA $name) === (@eval PkgB $name)
@test (PkgA.@context @f 1 2 3 4) == 10
@test (PkgB.@context @f 1 2 3 4) == 24

end  # module
