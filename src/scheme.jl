"""
MDP representation of a social insurance scheme.
"""
module Scheme

using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP
using POMDPTools: Deterministic, Uniform, SparseCat
using Distributions

function next_state(s, a, rng)
    sp = 0
    r = 0
    return (sp=sp, r=r)
end


# End of module.
end
