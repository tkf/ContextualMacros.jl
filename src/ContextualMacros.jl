module ContextualMacros

export @contextualmacro

using Base.Meta: isexpr

struct ContextualMacro{macroname} <: Function end

"""
    ContextualMacros.def(macroname::Symbol) -> f

Return a function callable as `f(__source__, __module__, args...)`.
"""
def(macroname::Symbol) = ContextualMacro{macroname}()

function _macroname_of(ex)
    if !(isexpr(ex, :macrocall, 2) && ex.args[1] isa Symbol)
        throw(ArgumentError("Expected a macro name (e.g., `@f`). Got:\n$ex"))
    end
    return Symbol(String(ex.args[1])[2:end])
end

"""
    @contextualmacro @macroname

Define a contextual macro `@macroname`.
"""
macro contextualmacro(ex)
    macroname = _macroname_of(ex)
    quote
        macro $macroname(args...)
            $(def(macroname))(__source__, __module__, args...)
        end
    end |> esc
end

"""
    ContextualMacros.@def @macroname

Define a contextual macro `@macroname` whose identity is solely
determined by the name of the macro.

!!! warning "Unstable"

    This is an experimental API.
"""
macro def(ex)
    macroname = _macroname_of(ex)
    withat = Symbol("@$macroname")
    esc(:(const $withat = $(QuoteNode(def(macroname)))))
end
# Experimental because the calling convention of macros is not a part
# of the stable API of Julia.

"""
    ContextualMacros.expandwith(module, expression; definitions...)

Macro-expand `expression` with contextual macro `@f` whose definition
is given by `definitions[:f]`.

Each value of `definitions` is a function that takes a single argument
with a "context" object with (at least) following properties:

- `__module__::Module`: module in which the macro is expanded
- `__source__::LineNumberNode`: line at which the macro is expanded
- `args`: arguments to the macro
"""
function expandwith(__module__::Module, ex; kwargs...)
    with(; kwargs...) do
        macroexpand(__module__, ex)
    end
end

"""
    ContextualMacros.with(f; definitions...)

Run function `f` while using the definitions of the macros specified
by `definitions`.  See also [`expandwith`](@ref).
"""
function with(f; definitions...)
    lock(DEFINITION_LOCK) do
        original = copy(DEFINITION_STACK)
        try
            push!(DEFINITION_STACK, values(definitions))
            f()
        finally
            expected = vcat(original, [values(definitions)])
            if !isequal(DEFINITION_STACK, expected)
                @error("DEFINITION_STACK is corrupted. Trying to recover.")
            end
            append!(empty!(DEFINITION_STACK), original)
        end
    end
end

# Not sure if macro expansions can run concurrently.  But let's lock
# it to play on the safe side...
const DEFINITION_LOCK = ReentrantLock()
const DEFINITION_STACK = []
const DEFINITION_CONSUMERS = Pair{String,Vector{Symbol}}[]

function (::ContextualMacro{macroname})(__source__, __module__, args...) where {macroname}
    ctx = (__module__ = __module__, __source__ = __source__, args = args)
    for def in reverse(DEFINITION_STACK)
        if (f = get(def, macroname, nothing)) !== nothing
            return f(ctx)
        end
    end
    throw(NotInContextError(macroname))
end

struct NotInContextError <: Exception
    macroname::Symbol
end

function Base.showerror(io::IO, err::NotInContextError)
    outside_context_error_message(io, err.macroname)
end

function providers_by_macroname(macroname, consumers = DEFINITION_CONSUMERS)
    providers = String[]
    for (pro, macros) in consumers
        if macroname in macros
            push!(providers, pro)
        end
    end
    return providers
end

function outside_context_error_message(io::IO, macroname)
    providers = providers_by_macroname(macroname)
    println(io, "Macro `@", macroname, "` used outside context.")
    if isempty(providers)
        print(io, "No package implements `@", macroname, "`.")
        return
    end
    print(io, "It must be used in one of the following macro(s):")
    for n in providers
        println(io)
        print(io, n)
    end
end

"""
    ContextualMacros.register(context_name::String, macronames::Symbol...)
"""
function register(context_name::String, macronames::Symbol...)
    lock(DEFINITION_LOCK) do
        push!(DEFINITION_CONSUMERS, context_name => collect(Symbol, macronames))
    end
    return
end

function _cleanup()
    empty!(DEFINITION_STACK)
    empty!(DEFINITION_CONSUMERS)
end

function __init__()
    # Make it work nicely in sysimage:
    _cleanup()
    atexit(_cleanup)
end

# Use README as the docstring of the module:
@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end ContextualMacros

end
