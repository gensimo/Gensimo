using DataFrames, Distributions, StatsBase, Dates, Random
using DataStructures: OrderedDict


function events(from_date, to_date, lambda)
    # Get a list of the dates under consideration.
    dates = from_date:Day(1):to_date
    # Get the overall intensity for the period.
    Λ = length(dates)*lambda
    # Get the number of events from the corresponding Poisson distribution.
    nevents = rand(Poisson(Λ))
    # Sample the events uniformly and without replacement from the dates.
    # TODO: This can return an empty list.
    events = sample(dates, nevents; replace=false)
    # Deliver as a sorted list.
    return sort(events)
end

function request_cost( client::Client # The client, including health state(s).
                     , date::Date # At which request is placed.
                     , β=.01 # Decay rate, defaults to ~37% in 100 days.
                     , basecost=10.0 # Number of dollars.
                     , rng=nothing # Pseudo random number generator.
                     )
    # If not provided, get the pseudo-randomness from device.
    isnothing(rng) ? rng = RandomDevice() : rng
    # Deliver.
    return basecost * n(dτ(client, date), λ(client), β, rng)
end

request_cost(client, base=100.0, rng=nothing) = base*nrequests(client, rng)

const Context = Dict{Symbol, Any}
distros(context::Context) = context[:distros]
timeline(context::Context) = context[:epoch]:Day(1):context[:eschaton]

const Scenario = Dict{Symbol, Any}

@kwdef mutable struct Conductor
    context::Context = Context() # Model parameters.
    epoch::Date = Date(2020)     # Initial date.
    eschaton::Date = Date(2021)  # Final date.
    clients::Vector{Client} = Client[]  # The client cohort.
    clienteles::Vector{Clientele} = Clientele[] # The organisational structure.
    providers::Vector{Provider} = Provider[] # External health care providers.
end

# Accessors.
context(c::Conductor) = c.context
epoch(c::Conductor) = c.epoch
eschaton(c::Conductor) = c.eschaton
clients(c::Conductor) = c.clients
clienteles(c::Conductor) = c.clienteles
providers(c::Conductor) = c.providers

# Derivative accessors.
agents(c::Conductor) = [clients(c)... , insurers(c)... , providers(c)...]
nagents(c::Conductor) = length(agents(c))
nclients(c::Conductor) = c |> clients |> length
nclienteles(c::Conductor) = c |> clienteles |> length
nmanagers(c::Conductor) = sum([ length(managers(c)) for p in clienteles(c) ])
nproviders(c::Conductor) = c |> providers |> length
timeline(c::Conductor) = collect(epoch(c):Day(1):eschaton(c))

function Conductor( context::Context
                  , epoch::Date, eschaton::Date
                  , nclients::Integer=1
                  ; cohort=:uniform # or :uniform.
                  )
    # Convenience inner function to mass-produce Client agents.
    function makeclients(dates, n)
        return [ Client( id=i, pos=(0.0, 0.0), vel=(0.0, 0.0)
                       , personalia = Personalia()
                       , history = [ (rand(dates), State(rand(12))) ]
                       , claim = Claim() )
                 for i ∈ 1:n ]
    end
    # Create random clients according to cohort setting.
    if cohort == :firstyear # All clients have day zero in first year.
        dates = epoch:Day(1):epoch+Year(1)
        clients = makeclients(dates, nclients)
    elseif cohort == :firstday
        clients = [ Client( id=i, pos=(0.0, 0.0), vel=(0.0, 0.0)
                       , personalia = Personalia()
                       , history = [ (epoch, State([.1, .1, rand(10)...])) ]
                       , claim = Claim() )
                    for i ∈ 1:nclients ]
    elseif cohort == :uniform # Clients have days zeros anywhere in timeline.
        dates = epoch:Day(1):eschaton
        clients = makeclients(dates, nclients)
    else # Default to :uniform cohort setting.
        dates = epoch:Day(1):eschaton
        clients = makeclients(dates, nclients)
    end
    # Instantiate and deliver the object.
    return Conductor( context=context
                    , epoch=epoch, eschaton=eschaton
                    , clients=clients )
