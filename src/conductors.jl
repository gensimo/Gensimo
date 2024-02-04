using DataFrames, Distributions, StatsBase, Dates, Random
using Agents
using DataStructures: OrderedDict


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

# function n( t # Number of days passed.
          # , λ # Initial hazard rate (mean #requests at previous date).
          # , β # Decay rate of exponential decline of λ.
          # , rng=nothing # Pseudo random number generator.
          # )
    # # If not provided, get the pseudo-randomness from device.
    # isnothing(rng) ? rng = RandomDevice() : rng
    # if t < 0
        # return 0 # Only non-negative times are considered.
    # else
        # λ′ = λ * exp(-β*t) # Hazard rate declines exponentially.
        # n = rand(rng, Poisson(λ′)) # Draw from current Poisson distribution.
        # # Deliver.
        # return n
    # end
# end

# function nrequests( client::Client # The client, including health state(s).
                  # , date::Date # For which the number of requests is requested.
                  # , β=.01 # Decay rate, defaults to ~37% in 100 days.
                  # , rng=nothing # Pseudo random number generator.
                  # )
    # # If not provided, get the pseudo-randomness from device.
    # isnothing(rng) ? rng = RandomDevice() : rng
    # # Deliver.
    # return n(dτ(client, date), λ(client), β, rng)
# end

function nrequests(state::State, rng=nothing)
    # If not provided, get the pseudo-randomness from device.
    isnothing(rng) ? rng = RandomDevice() : rng
    # Deliver.
    return rand(rng, Poisson(λ(state)))
end

nrequests(client::Client, rng=nothing) = nrequests(client |> state, rng)

function request_cost( client::Client # The client, including health state(s).
                     , date::Date # At which request is placed.
                     , β=.01 # Decay rate, defaults to ~37% in 100 days.
                     , basecost=10.0 # Number of dollars.
                     , rng=nothing # Pseudo random number generator.
                     )
    # If not provided, get the pseudo-randomness from device.
    isnothing(rng) ? rng = RandomDevice() : rng
    # Deliver.
    return basecost * n(dτ(client, date), λ(client), β, rng)
end

request_cost(client, base=100.0, rng=nothing) = base*nrequests(client, rng)

struct Context
    # Necessary context --- these fields are needed by any simulation.
    request_distros::Dict
    services::Vector{Service} # List of `Service`s (label, cost).
    segments::Vector{Segment} # List of `Segment`s (dvsn, brnch, tm, mngr).
    # Optional context --- these fields can be inferred or ignored.
    states::Vector{Vector{String}} # List of allowed service lists ('states').
    probabilities::Dict{Vector{String}, AbstractArray} # Trnstn prbs.
end

Context( request_distros
       , services, segments) = Context( request_distros
                                      , services
                                      , segments
                                      , Vector{Vector{String}}()
                                      , Dict{ Vector{Vector{String}}
                                            , AbstractArray}() )

Context(request_distros) = Context( request_distros
                                  , Vector{Service}()
                                  , Vector{Segment}()
                                  , Vector{Vector{String}}()
                                  , Dict{ Vector{String}
                                        , AbstractArray}() )

Context() = Context( Dict()
                   , Vector{Service}()
                   , Vector{Segment}()
                   , Vector{Vector{String}}()
                   , Dict{Vector{String}, AbstractArray}() )

distros(context::Context) = context.request_distros
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
# Derivative accessors.
nclients(conductor::Conductor) = conductor |> clients |> length
timeline(conductor::Conductor) = ( epoch(conductor):Day(1):eschaton(conductor)
                                   |> collect )
isonscheme(client::Client, date::Date) = date >= dayzero(client)

