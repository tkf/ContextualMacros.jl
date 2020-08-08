# ContextualMacros

[![GitHub Actions](https://github.com/tkf//ContextualMacros.jl/workflows/Run%20tests/badge.svg)](https://github.com/tkf//ContextualMacros.jl/actions?query=workflow%3ARun+tests)

ContextualMacros.jl is a package for implementing contextual macro
expansion.

## Examples

```julia
module MyAbstractMacroPackage
    using ContextualMacros
    @contextualmacro @f
end

module MyPackageA
    export @f, @context_a

    using ContextualMacros
    using ..MyAbstractMacroPackage: @f

    macro context_a(ex)
        ContextualMacros.expandwith(
            __module__,
            ex;
            f = ctx -> Expr(:call, +, ctx.args...),
        )
    end
end

module MyPackageB
    export @f, @context_b

    using ContextualMacros
    using ..MyAbstractMacroPackage: @f

    macro context_b(ex)
        ContextualMacros.expandwith(
            __module__,
            ex;
            f = ctx -> Expr(:call, *, ctx.args...),
        )
    end
end

using .MyPackageA
using .MyPackageB

(@context_a @f 1 2 3 4), (@context_b @f 1 2 3 4), (@context_b @context_a @f 1 2 3 4)

# output

(10, 24, 10)
```
