module Gensimo

# Include and export essentials from clients.jl.
include("clients.jl")
export Claim, events, services
export Client, reset_client, personalia, history, claim,
       dates, date, states, state, dayzero, nids
export Event, date, change
export Personalia, name, age, sex
export Segment, division, branch, team, manager
export Service, label, cost, labour, approved
export State,
       big6, nids
export name, heaviside

# Include and export essentials from display.jl.
include("display.jl")
export baseplot, gplot, datesplot
       costseriesplot, costseriesplot_ensemble, costseriesplot_tiled

# Include and export essentials from conductors.jl.
include("conductors.jl")
export Conductor, clients, context, epoch, eschaton
export Context, services, segments, states, probabilities

# Importing deliberation modules.
include("DeliberationMDP.jl")
import .DeliberationMDP as MDP
export MDP

include("DeliberationABM.jl")
import .DeliberationABM as ABM
export ABM

include("DeliberationNGCM.jl")
import .DeliberationNGCM as NGCM

end # Module Gensimo.
