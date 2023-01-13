module SI

using Revise
using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP
using POMDPTools: Deterministic, Uniform, SparseCat
using Distributions

struct SchemeState
    state::String
end

struct ClientState
    physical_health::Integer
    mental_health::Integer
end

struct SIState
    client_state::ClientState
    scheme_state::SchemeState
end

scheme_statelist = [ "Ambulance only"
                   , "Physiotherapy"
                   , "Psychotherapy"
                   , "Medication (mental)"
                   , "Income support" ]
scheme_states = [ SchemeState(string(s)) for s ∈ "AB" ]

client_states = [ ClientState(physical, mental) for
                  physical ∈ [i for i ∈ 0:1],
                  mental ∈ [i for i ∈ 0:1] ]

si_states = [ SIState(c, s) for c ∈ client_states, s ∈ scheme_states ]

"""Deterministic transition function. Action equals next state."""
function si_transition(s, a)
    return Deterministic(a)
end

"""Reward function. Gives mental health penalty for staying in same state."""
function si_reward(s, a, sp)
    if a === s
        return s.client_state.mental_health - 1
    end
end

si = QuickMDP( states = si_states
              , actions = si_states
              , transition = si_transition
              , reward = si_reward
              , discount = .95
              , initialstate = Deterministic(si_states[4])
              )

function simulate(si)
    sim(si, max_steps=10) do s
        println(s)
        sstate = rand(Uniform(scheme_states))
        if sstate === s.scheme_state
            println("yes")
            cstate = ClientState(s.client_state.physical_health, 0)
        else
            cstate = ClientState( s.client_state.physical_health
                                , s.client_state.mental_health )
        end
        return SIState(cstate, sstate)
    end
end

sipp = QuickMDP( gen = function (s, a, rng)
                    sp = rand(rng, Uniform(si_states))
                    r = sp.client_state.mental_health
                return (sp=sp, r=r)
                end
              , actions = si_states
              , initialstate = Deterministic(si_states[1])
              , discount = .95
              , isterminal = s -> s == si_states[end] )

sip = QuickMDP( states = si_states
              , actions = si_states

              , transition = function (s, a)
                    return Uniform(si_states)
                end
                , reward = function (s, a, sp)
                    sp.client_state.mental_health
                end

              , discount = .9
              , initialstate = Deterministic(si_states[1])
              # , isterminal = s -> s == si_states[end]
)


# Module end.
end
