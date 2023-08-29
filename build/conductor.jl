using Dates
using Distributions, StatsBase

# Number of clients.
nclients = 2

# Define the time frame.
epoch = Date(2020)
eschaton = Date(2023)
era = eschaton - epoch
today = epoch

# Define a 'history' object tracking states of each agent over the time steps.
history = Dict(i => [ state() ] for i in 1:nclients)


# Make a naive bimodal distribution using Gaussians.
μ₁ = epoch + Dates.Day(14) |> Dates.value
μ₂ = epoch + Dates.Day(365) |> Dates.value
σ₁ = 10
σ₂ = 100
f(x) = exp(-((x-μ₁)/σ₁)^2) + .5*exp(-((x-μ₂)/σ₂)^2)

# Turn the distribution f(x) into a probability mass function.
ds = epoch:Day(1):eschaton # From beginning to end, one day at a time.
ps = f.(Dates.value.(ds)) / sum(f.(Dates.value.(ds)))
pmf = DiscreteNonParametric(Dates.value.(ds), ps)

# From: https://en.wikipedia.org/wiki/Birth_process
function p( n # Size of initial population.
          , k # Size of projected population.
          , t # Time.
          , λ # Rate.
          )
    m = k - n
    return binomial(n, m) * (λ*t)^m * (1 - λ*t)^(n-m)
end


