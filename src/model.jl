module InsuranceModel

using Agents
using AgentsX
using Random
using InteractiveDynamics
using CairoMakie

using .ClientAgent

"""
    initialise()
Initialise function for the ABM.
This function will return the ABM.
Arguments necessary for declaring the space will need to be passed manually.
"""

function initialise(step_function; numagents = 1000, seed = 250 )
    space = GridSpace
    properties = Dict(:step_function => step_function)
    rng = Random.MersenneTwister(seed)
    
    model = ABM(
        Client, space;
        properties, rng
    )

    for n in 1:numagents
        agent = Client(
            n,
            (0, 0),
            state()
        )
        add_agent_single!(agent, model)
    end

    return model

end

#TODO reorder agent actions in expected execution order if required.
#TODO insert keyword arguments if required
model = initialise([])

end # module