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
    dayzero::Date     # Date of entering the scheme, e.g. date of accident.
    severity::Float64 # Multiplies the intensity of the request point process.
end

Client() = Client(rand(days(Metronome())), 1+rand(Exponential()))

function client_events(client::Client, to_date::Date)
    return events(client.dayzero, to_date, client.severity/Dates.days(Year(1)))
end



# Define a 'history' object tracking states of each agent over the time steps.
history = Dict(i => Dict( date => [ state() ] for i in 1:nclients
                                              for date in dates ) )


# Make a naive bimodal distribution using Gaussians.
μ₁ = epoch + Dates.Day(14) |> Dates.value
μ₂ = epoch + Dates.Day(365) |> Dates.value
σ₁ = 10
σ₂ = 100
f(x) = exp(-((x-μ₁)/σ₁)^2) + .5*exp(-((x-μ₂)/σ₂)^2)

# Turn the distribution f(x) into a probability mass function.
ds = epoch:Day(1):eschaton # From beginning to end, one day at a time.
ps = f.(Dates.value.(ds)) / sum(f.(Dates.value.(ds)))
pmf = DiscreteNonParametric(Dates.value.(ds), ps)

# TODO: structure and constructor to set up a simulation object, i.e. Conductor.

struct Conductor
    states::Vector{State}
    services::Vector{Service}
    probabilities::Dict{State, AbstractArray}
end
