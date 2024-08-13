using Agents
using DataStructures

@kwdef mutable struct Clientele
    clients::Vector{Client} = Client[]
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

clients(clientele::Clientele) = clientele.clients

function Base.iterate(clientele::Clientele, state=1)
    if state > length(clients(clientele))
        return nothing
    else
        return clients(clientele)[state], state + 1
    end
end

function requests(clientele::Clientele; status=:open)
    return Dict( request => client for client in clientele
                                   for request in requests(client)
                                   if requests(client) |> !isempty
                                   && Gensimo.status(request) == status )
end

@multiagent struct InsuranceWorker(ContinuousAgent{2, Float64})
    @subagent struct ClientAssistant
        pool::Clientele # Multiple ClientAssistants will share the same pool.
        capacity::Float64 # Basically FTE fraction, so workload is required FTE.
    end
    @subagent struct ClaimsManager
        portfolio::Clientele # In principle: one portfolio, one claims manager.
        capacity::Float64 # Basically FTE fraction, so workload is required FTE.
    end
end
