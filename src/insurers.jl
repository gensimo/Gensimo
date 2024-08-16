using Agents


@multiagent struct InsuranceWorker(ContinuousAgent{2, Float64})
    @subagent struct ClientAssistant
        capacity::Float64 # Basically FTE fraction, so workload is required FTE.
    end
    @subagent struct ClaimsManager
        capacity::Float64 # Basically FTE fraction, so workload is required FTE.
    end
end

const Task = Pair{Request, Pair{Event, Client}}

# Accessors, mutators and assorted utility functions.
request(task::Task) = task.first
event(task::Task) = task.second.first
client(task::Task) = task.second.second
date(task::Task) = date(event(task))
Base.isless(t1::Task, t2::Task) = date(event(t1)) < date(event(t2))

function close!(task::Task, date::Date)
    status!(request(task), :closed)
    term!(event(task), date)
end

@kwdef mutable struct Clientele
    clients::Vector{Client} = Client[]
    managers::Dict{InsuranceWorker,Vector{Task}} = Dict()
end

# Constructors.
Clientele(n::Integer) = Clientele(clients=[Client() for i ∈ 1:n])

# Assorted accessors and mutators.
clients(clientele::Clientele) = clientele.clients
managers(clientele::Clientele) = keys(clientele.managers) |> collect
allocations(clientele::Clientele) = clientele.managers
function managers!(c::Clientele, ms::Vector{InsuranceWorker})
    for m in ms
        c.managers[m] = Task[]
    end
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

function Base.length(clientele::Clientele)
    return length(clientele.clients)
end

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

function tasks(client::Client)
    ts = []
    for event in events(client)
        if change(event) isa Request
            if status(change(event)) == :open
                push!(ts, change(event) => event => client)
            end
        end
    end
    return ts
end

function tasks(clientele::Clientele)
    return sort([ task for client in clientele for task in tasks(client) ])
end

function allocate!(clientele::Clientele, m::InsuranceWorker, t::Task)
    r = request(t)
    # Do the allocation --- either add to m's list or add m with t.
    if m ∈ managers(clientele)
        push!(allocations(clientele)[m], t)
    else
        allocations(clientele)[m] = [t]
    end
    # Update the status of the request.
    status!(r, :allocated)
end

function allocate!(clientele::Clientele, taskfor::Pair)
    # Get the manager and the task.
    m, t = taskfor
    # Call the other `allocate!` function.
    allocate!(clientele, m, t)
end
