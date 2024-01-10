module DeliberationMDP

using POMDPs: simulate
using QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP
using POMDPTools: Deterministic, Uniform, SparseCat, RandomPolicy
using DataStructures: OrderedDict

using Gensimo

function simulate!(conductor::Conductor)
    # Treat every case separately.
    for case in conductor.cases
        dates = sort(collect(keys(conductor.histories[case]))) # Event dates.
        n = length(dates) # Number of events.
        states = get_history( conductor.context.states
                            , conductor.context.states[1]
                            , conductor.context.probabilities
                            , n )
        # Update history in `Conductor` object.
        conductor.histories[case] = OrderedDict(dates .=> states)
    end
end

function reward(s, a, sp)
    if sp == s
        return 0.0
    else
        return -(α(sp)[end]).cost
    end
end

function make_transitionf(states, probabilities)
    return (s, a) -> SparseCat(states, Array(probabilities[s]))
end

# Instantiate the scheme.
initialise( states::Vector{State}
          , state::State
          , probabilities ) = QuickMDP( states = states
                                      , actions = [:default]
                                      , discount = .95
                                      , transition =
                                        make_transitionf(states, probabilities)
                                      , reward = reward
                                      , initialstate = Deterministic(state)
                                      # , isterminal = s -> s ∈ terminalstates
                                      )

function get_history(states, initialstate, probabilities, nsteps)
    model = initialise(states, initialstate, probabilities)
    policy = RandomPolicy(model)
    hr = HistoryRecorder(max_steps=nsteps)
    history = simulate(hr, model, policy)
    return [ history[i][1] for i in 1:length(history) ]
end

"""
    steppol(model; policy=nothing, nsteps=3)

Step through the policy for `nsteps` steps and print state information.
"""
function steppol(model; policy=nothing, nsteps=3)
    if isnothing(policy)
        policy = RandomPolicy(model)
    end
    step = 1
    endstate = nothing
    totalr = 0.0
    for (s, a, r, sp) in stepthrough( model
                                    , policy
                                    , "s,a,r,sp"
                                    , max_steps=nsteps )
        println("Step #$step")
        println("==========")
        println("Services:\n$sp")
        # println("Action: $a")
        println("Cost increment: \$$(abs(r))\n")
        step += 1
        endstate = sp
        totalr += r
    end
    println("============================")
    println("End state after $(step-1) steps:\n$endstate")
    println("Total costs: \$$(abs(totalr))\n")
end


function plist(state)
    # Treat first service separately.
    i = findfirst(==([]), states)
    j = findfirst(==(state[1:1]), states)
    ps = [ A[i, j] ]
    # Loop through rest of services.
    for k ∈ 2:length(state)
        i = findfirst(==(state[1:k-1]), states)
        j = findfirst(==(state[1:k]), states)
        ps = [ ps; A[i, j]]
    end
    return ps
end


function pprint(state)
    return join([ string( "| ", service, "\n") for service ∈ state ])
end

function pplot(A)
    labels = [ (string(i), pprint(state)) for (i, state) in enumerate(states) ]
    gplot(DiGraph(A), labels)
end

end # Module DeliberationMDP.