end

function Conductor( context::Context
                  , eschaton::Date # End-date only --- initial date inferred.
                  , clients::Vector{Client} )
    # Collect and sort all `dayzero`es of the clients.
    zerodays = [dayzero(client) for client ∈ clients] |> sort
    # Start the simulation on the first zero day.
    epoch = zerodays[1]
    # End of simulation needs to be later than all zero days.
    if zerodays[end] < eschaton
        return Conductor( context=context
                        , epoch=epoch, eschaton=eschaton
                        , clients=clients )
    else
        error("At least one client has zero day at or after end of simulation.")
    end
end

function Conductor( epoch::Date, eschaton::Date
                  , nclients::Integer=1
                  ; cohort=:uniform )
    return Conductor(Context(), epoch, eschaton, nclients, cohort=cohort)
end

function Conductor( context            # Model parameters.
                  ; epoch, eschaton    # First and last day of simulation.
                  , nclients           # Number of clients.
                  , nportfolios        # Number of portfolios (each 1 manager).
                  , nmanagersperpool   # List: number of managers for each pool.
                  , providerpopulation # Dict{Symbol, Float64}: type=>frequency.
                  )
    # Number of pools.
    npools = length(nmanagersperpool)
    # Keep track of the agent IDs.
    index = 0
    # Generate the clients
    clients = [ Client( id=i, pos=(0.0, 0.0), vel=(0.0, 0.0)
                      , personalia = Personalia()
                      , history = [ ( rand(epoch:epoch+Year(3)-Day(1))
                                     , State( [ rand(11)...
                                              , .75 + (.5-rand())/2 ] )) ]
                      , claim = Claim() )
                for i ∈ 1:nclients ]
    # Update index.
    index += nclients
    # Generate the portfolios.
    portfolios = [ Clientele(id=index+i, pos=(0.0, 0.0), vel=(0.0, 0.0))
                   for i in 1:nportfolios ]
    # Update index with number of Clientele agents.
    index += nportfolios
    # One manager per portfolio.
    for portfolio in portfolios
        index += 1 # Update index for each manager also.
        managers!( portfolio
                 , [ Manager(index, (0, 0), (0, 0), rand(28:32)) ])
    end
    pools = [ Clientele(id=index+i, pos=(0.0, 0.0), vel=(0.0, 0.0))
              for i in 1:npools ]
    # Update index with number of Clientele agents.
    index += npools
    # Several managers per pool --- given by `nmanagersperpool` list.
    for (n, pool) in enumerate(pools)
        managers!(pool, [ Manager(index+i, (0, 0), (0, 0), rand(28:32))
                          for i in 1:nmanagersperpool[n] ])
        # Update index with number of managers in this pool.
        index += nmanagersperpool[n]
    end
    providers = Provider[]
    menu = Dict(s=>context[:costs][s] for s in context[:alliedhealthservices])
    for (i, (key, val)) in enumerate(providerpopulation)
        kw_post = make_provider_template(menu, type=key)
        kw_pre = (id=index+i, pos=(0.0, 0.0), vel=(0.0, 0.0))
        push!(providers, Provider(kw_pre..., kw_post...))
        index += 1 # Update the index.
    end
    context[:providerpopulation] = providerpopulation
    return Conductor(; context, epoch, eschaton
                    , clients
                    , clienteles = [ pools..., portfolios... ]
                    , providers )
end

function provides(conductor::Conductor, service::String)
    return [ provider for provider in providers(conductor)
                      if provides(provider, service) ]
end

function nactive(conductor::Conductor, date::Date; tier=:ignore)
    if tier==:ignore
        return sum([ isactive(client, date) for client in clients(conductor) ])
    else
        return sum([ isactive(client, date) for client in clients(conductor)
                     if Gensimo.tier(client) == tier ])
    end
end

function nonscheme(conductor::Conductor, date::Date; tier=:ignore)
    if tier==:ignore
        return sum([ isonscheme(client, date) for client in clients(conductor)])
    else
        return sum([ isonscheme(client, date) for client in clients(conductor)
                     if Gensimo.tier(client) == tier ])
    end
