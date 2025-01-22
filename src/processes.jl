using Agents
using Dates, Random, Distributions, StatsBase, DataFrames

const Scenarios = NamedTuple
using DimensionalData
using DimensionalData.Dimensions: label


function simulate!(conductor::Conductor)
    model = initialise(conductor)
    step!( model
         , length(model.epoch:Day(1):model.eschaton) - 1 ) # Up to eschaton.
end

function trace!(conductor::Conductor; fun, nsteps=nothing, dates=false)
    # Make a model.
    model = initialise(conductor)
    # Prepare an array for the output by filling it with zeroeth-step element.
    output = [fun(model)]
    # Likewise for the dates array.
    days = [date(model)]
    # Infer nsteps if necessary.
    if isnothing(nsteps)
        nsteps = length(model.epoch:Day(1):model.eschaton) - 1 # Up to eschaton.
    end
    # Step through the simulation, filling the arrays.
    for t ∈ 1:nsteps
        step!(model)
        push!(days, date(model))
        push!(output, fun(model))
    end
    # Deliver the time series as [outputs] or as ([dates], [outputs]).
    if dates
        return days, outputs
    else
        return output
    end
end

function traces!(model::AgentBasedModel; funs, nsteps=nothing)
    # Prepare arrays for output by filling them with zeroeth-step element.
    outputs = [ [Float64(funs[i](model))] for i in 1:length(funs) ]
    # Likewise for the dates array.
    days = [date(model)]
    # Infer nsteps if necessary.
    if isnothing(nsteps)
        nsteps = length(model.epoch:Day(1):model.eschaton) - 1 # Up to eschaton.
    end
    # Step through the simulation, filling the arrays.
    for t ∈ 1:nsteps
        # One step at a time.
        step!(model)
        # Current model date needs to be written to array only once.
        push!(days, date(model))
        # Obtain the output for each function successively.
        for i in 1:length(funs)
            push!(outputs[i], funs[i](model))
        end
    end
    xs = [ :date=>days
         , [Symbol(funs[i])=>outputs[i] for i in 1:length(funs)]... ]
    # Deliver as DataFrame.
    return DataFrame(xs)
end

function traces!(conductor::Conductor; funs, nsteps=nothing)
    # Make a model.
    model = initialise(conductor)
    # Deliver as DataFrame by calling main `traces!()` function.
    return traces!(model; funs=funs, nsteps=nsteps)
end

function traces!(models::DimArray{AgentBasedModel}; funs, nsteps=nothing)
    # Iterate prudently over the entries in the hypercube.
    for vals in Iterators.product(dims(models)...)
        dimlabels = Symbol.(DimensionalData.Dimensions.label.(dims(models)))
        scenario = NamedTuple{dimlabels}(vals)
        println(scenario)
        # Dict{Symbol, Any} to characterise the scenario of the hypercube entry.
        coordinates = NamedTuple{keys(scenario)}(At.(values(scenario)))
        models[coordinates...] |> println
    end
    println("RWARK!!!")
end

