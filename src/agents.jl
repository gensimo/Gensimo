# using Agents
using Gensimo
using Random
using FileIO, JLD2
using Dates
# # Make a Clientele.
# clientele = Clientele(3)
# # Generate some InsuranceWorkers.
# cas = [ ClientAssistant(i, (0, 0), (0, 0), rand(30:50)) for i in 1:4 ]
# # Add the InsuranceWorkers to the Clientele --- so it is a 'pool'.
# managers!(clientele, cas)
# # Open some request events for the clients.
# es = [ Event(rand(Date(2020):Date(2022)), Request(rstring))
       # for rstring in [ "ZABATZ", "MEMETZ", "HAZAAH", "RWARK!"] ]
# # Add these events to the clients, randomly.
# for e in es
    # c = rand(clients(clientele))
    # push!(c, e)
# end


###
d = load("data/tac-newmarkov.jld2")
d = Dict( Symbol(x) => d[x] for x in keys(d) )
daystodecision = load("data/tac-daystodecision.jld2")["daystodecision"]
costs = load("data/tac-costs.jld2")["costs"]
alliedhealthservices = load("data/tac-alliedhealth.jld2")["alliedhealth"]
menu = Dict(s=>costs[s] for s in alliedhealthservices)
population = Dict( :vanilla     => .2
                 , :martyr      => .2
                 , :emerging    => .2
                 , :established => .2
                 , :fraud       => .1
                 , :incompetent => .1 )

population2 = Dict( :vanilla     => .1
                  , :martyr      => .1
                  , :emerging    => .1
                  , :established => .1
                  , :fraud       => .3
                  , :incompetent => .3 )
# n = 10
# cs = [ Client( id=i, pos=(0.0, 0.0), vel=(0.0, 0.0)
                       # , personalia = Personalia()
                       # , history = [ ( rand(Date(2020):Date(2021))
                                     # , State(rand(12))) ]
                       # , claim = Claim() ) for i ∈ 1:n ]
# portfolio = Clientele(id=n+5, pos=(0.0, 0.0), vel=(0.0, 0.0))
# managers!(portfolio, [ ClaimsManager(i, (0, 0), (0, 0), rand(25:35))
                       # for i in n+1:n+1 ])
# pool = Clientele(id=n+6, pos=(0.0, 0.0), vel=(0.0, 0.0))
# managers!(pool, [ ClientAssistant(i, (0, 0), (0, 0), rand(30:50))
                  # for i in n+2:n+4 ])


using XLSX

# Load the scenarios file
xs = XLSX.readxlsx("scenarios.xlsx")
# Get the list of sheet names.
shs = XLSX.sheetnames(xs)
# Assumes the first sheet is general settings, file locations etc.
scenario1 = shs[2]
# Load Scenario 1.
df1 = DataFrame(XLSX.readtable("scenarios.xlsx", scenario1))
# Get the actual parameters of the scenario.
sc1 = Dict(Symbol.(df[:, 1]) .=> df[:, 2])
# Fix `nmanagersperpool`.
nmpp = parse.(Integer, [ sc1[:nmanagersperpool][1], sc1[:nmanagersperpool][4] ])
sc1[:nmanagersperpool] = nmpp
