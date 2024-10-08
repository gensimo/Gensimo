using Agents
using DataFrames, StaticArrays, Dates, Printf

function heaviside(x::Real)
    if x>=0
        return 1.0
    else
        return 0.0
    end
end

struct State <: FieldVector{12, Float64}
    # Primary --- Big 6 complexities.
    physical_health::Float64
    psychological_health::Float64
    persistent_pain::Float64
    service_environment::Float64
    accident_response::Float64
    recovery_expectations::Float64
    # Secondary --- Supplementary complexities.
    prior_health::Float64 # Docs suggest this is a _list_ of pre-conditions.
    prior_finance::Float64
    fault::Float64 # Could be boolean.
    support_optimism::Float64
    sollicitor_engagement::Float64 # Could be boolean.
    satisfaction::Float64 # Satisfaction with the scheme.
end

# Black magic making, e.g. added State be of State type again.
StaticArrays.similar_type(::Type{State}, ::Type{Float64}, s::Size{(12,)}) =
State

function big6(state::State)
    return state[1:6]
end

function nids(state::State)
    return heaviside.(.5 .- big6(state)) |> sum |> Integer
end

function λ(state::State, mean=:arithmetic)
    mean == :arithmetic && return state[1:2] |> sum |> x->1/(x/2) - 1
    mean == :geometric && return state[1:2] |> prod |> x->1/(x^(1/2)) - 1
    mean == :harmonic && return map(x->1/x, state[1:2]) |> sum |> x->1/(2/x) - 1
end

@kwdef mutable struct Request
    label::String # Description of the request.
    cost::Float64 = 0.0 # Monetary cost of the request in e.g. AUD.
    labour::Float64 = 0.0 # Labour cost of the request in person-hours.
    status::Symbol = :open # Approved, denied, pending, reopened etc.
end

Request(service) = Request(label=service)

label(request::Request) = request.label
labour(request::Request) = request.labour
labour!(request::Request, l) = request.labour = l
status(request::Request) = request.status
status!(request::Request, s::Symbol) = request.status = s
approved(request::Request) = status(request) == :approved
cost(request::Request) = approved(request) ? request.cost : 0.0
cost!(request::Request, c) = request.cost = c

struct Segment
    tier::Int64
    label::String
end

tier(segment::Segment) = segment.tier
label(segment::Segment) = segment.label

struct Package
    label::String # The name of the package.
    fromto::Tuple{Date, Date} # First and last day the package is active.
    cover::Dict{String, Real} # Label and number of services covered.
    plans::Dict{String, Tuple{Date, Period}} # Label, 1st day and frequency.
end

label(package::Package) = package.label
fromto(package::Package) = package.fromto
cover(package::Package) = package.cover
plans(package::Package) = package.plans
firstday(package::Package) = package.fromto[1]
lastday(package::Package) = package.fromto[2]
isactive(package::Package, date::Date) = ( firstday(package)
                                         <= date
                                         <= lastday(package) )
function iscovered(package::Package, service::String, date::Date)
    # Service is in package, date in package lifetime and service not depleted.
    return ( service ∈ cover(package) |> keys # Service in package at all?
             && isactive(package, date)       # Date within life of package?
             && cover(package)[service] > 0 ) # Not depleted yet?
end
iscovered(service::String, date::Date) = p -> iscovered(p, service, date)

function coverleft(package::Package, service::String, date::Date)
    # No. Package expired, not active yet or depleted.
    if !iscovered(package, service, date)
        return 0
    else
        return cover(package)[service]
    end
end
coverleft(service::String, date::Date) = p -> coverleft(p, service, date)

function dates(package::Package, plan::String)
    # Get the first date and the period of the service sequence.
    date, period = plans(package)[plan]
    # Prepare the list of `Date`s.
    dates = Date[]
    # Fill the list.
    while date <= lastday(package)
        push!(dates, date)
        date += period
    end
    # Deliver.
    return dates
end

