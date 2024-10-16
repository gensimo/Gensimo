using GraphMakie, Graphs, Dates, Agents
using Statistics: mean

# Black magic to import GLMakie except for `events()`.
import GLMakie
for x in names(GLMakie)
    if x != :events
        @eval import GLMakie.$x
    end
end

function baseplot(g) # Basic graph plotting with nice defaults.
    fig, ax, p = graphplot( g
                          , nlabels=string.(1:nv(g))
                          , nlabels_distance=5
                          , node_color=:white
                          , node_attr=(;strokewidth=2)
                          )
    # Clean up the plot.
    hidedecorations!(ax)
    hidespines!(ax)
    ax.aspect = DataAspect()
    # Return like `graphplot()`.
    return fig, ax, p
end

function gplot(g, labels=nothing) # Basic graph plotting with nice defaults.
    # A good starting point. Return this unchanged if no labels passed.
    fig, ax, p = baseplot(g)
    # Pairs of labels: list of tuples of (nohover, hover) labels.
    if typeof(labels) == Vector{Tuple{String, String}}
        # Sub-function to pass to the event handler.
        function action(state, id, event, axis)
            if state
                p.nlabels[][id] = labels[id][2]
            else
                p.nlabels[][id] = labels[id][1]
            end
            p.nlabels[] = p.nlabels[]
        end
        register_interaction!(ax, :nodehover, NodeHoverHandler(action))
    # List of labels.
    elseif typeof(labels) == Vector{String}
        # Apply the labels.
        p.nlabels[] = labels
    end
    # Deliver.
    display(fig)
    # Return like `graphplot()`.
    return fig, ax, p
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

"""Use a decent Garamond for the plot."""
settheme!() = Makie.set_theme!( fontsize=14
                        , fonts=(
                                ; regular="Garamond"
                                , bold="Garamond Bold"
                                , italic="Garamond Italic"
                                , bold_italic="Garamond Bold Italic" )
                        )

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

function datesplot( dates::Vector{Date}, values
                  ; labels=""
                  , title=""
                  , xlabel=""
                  , ylabel=""
                  , maxdates=20 )
    # Use a decent Garamond for the plot.
    settheme!()
    # Obtain fig and ax objects.
    fig = Figure()
    ax = Axis( fig[1, 1]
             , xlabel=xlabel
             , ylabel=xlabel
             , title=title )
    # Convert dates to integers, i.e. days since rounding epoch.
    days = Dates.date2epochdays.(dates)
    # Plot against those integers. Put labels if provided.
    plt = scatterlines!(ax, days, values, color=:black)
    if !isnothing(labels)
        text!( labels
             , position=collect(zip(days, values))
             , align=(:left, :bottom) )
    end
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
    return days, dates # fig, ax, plt
end

datesplot(dates_values, kwargs...) = datesplot(dates_values..., kwargs...)

function datesplots( dateses::Vector{Vector{Date}} # List of lists of dates.
                   , valueses # List of lists of values.
                   ; labelses=nothing # List of lists of e.g. strings.
                   , titles=nothing # List of strings.
                   , xlabels=nothing # List of strings.
                   , ylabels=nothing # List of strings.
                   , ylimses=nothing # List of tuples or vectors.
                   , maxdates=20
                   , linked=:all
                   )
    n = length(dateses)
    # Use a decent Garamond for the plot.
    settheme!()
    # Obtain Figure object.
    fig = Figure()
    axes = []
    plt = nothing # Just so it is there to be assigned to in the loop below.
    # Prepare labels etc.
    isnothing(ylabels) ? ylabels = [ "" for i ∈ 1:n ] : ylabels
    isnothing(xlabels) ? xlabels = [ "" for i ∈ 1:n ] : xlabels
    isnothing(titles) ? titles = [ "" for i ∈ 1:n ] : titles
    isnothing(ylimses) ? ylimses = [ nothing for i ∈ 1:n ] : ylimses
    # Add axes for each data set.
    for i in 1:length(dateses)
        # Make plots appear as rows.
        ax = Axis( fig[i, 1]
                 , title=titles[i]
                 , xlabel=xlabels[i]
                 , ylabel=ylabels[i] )
        # Specify the vertical axis end points, if desired.
        if !isnothing(ylimses[i])
            ylims!(ax, ylimses[i])
        end
        # Collect dates and cost lists for this case from the Conductor object.
        dates = dateses[i]
        values = valueses[i]
        # Convert dates to integers, i.e. days since rounding epoch.
        days = Dates.date2epochdays.(dates)
        # Plot against those integers.
        plt = scatterlines!(ax, days, values, color=:black)
        # --- need to do `unique` to avoid Makie bug about "range step zero".
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
        # Then put the dates in place of integers
        ax.xticks = (days, string.(dates))
        # Quarter π rotation to avoid clutter.
        ax.xticklabelrotation = π/4
        # Add this Axis to the list.
        push!(axes, ax)
    end
    # Link the chosen axes, so they have the same scale.
    if linked == :all
        linkxaxes!([axes[i] for i in 1:length(dateses)]...)
    else
        linkxaxes!([axes[i] for i in linked]...)
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

