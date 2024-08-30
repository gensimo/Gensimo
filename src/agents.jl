# using Agents
using Random

# Make a Clientele.
clientele = Clientele(3)
# Generate some InsuranceWorkers.
cas = [ ClientAssistant(i, (0, 0), (0, 0), rand(1:10)) for i in 1:4 ]
# Add the InsuranceWorkers to the Clientele --- so it is a 'pool'.
managers!(clientele, cas)
# Open some request events for the clients.
es = [ Event(rand(Date(2020):Date(2022)), Request(rstring))
       for rstring in [ "ZABATZ", "MEMETZ", "HAZAAH", "RWARK!"] ]
# Add these events to the clients, randomly.
for e in es
    c = rand(clients(clientele))
    push!(c, e)
end

n = 10
cs = [ Client( id=i, pos=(0.0, 0.0), vel=(0.0, 0.0)
                       , personalia = Personalia()
                       , history = [ ( rand(Date(2020):Date(2021))
                                     , State(rand(12))) ]
                       , claim = Claim() )
                 for i ∈ 1:n ]
portfolio = Clientele()
managers!(portfolio, [ ClaimsManager(i, (0, 0), (0, 0), rand(1:10))
                       for i in n+1:n+1 ])
pool = Clientele()
managers!(pool, [ ClientAssistant(i, (0, 0), (0, 0), rand(1:10))
                  for i in n+2:n+4 ])