function initialise( context::Context # Constants (settings and parameters).
                   , scenarios::Scenarios # Variable ranges.
                   , seed = nothing
                   )
    # If no seed provided, get the pseudo-randomness from device.
    isnothing(seed) ? seed = rand(RandomDevice(), 0:2^16) : seed
    rng = Xoshiro(seed)
    # Create a 'continuous' space.
    dimensions = ( context |> timeline |> length |> float # For days>dayzero.
                 , 10000.0                                # For $.
                 )
    space = ContinuousSpace(dimensions, spacing=1.0, periodic=false)
    # Set up the model(s) hypercube --- each variable range a named axis.
    A = Array{ABM, length(scenarios)}(undef, length.(values(scenarios)))
    models = DimArray(A, scenarios)
    # Iterate prudently over the entries in the hypercube.
    for vals in Iterators.product(values(scenarios)...)
        # Dict{Symbol, Any} to characterise the scenario of the hypercube entry.
        scenario = Dict(keys(scenarios) .=> vals)
        # Any shared params in `context` and `scenario` uses the _latter_.
        properties = merge(context, scenario)
        # Prepare an `AgentBasedModel` object.
        model = StandardABM( Union{ Client
                                  , Clientele
                                  , Manager
                                  , Provider }
                            , space
                            ; properties
                            , warn = false
                            , agent_step! = step_agent!
                            , model_step! = step_model!
                            , rng )
        # Add clients.
        for i in 1:properties[:nclients]
            # Random day zero in the first three years since simulation start.
            day0 = rand( rng
                        , properties[:epoch]:( properties[:epoch]
                                             + Year(3)
                                             - Day(1) ) )
            state0 = State( [ rand(11)..., .75 + (.5-rand())/2 ] )
            add_agent!( (0.0, 0.0) # Position.
                      , Client # Agent type.
                      , model # To which it should be added.
                      ; vel = (0.0, 0.0)
                      , personalia = Personalia() # Random personalia.
                      , history = [ ( day0, state0) ]
                      , claim = Claim() # Empty claim.
                      )
        end
        # Add clienteles --- portfolios.
        for i in 1:properties[:nportfolios]
            # Add the `Clientele` agent.
            portfolio = add_agent!( (0.0, 0.0) # Position.
                                  , Clientele # Agent type.
                                  , model # To which it should be added.
                                  ; vel = (0.0, 0.0)
                                  )
            # A portfolio is a clientele with just one manager.
            manager = add_agent!( (0.0, 0.0) # Position.
                                , Manager # Agent type.
                                , model # To which it should be added.
                                ; vel = (0.0, 0.0)
                                , capacity = rand(rng, 28:32) # Task capacity.
                                )
            # Add the manager to the portfolio also.
            managers!(portfolio, [manager])
        end
        # Add clienteles --- pools.
        for i in 1:length(properties[:nmanagersperpool])
            # Add the `Clientele` agent.
            pool = add_agent!( (0.0, 0.0) # Position.
                             , Clientele # Agent type.
                             , model
                             ; vel = (0.0, 0.0)
                             ) # To which it should be added.
            # Each pool has at least two managers.
            nmanagers = properties[:nmanagersperpool][i]
            managers = [ add_agent!( (0.0, 0.0) # Position.
                                   , Manager # Agent type.
                                   , model # To which it should be added.
                                   ; vel = (0.0, 0.0)
                                   , capacity = rand(rng, 28:32) # Task capacity
                                   )
                         for i in 1:nmanagers ]
            # Add the managers to the pool also.
            managers!(pool, managers)
        end
        # Add providers.
        providers = Provider[]
        menu = Dict( s => context[:costs][s]
                     for s in context[:alliedhealthservices] )
        for (key, val) in properties[:providerpopulation]
            add_agent!( (0.0, 0.0) # Position.
                      , Provider # Agent type.
                      , model # To which it should be added.
                      ; vel = (0.0, 0.0)
                      , make_provider_template(menu, type=key)... )
        end
        # Push the model into the hypercube at the right spot.
        coordinates = NamedTuple{Tuple(keys(scenario))}(At.(values(scenario)))
        models[coordinates...] = model
    end
    # Deliver.
    return models
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
    agents = model |> allagents |> collect |> values
    return [ agent for agent in agents if typeof(agent) == Clientele ]
end

function clienteles(model::AgentBasedModel; tier=Nothing)
    # Should be overridden and implemented in application specific modules.
    return clienteles(model)
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

function nopenrequests(model::AgentBasedModel)
    # Return number of open requests --- i.e. everything waiting to be queued.
    return sum([ nopen(clientele) for clientele in clienteles(model) ])
end

function nwaiting(model::AgentBasedModel)
    return length([ c for c in clients(model) if iswaiting(c, date(model)) ])
end

function nopenclients(model::AgentBasedModel)
    return length([ c for c in clients(model) if isopen(c, date(model)) ])
end

function qoccupation(model::AgentBasedModel)
    totalcapacity = sum([capacity(c) for c in clienteles(model)])
    totalfree = sum([nfree(c; total=true) for c in clienteles(model)])
    # Deliver fraction of total queue capacity used.
    return (totalcapacity - totalfree) / totalcapacity
end

function satisfaction(model::AgentBasedModel)
    # Return mean satisfaction as a percentage.
    σs = [ satisfaction( client, date(model)
                       ; denialmultiplier = model.denialmultiplier
                       , irksusceptibility = model.irksusceptibility )
          for client in clients(model)
          if isopen(client, date(model)) ]
    # Deliver.
    if isempty(σs)
        return 100.0*mean(σ₀.(clients(model)))
    else
        return 100.0*mean(σs)
    end
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
    types = model.providerpopulation |> keys |> collect
    # Obtain the template of this provider to compare with.
    ptemplate = template(provider)
    # In case there are no matches.
    ptype = nothing
    # Re-construct the allied health service menu of this model.
    menu = Dict( s => model.costs[s]
                 for s in model.alliedhealthservices )
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

