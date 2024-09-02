using Agents
using Dates, Random, Distributions

function simulate!(conductor::Conductor)
    model = initialise(conductor)
    step!( model
         , length(model.epoch:Day(1):model.eschaton) - 1 ) # Up to eschaton.
end

function initialise( conductor::Conductor
                   , seed = nothing )
    # If no seed provided, get the pseudo-randomness from device.
    isnothing(seed) ? seed = rand(RandomDevice(), 0:2^16) : seed
    rng = Xoshiro(seed)
    # Create a 'continuous' space.
    dimensions = ( conductor |> timeline |> length |> float # For days>dayzero.
                 , 10000.0                                  # For $.
                 )
    space = ContinuousSpace(dimensions, spacing=1.0, periodic=false)
    # Set up the model.
    model = StandardABM( Union{ Client
                              , Clientele
                              , InsuranceWorker
                              , Provider }
                       , space
                       ; properties = conductor
                       , warn = false
                       , agent_step! = step_agent!
                       , model_step! = step_model!
                       , rng )
    # Add clients.
    for client in clients(conductor)
        add_agent_own_pos!(client, model)
    end
    # Set up the insurance organisation.
    for clientele in clienteles(conductor)
        add_agent!(clientele, model)
        for manager in managers(clientele)
            add_agent!(manager, model)
        end
    end
    # Add providers. TODO: This needs to be included in the conductor.
    for p in 1:3
        menu = Dict("Allied Health Service" => 80.0 + randn(abmrng(model)))
        capacity = 5 + rand(abmrng(model), -5:5)
        add_agent!( Provider, model
                  ; vel=(0.0, 0.0), menu=menu, capacity=capacity )
    end
    # Deliver.
    return model
end

function date(model::AgentBasedModel)
    return model.epoch + Day(abmtime(model))
end

function clients(model::AgentBasedModel)
    agents = model |> allagents |> collect |> values
    return [ agent for agent in agents if typeof(agent) == Client ]
end

function clienteles(model::AgentBasedModel)
    return model.clienteles
end

function portfolios(model::AgentBasedModel)
    return [ p for p in clienteles(model) if p |> isportfolio ]
end

function pools(model::AgentBasedModel)
    return [ p for p in clienteles(model) if p |> ispool ]
end

function providers(model::AgentBasedModel)
    agents = model |> allagents |> collect |> values
    return [ agent for agent in agents if typeof(agent) == Provider ]
end

function nevents(model::AgentBasedModel; cumulative=false)
    clientele = clients(model)
    datum = date(model) - Day(1)
    # Count events for each client.
    eventcount = 0
    for client in clientele
        for event in events(client)
            if cumulative
                if date(event) <= datum # Count all events before the datum.
                    eventcount += 1
                end
            else
                if date(event) == datum # Count only events on the datum.
                    eventcount += 1
                end
            end
        end
    end
    # Deliver.
    return eventcount
end

function nactive(model::AgentBasedModel)
    agents = model |> allagents |> collect |> values
    clients = [ agent for agent in agents if typeof(agent) == Client ]
    return sum([ isactive(client, date(model)) for client in clients ])
end

function cost(client::Client, model::AgentBasedModel; cumulative=false)
    datum = date(model) - Day(1)
    totalcost = 0
    for event in events(client)
        if cumulative
            if date(event) <= datum # Count all events before the datum.
                totalcost += cost(event)
            end
        else
            if date(event) == datum # Count only events on the datum.
                totalcost += cost(event)
            end
        end
    end
    # Deliver.
    return totalcost
end

function cost(model::AgentBasedModel; cumulative=false)
    clientele = clients(model)
    datum = date(model) - Day(1)
    # Count events for each client.
    totalcost = 0
    for client in clientele
        totalcost += cost(client, model; cumulative=cumulative)
    end
    # Deliver.
    return totalcost
end

function workload(model::AgentBasedModel; cumulative=false)
    datum = date(model) - Day(1) # ABM time gets updated _after_ clients.
    return sum([ workload(client, datum; cumulative=cumulative)
                 for client in clients(model) ])
end

