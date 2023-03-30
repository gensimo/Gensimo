"""
MDP representation of a social insurance scheme.
"""
module Scheme

using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP
using POMDPTools: Deterministic, Uniform, SparseCat
using Distributions

include("states.jl")
using .States

function reward(s, a, sp)
    if sp == s
        return -1.0
    elseif isempty(sp)
        return 1.0
    else
        return 0.0
    end
end

function transition(s, a)
    # Return uniform distribution over all claims at unit distance from `s`.
    return Uniform(neighbours(s))
end

scheme = QuickMDP( states = claims()
                 , actions = [:default]
                 , discount = .95
                 , transition = transition
                 , reward = reward
                 , initialstate=claims()[8]
                 )


# End of module.
end