end

function nactive(conductor::Conductor; tier=:ignore)
    return ( timeline(conductor)
           , (date->nactive(conductor, date, tier=tier)).(timeline(conductor)) )
end

function workload(conductor::Conductor; tier=:ignore)
    dateses = []
    hourses = []
    for client in clients(conductor)
        if tier != :ignore
            if Gensimo.tier(client) == tier
                dates, hours = workload(client)
                append!(dateses, dates)
                append!(hourses, hours)
            end
        else
            dates, hours = workload(client)
            append!(dateses, dates)
            append!(hourses, hours)
        end
    end
    df = sort(DataFrame(date=dateses, hours=hourses), :date)
    gdf = combine(groupby(df, :date), :hours => sum)
    return Vector{Date}(gdf.date), gdf.hours_sum
end

function workload_average(conductor::Conductor)
    dateses = []
    hourses = []
    n = nclients(conductor)
    for client in clients(conductor)
        dates, hours = workload(client)
        if !isempty(dates)
            firstdate = minimum(dates)
            dates = Dates.epochdays2date.(Dates.value.(dates - firstdate))
            append!(dateses, dates)
            append!(hourses, hours)
        end
    end
    hourses /= n
    df = sort(DataFrame(date=dateses, hours=hourses), :date)
    gdf = combine(groupby(df, :date), :hours => sum)
    return Vector{Date}(gdf.date), gdf.hours_sum
end

function cost(conductor::Conductor; cumulative=false)
    dateses = []
    dollarses = []
    for client in clients(conductor)
        dates, dollars = cost(client)
        append!(dateses, dates)
        append!(dollarses, dollars)
    end
    df = sort(DataFrame(date=dateses, cost=dollarses), :date)
    gdf = combine(groupby(df, :date), :cost => sum)
    costs = cumulative ? cumsum(gdf.cost_sum) : gdf.cost_sum
    return Vector{Date}(gdf.date), costs
end

function cost_average(conductor::Conductor; cumulative=false)
    dateses = []
    dollarses = []
    n = nclients(conductor)
    for client in clients(conductor)
        dates, dollars = cost(client)
        if !isempty(dates)
            firstdate = minimum(dates)
            dates = Dates.epochdays2date.(Dates.value.(dates - firstdate))
            append!(dateses, dates)
            append!(dollarses, dollars)
        end
    end
    dollarses /= n
    df = sort(DataFrame(date=dateses, cost=dollarses), :date)
    gdf = combine(groupby(df, :date), :cost => sum)
    costs = cumulative ? cumsum(gdf.cost_sum) : gdf.cost_sum
    return Vector{Date}(gdf.date), costs
end

function statistics(conductor::Conductor)
    ncs = conductor |> nclients
    simulation_window = (conductor |> epoch, conductor |> eschaton)
    first_dayzero = sort(dayzero.(clients(conductor)))[1]
    last_event = sort(date.(conductor |> clients))[end]
    event_window = (first_dayzero, last_event)
    # Deliver the statistics as a named tuple.
    return ( nclients = ncs
           , simulation_window = simulation_window
           , event_window = event_window
           )
end

function client(request::Request, conductor::Conductor)
    cs = []
    for client in clients(conductor)
        for event in client |> events
            if request == change(event)
                push!(cs, client)
            end
        end
    end
    if length(cs) == 0
        return nothing
    elseif length(cs) == 1
        return cs[1]
    else
        return cs
    end
end

function event(request::Request, conductor::Conductor)
    es = []
    for client in clients(conductor)
        for event in client |> events
            if request == change(event)
                push!(es, event)
            end
        end
    end
    if length(es) == 0
        return nothing
    elseif length(es) == 1
        return es[1]
    else
        return es
    end
end

function costseriesplot(conductor; cases=nothing, layout=:ensemble)
    # Use appropriate back-end function.
    layout == :ensemble &&
        begin
            return costseriesplot_ensemble(conductor, cases=cases)
        end
    layout == :tiled &&
        begin
            return costseriesplot_tiled(conductor, cases=cases)
        end