function position(client::Client, model::AgentBasedModel)
    days = (date(client) - dayzero(client)).value |> float
    geld = minimum([cost(client, model; cumulative=true), 10000.0])
    return (days, geld)
end

function step_agent!(agent, model)
    if agent isa Client
        step_client!(agent, model)
    end
end

function step_model!(model) end

function step_client!(client::Client, model::AgentBasedModel)
    # Today's date as per the model's calendar.
    today = date(model)
    # Has this client's time come?
    if τ(client, today) < 0
        return # Client's time has not come yet. Move to next day.
    end
    # Has the client been onboarded?
    if !isonscheme(client) # TODO: See `onscheme()` function.
        # 1. Segmentation.
        segment!(client, model)
        # 2. Allocation to Clientele, i.e. add to pool or portfolio.
        if tier(client, model) == model.context[:ntiers]
            # If in highest tier, add to a random portfolio.
            push!(rand(abmrng(model), portfolios(model)), client)
        else
            # Otherwise, add to a random pool.
            push!(rand(abmrng(model), pools(model)), client)
        end
    end
    # # Any requests due today from a plan in the client's package?
    # plans = client |> planned(date)
    # for plan in plans
        # # TODO: events, feedback = process(client, model; plan=plan)
        # # TODO: Log events and do things with feedback.
    # end

    # Client on-scheme and on-board. Open events for today's requests, if any.
    for service in requests(client, model)
        e = Event(date(model), Request(service))
        push!(client, e)
    end
        # TODO: event, feedback = process(client, model; request=service)
        # TODO: Log events and do things with feedback.

    # # Client's requests are processed. Add events to claim and use feedback.
    # for event in events # Adding events from processed requests, if any.
        # client += event
    # end
    # if feedback |> !isnothing # Make use of feedback, if any.
        # # Adjust the request timing and volume (hazard rate).
        # new_λ = stap( 1, λ(client)
                    # ; u = feedback.uptick
                    # , d = feedback.downtick
                    # , p = feedback.probability )
        # update_client!(client, date(model), new_λ)
        # # Adjust the probabilities for the kind of next service requested.
        # # TODO: Adjust the Markov Chain or distributions in the `Context`.
    # end
end

function tier(client::Client, model::AgentBasedModel)
    # How many service levels are there?
    ntiers = model.context[:ntiers]
    # What level is appropriate for this client? Tiers evenly spread.
    h = hazard(client) # Hazard level, mean of ϕ and ψ --- between 0 and 1.
    tier = 1 # Corresponding to h == 1.
    # Loop until appropriate level found.
    while h < 1 - tier / ntiers
        tier += 1
    end
    # Deliver.
    return tier
end

function segment!(client::Client, model::AgentBasedModel)
    # Assess the tier.
    t = tier(client, model)
    # Make a Segment object.
    s = Segment(t, "Service Level $t")
    # Put it in a segmentation Event.
    e = Event(date(model), s)
    # Add the segmentation event to the client's claim.
    push!(client, e)
end

function process( client, model
                ; request = nothing # Processing either a request ...
                , plan = nothing    # ... or a plan.
                )
    if request |> !isnothing
        return process_request(client, model, request) # -> (event, feedback)
    end
    if plan |> !isnothing
        return process_plan(client, model, request) # -> (event, feedback)
    end
end

function process_request(client::Client, model::AgentBasedModel; request)
    if iscovered(client, request, date(model))
        return process_cover(client, model, request)
    end

    acceptance_probability = .8 # TODO: Obvs not hard code, make model prop.

    cost = 50.0 + 50 * rand(abmrng(model))
    if rand(abmrng(model), Bernoulli(acceptance_probability))
        request = Request(request, cost, 0.0, true) # Request approved.
    else
        request = Request(request, cost, 0.0, false) # Request denied.
    end
    event = Event(date(model), request)
    return events, feedback
end

function process_cover(client::Client, model::AgentBasedModel; request)
    # Find the package with the cover for this service request.
    p = coveredin(client, request, date(model), allpackages=false)
    # Decrement the cover by one unit.
    cover(p)[request] -= 1
    # Return an `Event` with zero cost.
    return Event(date(model), Request(request, 0.0, 0.0, :approved))
