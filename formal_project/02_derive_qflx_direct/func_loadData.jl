using Formatting
using NCDatasets

function loadData(
    datafiles :: AbstractDict,
    varnames :: AbstractArray{String},
    y :: Int64,
    m :: Int64,
    d :: Int64;
    layers :: Union{UnitRange, Colon} = Colon(),
)

    key = format("{:04d}-{:02d}", y, m)

    full_path = datafiles[key][:fp]

    ds = Dataset(full_path, "r")

    data = Dict()

    for varname in varnames

        v = ds[varname]
        dim = length(size(v))

        if dim == 4
            rng = (:, :, layers, d)
        elseif dim == 3
            rng = (:, :, d)
        else
            throw(ErrorException("Unknown dimension: $(dim) of variable $(varname) in file $(full_path)"))
        end

        data[varname] = nomissing(ds[varname][rng...], NaN)

        if dim == 4
            data[varname] = permutedims(data[varname], [3, 1, 2])
        end
    end
    close(ds)

    return data

end
