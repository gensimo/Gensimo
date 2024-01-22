module Gensimo

# Include and export essentials from clients.jl.
include("clients.jl")
export Claim, events, services
export Client, reset_client, personalia, history, claim, segment,
       dates, date, states, nstates, state, dayzero,
       nids, τ, dτ, λ, age,
       events, nevents, services, nservices,
       isactive, workload
export Event, date, change, cost, labour
export Personalia, name, age, sex
export Segment, division, branch, team, manager
export Service, label, cost, labour, approved
export State,
       big6, nids, healthindex
export name, heaviside, n

# Include and export essentials from conductors.jl.
include("conductors.jl")
export Conductor, clients, nclients, context, epoch, eschaton, timeline,
       nactive, statistics, workload, workload_average, cost, cost_average,
       nrequests, request_cost
export Context, services, segments, states, probabilities

# Include and export essentials from display.jl.
include("display.jl")
export baseplot, gplot, datesplot,
       costseriesplot, costseriesplot_ensemble, costseriesplot_tiled,
       datesplots, clientplot, conductorplot

end # Module Gensimo.
