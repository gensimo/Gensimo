"""
Provides a core type and utilities for social insurance client states.

The state of a client is modelled by the following type tree:

State
   - PhysioState
   - PsychoState
   - AdminState
       - [ Claim ]
           - Team
           -CaseManager
           - [ Service ]
"""
module States


export State, state, states, claims, claims_adjacency, neighbours, distance

export s1, s2, s3, c1, c2

using Combinatorics: powerset

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
    pool
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

function Base.:(==)(c1::Claim, c2::Claim)
    if distance(c1, c2) == 0
        return true
    else
        return false
    end
end

function Base.:(==)(s1::State, s2::State)
    # Are physiological and psychological layers the same?
    ϕ1 = s1.physiological.physical_health
    ψ1 = s1.psychological.psychological_health
    ϕ2 = s2.physiological.physical_health
    ψ2 = s2.psychological.psychological_health
    if ϕ1 != ϕ2 || ψ1 != ψ2
        return false
    end

    # Same number of claims?
    claims1 = s1.administrative.claims
    claims2 = s2.administrative.claims
    if length(claims1) != length(claims2)
        return false
    else
        nclaims = length(claims1)
    end

    # Is each claim the same?
    for i ∈ 1:nclaims
        team1 = claims1[i].team
        team2 = claims2[i].team
        mngr1 = claims1[i].case_manager
        mngr2 = claims2[i].case_manager
        services1 = claims1[i].services
        services2 = claims2[i].services
        if any([ team1 != team2
               , mngr1 != mngr2])
            return false
        elseif !issetequal(services1, services2)
            return false
        end
    end

    # All checks passed, the states are identical.
    return true
end

"""Return 'intervention' distance between claims."""
function distance(c1::Claim, c2::Claim)
    # Start with nothing.
    d=0

    # Abbreviate the nested fields.
    team1 = c1.team
    team2 = c2.team
    mngr1 = c1.case_manager
    mngr2 = c2.case_manager
    services1 = c1.services
    services2 = c2.services

    # Different team means an extra distance of 1.
    if team1 != team2
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

"""Return distance from fictional null claim."""
function distance(c1::Nothing, c2::Claim)
    # Start from 2 as any claim has a team and case manager.
    d = 2
    # Add the number of services.
    d += length(c2.services)
    # That is all.
    return d
end

"""Return distance from fictional null claim."""
function distance(c1::Claim, c2::Nothing)
    return distance(c2, c1)
end

"""Return 'intervention' distance between states."""
function distance(s1::State, s2::State)
    # Start with nothing.
    d = 0

    # Abbreviate deeply nestled fields.
    ϕ1 = s1.physiological.physical_health
    ψ1 = s1.psychological.psychological_health
    ϕ2 = s2.physiological.physical_health
    ψ2 = s2.psychological.psychological_health

    # Any difference in physiological health adds 1 to distance.
    if ϕ1 != ϕ2
        d += 1
    end
    # Any difference in psychological health adds 1 to distance.
    if ψ1 != ψ2
        d += 1
    end

    # Deal with the claims.
    claimsets = [ s1.administrative.claims, s2.administrative.claims ]
    # Size of smallest claim set.
    n = minimum(length.(claimsets))
    # First add distances between all claims up to size of smallest claim set.
    d += sum(distance.(claimsets[1][1:n], claimsets[2][1:n]))
    # Then add distances of remaining claims in larger claim set.
    claimset = claimsets[argmax(length.(claimsets))] # The larger claim set.
    m = length(claimset) # The size of the larger claim set.
    nothings = repeat([nothing], m-n) # A vector of nothings for comparison.
    # Add all distances of remaining claims with the fictional null claim.
    d += sum(distance.(nothings, claimset[n+1:end]))

    # Return the total distance.
    return d
end

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
              , change_claim=nothing # Or provide claim number and new claim.
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

    if isnothing(change_claim)
        α = state.administrative
    else
        claimno, newclaim = change_claim
        α[claimno] = newclaim
    end

    State(ϕ, ψ, α)
end

"""Generate all possible states, e.g. to obtain the MDP state space."""
function states()
    cs = claims()
    # TODO: Only single-claim states are generated, already nearly 5M states.
    states = [ state( physio_health=ϕ
                    , psycho_health=ψ
                    , add_claim=claim )
               for ϕ ∈ 100
               for ψ ∈ 100
               for claim ∈ cs ]

    return states
end

"""Generate claims adjacency matrix interpreting unit distance as adjacency."""
function claims_adjacency(cs=nothing)
    # Use all claims if no claim set provided.
    if isnothing(cs)
        cs = claims()
    end
    # Helper function: return 1 if distance implies adjacency, 0 otherwise.
    function isedge(d)
        if d == 1
            return 1
        else
            return 0
        end
    end
    # Build the adjacency matrix and return it.
    A = [ isedge(distance(c1, c2)) for c1 in cs, c2 in cs ]
    return A
end

"""Generate all possible claims, e.g. to obtain a state space."""
function claims()
    services = collect(instances(Service))
    servicesets = powerset(services)
    claims = [ Claim(team, casemanager, serviceset)
               for team ∈ instances(Team)
               for casemanager ∈ instances(CaseManager)
               for serviceset ∈ servicesets ]
    return claims
end

"""Return claims that are unit distance from `claim`."""
function neighbours(claim::Claim)
    # The teams that are not on the claim.
    teams = [ team for team ∈ instances(Team) if team != claim.team ]
    # The case managers that are not on the claim.
    mngrs = [ mngr for mngr ∈ instances(CaseManager)
                    if mngr != claim.case_manager ]
    # All service sets with one service removed.
    services_minus_one = [ [claim.services[1:i-1]; claim.services[i+1:end]]
                           for i ∈ length(claim.services) ]
    # All service sets with one extra service.
    services_plus_one = [ [claim.services; [service]]
                          for service ∈ instances(Service)
                          if service ∉ claim.services ]
    # Claims one team away.
    claims_dteam = [ Claim(team, claim.case_manager, claim.services)
                     for team ∈ teams ]
    # Claims one case manager away.
    claims_dmngr = [ Claim(claim.team, mngr, claim.services)
                     for mngr ∈ mngrs ]
    # Claims one service away.
    claims_dservice = [ Claim(claim.team, claim.case_manager, services)
                        for services ∈ [ services_minus_one
                                       ; services_plus_one ] ]
    # All the claims at unit distance.
    claims = [ claims_dteam; claims_dmngr; claims_dservice ]

    # Return them.
    return claims
end

# Bogoclaims.
c1 = Claim(Team(0), CaseManager(0), [Service(0), Service(2)])
c2 = Claim(Team(2), CaseManager(1), [Service(1), Service(3)])

# Bogostates.
s1 = State(PhysioState(59), PsychoState(73), AdminState([c1, c2]))
s2 = state(s1)
s3 = state(s1,  add_service=(1, States.Service(1)))

# End of module.
end
