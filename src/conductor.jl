using Dates
using Distributions, StatsBase


# Number of clients.
nclients = 2
# Service request intensity, in mean requests per day.
λ = 1 / Dates.days(Year(1))

struct Metronome
    epoch::Date
    eschaton::Date
end

Metronome() = Metronome(Date(2020), Date(2023))

function days(epoch::Date, eschaton::Date)
    return epoch:Day(1):eschaton
end

function days(m::Metronome)
    return days(m.epoch, m.eschaton)
end

function events(from_date, to_date, lambda)
    # Get a list of the dates under consideration.
    dates = days(from_date, to_date)
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

struct Client
    state::State      # Initial state of client.
    dayzero::Date     # Date of entering the scheme, e.g. date of accident.
    severity::Float64 # Multiplies the intensity of the request point process.
end

Client() = Client(state(), rand(days(Metronome())), 1+rand(Exponential()))

function client_events(client::Client, to_date::Date)
    return events(client.dayzero, to_date, client.severity/Dates.days(Year(1)))
end

mutable struct Conductor
    services::Vector{Service} # List of `Service`s (label, cost).
    states::Vector{State}     # List of `State`s allowed (e.g. empirical).
    epoch::Date               # Initial date.
    eschaton::Date            # Final date.
    probabilities::Dict{State, AbstractArray} # State transition probabilities.
    clients::Vector{Client}   # `Client`s (dayzero, severity).
    histories::Dict           # Each `Client`'s history (`Date`=>`State`).
end

function Conductor( services
                  , states
                  , epoch, eschaton
                  , nclients=1
                  , probabilities=nothing)
    # Create n random `Client`s.
    clients = [ Client() for i in 1:nclients ]
    # Prepare a history for each client with no states against the `Date`s yet.
    histories = Dict( client=>Dict( client_events(client, eschaton) .=> nothing)
                      for client in clients )
    # Provide an empty probabilities dictionary if `nothing` provided.
    if isnothing(probabilities)
        probabilities = Dict{State, AbstractArray}()
    end
    # Instantiate and deliver the object.
    return Conductor( services
                    , states
                    , epoch
                    , eschaton
                    , probabilities
                    , clients
                    , histories )
end

function run(conductor::Conductor)
end











