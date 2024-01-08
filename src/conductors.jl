using Distributions, StatsBase, Dates
using Agents
using DataStructures: OrderedDict

# using ..Gensimo

# export Conductor, Case, extract, case_events, events, Context

function events(from_date, to_date, lambda)
    # Get a list of the dates under consideration.
    dates = from_date:Day(1):to_date
    # Get the overall intensity for the period.
    Λ = length(dates)*lambda
    # Get the number of events from the corresponding Poisson distribution.
    nevents = rand(Poisson(Λ))
    # Sample the events uniformly and without replacement from the dates.
    # TODO: This can return an empty list.
    events = sample(dates, nevents; replace=false)
    # Deliver as a sorted list.
    return sort(events)
end

struct Context
    # Necessary context --- these fields are needed by any simulation.
    services::Vector{Service} # List of `Service`s (label, cost).
    segments::Vector{Segment} # List of `Segment`s (dvsn, brnch, tm, mngr).
    # Optional context --- these fields can be inferred or ignored.
    states::Vector{Vector{String}} # List of allowed service lists ('states').
    probabilities::Dict{Vector{String}, AbstractArray} # Trnstn prbs.
end

Context(services, segments) = Context( services
                                     , segments
                                     , Vector{Vector{String}}()
                                     , Dict{ Vector{Vector{String}}
                                           , AbstractArray}() )

services(context::Context) = context.services
segments(context::Context) = context.segments
states(context::Context) = context.states
probabilities(context::Context) = context.probabilities

mutable struct Conductor
    context::Context          # Allowed `Segments`s, `Service`s etc.
    epoch::Date               # Initial date.
    eschaton::Date            # Final date.
    clients::Vector{Client}   # The clients to simulate (states and claims).
end

# Accessors.
context(c::Conductor) = c.context
epoch(c::Conductor) = c.epoch
eschaton(c::Conductor) = c.eschaton
clients(c::Conductor) = c.clients

function Conductor( context::Context
                  , epoch::Date, eschaton::Date
                  , nclients::Integer=1 )
    # Create random clients, with epoch < `dayzero` < eschaton.
    clients = [ Client( Personalia()
                      , Dict(rand(epoch:Day(1):eschaton)=>State(rand(12)))
                      , Claim() ) for i ∈ 1:nclients ]
    # Instantiate and deliver the object.
    return Conductor( context
                    , epoch, eschaton
                    , clients )
end

function Conductor( context::Context
                  , eschaton::Date # End-date only --- initial date inferred.
                  , clients::Vector{Client} )
    # Collect and sort all `dayzero`es of the clients.
    zerodays = [dayzero(client) for client ∈ clients] |> sort
    # Start the simulation on the first zero day.
    epoch = zerodays[1]
    # End of simulation needs to be later than all zero days.
    if zerodays[end] < eschaton
        return Conductor(context, epoch, eschaton, clients)
    else
        error("At least one client has zero day at or after end of simulation.")
    end
end

function extract( conductor::Conductor
                ; what=:costs )
    return Dict( case =>
                 ( collect(keys(conductor.histories[case]))
                 # TODO: Convert below to Float64.
                 , cost.(collect(values(conductor.histories[case]))) )
                 for case in conductor.cases )
end
