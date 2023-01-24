"""
Provides a core type and utility constructor for social insurance clients.
"""
module Clients

export Client, client

"""
    client(physical_health, psycholical_health, administrative_state)

Return a client as an instance of the Client type using integer values for
the physiological, psychological and administrative layers.

# Example
```julia-repl
julia> client(100, 100, 1) # Instantiate a fully fit client receiving physio.
Client(PhysioState(100), PsychoState(100), phy siotherapy)
```
"""
function client(physio_health, psycho_health, admin_state)
    physiological = PhysioState(physio_health)
    psychological = PsychoState(psycho_health)
    administrative = AdminState(admin_state)
    return Client(physiological, psychological, administrative)
end

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
Type to serve as the core of the client agents in the ABM section as well as of the states of the MDP section.of the model framework.
"""
struct Client
    physiological::PhysioState
    psychological::PsychoState
    administrative::AdminState
end


# End of module.
end
