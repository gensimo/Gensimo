using Agents
using Dates, DataFrames
using DimensionalData
using DimensionalData.Dimensions: label
using CSV
using HDF5

function traces!(model::AgentBasedModel; funs, nsteps=nothing)
    # Prepare arrays for output by filling them with zeroeth-step element.
    outputs = [ [Float64(funs[i](model))] for i in 1:length(funs) ]
    # Likewise for the dates array.
    days = [date(model)]
    # Infer nsteps if necessary.
    if isnothing(nsteps)
        nsteps = length(model.epoch:Day(1):model.eschaton) - 1 # Up to eschaton.
    end
    # Step through the simulation, filling the arrays.
    for t ∈ 1:nsteps
        # One step at a time.
        step!(model)
        # Current model date needs to be written to array only once.
        push!(days, date(model))
        # Obtain the output for each function successively.
        for i in 1:length(funs)
            push!(outputs[i], funs[i](model))
        end
    end
    xs = [ :date=>days
         , [Symbol(funs[i])=>outputs[i] for i in 1:length(funs)]... ]
    # Deliver as DataFrame.
    return DataFrame(xs)
end

function traces!(models::DimArray{AgentBasedModel}; funs, nsteps=nothing)
    # Labels of the axes.
    dimlabels = Symbol.(DimensionalData.Dimensions.label.(dims(models)))
    # Create an axis for the dates.
    dates = Dim{:date}(models[1].epoch:Day(1):models[1].eschaton |> collect)
    # Create an axis for the output variables (i.e. the `funs`).
    outvars = Dim{:outvar}(Symbol.(funs))
    # Prepare an output hypercube.
    hcube = zeros(dates, outvars, dims(models)...)
    # Iterate prudently over the entries in the hypercube.
    for vals in Iterators.product(dims(models)...)
        # Make a `Selector` to look up the right model.
        coordinates = NamedTuple{dimlabels}(At.(vals))
        # Get the model.
        model = models[coordinates...]
        # Run the model.
        df = traces!(model; funs=funs, nsteps=nsteps)
        # Add to the hypercube (without dates, they are already in the axis).
        hcube[:, :, coordinates...] .= df[:, 2:end]
    end
    # Deliver.
    return hcube
end

function cubeaxes(cube::DimArray)
    axiskeys = Symbol.(DimensionalData.Dimensions.label.(dims(cube)))
    axes = [ collect(axis) for axis in val.(dims(cube)) ]
    return OrderedDict(axiskeys .=> axes)
end

function scenarioslice(cube::DimArray, scenario::AbstractDict)
    # Axis labels --- in correct order --- excluding dates and outvars.
    ks = Tuple(keys(cubeaxes(cube)))[3:end]
    # Construct coordinates for hypercube the _hard_ way.
    coordinates = NamedTuple{ks}(At.(scenario[k] for k in ks))
    # Retrieve the desired slice of hypercube.
    slice = cube[:, :, coordinates...]
    # Turn this into a DataFrame.
    datedict = OrderedDict(:date => collect(dims(slice)[1].val))
    outvardict = OrderedDict( key => collect(slice[:, At(key)])
                              for key in dims(slice)[2] )
    d = merge(datedict, outvardict)
    # Deliver.
    return DataFrame(d)
end

function tostring(d)
    kvs = [ string(k, " = ", v) for (k, v) in d ]
    s = "["
    for kv in kvs
        s = string(s, " ", kv, " |")
    end
    s = s[1:end-1]
    s = string(s, "]")
    return s
end

function scenariostack(cube::DimArray, stack::Vector{Scenario})
    return OrderedDict(tostring(s) => scenarioslice(cube, s) for s in stack)
end

function writecube(fname::String, cube::DimArray; numpy=true)
    # Extract the array from the DimArray.
    cube = cube |> parent
    # Reverse order of axes for NumPy compatibility if requested.
    if numpy
        cube = permutedims(cube, collect(ndims(cube):-1:1))
    end
    # Write the HDF5 file.
    h5write(fname, "hcube", cube)
end

function writeaxes(fname::String, cube::DimArray)
    # First write a CSV with the axis names.
    CSV.write( string(fname, "-axes", ".csv")
             , Dict(:axis=>collect(keys(cubeaxes(cube)))))
    # Then write CSVs for each of the axes.
    for (axis, entry) in cubeaxes(cube)
        CSV.write(string(fname, "-", axis, ".csv"), Dict(axis => entry))
    end
end
