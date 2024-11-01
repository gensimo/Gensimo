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
                              , Manager
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
    for clientele in clienteles(conductor) # Pools and portfolio environments.
        add_agent!(clientele, model)
        for manager in managers(clientele) # And their managers.
            add_agent!(manager, model)
        end
    end
    # Add providers.
    for provider in providers(conductor)
        add_agent!(provider, model)
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

function clientele(manager::Manager, model::AgentBasedModel)
    for clientele in clienteles(model)
        for manager′ in managers(clientele)
            if manager′ == manager
                return clientele
            end
        end
    end
end

function tasks(manager::Manager, model::AgentBasedModel)
    return allocations(clientele(manager, model))[manager]
end

function ntasks(clientele::Clientele)
    # Return number of allocated tasks --- i.e. everything in the queues.
    return sum([ length(allocations(clientele)[manager])
                 for manager in managers(clientele) ])
end

function ntasks(model::AgentBasedModel)
    # Return number of allocated tasks --- i.e. everything in the queues.
    return sum([ ntasks(clientele) for clientele in clienteles(model) ])
end

function nopen(clientele::Clientele)
    # Return number of open requests --- i.e. everything waiting to be queued.
    if isempty(clients(clientele))
        return 0
    else
        return sum([ length(requests(client; status=:open))
                     for client in clientele ])
    end
end

function nopen(model::AgentBasedModel)
    # Return number of open requests --- i.e. everything waiting to be queued.
    return sum([ nopen(clientele) for clientele in clienteles(model) ])
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

function managers(model::AgentBasedModel)
    agents = model |> allagents |> collect |> values
    return [ agent for agent in agents if typeof(agent) == Manager ]
end

function type(provider::Provider, model::AgentBasedModel)
    # Get all the available provider types in this model.
    types = model.context[:providerpopulation] |> keys |> collect
    # Obtain the template of this provider to compare with.
    ptemplate = template(provider)
    # In case there are no matches.
    ptype = nothing
    # Re-construct the allied health service menu of this model.
    menu = Dict( s => model.context[:costs][s]
                 for s in model.context[:alliedhealthservices] )
    # Compare provider template against available types.
    for type in types
        if ptemplate == make_provider_template(menu; type)
            ptype = type # Found!
        end
    end
    # Deliver.
    return ptype
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

function provides(model::AgentBasedModel, service::String)
    return [ provider for provider in providers(model)
                      if provides(provider, service) ]
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
    # Client step --- requests etc.
    if agent isa Client
        step_client!(agent, model)
    end
    # Clientele step --- task allocation.
    if agent isa Clientele
        step_clientele!(agent, model)
    end
    # Manager step --- processing requests.
    if agent isa Manager
        step_manager!(agent, model)
    end
    # Provider step --- nothing yet.
    if agent isa Provider
        step_provider!(agent, model)
    end
end

function step_model!(model) end

function step_provider!(provider::Provider, model::AgentBasedModel) end

function step_manager!(manager::Manager, model::AgentBasedModel)
    # Today's date as per the model's calendar.
    today = date(model)
    # Get the number of days grace period.
    grace = Day(model.context[:graceperiod])
    # Get the probability of approval.
    p = model.context[:approvalrate]
    # Get the manager's allocated tasks.
    ts = tasks(manager, model)
    # Get the base number of hours to decision for each service.
    days = model.context[:daystodecision]
    # For each task, check if it is overdue and process it accordingly.
    for t in ts
        # How many days to decision on average for this service request?
        ndays = Day(round(Int, days[label(request(t))]))
        # Waiting. Counting from allocation, which is later than request date.
        ndayswaiting = today - allocatedon(t)
        # Compute the labour involved --- TODO: Naive.
        labour = ndays.value * 8.0 / capacity(manager)
        # Wait with processing until ndays --- request takes _at least_ ndays.
        if ndayswaiting >= ndays
            # If _requested_ within grace period, just approve.
            if requestedon(t) - dayzero(client(t)) <= grace
                # Approve, log in event, request and clear from task list.
                close!(t, today; status=:approved, labour)
            else
                # TODO: Put in deliberation loop.
                # TODO: Make d-loop dependent on the rarity of the request made?
                # Flip a virtual, weighted coin.
                approved = rand(abmrng(model), Bernoulli(p))
                if approved
                    close!(t, today; status=:approved, labour)
                else
                    # More labour for denied requests.
                    labour *= model.context[:denialmultiplier]
                    close!(t, today; status=:denied, labour)
                end
            end
        end
    end
end

