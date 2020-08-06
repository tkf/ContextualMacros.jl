module TestExpansionErrors

using ContextualMacros
using Test

@contextualmacro @f

macro expansion_error(ex)
    quote
        err = try
            $Base.@eval $__module__ $ex
            nothing
        catch _err
            _err
        end
        $Test.@test err !== nothing
        err
    end
end

msgof(err) = sprint(showerror, err)

function with_fake_context(f)
    orig = copy(ContextualMacros.DEFINITION_CONSUMERS)
    try
        ContextualMacros.register("@fake_context", :f)
        f()
    finally
        copyto!(empty!(ContextualMacros.DEFINITION_CONSUMERS), orig)
    end
end

function with_no_contexts(f)
    with_fake_context() do
        ContextualMacros._cleanup()
        f()
    end
end

with_fake_context() do
    @testset "NotInContextError (with `@fake_context`)" begin
        err = @expansion_error @f
        @test occursin("Macro `@f` used outside context.", msgof(err))
        @test occursin("@fake_context", msgof(err))
    end
end

with_no_contexts() do
    @testset "NotInContextError (no contexts)" begin
        err = @expansion_error @f
        @test occursin("Macro `@f` used outside context.", msgof(err))
        @test occursin("No package implements `@f`.", msgof(err))
    end
end

end  # module
