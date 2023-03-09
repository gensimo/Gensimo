module ClientAgent

using Agents
using AgentsX

include("states.jl")
using .States
export Client

include("actions.jl")

# State = States.State
# state = States.state

"""
    Client <:AbstractAgent
A Client in a GridSpace.
The agents by default possess the following layers:
    - PhysioState
    - PsychoState
    - AdminState
Spatial functions are handled by the respective space of Agents.jl
"""

mutable struct Client <:AbstractAgent
    id::Int
    #TODO customise 'pos' as necessary
    pos::NTuple{2, Int}
    State::State
end

end # module