function step_clientele!(clientele::Clientele, model::AgentBasedModel)
    # Make chronologically ordered tasklist, oldest first.
    ts = tasks(clientele)
    # Keep allocating tasks to random managers with capacity.
    while anyfree(clientele) && !isempty(ts)
        # Select a random manager with free slots to allocate to.
        manager = rand(abmrng(model), freemanagers(clientele))
        # Allocate the task to the manager.
        allocate!(clientele, manager => popfirst!(ts), date(model))
    end
end

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
    # plans = client |> plannedon(date)
    # for plan in plans
        # # TODO: events, feedback = process(client, model; plan=plan)
        # # TODO: Log events and do things with feedback.
    # end

    # Client on-scheme and on-board. Open events for today's requests, if any.
    for service in requests(client, model)
        bad = false
        # If client has a plan for this service, ignore the request.
        if service in activeplans(client, today)
            println(service)
            println("THIS SERVICE IS IN AN ACTIVE PLAN ALREADY.")
            bad = true
        # If client has service covered in package, use and update cover.
        elseif service in coveredon(client, today)
            # TODO: Cover requests not used at present.
            # TODO: Set status as :covered and cost = 0 (as cover is paid).
            # TODO: Decrement cover, if applicable.
        # An allied health service request spawns a process with a Provider.
        elseif service ∈ model.context[:alliedhealthservices]
            if bad
                println("BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD")
            end
            # If this service is already in a plan/package, skip it.
            # Find a random provider who can offer the service.
            ppop = model.context[:providerpopulation]
            ptype = sample( abmrng(model)
                          , collect(keys(ppop))
                          , Weights(collect(values(ppop))) )
            provider = filter(p->type(p, model)==ptype , providers(model))[1]
            # How many of these services will the client expect to need?
            n = nexpected(client, model; service)
            # Over- or underservice this number as per provider type.
            m = round(Int64, n * sfactor(provider))
            # Maximum number of sessions from the model parameters.
            cap = model.context[:alliedhealthpackagecap]
            # Several cases, depending on m.
            if m < 2 # Then just make it a normal service request.
                # This bypasses the provider --- get default price.
                price = model.context[:costs][service]
                # Make a Request with this price.
                r = Request(item=service, cost=price)
                # Put the Service Request in an Event.
                e = Event(today, r)
                # Add open event to client's claim to await allocation on queue.
                push!(client, e)
                println(e)
            elseif m < cap # Package size m.
                # Wrap the service in a Plan.
                plan = Plan(service, today+Day(1), Week(1), m)
                # Provider provides price for plan.
                price = m * provider[service]
                # Make a Request with this price.
                r = Request(item=plan, cost=price)
                # Put the Service Request in an Event.
                e = Event(today, r)
                # Add open event to client's claim to await allocation on queue.
                push!(client, e)
                println(e)
            else # Package cap or more expected --- give package of size cap.
                # Wrap the service in a Plan.
                plan = Plan(service, today+Day(1), Week(1), cap)
                # Provider provides price for plan.
                price = cap * provider[service]
                # Make a Request with this price.
                r = Request(item=plan, cost=price)
                # Put the Service Request in an Event.
                e = Event(today, r)
                # Add open event to client's claim to await allocation on queue.
                push!(client, e)
                println(e)
            end
        # Otherwise, open event and await allocation on the relevant queue.
        else
            # Get default price.
            price = model.context[:costs][service]
            # Make a Request with this price.
            r = Request(item=service, cost=price)
            # Put the Service Request in an Event.
            e = Event(today, r)
            # Add open event to client's claim to await allocation on queue.
            push!(client, e)
            println(e)
        end
    end

    # Recovery and iatrogenics. For now, just binomial options style recovery.
    # TODO: Improve.
    new_λ = stap( 1, λ(client) )
                # ; u = feedback.uptick
                # , d = feedback.downtick
                # , p = feedback.probability
    update_client!(client, date(model), new_λ)
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

function nexpected(client::Client, model::AgentBasedModel; service=nothing)
    # Get current hazard rate.
    lambda = λ(client)
    # Compute total expected number of service requests --- quick Monte Carlo.
    N = [ sum(lambda * walk(100 * 365)) for i ∈ 1:1000 ] |> mean
    # Deliver total expected requests or just those for `service`.
    if isnothing(service)
        return round(Int64, N) # Total number of requests expected.
    else
        # Compute expected number of requests for `service` given client's λ.
        T = model.context[:T] # Markov transition matrix.
        tolist = model.context[:tolist] # All requestable services.
        marginal = sum(T, dims=1) / size(T)[1] # Sum out `fromlist` dimension.
        index = findfirst(==(service), tolist) # Index of `service` in the list.
        p = marginal[index] # The desired marginal probability of `service`.
        n = round(Int64, N * p) # Probability as frequency.
        return n # Number of requests for `service` expected.
    end
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
    # Add nrs requests to the rs list.
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

