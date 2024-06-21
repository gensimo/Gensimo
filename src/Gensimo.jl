module Gensimo

# Convenience functions for pipelines.
at(index) = A -> getindex(A, index)
at(r, c) = A -> A[r, c]
export at

# Include and export essentials from clients.jl.
include("clients.jl")
export Claim, events, services
export Client, reset_client, personalia, history, claim, segment,
       dates, date, states, nstates, state, dayzero,
       update_client!,
       nids, τ, dτ, λ, age,
       events, nevents, services, nservices, nrequests,
       isactive, isonscheme, workload
export Event, date, change, cost, labour
export Personalia, name, age, sex
export Segment, tier, label, division, branch, team, manager
export Service, label, cost, labour, approved
export State,
       big6, nids, healthindex
export name, heaviside, n

# Include and export essentials from conductors.jl.
include("conductors.jl")
export Conductor, clients, nclients, context, epoch, eschaton, timeline,
       nactive, nonscheme, statistics, workload, workload_average, cost,
       cost_average, request_cost
export Context, distros, services, segments, states, probabilities

# Include and export essentials from display.jl.
include("display.jl")
export baseplot, gplot, datesplot,
       costseriesplot, costseriesplot_ensemble, costseriesplot_tiled,
       datesplots, clientplot, conductorplot, nactiveplot

# Include and export essentials from insurers.jl.
include("insurers.jl")
export Clientele, InsuranceWorker, ClientAssistant, ClaimsManager

# Include and export essentials from providers.jl.
include("providers.jl")
export Provider, services, asks, capacity, capacity!

# Include and export essentials from processes.jl.
include("processes.jl")
export initialise, simulate!,
       client_step!, agent_step!, model_step!,
       stap, walk, nrequests, requests

end # Module Gensimo.
