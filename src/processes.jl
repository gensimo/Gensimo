using Agents

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
