using Dates
using Distributions, StatsBase
using Agents

include("deliberation.jl")

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

struct Case
    state::State      # Initial state of case.
    dayzero::Date     # Date of entering the scheme, e.g. date of accident.
    severity::Float64 # Multiplies the intensity of the request point process.
end

Case() = Case( state() # Empty state.
             , rand(Date(2020):Day(1):Date(2023)) # Random day zero.
             , 1+rand(Exponential()) ) # Random severity.

function case_events(case::Case, to_date::Date)
    return events(case.dayzero, to_date, case.severity/Dates.days(Year(1)))
end

mutable struct Conductor
    services::Vector{Service} # List of `Service`s (label, cost).
    states::Vector{State}     # List of `State`s allowed (e.g. empirical).
    epoch::Date               # Initial date.
    eschaton::Date            # Final date.
    probabilities::Dict{State, AbstractArray} # State transition probabilities.
    cases::Vector{Case}       # `Case`s (dayzero, severity).
    histories::Dict           # Each `Case`'s history (`Date`=>`State`).
end

function Conductor( services
                  , states
                  , epoch, eschaton
                  , ncases=1
                  , probabilities=nothing)
    # Create n random `Case`s.
    cases = [ Case() for i in 1:ncases ]
    # Prepare a history for each case with no states against the `Date`s yet.
    histories = Dict( case=>Dict( vcat( case.dayzero
                                      , case_events(case, eschaton) )
                                 .=> [case.state] )
                      for case in cases )
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
                    , cases
                    , histories )
end

function simulate!(conductor::Conductor)
    # Treat every case separately.
    for case in conductor.cases
        # First create a model with no clients and one manager.
        model = initialise( conductor.states
                          , conductor.services
                          , nclients=0
                          , nmanagers=1 )
        # Add a client agent for this case.
        add_agent!(Client, model, case.state)
        # Run model for as many steps as events in case. Collect data.
        dates = collect(keys(conductor.histories[case])) # Dates of events.
        n = length(dates) - 1 # Number of events, minus one for initial state.
        df, _ = run!(model, agent_step!, model_step!, n, adata=[:state]) # Data.
        # Keep only `Client` agent `State`s. Convert from `State?` type.
        states = convert.(State, df[df.:agent_type .== :Client, :state])
        # Update history in `Conductor` object.
        conductor.histories[case] = Dict(dates .=> states)
    end
end


function extract( conductor::Conductor
                ; what=:costs )
    return Dict( case =>
                 ( [ collect(keys(c.histories[case])) ]
                 # TODO: Convert below to Float64.
                 , [ cost.(collect(values(c.histories[case]))) ] )
                 for case in conductor.cases )
end