end

function costseriesplot_ensemble(conductor; cases=nothing)
    # Use a decent Garamond for the plot.
    settheme!()
    # Obtain Figure and Axis objects.
    fig = Figure()
    ax = Axis( fig[1, 1]
             , ylabel="cumulative cost [ \$ ]" )
    # If cases are provided, use only those, if not, use them all.
    if isnothing(cases)
        cases = conductor.cases
    end
    # Iterate over cases to add series to axis.
    for case in cases
        # Collect dates and cost lists for this case from the Conductor object.
        dates = collect(keys(conductor.histories[case]))
        costs = cost.(collect(values(conductor.histories[case])))
        # Convert dates to integers, i.e. days since rounding epoch.
        days = Dates.date2epochdays.(dates)
        # Plot against those integers.
        scatterlines!(ax, days, costs, color=:black)
    end
    # Get the tick marks so there are 11 ticks on the horizontal axis.
    ndays_epoch = Dates.date2epochdays(conductor.epoch)
    ndays_eschaton = Dates.date2epochdays(conductor.eschaton)
    step = floor((ndays_eschaton - ndays_epoch) / 10)
    days = ndays_epoch:step:ndays_eschaton
    dates = Dates.epochdays2date.(days)
    # Then put the dates in place of those integers.
    ax.xticks = (days, string.(dates))
    # Quarter π rotation to avoid clutter.
    ax.xticklabelrotation = π/4
    # Show me what you got.
    display(fig)
    # Deliver.
    return fig, ax
end

function costseriesplot_tiled(conductor; cases=nothing)
    # Use a decent Garamond for the plot.
    settheme!()
    # Obtain Figure object.
    fig = Figure()
    axes = []
    plt = nothing # Just so it is there to be assigned to in the loop below.
    # If cases are provided, use only those, if not, use them all.
    if isnothing(cases)
        cases = conductor.cases
    end
    # Add axes for each Case.
    for (i, case) in enumerate(cases)
        # Make plots appear as rows.
        ax = Axis( fig[i, 1]
                 , xlabel=""
                 , ylabel="cumulative cost [ \$ ]" )
        # Link the axes, so they have the same scale.
        if i > 1
            linkxaxes!(axes[1], ax)
            linkyaxes!(axes[1], ax)
        end
        # Collect dates and cost lists for this case from the Conductor object.
        dates = collect(keys(conductor.histories[case]))
        costs = cost.(collect(values(conductor.histories[case])))
        # Convert dates to integers, i.e. days since rounding epoch.
        days = Dates.date2epochdays.(dates)
        # Plot against those integers.
        plt = scatterlines!(ax, days, costs, color=:black)
        # Then put the dates in place of those integers.
        ax.xticks = (days, string.(dates))
        # Quarter π rotation to avoid clutter.
        ax.xticklabelrotation = π/4
        # Add this Axis to the list.
        push!(axes, ax)
    end
    # Show me what you got.
    display(fig)
    # Deliver.
    return fig, axes, plt
end

