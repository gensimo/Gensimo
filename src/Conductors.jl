module Conductors

using Distributions, StatsBase, Dates
using Agents
using DataStructures: OrderedDict

using ..Gensimo

export Conductor, Case, extract, case_events, events, Context

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

Case(portfolio, manager) = Case( state( portfolio=portfolio
                                      , manager=manager ) # Empty state.
                               , rand(Date(2020):Day(1):Date(2023)) # Day 0.
                               , 1+rand(Exponential()) ) # Random severity.

function case_events(case::Case, to_date::Date)
    return events(case.dayzero, to_date, case.severity/Dates.days(Year(1)))
end

struct Context
    # Necessary context --- these fields are needed by any simulation.
    services::Vector{Service} # List of `Service`s (label, cost).
    portfolios::Vector{Portfolio} # List of `Portfolio`s (team, branch, div.).
    managers::Vector{String} # List of case manager names.
    # Optional context --- these fields can be inferred or ignored.
    states::Vector{State} # List of allowed `State`s (e.g. empirical).
    probabilities::Dict{State, AbstractArray} # State transition probabilities.
end

Context(services, portfolios, managers) = Context( services
                                                 , portfolios
                                                 , managers
                                                 , Vector{State}()
                                                 , Dict{State, AbstractArray}()
                                                 )

mutable struct Conductor
    context::Context # Alloweds `State`s, `Service`s etc.
    # services::Vector{Service} # List of `Service`s (label, cost).
    # states::Vector{State}     # List of `State`s allowed (e.g. empirical).
    epoch::Date               # Initial date.
    eschaton::Date            # Final date.
    # probabilities::Dict{State, AbstractArray} # State transition probabilities.
    cases::Vector{Case}       # `Case`s (dayzero, severity).
    histories::Dict           # Each `Case`'s history (`Date`=>`State`).
end


"""
    Conductor( services, states
             , epoch, eschaton
             , ncases=1
             , portfolios=nothing, managers=nothing
             , probabilities=nothing )

Create a Conductor object for use with deliberation ABMs.
"""
function Conductor( context::Context
                  # services::Vector{Service}, states::Vector{State}
                  , epoch::Date, eschaton::Date
                  , ncases=1 )
                  # ; portfolios=nothing, managers=nothing
                  # , probabilities=nothing )
    # Create n random `Case`s.
    cases = [ Case(rand(context.portfolios)
            , rand(context.managers))
              for i in 1:ncases ]
    # Prepare a history for each case with no states against the `Date`s yet.
    histories = Dict( case=>OrderedDict( vcat( case.dayzero
                                       , case_events(case, eschaton) )
                                         .=> [case.state] )
                      for case in cases )
    # Instantiate and deliver the object.
    return Conductor( context
                    , epoch
                    , eschaton
                    , cases
                    , histories )
end

function extract( conductor::Conductor
                ; what=:costs )
    return Dict( case =>
                 ( collect(keys(conductor.histories[case]))
                 # TODO: Convert below to Float64.
                 , cost.(collect(values(conductor.histories[case]))) )
                 for case in conductor.cases )
end


end # Module Conductors.
