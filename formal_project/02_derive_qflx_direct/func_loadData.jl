using Formatting
using NCDatasets

function _loadData(
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

function loadData(
    datafiles :: AbstractDict,
    varnames :: AbstractArray{String},
    t      :: AbstractCFDateTime,
    layers :: Union{UnitRange, Colon} = Colon(),
)

    t_curr = t
    data = loadData(
        OGCM_files,
        cdata_varnames,
        Dates.year(t_curr),
        Dates.month(t_curr),
        Dates.day(t_curr);
        layers = layers, 
    )

    t_prev = t_curr - Second(86400) 
    data_prev = loadData(
        OGCM_files,
        cdata_varnames,
        Dates.year(t_prev),
        Dates.month(t_prev),
        Dates.day(t_prev);
        layers = layers, 
    )

    for varname in keys(data)
        var      = data[varname]
        var_prev = data_prev[varname]

        @. var = (var + var_prev) / 2.0
    end

    return data

end
