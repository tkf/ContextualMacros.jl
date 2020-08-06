module TestCore

using ContextualMacros
using Test

ContextualMacros.@def @f
ContextualMacros.@def @g

@testset begin
    ex = ContextualMacros.expandwith(
        @__MODULE__,
        quote
            @f 1 2 3
            @g 4 5
        end;
        f = ctx -> QuoteNode((:f, ctx.args)),
        g = ctx -> QuoteNode((:g, ctx.args)),
    )
    nodes = filter(x -> x isa QuoteNode, ex.args)
    @test nodes == [QuoteNode((:f, (1, 2, 3))), QuoteNode((:g, (4, 5)))]
end

end  # module
