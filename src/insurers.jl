using Agents

mutable struct Clientele
    clients::Vector{Client}
end

function Base.getindex(clientele::Clientele, i)
    return clientele.clients[i]
end

function Base.setindex!(clientele::Clientele, client::Client, i)
    clientele.clients[i] = client
end

function Base.push!(clientele::Clientele, cs::Client...)
    for c in cs
        push!(clientele.clients, c)
    end
end

Clientele() = Clientele([])

@multiagent struct InsuranceWorker(NoSpaceAgent)
    @subagent struct ClientAssistant
        pool::Clientele # Multiple ClientAssistants will share the same pool.
        capacity::Float64 # Basically FTE fraction, so workload is required FTE.
    end
    @subagent struct ClaimsManager
        portfolio::Clientele # In principle: one portfolio, one claims manager.
        capacity::Float64 # Basically FTE fraction, so workload is required FTE.
    end
end
