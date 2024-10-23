using Agents

basemenu = Dict("Allied Health Service" => 80.0 + randn())

@agent struct Provider(ContinuousAgent{2, Float64})
    menu::Dict{String, Float64} = basemenu # Service on offer => ask price
    capacity::Int64 = 10 # Remaining --- how many services still on offer.
end

Provider() = Provider(id=1, pos=(0, 0), vel=(0, 0))


function services(provider::Provider)
    return provider.menu |> keys |> collect
end

function asks(provider::Provider)
    return provider.menu |> values |> collect
end

function provides(provider::Provider, service::String)
    return service ∈ services(provider) ? true : false
end

function capacity(provider::Provider)
    return provider.capacity
end

function capacity!(provider::Provider, capacity::Int64)
    provider.capacity = capacity
end

function Base.getindex(provider::Provider, service::String)
    if service in provider.menu |> keys
        return provider.menu[service]
    else
        return nothing
    end
end
