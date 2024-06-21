using Agents
using Dates, Random, Distributions

function simulate!(conductor::Conductor)
    model = initialise(conductor)
    step!( model
         , length(model.epoch:Day(1):model.eschaton) - 1 ) # Up to eschaton.
end

mutable struct Properties
    date::Date
    epoch::Date
    eschaton::Date
    context::Context
    rng
end

function initialise( conductor::Conductor
                   , seed=nothing )
    # If no seed provided, get the pseudo-randomness from device.
    isnothing(seed) ? seed = rand(RandomDevice(), 0:2^16) : seed
    rng = Xoshiro(seed)
    # Prepare the Properties object.
    ps = Properties( epoch(conductor)       # Properties.date
                   , epoch(conductor)       # Properties.epoch
                   , eschaton(conductor)    # Properties.eschaton
                   , context(conductor)     # Properties.context
                   , rng                    # Properties.rng
                   )
    # Set up the model.
    model = StandardABM( Union{Client, Provider}
                       ; properties = ps
                       , warn = false
                       , agent_step! = agent_step!
                       , model_step! = model_step! )
    # Add clients.
    for client in clients(conductor)
        add_agent!(client, model)
    end
    # Add some providers TODO: This needs to be included in the conductor.
    for p in 1:3
        menu = Dict("Allied Health Service" => 80.0 + randn(model.rng))
        capacity = 5 + rand(model.rng, -5:5)
        add_agent!( Provider, model; menu=menu, capacity=capacity)
    end
    # Deliver.
    return model
end

function agent_step!(agent, model)
    if agent isa Client
        client_step!(agent, model)
    end
    println(model.date)
end

function model_step!(model)
    model.date += Day(1)
end

function client_step!(client::Client, model)
    # Get the requests for today's hazard rate and deal with them sequentially.
    for request in requests(client)
        # 1. Establish what is requested.
        # 2. Identify the relevant liaisons (client, providers, insurers, ...)
        # 3. Spawn process.
    end

    # Update the client's hazard rate.
    update_client!(client, model.date, stap(1, (client |> λ)))
end

function requests(client::Client)
    # Get the number of requests for today's hazard rate.
    n = nrequests(client) # TODO: Needs model.rng for reproducibility.
    # TODO: Bogus request list.
    requests = []
    for i in 1:n
        if Bernoulli(.3) |> rand # Flip a weighted coin.
            # Coin says: request for Allied Health service.
            push!(requests, "Allied Health Service")
        else
            # Coin says: request for something else.
            push!(requests, "General Service (not Allied Health)")
        end
    end
    return requests
end

function stap( nsteps=1::Int, x₀=1.0
             ; u=1.09, d=1/1.11, p=.5, step=:multiplicative)
    # Take the requested number of steps.
    for t in 1:nsteps
        if step == :multiplicative
            # Flip a coin and multiply with the up or down delta as appropriate.
            x₀ *= rand(Bernoulli(p)) ? u : d
        elseif step == :additive
            # Flip a coin and add the up or down delta as may be the case.
            x₀ += rand(Bernoulli(p)) ? u : d
        else
            error("Unknown delta option: ", step)
        end
    end
    # Deliver.
    return x₀
end

function walk( T::Int, x₀=1.0
             ; u=1.09, d=1/1.11, p=.5, step=:multiplicative)
    # Record where you start.
    xs = [x₀]
    # Take single `step`s up to T-1.
    for t in 1:T-1
        push!(xs, stap(1, xs[end]; u=u, d=d, p=p, step=step))
    end
    # Deliver.
    return xs
end

