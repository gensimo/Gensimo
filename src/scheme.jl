"""
MDP representation of a social insurance scheme.
"""
module Scheme

using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP
using POMDPTools: Deterministic, Uniform, SparseCat, RandomPolicy
using Distributions

include("states.jl")
using .States

export scheme, policy, steppol

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

# Instantiate the scheme.
scheme = QuickMDP( states = claims()
                 , actions = [:default]
                 , discount = .95
                 , transition = transition
                 , reward = reward
                 , initialstate=Deterministic(claims()[8])
                 )

# Produce a random policy.
policy = RandomPolicy(scheme)

"""Step through the policy for `nsteps` steps and print state information."""
function steppol(nsteps=3)
    step = 0
    endstate = nothing
    for (s, a, r, sp) in stepthrough( scheme
                                    , policy
                                    , "s,a,r,sp"
                                    , max_steps=nsteps )
        println("Step #$step")
        println("==========")
        println("State:\n$s")
        println("Action: $a")
        println("Reward: $r\n")
        step += 1
        endstate = sp
    end
    println("============================")
    println("End state after $step steps:\n$endstate")
end


end # Module Scheme.