function planned(package::Package, date::Date)
    # First check if the date is within the lifetime of the package.
    if !isactive(package, date)
        return String[]
    # If so, return the list of services due today.
    else
        return [ plan for (plan, seq) in package |> plans
                      if date in dates(package, plan) ]
    end
end

function planleft(package::Package, plan::String, date::Date)
    return [ candidate for candidate in dates(package, plan)
                       if candidate >= date ]
end
planleft(service::String, date::Date) = p -> planleft(p, service, date)

function Base.in(service::String, package::Package)
    return ( service ∈ package |> cover |> keys
             || service ∈ package |> plans |> keys )
end

mutable struct Event
    date::Date # When did the change to the claim occur?
    change::Union{ Integer # The assessment, e.g. NIDS.
                 , Segment
                 , Request
                 , Package }
    term::Union{ Date      # When did the change to the claim close?
               , Nothing } # Or 'nothing' if event has no duration.
end

function Event(date::Date, change::Union{Integer, Segment, Request, Package})
    return Event(date, change, nothing)
end

date(e::Event) = e.date
term(e::Event) = e.term
startdate(e::Event) = date(e)
enddate(e::Event) = term(e)
term!(e::Event, date::Date) = e.term = date
enddate!(e::Event, date::Date) = term!(e, date)
change(e::Event) = e.change
Base.isless(e1::Event, e2::Event) = date(e1) < date(e2)
duration(e::Event) = isnothing(term(e)) ? 0 : (term(e) - date(e)).value

function cost(event::Event)
    if event |> change |> typeof == Request
        return event |> change |> cost
    else
        return 0.0
    end
end

function labour(event::Event)
    typeofchange = event |> change |> typeof
    typeofchange == Request && return event |> change |> labour
    typeofchange == Segment && return 0.0
    typeofchange <: Integer && return 0.0
    typeofchange == Package && return 0.0
end

struct Claim
    events::Vector{Event}
end

Claim() = Claim(Vector{Event}())
"""Return a new `Claim` with `Event` added."""
Base.:(+)(c::Claim, e::Event) = Claim([c.events..., e])

events(c::Claim) = c.events |> sort
requests(c::Claim) = [ change(event) for event in sort(events(c))
                       if typeof(change(event)) == Request ]
packages(c::Claim) = [ change(event) for event in sort(events(c))
                       if typeof(change(event)) == Package ]



struct Personalia
    name::String
    age::Int64
    sex::Bool
end

firstnamesM = [ "David", "John", "Peter", "Michael", "Paul", "Andrew", "Mark"
              , "Robert", "Ian", "Chris", "Steven", "James", "Tony", "Greg"
              , "Benjamin", "Richard", "Tim", "Jason" , "Stephen", "Daniel"
              , "Scott", "Craig" , "Matthew", "William", "Simon" , "Anthony"
              , "Thomas", "Brian", "Gary", "Adam", "Kim" , "Geoff", "Alan"
              , "Matt", "Wayne", "Shane", "Nick" , "Darren", "Bruce", "Kevin"
              , "Luke" , "Graham", "Sam", "Brett", "Terry" , "Phil", "Neil"
              , "Colin", "Stuart" , "Ken", "Jim", "Bob", "Graeme", "Alex"
              , "Brad", "Barry", "Martin", "Trevor", "Kerry" , "Ross", "Glenn"
              , "Nathan", "George", "Dean", "Ray" ]

firstnamesF = [ "Chris", "Julie", "Karen", "Michelle", "Helen", "Sue"
              , "Elizabeth", "Lisa", "Sarah", "Kate", "Kim", "Rebecca", "Jane"
              , "Jenny", "Susan", "Wendy", "Amanda", "Anne", "Christine"
              , "Sharon", "Jennifer", "Fiona", "Sam", "Robyn", "Margaret"
              , "Emma", "Nicole", "Melissa", "Linda", "Catherine", "Jo", "Alex"
              , "Louise", "Anna", "Kerry", "Kylie", "Jessica", "Debbie", "Mary"
              , "Angela" ]

