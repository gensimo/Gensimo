module Gensimo

# Include and export essentials from clients.jl.
include("clients.jl")
export Claim, events, services
export Client, reset_client, personalia, history, claim,
       dates, date, states, nstates, state, dayzero,
       nids, τ, dτ, nrequests, request_cost, λ, age,
       events, nevents, services, nservices
export Event, date, change, cost, labour
export Personalia, name, age, sex
export Segment, division, branch, team, manager
export Service, label, cost, labour, approved
export State,
       big6, nids, healthindex
export name, heaviside, n

# Include and export essentials from display.jl.
include("display.jl")
export baseplot, gplot, datesplot
       costseriesplot, costseriesplot_ensemble, costseriesplot_tiled

# Include and export essentials from conductors.jl.
include("conductors.jl")
export Conductor, clients, context, epoch, eschaton
export Context, services, segments, states, probabilities

end # Module Gensimo.
