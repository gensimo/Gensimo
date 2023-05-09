module Gensimo

include("model.jl")
include("scheme.jl")
include("display.jl")
using .Scheme
using .Display

export model, scheme, policy, steppol, gplot

end # Module Gensimo.