function Conductor( context::Context
                  , epoch::Date, eschaton::Date
                  , nclients::Integer=1
                  ; cohort=:uniform # or :uniform.
                  )
    # Reset the client ids.
    reset_client()
    # Create random clients according to cohort setting.
    if cohort == :firstyear # All clients have day zero in first year.
        dates = epoch:Day(1):epoch+Year(1)
    elseif cohort == :uniform # Clients have days zeros anywhere in timeline.
        dates = epoch:Day(1):eschaton
    else # Default to :uniform cohort setting.
        dates = epoch:Day(1):eschaton
    end
    clients = [ Client( Personalia()
                      , [ (dates |> rand, State(rand(12))) ]
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

function nactive(conductor::Conductor, date::Date; tier=:ignore)
    if tier==:ignore
        return sum([ isactive(client, date) for client in clients(conductor) ])
    else
        return sum([ isactive(client, date) for client in clients(conductor)
                     if Gensimo.tier(client) == tier ])
    end
end

function nonscheme(conductor::Conductor, date::Date; tier=:ignore)
    if tier==:ignore
        return sum([ isonscheme(client, date) for client in clients(conductor)])
    else
        return sum([ isonscheme(client, date) for client in clients(conductor)
                     if Gensimo.tier(client) == tier ])
    end
end

function nactive(conductor::Conductor; tier=:ignore)
    return ( timeline(conductor)
           , (date->nactive(conductor, date, tier=tier)).(timeline(conductor)) )
end

function workload(conductor::Conductor; tier=:ignore)
    dateses = []
    hourses = []
    for client in clients(conductor)
        if tier != :ignore
            if Gensimo.tier(client) == tier
                dates, hours = workload(client)
                append!(dateses, dates)
                append!(hourses, hours)
            end
        else
            dates, hours = workload(client)
            append!(dateses, dates)
            append!(hourses, hours)
        end
    end
    df = sort(DataFrame(date=dateses, hours=hourses), :date)
    gdf = combine(groupby(df, :date), :hours => sum)
    return Vector{Date}(gdf.date), gdf.hours_sum
end

function workload_average(conductor::Conductor)
    dateses = []
    hourses = []
    n = nclients(conductor)
    for client in clients(conductor)
        dates, hours = workload(client)
        if !isempty(dates)
            firstdate = minimum(dates)
            dates = Dates.epochdays2date.(Dates.value.(dates - firstdate))
            append!(dateses, dates)
            append!(hourses, hours)
        end
    end
    hourses /= n
    df = sort(DataFrame(date=dateses, hours=hourses), :date)
    gdf = combine(groupby(df, :date), :hours => sum)
    return Vector{Date}(gdf.date), gdf.hours_sum
end

function cost(conductor::Conductor; cumulative=false)
    dateses = []
    dollarses = []
    for client in clients(conductor)
        dates, dollars = cost(client)
        append!(dateses, dates)
        append!(dollarses, dollars)
    end
    df = sort(DataFrame(date=dateses, cost=dollarses), :date)
    gdf = combine(groupby(df, :date), :cost => sum)
    costs = cumulative ? cumsum(gdf.cost_sum) : gdf.cost_sum
    return Vector{Date}(gdf.date), costs
end

function cost_average(conductor::Conductor; cumulative=false)
    dateses = []
    dollarses = []
    n = nclients(conductor)
    for client in clients(conductor)
        dates, dollars = cost(client)
        if !isempty(dates)
            firstdate = minimum(dates)
            dates = Dates.epochdays2date.(Dates.value.(dates - firstdate))
            append!(dateses, dates)
            append!(dollarses, dollars)
        end
    end
    dollarses /= n
    df = sort(DataFrame(date=dateses, cost=dollarses), :date)
    gdf = combine(groupby(df, :date), :cost => sum)
    costs = cumulative ? cumsum(gdf.cost_sum) : gdf.cost_sum
    return Vector{Date}(gdf.date), costs
end

function statistics(conductor::Conductor)
    ncs = conductor |> nclients
    simulation_window = (conductor |> epoch, conductor |> eschaton)
    first_dayzero = sort(dayzero.(clients(conductor)))[1]
    last_event = sort(date.(conductor |> clients))[end]
    event_window = (first_dayzero, last_event)
    # Deliver the statistics as a named tuple.
    return ( nclients = ncs
           , simulation_window = simulation_window
           , event_window = event_window
           )
end
