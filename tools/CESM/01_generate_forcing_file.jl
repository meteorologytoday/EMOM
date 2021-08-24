using ArgParse
using Formatting
using NCDatasets
using JSON

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--POP2-monthly-profile"
            help = "POP2 ocean output monthly profile used as forcing. It is currently assume the data is centered at the middle of each month."
            arg_type = String
            required = true

        "--n-layers"
            help = "The number of vertical layers that is going to be output."
            arg_type = Int64
            required = true

        "--domain-file"
            help = "The CESM domain file that is consistent with the `--POP2-monthly-profile`."
            arg_type = String
            required = true
        
        "--output-dir"
            help = "Output directory"
            arg_type = String
            required = true

        "--output-forcing-file"
            help = "Output forcing file name."
            arg_type = String
            default = ""


    end

    return parse_args(s)
end

parsed = parse_commandline()

JSON.print(parsed, 4)

mkpath(parsed["output-dir"])

# First, determine output file name
if parsed["output-forcing-file"] == ""
    parsed["output-forcing-file"] = format("{:s}.{:d}-layers.nc", splitext(basename(parsed["POP2-monthly-profile"]))[1], parsed["n-layers"])
end

output_file = joinpath(parsed["output-dir"], parsed["output-forcing-file"])

println("# Output forcing file is going to be: ", output_file)

# Second, check if vairables exist
vars_check = ["z_t", "z_w_top", "z_w_bot", "TEMP", "SALT", "SHF", "SHF_QSW", "SFWF", "HBLT", "TAUX", "TAUY", "time_bound"]

println("# Check if the following variables exist: ", join(vars_check, ", "))

Dataset(parsed["POP2-monthly-profile"], "r") do ds
    local missing_vars = []
    for varname in vars_check
        if ! haskey(ds, varname)
            push!(missing_vars, varname)
        end
    end

    if length(missing_vars) != 0
        println("Error: The following variables are missing: ", join(missing_vars, ", "))
        throw(ErrorException("Please check variables in the input file."))
    else
        println("All the variables are found.")
    end

    if ds.dim["time"] != 12
        throw(ErrorException("I expect dimension of time = 12."))
    end
    
end

function pleaseRun(cmd)
    println(">> ", string(cmd))
    run(cmd)
end

pleaseRun(`
ncks -O -F -d z_t,1,$(parsed["n-layers"]) 
        -d z_w_top,1,$(parsed["n-layers"]) 
        -d z_w_bot,1,$(parsed["n-layers"]) 
       $(parsed["POP2-monthly-profile"]) $(output_file)
`)

pleaseRun(`
ncap2 -O -v -s 'time_bound=time_bound;'  
            -s 'z_t=-z_t/100.0;'         
            -s 'z_w_top=-z_w_top/100.0;' 
            -s 'z_w_bot=-z_w_bot/100.0;' 
            -s 'TEMP=TEMP;'              
            -s 'SALT=SALT;'              
            -s 'SWFLX=-SHF_QSW;'         
            -s 'NSWFLX=-(SHF-SHF_QSW);'  
            -s 'VSFLX=SFWF;'             
            -s 'HMXL=HBLT/100.0;'        
            -s 'TAUX=TAUX/10.0;'         
            -s 'TAUY=TAUY/10.0;'         
             $(output_file) $(output_file)
`)


pleaseRun(`
ncatted -a units,time,m,c,"days since 0001-01-01 00:00:00"
        -a units,time_bound,m,c,"days since 0001-01-01 00:00:00"
        $(output_file)
`)

pleaseRun(`
ncrename -d nlat,Ny -d nlon,Nx -d z_t,Nz $(output_file)
`)


Dataset(output_file, "r") do ds
    
    local TEMP  = permutedims(nomissing(ds["TEMP"][:, :, :, 1],  NaN), [3, 1, 2])
    local Nz, Nx, Ny = size(TEMP)


    z_w_top = nomissing(ds["z_w_top"][:], NaN) 
    z_w_bot = nomissing(ds["z_w_bot"][:], NaN) 

    local z_w = zeros(Float64, length(z_w_top)+1)
    z_w[1:end-1] = z_w_top
    z_w[end] = z_w_bot[end]

    Dataset(joinpath(parsed["output-dir"], "z_w.nc"), "c") do _ds

        defDim(_ds, "Nzp1", length(z_w))
        defVar(_ds, "z_w", z_w, ("Nzp1", ), ; attrib = Dict(
            "long_name" => "Vertical coordinate on W-grid",
            "units"     => "m",
        ))

    end


    mask_T = zeros(Float64, Nz, Nx, Ny)
    mask_T[isfinite.(TEMP)] .= 1.0
    valid_idx = mask_T .== 1.0
    local Nz_bot = convert(Array{Int64}, sum(mask_T, dims=1)[1, :, :])
    
    Dataset(joinpath(parsed["output-dir"], "Nz_bot.nc"), "c") do _ds
        defDim(_ds, "Nx", Nx)
        defDim(_ds, "Ny", Ny)
        defVar(_ds, "Nz_bot", Nz_bot, ("Nx", "Ny", ), ; attrib = Dict(
            "long_name" => "z-grid idx of the deepest cell",
            "units"     => "none",
        ))

    end


end

