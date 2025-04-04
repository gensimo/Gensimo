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
       nids, τ, dτ, λ, age, hazard, σ, σ₀,
       events, nevents, requests, nrequests, nrequests, packages,
       isactive, isonscheme, issegmented,
       workload
export Event,
       date, change, cost, labour, term, term!
export Personalia,
       name, age, sex
export Segment,
       tier, label, division, branch, team, manager
export Allocation,
       clientele
export Package,
       label, fromto, cover, plans, term, term!, enddate, enddate!,
       firstday, lastday, isactive, iscovered, coverleft, coveredin,
       planned, planleft, dates
export Request,
       label, cost, labour, approved, denied, status,
       cost!, labour!, status!
export State,
       big6, nids, healthindex
export name, heaviside, n
export activeplans, satisfaction, duration

# Include and export essentials from insurers.jl.
include("clienteles.jl")
export Clientele, Manager, ClientAssistant, ClaimsManager,
       capacity, capacity!, efficiency, efficiency!,
       allocations, nallocations, nfree, pfree, anyfree, freemanagers, nactive
       Task, tasks, close!, allocate!, requestedon, allocatedon,
       ispool, isport, isportfolio, managers, cap, isatcap, nclients, nmanagers,
       cap!

# Include and export essentials from providers.jl.
include("providers.jl")
export Provider, template, sfactor, rfactor, services, asks, provides,
       capacity, capacity!,
       make_provider_template

# # Include and export essentials from conductors.jl.
# include("conductors.jl")
# export Conductor, clients, nclients, context, epoch, eschaton, timeline,
       # nactive, nonscheme, statistics, workload, workload_average, cost,
       # cost_average, request_cost,
       # client, event,
       # clienteles, nclienteles, nmanagers,
       # providers, provides, agents,
       # nproviders, nagents
# export Context, distros, requests, segments, states, probabilities

# Include and export essentials from initialisation.jl.
include("initialisation.jl")
export initialise
export Context, timeline
export Scenario, Scenarios, rand, listify
export step_agent!, step_model!,
       step_client!, step_manager!, step_clientele!, step_provider!
export clients, clienteles, clientele, providers, managers,
       stap, walk, requests, nexpected
       provides, portfolios, pools,
       type, allocate!,  date, listify
       position, rand, requests, segment!, tasks, tier, cost

# Include and export essentials from simulation.jl.
include("simulation.jl")
export traces!
export cubeaxes, scenarioslice, writecube # Hypercube tools.

# Include and export essentials from tracers.jl.
include("tracers.jl")
export tracers,
       allocated, cost, cost_cumulative, cost_mediancum, nactive, nclients,
       nevents, nopenclients, nopenrequests, ntasks, nwaiting, qoccupation,
       satisfaction, workload, cost_meancum

# # Include and export essentials from processes.jl.
# include("processes.jl")
# export initialise, simulate!,
       # clienteles, clientele,
       # client_step!, agent_step!, model_step!,
       # stap, walk, nrequests, requests,
       # nevents, cost, cost_cumulative, cost_meancum, nactive, nclients,
       # workload, ntasks, nopen, provides,
       # next_request, next_requests,
       # portfolios, pools,
       # type, qoccupation, trace!, traces!, cubeaxes, writecube, writeaxes,
       # scenarioslice, allocated

# Include and export essentials from display.jl.
include("visualisation.jl")
export baseplot, gplot, datesplot,
       costseriesplot, costseriesplot_ensemble, costseriesplot_tiled,
       datesplots, clientplot, conductorplot, nactiveplot,
       dashboard, tracesplot, compareplot

# Export everything this module defines up to here.
for n in names(@__MODULE__; all=true)
    if Base.isidentifier(n) && n ∉ (Symbol(@__MODULE__), :eval, :include)
        @eval export $n
    end
end

end # Module Gensimo.
