"""
Provides a core type and utility constructor for social insurance client states.
"""
module States

export State, state

struct PhysioState
    physical_health::Integer
end

struct PsychoState
    psychological_health::Integer
end

"""Administrative state (SchemeState) as Enum type for the time being."""
@enum AdminState begin
    ambulance
    physiotherapy
    psychotherapy
    medication
    income_support
end

"""
Type to serve as the core of the state agents in the ABM section as well as of the states of the MDP section.of the model framework.
"""
struct State
    physiological::PhysioState
    psychological::PsychoState
    administrative::AdminState
end

"""
    state(physical_health, psycholical_health, administrative_state)

Return a state as an instance of the `State` type using integer values for
the physiological, psychological and administrative layers of the client.

# Example
```julia-repl
julia> state(100, 100, 1) # Instantiate a fully fit state receiving physio.
State(PhysioState(100), PsychoState(100), phy siotherapy)
```
"""
function state(physio_health, psycho_health, admin_state)
    physiological = PhysioState(physio_health)
    psychological = PsychoState(psycho_health)
    administrative = AdminState(admin_state)
    return State(physiological, psychological, administrative)
end

nadminstates = length(instances(AdminState))
states = [ state(ϕ, ψ, α) for ϕ ∈ 0:100, ψ ∈ 0:100, α ∈ 0:nadminstates-1 ]


# End of module.
end
