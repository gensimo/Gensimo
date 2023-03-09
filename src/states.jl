"""
Provides a core type and utilities for social insurance client states.

The state of a client is modelled by the following type tree:

State
   - PhysioState
   - PsychoState
   - AdminState
       - [ Claim ]
           - Team
           - CaseManager
           - [ Service ]
"""
module States

export State, state

struct PhysioState
    physical_health::Integer
end

struct PsychoState
    psychological_health::Integer
end

"""Teams as simple enumerated type."""
@enum Team begin
    team_1
    team_2
    team_3
end

"""CaseManagers as simple enumerated type."""
@enum CaseManager begin
    alex
    blake
    charlie
    dee
    evelyn
end

"""Services as simple enumerated type."""
@enum Service begin
    ambulance
    physiotherapy
    psychotherapy
    medication
    income_support
end

struct Claim
    team::Team
    case_manager::CaseManager
    services::Vector{Service}
end

struct AdminState
    claims::Vector{Claim}
end

"""
Type to serve as the core of the state agents in the ABM section as well as of the states of the MDP section.of the model framework.
"""
struct State
    physiological::PhysioState
    psychological::PsychoState
    administrative::AdminState
end

# Bogoclaim.
c1 = Claim(Team(0), CaseManager(0), [Service(0), Service(2)])
c2 = Claim(Team(2), CaseManager(1), [Service(1), Service(3)])

# Bogostate.
s = State(PhysioState(59), PsychoState(73), AdminState([c1, c2]))

function Base.show(io::IO, phy::PhysioState)
    print(io, "Physical Health: ", phy.physical_health, "%")
end

function Base.show(io::IO, psy::PsychoState)
    print(io, "Psychological Health: ", psy.psychological_health, "%")
end

function Base.show(io::IO, clm::Claim)
    services = join([ string( "       | ", service, "\n") for service ∈ clm.services ])
    print( io
         , "       Team: ", clm.team
         , "\n"
         , "       Case manager: ", clm.case_manager
         , "\n"
         , "       Services:"
         , "\n"
         , services
         )
end

function Base.show(io::IO, adm::AdminState)
    cs = join( [ string( "    ", index, ". =============\n", claim, "\n")
                 for (index, claim) ∈ enumerate(adm.claims) ] )
    print(io, "Claims:\n", cs)
end

function Base.show(io::IO, s::State)
    print( io
         , "Physiological layer\n"
         , "-------------------\n"
         , "  - ", s.physiological
         , "\n\n"
         , "Psychological layer\n"
         , "-------------------\n"
         , "  - ", s.psychological
         , "\n\n"
         , "Administrative layer\n"
         , "--------------------\n"
         , "  - ", s.administrative
         )
end

"""Universal (copy) constructor and (pure) mutator. No argument ever altered."""
function state( state=nothing # Or provide a State.
              ; physio_health=nothing # Or provide an integer 0:100.
              , psycho_health=nothing # Or provide an integer 0:100.
              , add_claim=nothing # Or provide Claim object.
              , add_service=nothing # Or provide claim number and Service.
              )

    if isnothing(state)
        # Return a fully healthy client with no claims.
        state=State(PhysioState(100) , PsychoState(100) , AdminState([]))
    else
        # Or a deep copy of the passed state.
        state = deepcopy(state)
    end

    if isnothing(physio_health)
        ϕ = state.physiological
    else
        ϕ = PhysioState(physio_health)
    end

    if isnothing(psycho_health)
        ψ = state.psychological
    else
        ψ = PsychoState(psycho_health)
    end

    if isnothing(add_service)
        α = state.administrative
    else
        α = state.administrative
        claim, service = add_service
        push!(state.administrative.claims[claim].services, service)
    end

    if isnothing(add_claim)
        α = state.administrative
    else
        push!(state.administrative.claims, add_claim)
    end

    State(ϕ, ψ, α)
end

"""Generate all possible states, e.g. to obtain the MDP state space."""
function states(nclaims=10, nservices=100)
    ϕs = [ PhysioState(i) for i ∈ 0:100 ]
    ψs = [ PsychoState(i) for i ∈ 0:100 ]


end
# nadminstates = length(instances(AdminState))
# states = [ state(ϕ, ψ, α) for ϕ ∈ 0:100, ψ ∈ 0:100, α ∈ 0:nadminstates-1 ]


# End of module.
end
