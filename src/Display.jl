module Display

using GraphMakie, Graphs, GLMakie, Dates

using ..Gensimo: State, state, cost

export baseplot, gplot, datesplot

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

function datesplot(conductor)
    # Use a decent Garamond for the plot.
    set_theme!( fontsize=14
              , fonts=(
                      ; regular="Garamond"
                      , bold="Garamond Bold"
                      , italic="Garamond Italic"
                      , bold_italic="Garamond Bold Italic" )
              )
    # Obtain fig object.
    fig = Figure()
    axes = []
    # Add axes for each Case.
    for (i, case) in enumerate(conductor.cases)
        # Make plots appear as rows.
        ax = Axis( fig[i, 1]
                 , xlabel=""
                 , ylabel="Cumulative Cost [ \$ ]" )
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
        # Plot against those integers. Put labels if provided.
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

function datesplot(dates::Vector{Date}, values, labels=nothing)
    # Use a decent Garamond for the plot.
    set_theme!( fontsize=14
              , fonts=(
                      ; regular="Garamond"
                      , bold="Garamond Bold"
                      , italic="Garamond Italic"
                      , bold_italic="Garamond Bold Italic" )
              )
    # Obtain fig and ax objects.
    fig = Figure()
    ax = Axis( fig[1, 1]
             , xlabel=""
             , ylabel="Cumulative Cost [ \$ ]"
             , title="Cost History")
    # Convert dates to integers, i.e. days since rounding epoch.
    days = Dates.date2epochdays.(dates)
    # Plot against those integers. Put labels if provided.
    plt = scatterlines!(ax, days, values, color=:black)
    if !isnothing(labels)
        text!( labels
             , position=collect(zip(days, values))
             , align=(:left, :bottom) )
    end
    # Then put the dates in place of those integers.
    ax.xticks = (days, string.(dates))
    # Quarter π rotation to avoid clutter.
    ax.xticklabelrotation = π/4
    # Show me what you got.
    display(fig)
    # Deliver.
    return fig, ax, plt
end


end # Module.
