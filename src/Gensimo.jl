module Gensimo

# Convenience functions for pipelines.
at(index) = A -> getindex(A, index)
at(r, c) = A -> A[r, c]
export at

# Include and export essentials from clients.jl.
include("clients.jl")
export Claim,
       events, requests
export Client,
       reset_client, personalia, history, claim, segment,
       dates, date, states, nstates, state, dayzero,
       update_client!,
       nids, τ, dτ, λ, age,
       events, nevents, requests, nrequests, nrequests, packages
       isactive, isonscheme, issegmented,
       workload
export Event,
       date, change, cost, labour, term, term!
export Personalia,
       name, age, sex
export Segment,
       tier, label, division, branch, team, manager
export Package,
       label, fromto, cover, plans, term, term!, enddate, enddate!,
       firstday, lastday, isactive, iscovered, coverleft, coveredin,
       planned, planleft, dates
export Request,
       label, cost, labour, approved, status,
       cost!, labour!, status!
export State,
       big6, nids, healthindex
export name, heaviside, n

# Include and export essentials from insurers.jl.
include("insurers.jl")
export Clientele, InsuranceWorker, ClientAssistant, ClaimsManager,
       Task, tasks, close!

# Include and export essentials from providers.jl.
include("providers.jl")
export Provider, services, asks, capacity, capacity!

# Include and export essentials from conductors.jl.
include("conductors.jl")
export Conductor, clients, nclients, context, epoch, eschaton, timeline,
       nactive, nonscheme, statistics, workload, workload_average, cost,
       cost_average, request_cost,
       client, event,
       insurers, providers, agents,
       ninsurers, nproviders, nagents
export Context, distros, requests, segments, states, probabilities

# Include and export essentials from display.jl.
include("display.jl")
export baseplot, gplot, datesplot,
       costseriesplot, costseriesplot_ensemble, costseriesplot_tiled,
       datesplots, clientplot, conductorplot, nactiveplot,
       dashboard

# Include and export essentials from processes.jl.
include("processes.jl")
export initialise, simulate!,
       client_step!, agent_step!, model_step!,
       stap, walk, nrequests, requests,
       nevents, cost, nactive, workload

# Export everything this module defines up to here.
for n in names(@__MODULE__; all=true)
    if Base.isidentifier(n) && n ∉ (Symbol(@__MODULE__), :eval, :include)
        @eval export $n
    end
end

end # Module Gensimo.
