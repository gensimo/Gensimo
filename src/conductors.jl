using DataFrames, Distributions, StatsBase, Dates, Random
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

const Context = Dict{Symbol, Any}
distros(context::Context) = context[:distros]

@kwdef mutable struct Conductor
    context::Context = Context() # Model parameters.
    epoch::Date = Date(2020)     # Initial date.
    eschaton::Date = Date(2021)  # Final date.
    clients::Vector{Client} = Client[]  # The client cohort.
    clienteles::Vector{Clientele} = Clientele[] # The organisational structure.
    providers::Vector{Provider} = Provider[] # External health care providers.
end

# Accessors.
context(c::Conductor) = c.context
epoch(c::Conductor) = c.epoch
eschaton(c::Conductor) = c.eschaton
clients(c::Conductor) = c.clients
clienteles(c::Conductor) = c.clienteles
providers(c::Conductor) = c.providers

# Derivative accessors.
agents(c::Conductor) = [clients(c)... , insurers(c)... , providers(c)...]
nagents(c::Conductor) = length(agents(c))
nclients(c::Conductor) = c |> clients |> length
nclienteles(c::Conductor) = c |> clienteles |> length
nmanagers(c::Conductor) = sum([ length(managers(c)) for p in clienteles(c) ])
nproviders(c::Conductor) = c |> providers |> length
timeline(c::Conductor) = collect(epoch(c):Day(1):eschaton(c))

function Conductor( context::Context
                  , epoch::Date, eschaton::Date
                  , nclients::Integer=1
                  ; cohort=:uniform # or :uniform.
                  )
    # Convenience inner function to mass-produce Client agents.
    function makeclients(dates, n)
        return [ Client( id=i, pos=(0.0, 0.0), vel=(0.0, 0.0)
                       , personalia = Personalia()
                       , history = [ (rand(dates), State(rand(12))) ]
                       , claim = Claim() )
                 for i ∈ 1:n ]
    end
    # Create random clients according to cohort setting.
    if cohort == :firstyear # All clients have day zero in first year.
        dates = epoch:Day(1):epoch+Year(1)
        clients = makeclients(dates, nclients)
    elseif cohort == :firstday
        clients = [ Client( id=i, pos=(0.0, 0.0), vel=(0.0, 0.0)
                       , personalia = Personalia()
                       , history = [ (epoch, State([.1, .1, rand(10)...])) ]
                       , claim = Claim() )
                    for i ∈ 1:nclients ]
    elseif cohort == :uniform # Clients have days zeros anywhere in timeline.
        dates = epoch:Day(1):eschaton
        clients = makeclients(dates, nclients)
    else # Default to :uniform cohort setting.
        dates = epoch:Day(1):eschaton
        clients = makeclients(dates, nclients)
    end
    # Instantiate and deliver the object.
    return Conductor( context=context
                    , epoch=epoch, eschaton=eschaton
                    , clients=clients )
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
        return Conductor( context=context
                        , epoch=epoch, eschaton=eschaton
                        , clients=clients )
    else
        error("At least one client has zero day at or after end of simulation.")
    end
end

function Conductor( epoch::Date, eschaton::Date
                  , nclients::Integer=1
                  ; cohort=:uniform )
    return Conductor(Context(), epoch, eschaton, nclients, cohort=cohort)
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

function client(request::Request, conductor::Conductor)
    cs = []
    for client in clients(conductor)
        for event in client |> events
            if request == change(event)
                push!(cs, client)
            end
        end
    end
    if length(cs) == 0
        return nothing
    elseif length(cs) == 1
        return cs[1]
    else
        return cs
    end
end

function event(request::Request, conductor::Conductor)
    es = []
    for client in clients(conductor)
        for event in client |> events
            if request == change(event)
                push!(es, event)
            end
        end
    end
    if length(es) == 0
        return nothing
    elseif length(es) == 1
        return es[1]
    else
        return es
    end
end
