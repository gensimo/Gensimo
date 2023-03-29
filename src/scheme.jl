"""
MDP representation of a social insurance scheme.
"""
module Scheme

using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP
using POMDPTools: Deterministic, Uniform, SparseCat
using Distributions

include("states.jl")
using .States

claims = claims()


function reward(s, a, sp)
    if sp == s
        return -1.0
    else
        return 0.0
    end
end

function transition(s, a)
    cs = claims()
    id = findfirst(==(s), cs)
    return Uniform()
end

scheme = QuickMDP( states = states()
                 , actions = [:default]
                 , discount = .95
                 , transition =
                 )

function next_state(s, a, rng)
    sp = 0
    r = 0
    return (sp=sp, r=r)
end


# End of module.
end