lastnames = [ "Smith", "Jones", "Williams", "Brown", "Wilson", "Taylor"
            , "Anderson", "Johnson", "White", "Thompson", "Lee", "Martin"
            , "Thomas", "Walker", "Kelly", "Young", "Harris", "King", "Ryan"
            , "Roberts", "Hall", "Evans", "Davis", "Wright", "Baker", "Campbell"
            , "Edwards", "Clark", "Robinson", "McDonald", "Hill", "Scott"
            , "Clarke", "Mitchell", "Stewart", "Moore", "Turner", "Miller"
            , "Green", "Watson", "Bell", "Wood", "Cooper", "Murphy", "Jackson"
            , "James", "Lewis", "Allen", "Bennett", "Robertson", "Collins"
            , "Cook", "Murray", "Ward", "Phillips", "O'Brien", "Nguyen"
            , "Davies", "Hughes", "Morris", "Adams", "Johnston", "Parker"
            , "Ross", "Gray", "Graham", "Russell", "Morgan", "Reid", "Kennedy"
            , "Marshall", "Singh", "Cox", "Harrison", "Simpson", "Richardson"
            , "Richards", "Carter", "Rogers", "Walsh", "Thomson", "Bailey"
            , "Matthews", "Cameron", "Webb", "Chapman", "Stevens", "Ellis"
            , "McKenzie", "Grant", "Shaw", "Hunt", "Harvey", "Butler", "Mills"
            , "Price", "Pearce", "Barnes", "Henderson", "Armstrong" ]

function name(sex)
    if sex
        return string(rand(firstnamesM), " ", rand(lastnames))
    else
        return string(rand(firstnamesF), " ", rand(lastnames))
    end
end

Personalia() = ( sex = rand(0:1) |> Bool
               ; Personalia(name(sex), rand(0:100), sex) )

# Accessors.
name(p::Personalia) = p.name
age(p::Personalia) = p.age
sex(p::Personalia) = p.sex

@agent struct Client(ContinuousAgent{2, Float64})
    personalia::Personalia = Personalia()
    history::Vector{Tuple{Date, State}} = [(Date(2020), State(rand(12)))]
    claim::Claim = Claim()
end

# Constructors.
Client(client::Client) = deepcopy(client)
Client( personalia::Personalia = Personalia()
      , history::Vector{Tuple{Date, State}} = [(Date(2020), State(rand(12)))]
      , claim::Claim = Claim()
      ) = Client(; id=1, pos=(.0, .0), vel=(.0, .0), personalia, history, claim)

# Make working with history-field easy.
Base.isless(h1::Tuple{Date, State}, h2::Tuple{Date, State}) = h1[1] < h2[1]
dates(history::Vector{Tuple{Date, State}}) = map(t->t[1], history |> sort)
states(history::Vector{Tuple{Date, State}}) = map(t->t[2], history |> sort)
date(history::Vector{Tuple{Date, State}}) = dates(history)[end]
state(history::Vector{Tuple{Date, State}}) = states(history)[end]

# Accessors.
personalia(client::Client) = client.personalia
history(client::Client) = client.history
claim(client::Client) = client.claim

# Assorted derivative accessors.
age(client::Client) = client |> personalia |> age
dates(client::Client) = client |> history |> dates
states(client::Client) = client |> history |> states
date(client::Client) = client |> history |> date
state(client::Client) = client |> history |> state
dayzero(client::Client) = dates(client)[1]
function requests(client::Client; status=nothing)
    if isnothing(status)
        return requests(claim(client))
    else
        return [ r for r in requests(client) if r.status==status ]
    end
end
events(client::Client) = client |> claim |> events
tier(client::Client) = issegmented(client) ? tier(segment(client)) : nothing
name(client::Client) = name(personalia(client))