end

function process_plan(client::Client, model::AgentBasedModel; request)
    # All there is to do is return an `Event` with zero cost.
    return Event(date(model), Request(request, 0.0, 0.0, :approved))
end

function _step_client!(client::Client, model::AgentBasedModel)
    # Get the requests for today's hazard rate and deal with them sequentially.
    for request in _requests(client, model)
        # Is the request for an allied health service?
        if request == "Allied Health Service"
            # Spawn the relevant process.
            request_liaising!(client, model, request=request)
        else
            # Spawn the relevant process.
            request_simple!(client, model, request=request)
        end
    end
    # Update the client's hazard rate.
    move_agent!(client, position(client, model), model)
    update_client!(client, date(model), stap(1, (client |> λ)))
end

function request_simple!( client::Client, model::AgentBasedModel
                        ; request )
    # Write up the `Request` with a random cost.
    cost = 50.0 + 50 * rand(abmrng(model))
    request = Request(request, cost, 0.0, :approved)
    # Make it an `Event`.
    event = Event(date(model), request)
    # Add the event to the client's `Claim`.
    push!(client, event)
end

function request_liaising!( client::Client, model::AgentBasedModel
                          ; request )
    # Select a provider --- randomly, for now.
    provider = random_agent(model, agent->typeof(agent)==Provider)
    # Write up the `Request`.
    request = Request(request, provider[request], 0.0, :approved)
    # Make it an `Event`.
    event = Event(date(model), request)
    # Add the event to the client's `Claim`.
    push!(client, event)
end

function _requests(client::Client, model::AgentBasedModel)
    # Get the number of requests for today's hazard rate.
    n = nrequests(client, abmrng(model))
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

function next_request(client::Client, model::AgentBasedModel)
    # Get the necessary data.
    tolist = model.context.request_distros["tolist"]
    fromlist = model.context.request_distros["fromlist"]
    T = model.context.request_distros["T"]
    # Deduce order of Markov Chain.
    if fromlist[1] isa Tuple
        order = length(fromlist[1])
    else
        order = 1
    end
    # Get order-length tail of request sequence.
    rs = label.(requests(client))
    # Fill the from Tuple with the corresponding requests --- if any.
    n = minimum([order, length(rs)])
    from = Tuple(i <= n ? rs[end - (i-1)] : nothing for i ∈ reverse(1:order))
    # If the order is one, no need to wrap from in a Tuple.
    if length(from) == 1
        from = from[1]
    end
    # Turn from into an integer index.
    i = findfirst(==(from), fromlist)
    # Get the probability distribution.
    ps = Distributions.Categorical(T[i, :])
    # Draw from the probability distribution.
    j = rand(abmrng(model), ps)
    # Deliver.
    return tolist[j]
end

function requests(client::Client, model::AgentBasedModel)
    # Get the number of requests for today's hazard rate.
    nrs = nrequests(client, abmrng(model))
    # Obtain the necessary data.
    tolist = model.context[:tolist]
    fromlist = model.context[:fromlist]
    T = model.context[:T]
    # Deduce order of Markov Chain.
    if fromlist[1] isa Tuple
        order = length(fromlist[1])
    else
        order = 1
    end
    # Get order-length tail of request sequence.
    rs = label.(requests(client))
    for r ∈ 1:nrs
        # Fill the from Tuple with the corresponding requests --- if any.
        n = minimum([order, length(rs)])
        from = Tuple( i <= n ? rs[end - (i-1)] : nothing
                      for i ∈ reverse(1:order) )
        # If the order is one, no need to wrap from in a Tuple.
        if length(from) == 1
            from = from[1]
        end
        # Turn from into an integer index.
        i = findfirst(==(from), fromlist)
        # Get the probability distribution.
        ps = Distributions.Categorical(T[i, :])
        # Draw from the probability distribution.
        j = rand(abmrng(model), ps)
        # Append the new request to the request list.
        push!(rs, tolist[j])
    end
    # Deliver.
    return last(rs, nrs)
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