function nactiveplot( conductor::Conductor
                    ; tiers=[1, 2, 3]
                    , percentages=false
                    , title=""
                    , xlabel=""
                    , ylabel="Number of active clients [#]"
                    , maxdates=20 )
    # Use a decent Garamond for the plot.
    settheme!()
    # Obtain fig and ax objects.
    fig = Figure()
    ax = Axis( fig[1, 1]
             , xlabel=xlabel
             , ylabel=xlabel
             , title=title )
    # Get the dates.
    dates = timeline(conductor)
    # Get the values for each tier.
    valueses = Dict()
    for tier in tiers
        valueses[tier] = nactive(conductor, tier=tier)[2]
    end
    total = nactive(conductor)[2]
    valueses[:total] = total
    # Convert to percentages of :total if desired.
    if percentages
        for (key, val) in valueses
            valueses[key] = val ./ total # TODO: Deal with NaNs better here.
        end
    end
    # Convert dates to integers, i.e. days since rounding epoch.
    days = Dates.date2epochdays.(dates)
    # Plot against those integers. Put labels if provided.
    plots = []
    for tier in tiers
        push!(plots, scatterlines!(ax, days, valueses[tier]))
    end
    push!(plots, scatterlines!(ax, days, valueses[:total]))
    legend = fig[1, end+1] = Legend( fig
                                   , plots
                                   , [(string.(tiers))..., "Total"] )
    # Duplicates are unnecessary and may trigger Makie bug.
    days = days |> unique
    dates = dates |> unique
    # Too many dates clutter the horizontal axis.
    if length(days) > maxdates
        ndays = days[1]:days[end] |> length # All days, superset of `days`.
        step = round(Integer, ndays / maxdates)
        lastday = days[end]
        days = days[1]:step:days[end] |> collect
        if !(lastday in days)
            push!(days, lastday)
        end
        lastdate = dates[end]
        dates = dates[1]:Day(step):dates[end] |> collect
        if !(lastdate in dates)
            push!(dates, lastdate)
        end
    end
    # Then put the dates in place of integers.
    ax.xticks = (days, string.(dates))
    # Quarter π rotation to avoid clutter.
    ax.xticklabelrotation = π/4
    # Show me what you got.
    display(fig)
    # Deliver.
    return valueses# fig, ax, plt
end

function clientplot(client::Client)
    # Use a decent Garamond for the plot.
    settheme!()
    # Obtain dates and values of the client's history.
    days_ϕψσ = client |> dates
    vals_ϕ = map(t->t[1], client |> states)
    vals_ψ = map(t->t[2], client |> states)
    vals_σ = map(t->t[12], client |> states)
    vals_cost = cost.(client |> events) |> cumsum
    vals_labour = labour.(client |> events) |> cumsum
    days_cl = date.(client |> events)
    dateses = [ days_ϕψσ, days_ϕψσ, days_ϕψσ# For ϕ, ψ and σ.
              , days_cl, days_cl ] # For cost and labour.
    return datesplots( dateses
                     , [ vals_ϕ
                       , vals_ψ
                       , vals_σ
                       , vals_cost
                       , vals_labour ]
                     , ylabels=[ "ϕ [%]"
                               , "ψ [%]"
                               , "σ [%]"
                               , "Cumulative cost [\$]"
                               , "Cumulative workload [hours/day]" ]
                     , ylimses=[ (0, 1)
                               , (0, 1)
                               , (0, 1)
                               , nothing
                               , nothing ] )
end

function conductorplot(conductor::Conductor)
    # Use a decent Garamond for the plot.
    settheme!()
    # Collect the series to plot.
    nactive_ds, nactive_vs = nactive(conductor)
    workload_ds, workload_vs = workload(conductor)
    workload_average_ds, workload_average_vs = workload_average(conductor)
    cost_ds, cost_vs = cost(conductor)
    cost_cum_ds, cost_cum_vs = cost(conductor, cumulative=true)
    cost_average_cum_ds, cost_average_cum_vs = cost_average( conductor
                                                           , cumulative=true)
    # Collect for overview.
    dateses = [ nactive_ds
              , workload_ds
              , cost_ds
              , cost_cum_ds
              , workload_average_ds
              , cost_average_cum_ds
              ]
    valueses = [ nactive_vs
               , workload_vs
               , cost_vs
               , cost_cum_vs
               , workload_average_vs
               , cost_average_cum_vs
               ]
    ylabels = [ "Active clients [#]"
              , "Workload [hours/day]"
              , "Cost [\$]"
              , "Cumulative cost [\$]"
              , "Workload (mean) per client [hours/day]"
              , "Cost (mean, cum.) per client [\$]"
              ]
    # Send to datesplots() and deliver.
    return datesplots( dateses, valueses
                     ; ylabels = ylabels
                     , ylimses = [ nothing
                                 , nothing
                                 , nothing
                                 , nothing
                                 , nothing
                                 , nothing ]
                     , linked=collect(1:4) )
end