# Other utility functions.
τ(client::Client, date::Date) = date - dayzero(client) |> Dates.value
τ(date::Date) = client -> τ(client, date)
dτ(client::Client, datum::Date) = datum - date(client) |> Dates.value
dτ(date::Date) = client -> dτ(client, date)
λ(client::Client, mean=:arithmetic) = λ(client |> state, mean)
Base.push!(claim::Claim, event::Event) = push!(claim.events, event)
Base.push!(client::Client, event::Event) = push!(client.claim.events, event)

# nrequests(client::Client) = client |> requests |> length
nevents(client::Client) = client |> events |> length
nstates(client::Client) = client |> states |> length
function segment(client::Client)
    segevents = [ e for e in events(client) if change(e) isa Segment ]
    if isempty(segevents)
        return nothing
    else
        return segevents[end] |> change
    end
end
issegmented(client::Client) = !isnothing(client |> segment)
isonscheme = issegmented # TODO: On-scheme may include more than segmentation.

"""NB: NIDS of a `Client` gives assesed NIDS != nids(client |> state)."""
nids(client::Client) = [ event for event in events(client)
                         if change(event) isa Integer ][end] |> change
packages(client::Client) = client |> claim |> packages
function planned(client::Client, date::Date)
    plans = String[]
    for package in packages(client)
        for plan in planned(package, date)
            push!(plans, plan)
        end
    end
    return plans
end
planned(date::Date) = client -> planned(client, date)

function iscovered(client::Client, service::String, date::Date)
    return [ iscovered(p, service, date) for p in packages(client) ] |> any
end

function coveredin( client::Client, service::String, date::Date
                  ; allpackages=false # Return only last package by default.
                  )
    ps = [ p for p in packages(client) if iscovered(p, service, date) ]
    if allpackages
        return ps
    else
        return ps[end]
    end
end


function λ(mean=:arithmetic)
    function(x)
        if typeof(x) == Client
            return λ(x |> state, mean)
        end
        if typeof(x) == State
            return λ(x, mean)
        end
    end
end

function hazard(client::Client)
    return mean(state(client)[1:2])
end

function update_client!(client::Client, date::Date, state::State)
    # Update client's actual state vector.
    push!(client.history, (date, state))
    # Update client's 'position' accordingly.
    # client.pos = state[1], state[2]
end

function update_client!(client::Client, date::Date, ϕ, ψ, σ=nothing)
    # Use current σ if no new value provided.
    isnothing(σ) ? σ = state(client)[end] : σ
    # Update client's `State` vector at entries for ϕ, ψ and σ only.
    s = State([ ϕ, ψ, state(client)[3:11]..., σ ])
    # Do the updating.
    update_client!(client, date, s)
end

function update_client!(client::Client, date::Date, λ)
    # Just call `update_client!` with inferred ϕ and ψ.
    update_client!(client, date, 1/(λ+1), 1/(λ+1))
end

function isactive(client::Client, refdate::Date)
    if isempty(client |> events)
        return false
        # Below leads to unsegmented but 'active' clients with no requests.
        # lasteventdate = dayzero(client)
    else
        lasteventdate = (client |> events)[end] |> date
    end
    afterzero = dayzero(client) <= refdate
    beforeend = refdate - lasteventdate < Day(90)
    return afterzero && beforeend
end

function workload(client::Client)
    dates = date.(client |> events)
    hours = labour.(client |> events)
    df = sort(DataFrame(date=dates, hours=hours), :date)
    gdf = combine(groupby(df, :date), :hours => sum)
    return Vector{Date}(gdf.date), gdf.hours_sum
end

function workload(client::Client, datum::Date; cumulative=false)
    if cumulative
        return sum([ labour(event) for event in events(client)
                     if date(event) <= datum ])
    else
        return sum([ labour(event) for event in events(client)
                     if date(event) == datum ])
    end
end

function cost(client::Client; cumulative=false)
    dates = date.(client |> events)
    dollars = cost.(client |> events)
    df = sort(DataFrame(date=dates, cost=dollars), :date)
    gdf = combine(groupby(df, :date), :cost => sum)
    costs = cumulative ? cumsum(gdf.cost_sum) : gdf.cost_sum
    return Vector{Date}(gdf.date), costs
