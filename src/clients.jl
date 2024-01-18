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

# Black magic making, e.g. added State be of Factor type again.
StaticArrays.similar_type(::Type{State}, ::Type{Float64}, s::Size{(12,)}) =
State

function big6(state::State)
    return state[1:6]
end

function nids(state::State)
    return heaviside.(.5 .- big6(state)) |> sum |> Integer
end

# function λ(state::State, mean=:harmonic)
    # mean == :arithmetic && return big6(state) |> sum |> x->1/(x/6)
    # mean == :geometric && return big6(state) |> prod |> x->1/(x^(1/6))
    # mean == :harmonic && return map(x->1/x, big6(state)) |> sum |> x->1/(6/x)
# end

function λ(state::State, mean=:arithmetic)
    mean == :arithmetic && return state[1:2] |> sum |> x->1/(x/2) - 1
    mean == :geometric && return state[1:2] |> prod |> x->1/(x^(1/2)) - 1
    mean == :harmonic && return map(x->1/x, state[1:2]) |> sum |> x->1/(2/x) - 1
end

struct Service
    label::String # Description of the service.
    cost::Float64 # Monetary cost of the service in e.g. AUD.
    labour::Float64 # Labour cost of the service in person-hours.
    approved::Bool # Whether the service request is approved or denied.
end

label(s::Service) = s.label
cost(s::Service) = s.cost
labour(s::Service) = s.labour
approved(s::Service) = s.approved

struct Segment
    division::String
    branch::String
    team::String
    manager::String
end

division(p::Segment) = p.division
branch(p::Segment) = p.branch
team(p::Segment) = p.team
manager(p::Segment) = p.manager

struct Event
    date::Date # When did the change to the claim occur?
    change::Union{ Integer # The assessment, e.g. NIDS.
                 , Segment
                 , Service }
end

date(e::Event) = e.date
change(e::Event) = e.change
Base.isless(e1::Event, e2::Event) = date(e1) < date(e2)

function cost(event::Event)
    if event |> change |> typeof == Service
        return event |> change |> cost
    else
        return 0.0
    end
end

function labour(event::Event)
    typeofchange = event |> change |> typeof
    typeofchange == Service && return event |> change |> labour
    typeofchange == Segment && return 0.0
    typeofchange isa Integer && return 0.0
end

struct Claim
    events::Vector{Event}
end

Claim() = Claim(Vector{Event}())
"""Return a new `Claim` with `Event` added."""
Base.:(+)(c::Claim, e::Event) = Claim([c.events..., e])

events(c::Claim) = c.events |> sort
services(c::Claim) = [ change(event) for event in sort(events(c))
                       if typeof(change(event)) == Service ]

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

@agent Client ContinuousAgent{2} begin
    personalia::Personalia
    history::Vector{Tuple{Date, State}}
    claim::Claim
end

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
services(client::Client) = client |> claim |> services
events(client::Client) = client |> claim |> events
# Other utility functions.
τ(client::Client, date::Date) = date - dayzero(client) |> Dates.value
τ(date::Date) = client -> τ(client, date)
dτ(client::Client, datum::Date) = datum - date(client) |> Dates.value
dτ(date::Date) = client -> dτ(client, date)
λ(client::Client, mean=:arithmetic) = λ(client |> state, mean)
Base.:(+)(client::Client, event::Event) = ( client.claim += event
                                          ; client )
nservices(client::Client) = client |> services |> length
nevents(client::Client) = client |> events |> length
nstates(client::Client) = client |> states |> length
segment(client::Client) = [ event for event in events(client)
                            if change(event) isa Segment ][end] |> change
"""NB: NIDS of a `Client` gives assesed NIDS != nids(client |> state)."""
nids(client::Client) = [ event for event in events(client)
                         if change(event) isa Integer ][end] |> change

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

function Client(id, pos, personalia, history, claim)
    s = history |> state
    return Client( id # Agent ID.
                 , (s[1], s[2]) # 2D (ϕ, ψ) 'location' vector.
                 , (0.0, 0.0) # Dummy 'velocity' vector.
                 , personalia
                 , history
                 , claim )
end

function Client(id, personalia, history, claim)
    s = history |> state
    return Client( id # Agent ID.
                 , (s[1], s[2]) # 2D (ϕ, ψ) 'location' vector.
                 , (0.0, 0.0) # Dummy 'velocity' vector.
                 , personalia
                 , history
                 , claim )
end

function ClientMaker(id=0)
    id -= 1 # So as to actually start at the current value of `id`.
    function C(personalia, history, claim)
        id += 1
        return Client(id, personalia, history, claim)
    end
end

let
    start_id = 0
    global function Client(personalia, history, claim; id=nothing)
        isnothing(id) ? start_id += 1 : start_id = id
        return Client(start_id, personalia, history, claim)
    end
end

function reset_client()
    Client( Personalia()
          , [ (Date(2020), State(rand(12))) ]
          , Claim()
          ; id=0 )
    return nothing
end

function isactive(client::Client, refdate::Date)
    if isempty(client |> events)
        lasteventdate = dayzero(client)
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

function cost(client::Client; cumulative=false)
    dates = date.(client |> events)
    dollars = cost.(client |> events)
    df = sort(DataFrame(date=dates, cost=dollars), :date)
    gdf = combine(groupby(df, :date), :cost => sum)
    costs = cumulative ? cumsum(gdf.cost_sum) : gdf.cost_sum
    return Vector{Date}(gdf.date), costs
end

function Base.show(io::IO, client::Client)
    n = client |> nevents
    n < 10 ? n : n=10
    println( io
           , "Client ID: ", client.id, "\n"
           , personalia(client)
           , "Status (", date(client), "):\n"
           , "  | ϕ = ", state(client)[1], "\n"
           , "  | ψ = ", state(client)[2], "\n"
           , "Claim (showing ", n , "/", nevents(client), " newest events):"
           , "\n"
           , claim(client)
           )
end

function Base.show(io::IO, personalia::Personalia)
    println( io
           , "  | ", name(personalia), ". "
           , age(personalia), " year-old "
           , sex(personalia) ? "male" : "female", "."
           )
end

function Base.show(io::IO, claim::Claim)
    if !isempty(claim.events)
        n = claim |> events |> length
        n < 10 ? n : n=10
        for i in 1:n
            println(io, events(claim)[i])
        end
    else
        print(io, "  | Empty claim.")
    end
end

function Base.show(io::IO, event::Event)
    if typeof(change(event)) == Segment
        print( io
             , "  ", date(event), " > segmentation", "\n"
             , change(event)
             )
    elseif typeof(change(event)) == Service
        print( io
             , "  ", date(event), " > service request", "\n"
             , "  | ", change(event)
             )
    elseif typeof(change(event)) <: Integer
        print( io
             , "  ", date(event), " > assessment", "\n"
             , "  | ", "NIDS: ", change(event)
             )
    end
end

function Base.show(io::IO, segment::Segment)
    print( io
         , "  | Division: ", division(segment), "\n"
         , "  | Branch: ", branch(segment), "\n"
         , "  | Team: ", team(segment), "\n"
         , "  | Manager: ", manager(segment)
         )
end

function Base.show(io::IO, service::Service)
    print( io, "<", label(service), ">"
         , " @ ", @sprintf "\$%.2f" cost(service)
         , " + ", labour(service), " hours FTE equivalent."
         , approved(service) ? " Approved." : " Denied."
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
