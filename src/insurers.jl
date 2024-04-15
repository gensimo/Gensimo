using Agents

mutable struct Clientele
    clients::Vector{Client}
end

# TODO: Make the 'clientele' part of the agents inherited from a supertype.

@agent ClientAssistant NoSpaceAgent begin
    pool::Clientele # Multiple ClientAssistants will share the same pool.
    capacity::Float64 # Basically FTE fraction --- so workload is required FTE.
end

@agent ClaimsManager NoSpaceAgent begin
    portfolio::Clientele # In principle: one portfolio, one claims manager.
end



struct Insurer
    cohort::Vector{Client}
    client_assistants::Vector{ClientAssistant}
    claims_managers::Vector{ClaimsManager}
end
