"""
    States

Provides a core type and utilities for social insurance client states.

The state of a client is modelled by the following type tree:

State

* PhysioState

    * Physical health           # As a percentage

* PsychoState

    * Psychological health      # As a percentage.

* AdminState

    * Segment                 # (Team, Branch, Division)
    * Manager                   # Team or case manager
    * [ Service ]               # List of services (name and cost)
"""
module States


export State, state, distance
export Service, Segment, Event, Claim
export Factors, fromvector
export lift_from_data
export phy, ϕ, psi, ψ, adm, α, ser, σ
export cost, costs

using StaticArrays, Dates, Printf

struct Factors <: FieldVector{12, Float64}
    # Primary --- Big 6 complexities.
    physical_health::Float64
    psychological_health::Float64
    persistent_pain::Float64
    service_environment::Float64
    accident_response::Float64
    recovery_expectations::Float64
    # Secondary --- Supplementary complexities.
    prior_health::Float64 # Docs suggest this is a _list_ of pre-conditions.
    prior_finance::Float64
    fault::Float64 # Could be boolean.
    support_optimism::Float64
    sollicitor_engagement::Float64 # Could be boolean.
    satisfaction::Float64 # Satisfaction with the scheme.
end

# Black magic making, e.g. added Factors be of Factor type again.
StaticArrays.similar_type(::Type{Factors}, ::Type{Float64}, s::Size{(12,)}) =
Factors

function tovector(fs::Factors)
    return [ fs.physical_health
           , fs.psychological_health
           , fs.persistent_pain
           , fs.service_environment
           , fs.accident_response
           , fs.recovery_expectations
           , fs.prior_health
           , fs.prior_finance
           , fs.fault
           , fs.support_optimism
           , fs.sollicitor_engagement
           , fs.satisfaction ]
end

struct Service
    label::String # Description of the service.
    cost::Float64 # Monetary cost of the service in e.g. AUD.
    labour::Integer # FTE cost of the service in person-hours
    approved::Bool # Whether the service request is approved or denied.
end

label(s::Service) = s.label
cost(s::Service) = s.cost
labour(s::Service) = s.labour
approved(s::Service) = s.approved

struct Segment
    division::String
    branch::String
    team::String
    manager::String
end

division(p::Segment) = p.division
branch(p::Segment) = p.branch
team(p::Segment) = p.team
manager(p::Segment) = p.manager

struct Event
    date::Date # When did the change to the claim occur?
    change::Union{ Integer # The assessment, e.g. NIDS.
                 , Segment
                 , Service }
end

date(e::Event) = e.date
change(e::Event) = e.change
Base.isless(e1::Event, e2::Event) = date(e1) < date(e2)

struct Claim
    events::Vector{Event}
end

Claim() = Claim(Vector{Event}())
"""Return a new `Claim` with `Event` added."""
Base.:(+)(c::Claim, e::Event) = Claim([c.events..., e])

events(c::Claim) = c.events
services(c::Claim) = [ change(event) for event in sort(events(c))
                       if typeof(change(event)) == Service ]


struct AdminState
    assessment::Integer        # E.g. NIDS score ∈ [0, 6].
    segment::Segment       # (Team, Branch, Division).
    manager::String            # Team or case manager.
    services::Vector{Service}  # Simplifyingly assumes one claim.
end

AdminState(pf, mn, sv) = AdminState(-1, pf, mn, sv)

struct State
    factors::Factors
    administrative::AdminState
end

function fromvector!(state::State, factors::Vector{Float64})
    state.factors = Factors(factors...)
end

function ϕ(s::State)
    return s.factors.physical_health
end

function ψ(s::State)
    return s.factors.psychological_health
end

function α(s::State, services_only=true)
    if services_only
        return s.administrative.services
    else
        return ( s.administrative.assessment
               , s.administrative.segment
               , s.administrative.manager
               , s.administrative.services )
    end
end

function σ(s::State)
    return map(service->service.label, s.administrative.services)
end

function costs(state::State)
    if isempty(α(state))
        return [0]
    else
        return map(service->service.cost, α(state))
    end
end

function cost(state::State)
    return sum(costs(state))
end

# ASCII aliases.
phy = ϕ
psy = ψ
adm = α
ser = σ

"""Universal (copy) constructor."""
function state( state = nothing
              ; factors = nothing
              , assessment = nothing
              , segment = nothing
              , manager = nothing
              , services = nothing
              , ϕ = nothing
              , ψ = nothing
              )
    # If `state` provided, harvest fields for default values.
    if !isnothing(state)
        factors = state.factors
        # phi = phy(state)
        # psi = psy(state)
        as, pf, mn, sv = adm(state, false)
    # If not, provide some defaults.
    else
        fs = Factors(ones(Float64, 12)...)
        # phi = 100
        # psi = 100
        as = -1
        sm = Segment("", "", "", "")
        mn = ""
        sv = Vector{String}()
    end
    # Then set or change any fields that are provided.
    if !isnothing(factors)
        if typeof(factors) == Factors
            fs = factors
        elseif typeof(factors) == Vector{Float64}
            fs = Factors(factors...)
        else
            error("Factors wrong type (use type Factors or Vector{Float64}).")
        end
    end
    if !isnothing(assessment)
        as = assessment
    end
    if !isnothing(segment)
        sm = segment
    end
    if !isnothing(manager)
        mn = manager
    end
    if !isnothing(services)
        sv = services
    end
    if !isnothing(ϕ)
        fs = Factors(ϕ, fs[2:12]...)
    end
    if !isnothing(ψ)
        fs = Factors(fs[1], ψ, fs[3:12]...)
    end
    # Finally, deliver the state struct.
    return State( fs
                , AdminState(as, sm, mn, sv) )