function nclients(model::AgentBasedModel)
    return length(clients(model))
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

function cost_cumulative(model::AgentBasedModel)
    return cost(model; cumulative=true)
end

function cost_mediancum(model::AgentBasedModel)
    xs = [ cost(c, model; cumulative=true)
           for c in clients(model)
           if !isempty(events(c)) ]
    if isempty(xs)
        return 0
    else
        return median(xs)
    end
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
    grace = Day(model.graceperiod)
    # Get the probability of approval.
    p = model.approvalrate
    # Get the manager's allocated tasks.
    ts = tasks(manager, model)
    # Get the base number of hours to decision for each service.
    days = model.daystodecision
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
            # If client is allocated and grace period has passed, scrutinise.
            else
                # TODO: Put in deliberation loop.
                # TODO: Make d-loop dependent on the rarity of the request made?
                # Flip a virtual, weighted coin.
                approved = rand(abmrng(model), Bernoulli(p))
                if approved
                    close!(t, today; status=:approved, labour)
                else
                    # More labour for denied requests.
                    labour *= model.denialmultiplier
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

function allocate!(clientele::Clientele, client::Client)
    # Successfull allocation happen if clientele has not reached cap yet.
    if !isatcap(clientele)
        # Do the allocating.
        push!(clientele, client)
        # Deliver the changed clientele for further handling.
        return clientele
    else
        # Return a nothing for easy testing.
        return nothing
    end
end

function allocate!(client::Client, model::AgentBasedModel)
    if model.ntiers == 1
        # If there is just one tier, allocate to arbitrary available clientele.
        availablecs = filter(!isatcap, clienteles(model))
    elseif tier(client, model) == 1 # model.ntiers
        # Bottom tiers go to pools. Find available pools, if any.
        availablecs = filter(!isatcap, pools(model))
    else
        # Higher tiers go to portfolios. Find available portfolios, if any.
        availablecs = filter(!isatcap, portfolios(model))
    end
    # Finally, do the allocation if there is any availability.
    if !isempty(availablecs)
        # Allocate the client to one of the available relevant clienteles.
        clientele = allocate!(rand(abmrng(model), availablecs), client)
        # Make an `Allocation` object and `Event`.
        e = Event(date(model), Allocation(clientele))
        # Add the event to the client's claim.
        push!(client, e)
    else
        clientele = nothing
    end
    # Deliver the changed clientele.
    return clientele
end

