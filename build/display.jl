module Display

using GraphMakie, Graphs, GLMakie

export gplot, g

g = wheel_graph(5)

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

end # Module.