end

function state(services::Vector{Service})
    return state(services=services)
end

function state(services, segment, manager::String)
    return state(services=services, segment=segment, manager=manager)
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
    assessment1 = c1.assessment
    assessment2 = c2.assessment
    segment1 = c1.segment
    segment2 = c2.segment
    mngr1 = c1.manager
    mngr2 = c2.manager
    services1 = c1.services
    services2 = c2.services

    # Different assessment means an extra distance of 1.
    if assessment1 != assessment2
        d += 1
    end
    # Different team means an extra distance of 1. # TODO: Incorporate T, B, D.
    if segment1 != segment2
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
    # Abbreviate deeply nestled fields.
    fs1 = s1.factors
    fs2 = s2.factors
    α1 = s1.administrative
    α2 = s2.administrative
    # Compute Euclidean distance between factors vectors.
    factord = (fs1 - fs2).^2 |> sum |> sqrt
    # Compute administrative distance.
    admind = distance(α1, α2)
    # Return the total distance.
    return factord + admind
end

function Base.show(io::IO, claim::Claim)
    for event in events(claim)
        println(io, event)
        println()
    end
end

function Base.show(io::IO, event::Event)
    if typeof(change(event)) == Segment
        print( io
             , date(event), " (segment change):"
             , change(event)
             )
    elseif typeof(change(event)) == Service
        print( io
             , date(event), " (service request approved/denied):", "\n"
             , "  ", change(event)
             )
    elseif typeof(change(event)) <: Integer
        print( io
             , date(event), " (assessment change):", "\n"
             , "  ", "NIDS: ", change(event)
             )
    end
end

function Base.show(io::IO, segment::Segment)
    print( io, "\n"
         , "  | Division: ", division(segment), "\n"
         , "  | Branch: ", branch(segment), "\n"
         , "  | Team: ", team(segment), "\n"
         , "  | Manager: ", manager(segment)
         )
end

function Base.show(io::IO, service::Service)
    print( io, "<", label(service), ">"
         , " @ ", @sprintf "\$%.2f" cost(service)
         , " + ", labour(service), " hours FTE equivalent."
         , approved(service) ? " Approved." : " Denied."
         )
end

function Base.show(io::IO, adm::AdminState)
    services = join([ string( "  | ", service, "\n")
                      for service ∈ adm.services ])
    print( io
         , "  Assessment: ", adm.assessment
         , "\n"
         , "  Segment: ", adm.segment
         , "\n"
         , "  Services:"
         , "\n"
         , services
         )
end

function Base.show(io::IO, fs::Factors)
    print( io
         , "  Physical health: ", "\t ", fs.physical_health, "\n"
         , "  Psychological health: ", " ", fs.psychological_health, "\n"
         , "  Persistent pain: ", "\t ", fs.persistent_pain, "\n"
         , "  Service environment: ", "\t ", fs.service_environment, "\n"
         , "  Accident response: ", "\t ", fs.accident_response, "\n"
         , "  Recovery expectations: ", fs.recovery_expectations, "\n"
         , "  Prior health: ", "\t ", fs.prior_health, "\n"
         , "  Prior finance: ", "\t ", fs.prior_finance, "\n"
         , "  Fault: ", "\t\t ", fs.fault, "\n"
         , "  Support and optimism: ", " ", fs.support_optimism, "\n"
         , "  Sollicitor engagement: ", fs.sollicitor_engagement, "\n"
         , "  Satisfaction: ", "\t ", fs.satisfaction
         )
end

function Base.show(io::IO, s::State)
    print( io, "\n"
         , "Factors\n"
         , "-------\n"
         , s.factors
         , "\n\n"
         , "Administrative layer\n"
         , "--------------------\n"
         , s.administrative
         )
end



function lift_from_data( states # As list of list of service label strings.
                       , costs  # Dictionary of service labels => Float64.
                       , probabilities # Dictionary of state => probabilities.
                       , segments # List of Team, Branch, Division _tuples_.
                       , managers = nothing # List of managers [String]
                       )
    # First lift the services into the Service type via the `costs` dictionary.
    services = Service.(keys(costs), values(costs))
    # Then turn states into State types.
    # First turn the `states` list-of-lists into a `Services` list-of-lists.
    # Make label-cost pairs from the `states` list of list of labels.
    label_cost_pairs = map.(s->(s, costs[s]), states)
    # Then lift those into the `Service` type.
    services_list_of_lists = map.(s->Service(s...), label_cost_pairs)
    n = length(services_list_of_lists)
    # Lift the segment tuples into the `Segment` type.
    segments = map(t->Segment(t...), segments)
    # Make up a list of managers if nothing provided.
    if isnothing(managers)
        managers = [ "Alex", "Blake", "Charlie", "Dee", "Evelyn" ]
    end
    # Make states of `services_list_of_lists` and random segment and managers.
    states = state.( services_list_of_lists
                   , rand(segments, n)
                   , rand(managers, n) )
    # Finally, make a new State => probabilities dictionary.
    probabilities = Dict(s=>probabilities[σ(s)] for s in states)
    # Deliver.
    return states, services, probabilities, segments, managers
end

end # Module States.
