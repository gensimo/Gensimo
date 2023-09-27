using Agents, Random
using POMDPTools # For `Deterministic`
#using Gensimo, TACTAC

@agent Client NoSpaceAgent begin
    state::State
end

function Base.show(io::IO, client::Client)
    println(io, "Agent ID: ", client.id)
    println(io, "Agent type: Client")
    println()
    print(io, client.state)
end

@agent Manager NoSpaceAgent begin
    services::Dict{Service, Float64} # [ (services, probabilities) ]
end

function initialise( states, services
                   ; nclients = 2
                   , nmanagers = 1
                   , seed = nothing
                   )
    # If no seed provided, get the pseudo-randomness from device.
    if isnothing(seed)
        seed = rand(RandomDevice(), 0:2^16)
    end
    model = ABM( Union{Client, Manager}
               ; rng = Xoshiro(seed) # MersenneTwister(seed)
               , properties = Dict( :time => 0
                                  , :services => services
                                  , :states => states )
               , warn = false
               )
    # Add clients.
    for _ in 1:nclients
        add_agent!(Client, model, rand(model.rng, states))
    end
    # Add manager(s) with random propensities to approve a service request.
    d = Dict(s => rand(model.rng) for s in services)
    for _ in 1:nmanagers
        add_agent!(Manager, model, d)
    end
    return model
end

function inspect(model)
    clients = [ agent for agent ∈ allagents(model) if typeof(agent)==Client ]
    managers = [ agent for agent ∈ allagents(model) if typeof(agent)==Manager ]
    nclients = length(clients)
    nmanagers = length(managers)
    print("Clients: $nclients, ")
    print("IDs: ", [client.id for client in clients])
    println()
    print("Managers: $nmanagers, ")
    print("IDs: ", [manager.id for manager in managers])
end

function agent_step!(agent, model, restrict=true)
    # Only step Client agents.
    if typeof(agent) == Client
        # Extract the list of services the client's received to date.
        s = α(agent.state)
        # Client requests a service, randomly.
        if restrict # Only request services that would yield legal states.
            legal_states = [    vcat(s, service) for service in services
                             if vcat(s, service) in states ]
            service = rand(model.rng, legal_states)[end]
        else # Request any service.
            service = rand(model.rng, services)
        end
        # Find a Manager, randomly.
        managers = [ a for a ∈ allagents(model) if typeof(a)==Manager ]
        m = rand(model.rng, managers)
        # If service is approved, add it to client's services vector.
        if rand(model.rng) < m.services[service]
            # New administrative state (α) is old one plus new service.
            newservicelist = vcat(α(agent.state), service)
            agent.state = state(agent.state, services=newservicelist)
        else
            ψprime = round(Int, .9 * ψ(agent.state))
            agent.state = state(agent.state, ψ=ψprime)
        end
    end
end

function model_step!(model)
    model.time += 1
end

function transition(s, a)
    # Create a model instance with a just a manager.
    model = initialise(states, services, nclients=0, nmanagers=1)
    # Add a client agent with the requested state.
    add_agent!(Client, model, state(services=s))
    # Evolve the model one step only.
    step!(model, agent_step!, model_step!)
    print(model[2])
    # Return the new state as a deterministic probability distribution.
    return Deterministic(α(model[2].state))
end
























