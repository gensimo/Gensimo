using Agents
using StaticArrays, Dates, Printf

function heaviside(x::Real)
    if x>=0
        return 1.0
    else
        return 0.0
    end
end

struct State <: FieldVector{12, Float64}
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

# Black magic making, e.g. added State be of Factor type again.
StaticArrays.similar_type(::Type{State}, ::Type{Float64}, s::Size{(12,)}) =
State

function big6(state::State)
    return state[1:6]
end

function nids(state::State)
    return heaviside.(big6(state) .- .5) |> sum |> Integer
end

struct Service
    label::String # Description of the service.
    cost::Float64 # Monetary cost of the service in e.g. AUD.
    labour::Integer # FTE cost of the service in person-hours.
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

events(c::Claim) = c.events |> sort
services(c::Claim) = [ change(event) for event in sort(events(c))
                       if typeof(change(event)) == Service ]

struct Personalia
    name::String
    age::Integer
    sex::Bool
end

Personalia() = rand([ Personalia("Ozzy Driver", 66, 1)
                    , Personalia("Sydney Cooter", 19, 0) ])

name(p::Personalia) = p.name
age(p::Personalia) = p.age
sex(p::Personalia) = p.sex

@agent Client ContinuousAgent{2} begin
    personalia::Personalia
    states::Dict{Date, State}
    claim::Claim
end

dates(client::Client) = client.states |> keys |> collect |> sort
states(client::Client) = [ client.states[date] for date ∈ dates(client) ]
personalia(client::Client) = client.personalia
claim(client::Client) = client.claim
date(client::Client) = dates(client)[end]
state(client::Client) = client.states[date(client)]
dayzero(client::Client) = dates(client)[1]

function Client(id, pos, personalia, states, claim)
    date = sort(collect(keys(states)))[end]
    state = states[date]
    return Client( id # Agent ID.
                 , (state[1], state[2]) # 2D (ϕ, ψ) 'location' vector.
                 , (0.0, 0.0) # Dummy 'velocity' vector.
                 , personalia
                 , states
                 , claim )
end

function Client(id, personalia, states, claim)
    date = sort(collect(keys(states)))[end]
    state = states[date]
    return Client( id # Agent ID.
                 , (state[1], state[2]) # 2D (ϕ, ψ) 'location' vector.
                 , (0.0, 0.0) # Dummy 'velocity' vector.
                 , personalia
                 , states
                 , claim )
end

function ClientMaker(id=0)
    id -= 1 # So as to actually start at the current value of `id`.
    function C(personalia, states, claim)
        id += 1
        return Client(id, personalia, states, claim)
    end
end

let
    start_id = 0
    global function Client(personalia, states, claim; id=nothing)
        isnothing(id) ? start_id += 1 : start_id = id
        return Client(start_id, personalia, states, claim)
    end
end

function resetClient()
    Client( Personalia()
          , Dict(Date(2020)=>State(rand(12)))
          , Claim()
          ; id=0 )
    return nothing
end

function Base.show(io::IO, client::Client)
    println( io
           , "Client ID: ", client.id, "\n"
           , personalia(client)
           , "Status (", date(client), "):\n"
           , "  | ϕ = ", state(client)[1], "\n"
           , "  | ψ = ", state(client)[2], "\n"
           , "Claim:", "\n"
           , claim(client)
           )
end

function Base.show(io::IO, personalia::Personalia)
    println( io
           , "  | ", name(personalia), ". "
           , age(personalia), " year-old "
           , sex(personalia) ? "male" : "female", "."
           )
end

function Base.show(io::IO, claim::Claim)
    if !isempty(claim.events)
        for event in events(claim)
            println(io, event)
        end
    else
        print(io, "  | Empty claim.")
    end
end

function Base.show(io::IO, event::Event)
    if typeof(change(event)) == Segment
        print( io
             , "  ", date(event), " > segmentation", "\n"
             , change(event)
             )
    elseif typeof(change(event)) == Service
        print( io
             , "  ", date(event), " > service request", "\n"
             , "  | ", change(event)
             )
    elseif typeof(change(event)) <: Integer
        print( io
             , "  ", date(event), " > assessment", "\n"
             , "  | ", "NIDS: ", change(event)
             )
    end
end

function Base.show(io::IO, segment::Segment)
    print( io
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

function Base.show(io::IO, state::State)
    print( io, "\n"
         , "  Physical health: ", "\t ", state.physical_health, "\n"
         , "  Psychological health: ", " ", state.psychological_health, "\n"
         , "  Persistent pain: ", "\t ", state.persistent_pain, "\n"
         , "  Service environment: ", "\t ", state.service_environment, "\n"
         , "  Accident response: ", "\t ", state.accident_response, "\n"
         , "  Recovery expectations: ", state.recovery_expectations, "\n"
         , "  Prior health: ", "\t ", state.prior_health, "\n"
         , "  Prior finance: ", "\t ", state.prior_finance, "\n"
         , "  Fault: ", "\t\t ", state.fault, "\n"
         , "  Support and optimism: ", " ", state.support_optimism, "\n"
         , "  Sollicitor engagement: ", state.sollicitor_engagement, "\n"
         , "  Satisfaction: ", "\t ", state.satisfaction
         )
end
