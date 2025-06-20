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

"""Use a decent Garamond for the plot."""
settheme!() = Makie.set_theme!( fontsize=14
                        , fonts=(
                                ; regular="Garamond"
                                , bold="Garamond Bold"
                                , italic="Garamond Italic"
                                , bold_italic="Garamond Bold Italic" )
                        )

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
                   , onscreen=true
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
    # Show me what you got --- if requested.
    if onscreen
        display(fig)
    end
    # Deliver.
    return fig, axes, plt
end

function tracesplot(traces::DataFrame; nodates=true, onscreen=true)
    # First column is always the dates.
    n = ncol(traces) - 1
    # One may want the horizontal axes labels ("Date") suppressed.
    if nodates
        xlabels = [ "" for i ∈ 1:n ]
    else
        xlabels = [ "Date" for i in 1:n ]
    end
    # Give it all to datesplots() which will display it.
    fig, axes, plt = datesplots( [ traces.date for i ∈ 1:n]
                               , [ traces[:, i+1] for i ∈ 1:n ]
                               ; xlabels
                               , ylabels=names(traces)[2:end] )
    # Show me what you got --- if requested.
    if onscreen
        display(fig)
    end
    # Deliver the objects also.
    return fig, axes, plt
end

function compareplot( tracesdict::AbstractDict
                    ; column::Symbol, nodates=true, onscreen=true )
    # Get all the keys.
    ks = collect(keys(tracesdict))
    # First column is always the dates.
    n = ncol(tracesdict[ks[1]]) - 1
    # One may want the horizontal axes labels ("Date") suppressed.
    if nodates
        xlabels = [ "" for i ∈ 1:length(ks) ]
    else
        xlabels = [ "Date" for i in 1:length(ks) ]
    end
    # Give it all to datesplots() which will display it.
    fig, axes, plt = datesplots( [ tracesdict[k].date for k ∈ ks ]
                               , [ tracesdict[k][:, column] for k ∈ ks ]
                               ; xlabels
                               #, ylabels=[string(k, "\n", column) for k ∈ ks]
                               , titles=[string(k, "\n", column) for k ∈ ks]
                               , onscreen=false )
    # Link the vertical axes so they have the same scale.
    linkaxes!(axes...)
    # Show me what you got --- if requested.
    if onscreen
        display(fig)
    end
    # Deliver the objects also.
    return fig, axes, plt
end

function heatmap(model::AgentBasedModel)
    heat = nactive(model)
    return [ heat heat
            ; heat heat ]
end

function agent_marker(agent, model)
    if typeof(agent) == Manager
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
        if typeof(agent) == Manager
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
                                , mdata = [ nopenclients
                                          , nwaiting
                                          , cost_mediancum
                                          , nevents
                                          , qoccupation
                                          , nopenrequests
                                          , satisfaction
                                          ]
                                , mlabels = [ "open clients [ # ]"
                                            , "waiting clients [ # ]"
                                            , "median cumulative cost [ \$ ]"
                                            , "number of events [ # ]"
                                            , "queue occupation [ % ]"
                                            , "requests waiting [ # ]"
                                            , "mean satisfaction [ % ]"
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
