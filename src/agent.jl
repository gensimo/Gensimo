using Agents
using AgentsX

include("actions.jl")

"""
    PhysioState <:ParamLayer
The PhysioState layer for Client.
"""
mutable struct PhysioState <: ParamLayer
    #TODO enter parameters for the PhysioState Layer
end


"""
    PsychoState <:ParamLayer
The PsychoState layer for Client.
"""
mutable struct PsychoState <: ParamLayer
    #TODO enter parameters for the PsychoState Layer
end


"""
    AdminState <:ParamLayer
The AdminState layer for Client.
"""
mutable struct AdminState <: ParamLayer
    #TODO enter parameters for the AdminState Layer
end


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
    #pos::NTuple{2, Int}
    PhysioState::PhysioState
    PsychoState::PsychoState
    AdminState::AdminState
end