function heatmap(model::AgentBasedModel)
    heat = nactive(model)
    return [ heat heat
            ; heat heat ]
end

function agent_marker(agent, model)
    if typeof(agent) == InsuranceWorker
        return '⋄'
    end
    if typeof(agent) == Client
        return isactive(agent, date(model)-Day(1)) ? '□' : '*'
    end
end

function dashboard_costs(model::AgentBasedModel)
    agent_marker(agent) = agent_marker(agent, model)
    intcumcost(model) = round(Integer, cost(model; cumulative=true))
    intcost(model) = round(Integer, cost(model))
    intworkload(model) = round(Integer, workload(model; cumulative=true))
    # Pass the relevant options to the `abmplot()` function.
    fig, abmobs = abmexploration( model
                                ; add_controls = true
                                , adjust_aspect = false
                                , agent_marker, agent_size=25
                                , heatarray = heatmap
                                , heatkwargs = ( colorrange = (0, 100)
                                               , colormap = :thermal )
                                , mdata = [ nevents
                                          , intworkload
                                          , intcost
                                          , intcumcost ]
                                , mlabels = [ "events [ # ]"
                                            , "workload (cumulative) [ hrs ]"
                                            , "cost (incoming) [ \$ ]"
                                            , "cost (cumulative) [ \$ ]" ]
                                )
    # Show me what you got.
    display(fig)
    # Deliver.
    return fig, abmobs
end

function dashboard_fte(model::AgentBasedModel)
    function heat(model::AgentBasedModel)
        h = nactive(model)
        return [ h h
               ; h h ]
    end
    function agent_marker(agent)
        if typeof(agent) == InsuranceWorker
            return '⋄'
        elseif typeof(agent) == Client
            return isactive(agent, date(model)-Day(1)) ? '□' : '*'
        elseif typeof(agent) == Provider
            return '⋅'
        else # Then: typeof(agent) == Clientele
            return ' '
        end
    end
    # Specialise the agent_marker() function.
    # agent_marker(agent) = agent_marker(agent, model)
    # Pass the relevant options to the `abmplot()` function.
    fig, abmobs = abmexploration( model
                                ; add_controls = true
                                , adjust_aspect = false
                                , agent_marker
                                , agent_size=25
                                , heatarray = heat
                                , heatkwargs = ( colorrange = (0, 100)
                                               , colormap = :thermal )
                                , mdata = [ nactive
                                          , nevents
                                          , ntasks
                                          , nopen
                                          ]
                                , mlabels = [ "active clients [ # ]"
                                            , "number of events [ # ]"
                                            , "allocated tasks [ # ]"
                                            , "requests waiting [ # ]"
                                            ]
                                )
    # Show me what you got.
    display(fig)
    # Deliver.
    return fig, abmobs
end

function dashboard(model::AgentBasedModel; plots=:fte)
    if plots == :fte
        return dashboard_fte(model)
    elseif plots == :cost
        return dashboard_costs(model)
    else
        error("Unknown plots option: ", plots)
    end
end
