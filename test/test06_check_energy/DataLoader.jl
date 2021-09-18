module DataLoader

    using CFTime, Dates
    using NCDatasets
    using DataStructures
    using Formatting


    mutable struct DataLoaderInfo
        data_dict :: Dict
        state_varnames  :: Array
        forcing_varnames :: Array
        joint_varnames   :: Array
        layers :: Union{Colon, UnitRange}
        year_rng  :: Array{Integer}

        function DataLoaderInfo(;
            hist_dir :: String,
            casename :: String,
            state_varnames :: Array,
            forcing_varnames :: Array,
            year_rng :: Array{Int64, 1},
            layers :: Union{Colon, UnitRange} = Colon(),
        )

            joint_varnames = Array{String}(undef,0)
            append!(joint_varnames, state_varnames, forcing_varnames)

            println(joint_varnames)

            data_dict = makeDataDict(
                hist_dir,
                casename,
                joint_varnames,
                year_rng;
                verbose = true,
            )


            return new(
                data_dict,
                state_varnames,
                forcing_varnames,
                joint_varnames,
                layers,
                year_rng,
            )

        end
    end

    function makeDataDict(
        hist_dir :: String,
        casename :: String,
        varnames :: Array{String, 1},
        year_rng :: Array{Int64, 1};
        verbose :: Bool = false,
    )

        expect_filenames = DataStructures.OrderedDict()

        println("I will also check a month prior to the begin year because we are using 12/31 of previous year as initial profile.")
        
        for y=(year_rng[1]-1):(year_rng[2]+1), m=1:12
            
            if (y == year_rng[1] - 1 && m != 12) || (y == year_rng[2]+1 && m != 1)
                continue
            end

            key = format("{:04d}-{:02d}", y, m)


            filename = format("$(casename).pop.h.daily.{:04d}-{:02d}-01.nc", y, m)
            full_path = joinpath(hist_dir, filename)
            verbose && println("Checking $(key)")

            if ! isfile(full_path)
                throw(ErrorException("Error: File $(filename) does not exist in folder $(hist_dir)."))
            end

            ds = Dataset(full_path, "r")
            dom = daysinmonth(DateTimeNoLeap, y, m)
            if ds.dim["time"] != dom
                throw(ErrorException("Error: File $(filename) does not have $(dom) records."))
            end

            for varname in varnames
                if ! haskey(ds, varname)
                    throw(ErrorException("Error: File $(filename) does not have variable `$(varname)`."))
                end
            end
            close(ds)

            expect_filenames[key] = Dict(
                :fp => full_path,
                :fn => filename,
                :y => y,
                :m => m,
            )


        end
            
        return expect_filenames

    end

    function getYMD(t::AbstractCFDateTime)
        return Dates.year(t), Dates.month(t), Dates.day(t)
    end

    function loadDataByDate(
        dli :: DataLoaderInfo,
        t   :: AbstractCFDateTime;
    )

        y, m, d = getYMD(t)

        key = format("{:04d}-{:02d}", y, m)

        full_path = dli.data_dict[key][:fp]

        ds = Dataset(full_path, "r")

        data = Dict()

        for varname in dli.joint_varnames

            v = ds[varname]
            dim = length(size(v))

            if dim == 4
                rng = (:, :, dli.layers, d)
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

    function loadInitDataAndForcing(
        dli :: DataLoaderInfo,
        t   :: AbstractCFDateTime,
    )

        t_curr = t
        data = loadDataByDate(dli, t_curr)

        t_prev = t_curr - Second(86400) 
        data_prev = loadDataByDate(dli, t_prev)
        
        for varname in dli.state_varnames
            var      = data[varname]
            var_prev = data_prev[varname]

            @. var = (var + var_prev) / 2.0
        end

        return data

    end


end