end

function nrequests(state::State, rng=nothing)
    # If not provided, get the pseudo-randomness from device.
    isnothing(rng) ? rng = RandomDevice() : rng
    # Deliver.
    return rand(rng, Poisson(λ(state)))
end

nrequests(client::Client, rng=nothing) = nrequests(client |> state, rng)

function Base.show(io::IO, client::Client)
    n = client |> nevents
    n < 10 ? n : n=10
    println( io
           , "Client ID: ", client.id, "\n"
           , personalia(client), "\n"
           , "Status (", date(client), "):\n"
           , "  | ϕ = ", state(client)[1], "\n"
           , "  | ψ = ", state(client)[2], "\n"
           , "Claim (showing ", n , "/", nevents(client), " newest events):"
           , "\n"
           , claim(client)
           )
end

function Base.show(io::IO, personalia::Personalia)
    print( io
         , "  | ", name(personalia), ". "
         , age(personalia), " year-old "
         , sex(personalia) ? "male" : "female", "."
         )
end

function Base.show(io::IO, claim::Claim)
    if !isempty(claim.events)
        nevs = claim |> events |> length
        nevs < 10 ? n=nevs : n=10
        for i in (nevs-n)+1:nevs
            println(io, events(claim)[i])
        end
    else
        print(io, "  | Empty claim.")
    end
end

function Base.show(io::IO, event::Event)
    if !isnothing(term(event)) # Does the event have positive duration.
        dstring = string(" > ", term(event), " (", duration(event), " days)")
    else
        dstring = ""
    end
    if typeof(change(event)) == Segment
        print( io
             , "  ", date(event), " > segmentation"
             , dstring, "\n"
             , change(event)
             )
    elseif typeof(change(event)) == Request
        print( io
             , "  ", date(event), " > service request"
             , dstring, "\n"
             , "  | ", change(event)
             )
    elseif typeof(change(event)) == Package
        print( io
             , "  ", date(event), " > package addition"
             , dstring, "\n"
             , "  | ", change(event)
             )
    elseif typeof(change(event)) <: Integer
        print( io
             , "  ", date(event), " > assessment"
             , dstring, "\n"
             , "  | ", "NIDS: ", change(event)
             )
    end
end

function Base.show(io::IO, segment::Segment)
    print( io
         , "  | Tier ", tier(segment), " (", label(segment), ")"
         #= Old Segment fields:
         , "  | Division: ", division(segment), "\n"
         , "  | Branch: ", branch(segment), "\n"
         , "  | Team: ", team(segment), "\n"
         , "  | Manager: ", manager(segment)
         =#
         )
end

function Base.show(io::IO, request::Request)
    print( io, "<", label(request), ">"
         , " @ ", @sprintf "\$%.2f" cost(request)
         , " + ", labour(request), " hours FTE equivalent."
         , string(" ", titlecase(string(status(request))), ".")
         )
end

function Base.show(io::IO, state::State)
    print( io, "\n"
         , "  Physical health: ", "\t ", state.physical_health, "\n"
         , "  Psychological health: ", " ", state.psychological_health, "\n"
         , "  Persistent pain: ", "\t ", state.persistent_pain, "\n"
         , "  Service environment: ", "\t ", state.service_environment, "\n"
         , "  Accident response: ", "\t ", state.accident_response, "\n"
         , "  Recovery expectations: ", state.recovery_expectations, "\n"
         , "  Prior health: ", "\t ", state.prior_health, "\n"
         , "  Prior finance: ", "\t ", state.prior_finance, "\n"
         , "  Fault: ", "\t\t ", state.fault, "\n"
         , "  Support and optimism: ", " ", state.support_optimism, "\n"
         , "  Sollicitor engagement: ", state.sollicitor_engagement, "\n"
         , "  Satisfaction: ", "\t ", state.satisfaction
         )
end
