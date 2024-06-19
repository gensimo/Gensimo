using Agents, Random, Distributions

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
    println(model.date)
end

function model_step!(model)
    model.date += Day(1)
end

function walk(T::Int, x₀=1.0; u=1.09, d=1/1.11, p=.5, step=:multiplicative)
    xs = [x₀]
    for t in 1:T-1
        if step == :multiplicative
            push!(xs, xs[end] * (rand(Bernoulli(p)) ? u : d) )
        elseif step == :additive
            push!(xs, xs[end] + (rand(Bernoulli(p)) ? u : d) )
        else
            error("Unknown step option: ", step)
        end
    end
    return xs
end
