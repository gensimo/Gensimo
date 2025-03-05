function ntasks(model::AgentBasedModel)
    # Return number of allocated tasks --- i.e. everything in the queues.
    return sum([ ntasks(clientele) for clientele in clienteles(model) ])
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

function allocated(model::AgentBasedModel)
    n = nclients(model)
    nallocated = sum(isallocated.(clients(model)))
    return nallocated/n
end

tracers = [ allocated
          , cost, cost_cumulative, cost_mediancum
          , nactive
          , nclients
          , nevents
          , nopenclients
          , nopenrequests
          , ntasks
          , nwaiting
          , qoccupation
          , satisfaction
          , workload ]
