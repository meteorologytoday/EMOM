using Formatting
using NCDatasets

function loadData(
    datafiles :: Dict,
    varnames :: AbstractArray{String, 1},
    y :: Int64,
    m :: Int64,
    d :: Int64,
)

    key = format("{:04d}-{:02}", y, m)

    full_path = datafiles[key][:fp]

    ds = Dataset(full_path, "r")

    data = Dict()

    for varname in varnames

        v = ds[varname]
        dim = length(size(v))

        if dim == 4
            rng = (:, :, :, d)
        elseif dim == 3
            rng = (:, :, d)
        else
            throw(ErrorException("Unknown dimension: $(dim) of variable $(varname) in file $(full_path)"))
        end

        data[varname] = nomissing(ds[varname][rng...], NaN)
    end
    close(ds)

    return data

end
