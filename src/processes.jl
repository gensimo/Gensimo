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
    model = StandardABM( Client
                       ; properties = ps
                       , warn = false
                       , agent_step! = agent_step!
                       , model_step! = model_step! )
    # Add clients.
    for client in clients(conductor)
        add_agent!(client, model)
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
    # Get the number of requests for today's hazard rate.
    n = nrequests(client, model.rng)
    # Write that number as an `Event` for testing.
    client + Event(model.date, n)

    # Each request spawns its own process.
    for i in 1:n
        # 1. Establish what is requested.
        # 2. Identify the relevant liaisons (client, providers, insurers, ...)
        # 3. Spawn process.
    end

    # ####
    # TODO: Something not right here. Sometimes, hazard rate not updated.
    # ####

    # Update the client's hazard rate.
    update_client!(client, model.date, stap(1, (client |> λ)))
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

