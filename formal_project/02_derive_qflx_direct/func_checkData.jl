using Formatting
using CFTime, Dates
using DataStructures
using NCDatasets

function checkData(
    hist_dir :: String,
    casename :: String,
    varnames :: Array{String, 1},
    year_rng :: Array{Int64, 1};
    verbose :: Bool = false,
)

    expect_filenames = DataStructures.OrderedDict()

    println("I will also check a month prior to the begin year because we are using 12/31 of previous year as initial profile.")
    
    for y=(year_rng[1]-1):year_rng[2], m=1:12
        
        if y == year_rng[1] - 1 && m != 12
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

