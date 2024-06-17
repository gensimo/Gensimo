using Agents

@agent struct Provider(NoSpaceAgent)
    menu::Dict{String, Float64} # Service on offer => ask price
    capacity::Int64 # Remaining capacity --- how many services still on offer.
end

function services(provider::Provider)
    return provider.menu |> keys |> collect
end

function asks(provider::Provider)
    return provider.menu |> values |> collect
end

function capacity(provider::Provider)
    return provider.capacity
end

function capacity!(provider::Provider, capacity::Int64)
    provider.capacity = capacity
end

function Base.getindex(provider::Provider, service::String)
    return provider.menu[service]
end
