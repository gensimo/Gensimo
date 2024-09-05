using Agents


@multiagent struct InsuranceWorker(ContinuousAgent{2, Float64})
    @subagent struct ClientAssistant
        capacity::Int64 # Number of concurrent tasks the worker can work on.
    end
    @subagent struct ClaimsManager
        capacity::Int64 # Number of concurrent tasks the worker can work on.
    end
end

capacity(m::InsuranceWorker) = m.capacity

@kwdef mutable struct Task
    date::Union{Date, Nothing} = nothing # Date of allocation, not of event.
    request::Request
    event::Event # Date of event is request date <= task allocation date.
    client::Client
    allocation::Union{InsuranceWorker, Nothing} = nothing
end

# Constructors.
function Task(task::Pair{Request, Pair{Event, Client}})
    # Deliver an unallocated task.
    return Task( nothing
               , task.first
               , task.second.first
               , task.second.second
               , nothing )
end

# Accessors, mutators and assorted utility functions.
request(task::Task) = task.request # task.first
event(task::Task) = task.event # task.second.first
client(task::Task) = task.client # task.second.second
# date(task::Task) = date(event(task))
Base.isless(t1::Task, t2::Task) = date(event(t1)) < date(event(t2))
function allocate!(task::Task, manager::InsuranceWorker, date::Date)
    task.allocation = manager
    task.date = date
end
isallocated(task::Task) = !isnothing(task.allocation)
requestedon(task::Task) = task.event.date
allocatedon(task::Task) = task.date

function close!(task::Task, date::Date)
    status!(request(task), :closed)
    term!(event(task), date)
end

# @kwdef mutable struct Clientele
@agent struct Clientele(ContinuousAgent{2, Float64})
    clients::Vector{Client} = Client[]
    managers::Dict{InsuranceWorker,Vector{Task}} = Dict()
end

# Constructors.
Clientele(n::Integer) = Clientele( id=1, pos=(0, 0), vel=(0, 0)
                                 , clients=[Client() for i ∈ 1:n] )

# Assorted accessors and mutators.
clients(clientele::Clientele) = clientele.clients
managers(clientele::Clientele) = keys(clientele.managers) |> collect
isportfolio(clientele::Clientele) = length(managers(clientele)) == 1
isport(clientele::Clientele) = isportfolio(clientele)
ispool(clientele::Clientele) = length(managers(clientele)) > 1
allocations(clientele::Clientele) = clientele.managers
function nallocations(clientele::Clientele)
    return Dict( key => length(val) for (key, val) in allocations(clientele) )
end
function nfree(clientele::Clientele; total=false)
    d = Dict( key => capacity(key) - length(val)
              for (key, val) in allocations(clientele) )
    if total
        return sum(values(d))
    else
        return d
    end
end
anyfree(clientele::Clientele) = nfree(clientele; total=true) > 0
freemanagers(clientele::Clientele) = [ m for m in managers(clientele)
                                         if nfree(clientele)[m] > 0 ]
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
                push!(ts, Task(change(event) => event => client))
            end
        end
    end
    return ts
end

function tasks(clientele::Clientele)
    return sort([ task for client in clientele for task in tasks(client) ])
end

function allocate!( clientele::Clientele
                  , m::InsuranceWorker
                  , t::Task
                  , date::Date )
    r = request(t)
    # Do the allocation --- either add to m's list or add m with t.
    if m ∈ managers(clientele)
        push!(allocations(clientele)[m], t)
    else
        allocations(clientele)[m] = [t]
    end
    # Update the status of the request.
    status!(r, :allocated)
    # Update the task to list the allocation.
    allocate!(t, m, date)
end

function allocate!(clientele::Clientele, taskfor::Pair, date::Date)
    # Get the manager and the task.
    m, t = taskfor
    # Call the other `allocate!` function.
    allocate!(clientele, m, t, date)
end

function Base.show(io::IO, task::Task)
    if isallocated(task)
        s = string("(allocated on ", allocatedon(task), ")")
    else
        s = "(waiting)"
    end
    print( io
         , requestedon(task), " ", s
         , " for "
         , name(personalia(client(task)))
         , " (ID: ", client(task).id, ")"
         , "\n\t"
         , "<", label(request(task)), ">"
         )
end

function Base.show(io::IO, clientele::Clientele)
    println(io, "Clients (", length(clientele), "):")
    for client in clientele
        show(io, personalia(client))
        print(io, " (ID: ", client.id, ") ")
        nopen = length(requests(client; status=:open))
        nallo = length(requests(client; status=:allocated))
        println(io, "\t", "Requests: ", nopen, " open, ", nallo, " allocated.")
    end
    n = length(managers(clientele))
    if n == 0
        p = ""
    elseif n == 1
        p = " - portfolio"
    else
        p = " - pool"
    end
    println(io, "Managers (", n, p, "):")
    for man in managers(clientele)
        tasks = allocations(clientele)[man]
        println( io, "  | Manager ", man.id, " "
               , "/\t", length(tasks)
               , " task", length(tasks)==1 ? "" : "s", " allocated:")
        for task in tasks
            println(io, "    * ", task)
        end
    end
end