function step_client!(client::Client, model::AgentBasedModel)
    # Today's date as per the model's calendar.
    today = date(model)
    # Has this client's time come?
    if τ(client, today) < 0
        return # Client's time has not come yet. Move to next day.
    end
    # Has the client been segmented? If not, do so.
    if !issegmented(client)
        segment!(client, model)
    end
    # Has the client been allocated to a `Clientele`?
    if !isallocated(client)
        # If allocation fails because of no capacity, then clientele == nothing.
        clientele = allocate!(client, model)
    end

    # # Any requests due today from a plan in the client's package?
    # plans = client |> plannedon(date)
    # for plan in plans
        # # TODO: events, feedback = process(client, model; plan=plan)
        # # TODO: Log events and do things with feedback.
    # end

    # Recovery factor starts at unity every day --- rfactors may change it.
    provider_rfactor = 1.0
    # Client on-scheme and on-board. Open events for today's requests, if any.
    for service in requests(client, model)
        # If client has a plan for this service, ignore the request.
        if service in activeplans(client, today)
            # Doing nothing in this branch on purpose.
        # If client has service covered in package, use and update cover.
        elseif service in coveredon(client, today)
            # TODO: Cover requests not used at present.
            # TODO: Set status as :covered and cost = 0 (as cover is paid).
            # TODO: Decrement cover, if applicable.
        # An allied health service request spawns a process with a Provider.
        elseif service ∈ model.alliedhealthservices
            # If this service is already in a plan/package, skip it.
            # Find a random provider who can offer the service.
            ppop = model.providerpopulation
            ptype = sample( abmrng(model)
                          , collect(keys(ppop))
                          , Weights(collect(values(ppop))) )
            provider = filter(p->type(p, model)==ptype , providers(model))[1]
            # Take providers iatrogenics into account.
            provider_rfactor *= rfactor(provider)
            # How many of these services will the client expect to need?
            n = nexpected(client, model; service)
            # Over- or underservice this number as per provider type.
            m = round(Int64, n * sfactor(provider))
            # Maximum number of sessions from the model parameters.
            cap = model.alliedhealthpackagecap
            # Several cases, depending on m.
            if m < 2 # Then just make it a normal service request.
                # This bypasses the provider --- get default price.
                price = model.costs[service]
                # Make a Request with this price.
                r = Request(item=service, cost=price)
                # Put the Service Request in an Event.
                e = Event(today, r)
                # Add open event to client's claim to await allocation on queue.
                push!(client, e)
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
            end
        # Otherwise, open event and await allocation on the relevant queue.
        else
            # Get default price.
            price = model.costs[service]
            # Make a Request with this price.
            r = Request(item=service, cost=price)
            # Put the Service Request in an Event.
            e = Event(today, r)
            # Add open event to client's claim to await allocation on queue.
            push!(client, e)
        end
    end

    # ################################################################### #
    # If this is an as-yet unallocated client, approve all open requests. #
    # ################################################################### #

    if !isallocated(client) # Can also test `isnothing(clientele)`.
        # Get all events of this client that are open requests.
        es = [ e for e ∈ events(client) if typeof(change(e)) == Request
                                        && status(change(e)) == :open ]
        # Compute labour involved from the average #days to decision.
        days = model.daystodecision
        # Close each request and give each event an end date (in the future!).
        for e in es
            r = change(e)
            # How many days to decision on average for this service request?
            ndays = Day(round(Int, days[label(r)]))
            # Compute the labour involved --- TODO: Naive.
            work = ndays.value * 8.0 / 30 # 30 is mean capacity of managers.
            # Update the request with the labour and close it.
            labour!(r, work)
            status!(r, :closed)
            # Set the term (closing) date of the event to today.
            term!(e, today)
        end
    end

    #                  End of approving all open requests                 #
    # ################################################################### #

    # ################################################################### #
    # Recovery and iatrogenics.                                           #
    # ################################################################### #

    # Iatrogenics from client satisfaction.
    σ = satisfaction( client, today
                    ; denialmultiplier = model.denialmultiplier
                    , irksusceptibility = model.irksusceptibility )
    new_p = .5*(σ₀(client) - σ) / σ₀(client) # .5 if no satisfaction - or less.
    # Iatrogenics from allied health provider's rfactor (if applicable).
    new_p *= 2 / (1 + provider_rfactor) # Keeps 0 <= p <= 1.
    # Determine new hazard rate, incorporating iatrogenic factors.
    new_λ = stap( 1                       # One step at a time.
                , λ(client)               # From the current hazard rate.
                , p = new_p               # Hazard rate up when σ goes down.
                )
    # Log this in the client's history.
    update_client!( client, date(model)
                  ; λ=new_λ
                  , σ )

    #                    End of recovery and iatrogenics                  #
    # ################################################################### #

    # Update client's 'position'.
    days = (date(client) - dayzero(client)).value |> float
    geld = minimum([cost(client, cumulative=true)[2][end], 10000])
    position = (days, geld)
    move_agent!(client, position, model)
end

function tier(client::Client, model::AgentBasedModel)
    # How many service levels are there?
    ntiers = model.ntiers
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
        T = model.T # Markov transition matrix.
        tolist = model.tolist # All requestable services.
        marginal = sum(T, dims=1) / size(T)[1] # Sum out `fromlist` dimension.
        index = findfirst(==(service), tolist) # Index of `service` in the list.
        p = marginal[index] # The desired marginal probability of `service`.
        n = round(Int64, N * p) # Probability as frequency.
        return n # Number of requests for `service` expected.
    end
end

function requests(client::Client, model::AgentBasedModel)
    # Get the number of requests for today's hazard rate.
    nrs = nrequests(client, abmrng(model))
    # Obtain the necessary data.
    tolist = model.tolist
    fromlist = model.fromlist
    T = model.T
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
