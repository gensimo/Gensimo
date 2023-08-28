"""
Provides a core type and utilities for social insurance client states.

The state of a client is modelled by the following type tree:

State
    - PhysioState
        - Physical health
    - PsychoState
        - Psychological health
    - AdminState
        - Portfolio
        - Manager
        - [ Service ]
"""
module States


export State, state, state_from_services, distance
export phy, ϕ, psi, ψ, adm, α

using Dates, Printf

struct PhysioState
    physical_health::Integer
end

struct PsychoState
    psychological_health::Integer
end

struct Service
    label::String
    date::Date
    cost::Float64
end

struct AdminState
    portfolio::Tuple{String, String, String} # (Team, Branch, Division).
    manager::String                          # Team or case manager.
    services::Vector{String}                 # Simplifyingly assumes one claim.
end

struct State
    physiological::PhysioState
    psychological::PsychoState
    administrative::AdminState
end

function ϕ(s::State)
    return s.physiological.physical_health
end

function ψ(s::State)
    return s.psychological.psychological_health
end

function α(s::State, services_only=true)
    if services_only
        return s.administrative.services
    else
        return ( s.administrative.portfolio
               , s.administrative.manager
               , s.administrative.services )
    end
end

# ASCII aliases.
phy = ϕ
psy = ψ
adm = α

"""Universal (copy) constructor."""
function state( state = nothing
              ; ϕ = nothing
              , ψ =  nothing
              , portfolio = nothing
              , manager = nothing
              , services = nothing
              )
    # If `state` provided, harvest fields for default values.
    if !isnothing(state)
        phi = phy(state)
        psi = psy(state)
        pf, mn, sv = adm(state, false)
    # If not, provide some defaults.
    else
        phi = 100
        psi = 100
        pf = ("", "", "")
        mn = ""
        sv = Vector{String}()
    end
    # Then set or change any fields that are provided.
    if !isnothing(ϕ)
        phi = ϕ
    end
    if !isnothing(ψ)
        psi = ψ
    end
    if !isnothing(portfolio)
        pf = portfolio
    end
    if !isnothing(manager)
        mn = manager
    end
    if !isnothing(services)
        sv = services
    end
    # Finally, deliver the state struct.
    return State( PhysioState(phi)
                , PsychoState(psi)
                , AdminState(pf, mn, sv) )
end

function state_from_services(services)
    return state(services=services)
end

function Base.:(==)(c1::AdminState, c2::AdminState)
    if distance(c1, c2) == 0
        return true
    else
        return false
    end
end

function Base.:(==)(s1::State, s2::State)
    if distance(s1, s2) == 0
        return true
    else
        return false
    end
end

"""Return 'intervention' distance between administrative states (claims)."""
function distance(c1::AdminState, c2::AdminState)
    # Start with nothing.
    d=0

    # Abbreviate the nested fields.
    portfolio1 = c1.portfolio
    portfolio2 = c2.portfolio
    mngr1 = c1.manager
    mngr2 = c2.manager
    services1 = c1.services
    services2 = c2.services

    # Different team means an extra distance of 1. # TODO: Incorporate T, B, D.
    if portfolio1 != portfolio2
        d += 1
    end
    # Different case manager means an extra distance of 1.
    if mngr1 != mngr2
        d +=1
    end
    # Each service difference adds 1 to the distance.
    d += length(symdiff(services1, services2))

    # Return the total distance.
    return d
end

"""Return 'intervention' distance between overall states."""
function distance(s1::State, s2::State)
    # Start with nothing.
    d = 0

    # Abbreviate deeply nestled fields.
    ϕ1 = s1.physiological.physical_health
    ψ1 = s1.psychological.psychological_health
    ϕ2 = s2.physiological.physical_health
    ψ2 = s2.psychological.psychological_health
    α1 = s1.administrative
    α2 = s2.administrative

    # Any difference in physiological health adds 1 to distance.
    if ϕ1 != ϕ2
        d += 1
    end
    # Any difference in psychological health adds 1 to distance.
    if ψ1 != ψ2
        d += 1
    end

    d += distance(α1, α2)

    # Return the total distance.
    return d
end

function Base.show(io::IO, phy::PhysioState)
    print(io, "Physical Health: ", phy.physical_health, "%")
end

function Base.show(io::IO, psy::PsychoState)
    print(io, "Psychological Health: ", psy.psychological_health, "%")
end

function Base.show(io::IO, service::Service)
    print(s.label, " on ", s.date, " costing ", @sprintf "\$%.2f" s.cost)
end

function Base.show(io::IO, adm::AdminState)
    services = join([ string( "  | ", service, "\n")
                      for service ∈ adm.services ])
    print( io
         , "  Portfolio: ", adm.portfolio
         , "\n"
         , "  Case manager: ", adm.manager
         , "\n"
         , "  Services:"
         , "\n"
         , services
         )
end

function Base.show(io::IO, s::State)
    print( io
         , "Physiological layer\n"
         , "-------------------\n"
         , "  ", s.physiological
         , "\n\n"
         , "Psychological layer\n"
         , "-------------------\n"
         , "  ", s.psychological
         , "\n\n"
         , "Administrative layer\n"
         , "--------------------\n"
         , s.administrative
         )
end


# End of module.
end
