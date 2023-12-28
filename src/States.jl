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


export StateOld, stateOld, distance
export fromvector
export lift_from_data
export phy, ϕ, psi, ψ, adm, α, ser, σ
export cost, costs

using ..Gensimo

struct AdminStateOld
    assessment::Integer        # E.g. NIDS score ∈ [0, 6].
    segment::Segment           # (Team, Branch, Division).
    manager::String            # Team or case manager.
    services::Vector{Service}  # Simplifyingly assumes one claim.
end

AdminStateOld(pf, mn, sv) = AdminStateOld(-1, pf, mn, sv)

struct StateOld
    state::State
    administrative::AdminStateOld
end

function fromvector!(stateOld::StateOld, vector::Vector{Float64})
    stateOld.state = State(vector...)
end

function ϕ(s::StateOld)
    return s.state.physical_health
end

function ψ(s::StateOld)
    return s.state.psychological_health
end

function α(s::StateOld, services_only=true)
    if services_only
        return s.administrative.services
    else
        return ( s.administrative.assessment
               , s.administrative.segment
               , s.administrative.manager
               , s.administrative.services )
    end
end

function σ(s::StateOld)
    return map(service->service.label, s.administrative.services)
end

function costs(stateOld::StateOld)
    if isempty(α(stateOld))
        return [0]
    else
        return map(service->service.cost, α(stateOld))
    end
end

function cost(stateOld::StateOld)
    return sum(costs(stateOld))
end

# ASCII aliases.
phy = ϕ
psy = ψ
adm = α
ser = σ

"""Universal (copy) constructor."""
function stateOld( stateOld = nothing
              ; state = nothing
              , assessment = nothing
              , segment = nothing
              , manager = nothing
              , services = nothing
              , ϕ = nothing
              , ψ = nothing
              )
    # If `stateOld` provided, harvest fields for default values.
    if !isnothing(stateOld)
        state = stateOld.state
        # phi = phy(stateOld)
        # psi = psy(stateOld)
        as, pf, mn, sv = adm(stateOld, false)
    # If not, provide some defaults.
    else
        fs = State(ones(Float64, 12)...)
        # phi = 100
        # psi = 100
        as = -1
        sm = Segment("", "", "", "")
        mn = ""
        sv = Vector{String}()
    end
    # Then set or change any fields that are provided.
    if !isnothing(state)
        if typeof(state) == State
            fs = state
        elseif typeof(state) == Vector{Float64}
            fs = State(state...)
        else
            error("State wrong type (use type State or Vector{Float64}).")
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
        fs = State(ϕ, fs[2:12]...)
    end
    if !isnothing(ψ)
        fs = State(fs[1], ψ, fs[3:12]...)
    end
    # Finally, deliver the stateOld struct.
    return StateOld( fs
                , AdminStateOld(as, sm, mn, sv) )
end

function stateOld(services::Vector{Service})
    return stateOld(services=services)
end

function stateOld(services, segment, manager::String)
    return stateOld(services=services, segment=segment, manager=manager)
end

function Base.:(==)(c1::AdminStateOld, c2::AdminStateOld)
    if distance(c1, c2) == 0
        return true
    else
        return false
    end
end

function Base.:(==)(s1::StateOld, s2::StateOld)
    if distance(s1, s2) == 0
        return true
    else
        return false
    end
end

"""Return 'intervention' distance between administrative stateOlds (claims)."""
function distance(c1::AdminStateOld, c2::AdminStateOld)
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

"""Return 'intervention' distance between overall stateOlds."""
function distance(s1::StateOld, s2::StateOld)
    # Abbreviate deeply nestled fields.
    fs1 = s1.state
    fs2 = s2.state
    α1 = s1.administrative
    α2 = s2.administrative
    # Compute Euclidean distance between state vectors.
    factord = (fs1 - fs2).^2 |> sum |> sqrt
    # Compute administrative distance.
    admind = distance(α1, α2)
    # Return the total distance.
    return factord + admind
end

function Base.show(io::IO, s::StateOld)
    print( io, "\n"
         , "State\n"
         , "-------\n"
         , s.state
         , "\n\n"
         , "Administrative layer\n"
         , "--------------------\n"
         , s.administrative
         )
end



function lift_from_data( stateOlds # As list of list of service label strings.
                       , costs  # Dictionary of service labels => Float64.
                       , probabilities # Dictionary of stateOld => probabilities.
                       , segments # List of Team, Branch, Division _tuples_.
                       , managers = nothing # List of managers [String]
                       )
    # First lift the services into the Service type via the `costs` dictionary.
    services = Service.(keys(costs), values(costs))
    # Then turn stateOlds into StateOld types.
    # First turn the `stateOlds` list-of-lists into a `Services` list-of-lists.
    # Make label-cost pairs from the `stateOlds` list of list of labels.
    label_cost_pairs = map.(s->(s, costs[s]), stateOlds)
    # Then lift those into the `Service` type.
    services_list_of_lists = map.(s->Service(s...), label_cost_pairs)
    n = length(services_list_of_lists)
    # Lift the segment tuples into the `Segment` type.
    segments = map(t->Segment(t...), segments)
    # Make up a list of managers if nothing provided.
    if isnothing(managers)
        managers = [ "Alex", "Blake", "Charlie", "Dee", "Evelyn" ]
    end
    # Make stateOlds of `services_list_of_lists` and random segment and managers.
    stateOlds = stateOld.( services_list_of_lists
                   , rand(segments, n)
                   , rand(managers, n) )
    # Finally, make a new StateOld => probabilities dictionary.
    probabilities = Dict(s=>probabilities[σ(s)] for s in stateOlds)
    # Deliver.
    return stateOlds, services, probabilities, segments, managers
end

end # Module States.
