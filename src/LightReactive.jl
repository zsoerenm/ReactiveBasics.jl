module LightReactive

export Signal, value, foldp, subscribe!

# This API mainly follows that of Reactive.jl. One difference is that `merge` 
# returns a Tuple of Signals rather than the Signal with the highest precedence.

# The algorithms for were derived from the Swift Interstellar package
# https://github.com/JensRavens/Interstellar/blob/master/Sources/Signal.swift
# Copyright (c) 2015 Jens Ravens (http://jensravens.de)
# Offered with the MIT license


"""
A Signal is value that will contain a value in the future.
The value of the signal can change at any time.

Use `map` to derive new signals, subscribe!` to subscribe to updates of a signal,
and `push!` to update the current value of a signal. `value` returns the current
value of a signal.

```julia
text = Signal("")

text2 = map(s -> "Bye \$s", text)

subscribe!(text) do s
    println("Hello \$s")
end

push!(text, "world")

value(text)
value(text2)
```
"""
type Signal{T}
   value::T
   callbacks::Vector   # usually Functions, but could be other callable types
end

Signal(val) = Signal(val, Any[])

"""
The current value of the signal.
"""
value(u::Signal) = u.value

"""
Transform the signal into another signal using a function.
"""
function Base.map(f, u::Signal)
    signal = Signal(f(u.value))
    subscribe!(x -> push!(signal, f(x)), u)
    signal
end
function Base.map(f, u::Signal, v::Signal)
    signal = Signal(f(u.value, v.value))
    subscribe!(x -> push!(signal, f(x, v.value)), u)
    subscribe!(x -> push!(signal, f(u.value, x)), v)
    signal
end
function Base.map(f, u::Signal, v::Signal, w::Signal)
    signal = Signal(f(u.value, v.value, w.value))
    subscribe!(x -> push!(signal, f(x, v.value, w.value)), u)
    subscribe!(x -> push!(signal, f(u.value, x, w.value)), v)
    subscribe!(x -> push!(signal, f(u.value, v.value, x)), w)
    signal
end
function Base.map(f, u::Signal, v::Signal, w::Signal, xs::Signal...)
    us = (u,v,w,xs...)
    signal = Signal(f((u.value for u in us)...))
    @show signal
    for (i,u) in enumerate(us)
        subscribe!(u) do x
            vals = f(((i == j ? x : us[j].value for j in 1:length(us))...)...)
            push!(signal, vals)
        end
    end
    signal
end

"""
Update the value of a signal and propagate the change.
"""
function Base.push!(u::Signal, val)
    u.value = val
    foreach(f -> f(val), u.callbacks)
end

"""
Subscribe to the changes of this signal. Every time the signal is updated, the function `f` runs.
"""
function subscribe!(f, u::Signal)
    push!(u.callbacks, f)
    u
end


"""
Merge another signal into the current signal. The value of the signal is a
Tuple of the values of the contained signals.
    
    signal = merge(Signal("Hello"), Signal("World"))
    value(signal)
"""
function Base.merge(u::Signal, v::Signal)
    signal = Signal((u.value, v.value))
    subscribe!(x -> push!(signal, (x, v.value)), u)
    subscribe!(x -> push!(signal, (u.value, x)), v)
    signal
end
function Base.merge(u::Signal, v::Signal, w::Signal)
    signal = Signal((u.value, v.value, w.value))
    subscribe!(x -> push!(signal, (x, v.value, w.value)), u)
    subscribe!(x -> push!(signal, (u.value, x, w.value)), v)
    subscribe!(x -> push!(signal, (u.value, v.value, x)), w)
    signal
end
function Base.merge(u::Signal, v::Signal, w::Signal, xs::Signal...)
    us = (u,v,w,xs...)
    signal = Signal(((u.value for u in us)...))
    for (i,u) in enumerate(us)
        subscribe!(x -> push!(signal, ((i == j ? x : us[j].value for j in 1:length(us))...)), u)
    end
    signal
end

"""
Fold/map over past values. The first argument to the function `f`
is an accumulated value that the function can operate over, and the 
second is the current value coming in. `v0` is the initial value of
the accumulated value.

    a = Signal(2)
    # accumulate sums coming in from a, starting at zero
    b = foldp(+, 0, a) # b == 2
    push!(a, 2)        # b == 4
    push!(a, 3)        # b == 7
"""
function foldp(f, v0, us::Signal...)
    map(x -> v0 = f(v0, x), us...)
end

"""
Return a signal that updates based on the signal `u` if `f(value(u))` evaluates to `true`.
"""
function Base.filter{T}(f, default::T, u::Signal{T})
    signal = Signal(f(u.value) ? u.value : default)
    subscribe!(result -> f(result) && push!(signal, result), u)
    signal
end

end # module
