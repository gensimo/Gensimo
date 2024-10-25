using Agents

basemenu = Dict("Allied Health Service" => 80.0 + randn())

@agent struct Provider(ContinuousAgent{2, Float64})
    menu::Dict{String, Float64} = basemenu # Service on offer => ask price
    capacity::Int64 = 10 # Remaining --- how many services still on offer.
    sfactor::Float64 = 1.0 # Over- or underservicing factor.
    rfactor::Float64 = 1.0 # Recovery factor.
end


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

function capacity!(provider::Provider, capacity::Integer)
    provider.capacity = capacity
end

function sfactor(provider::Provider)
    return provider.sfactor
end

function sfactor!(provider::Provider, sfactor::Real)
    provider.sfactor = sfactor
end

function Base.getindex(provider::Provider, service::String)
    if service in provider.menu |> keys
        return provider.menu[service]
    else
        return nothing
    end
end

function make_provider_template(menu; type=:vanilla)
    scale(d, f) = Dict(key => f*d[key] for key in keys(d))
    # Default settings.
    if type == :vanilla
        return ( menu=menu             # No over- or undercharging.
               , capacity=10           # Default capacity.
               , sfactor=1.0           # No overservicing.
               , rfactor=1.0           # No iatrogenics.
               )
    # Martyrs overservice and undercharge. Iatrogenics: protracted recovery.
    elseif type == :martyr
        return ( menu=scale(menu, .75) # Undercharging at 75%
               , capacity=10           # Default capacity.
               , sfactor=1.5           # Overservicing by 50%
               , rfactor=.75           # Reduced recovery at 75%
               )
    # Emerging businesses overservice and overcharge. No iatrogenics.
    elseif type == :emerging
        return ( menu=scale(menu, 1.25) # Overcharging by 25%
               , capacity=10            # Default capacity.
               , sfactor=1.5            # Overservicing by 50%
               , rfactor=1.0            # No iatrogenics.
               )
    # Established businesses overcharge but don't overservice. No iatrogenics.
    elseif type == :established
        return ( menu=scale(menu, 1.25) # Overcharging by 25%
               , capacity=10            # Default capacity.
               , sfactor=1.0            # No overservicing.
               , rfactor=1.0            # No iatrogenics.
               )
    # Frauds overservice and overcharge. Iatrogenics: impaired recovery.
    elseif type == :fraud
        return ( menu=scale(menu, 1.25) # Overcharging by 25%
               , capacity=10            # Default capacity.
               , sfactor=1.5            # Overservicing by 50%
               , rfactor=.75            # Recovery impaired at 75%.
               )
    # Incompetents don't overservice or charge. Iatrogenics: impaired recovery.
    elseif type == :incompetent
        return ( menu=menu              # No over- or undercharging.
               , capacity=10            # Default capacity.
               , sfactor=1.0            # No overservicing.
               , rfactor=.75            # Recovery impaired at 75%.
               )
    else
        error("Unkown provider type: $type")
    end
end










