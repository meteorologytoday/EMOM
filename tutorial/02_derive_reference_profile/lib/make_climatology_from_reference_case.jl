using Formatting
using ArgParse
using DataStructures, JSON

println("""
This program generates the TEMP SALT daily mean and five-day mean profiles from a referenced
POP2 output. These output are meant to used for Q-flux finding.
""")


s = ArgParseSettings()
@add_arg_table s begin

    "--hist-dir"
        help = "The directory that contains POP2 outputs."
        arg_type = String
        required = true

    "--casename"
        help = "Casename"
        arg_type = String
        required = true

    "--output-dir"
        help = "The directory this program outputs to."
        arg_type = String
        default = "output"

    "--year-rng"
        help = "The range of the years. It accepts exactly two integer numbers."
        arg_type = Int64
        nargs = 2
        required = true

    "--layers"
        help = "The layers cropped. For EMOM, default it uses only top 33 layers of POP2."
        arg_type = Int64
        default = 33


end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)

function runOneCmd(cmd)
    println(">> ", string(cmd))
    run(cmd)
end

function pleaseRun(cmd)
    if isa(cmd, Array)
        for i = 1:length(cmd)
            runOneCmd(cmd[i])
        end
    else
        runOneCmd(cmd)
    end
end

casename = parsed["casename"]
beg_year = parsed["year-rng"][1]
end_year = parsed["year-rng"][2]

println("Begin year: $(beg_year)")
println("End   year: $(end_year)")

layers = parsed["layers"]
in_dir = parsed["hist-dir"]

coord = "z_t,z_w,z_w_top,z_w_bot,TAREA"

varnames_daily   = ["HMXL", "TEMP", "SALT"]
varnames_monthly = ["UVEL", "VVEL"]

all_varnames = copy(varnames_daily)
append!(all_varnames, varnames_monthly)

fileformats = Dict(
    "TEMP" => "{}.pop.h.nday1.{}-{}-01.nc",
    "SALT" => "{}.pop.h.nday1.{}-{}-01.nc",
    "HMXL" => "{}.pop.h.nday1.{}-{}-01.nc",
    "UVEL" => "{}.pop.h.{}-{}.nc",
    "VVEL" => "{}.pop.h.{}-{}.nc",
)

year_rng      = format( "{:04d}-{:04d}",  beg_year, end_year )
year_rng_eval = format( "{{{:04d}..{:04d}}}",  beg_year, end_year )

ref_file = joinpath(in_dir, format(fileformats["TEMP"], casename, format("{:04d}", beg_year), "01"))

out_dir  = parsed["output-dir"]
fivedays_mean_dir = "$(out_dir)/fivedays_mean"
monthly_mean_dir = "$(out_dir)/monthly"
mkpath(fivedays_mean_dir)
mkpath(monthly_mean_dir)

coord_file="$(out_dir)/coord.nc"
daily_time_file="$(out_dir)/time_daily.nc"
monthly_time_file="$(out_dir)/time_monthly.nc"

if isdir(out_dir)
    throw(ErrorException("ERROR: directory $(out_dir) already exists."))
end

pleaseRun(`mkdir -p $(out_dir)`)
pleaseRun(`julia $(@__DIR__)/make_daily_time.jl --output $(daily_time_file) --years 1`)
pleaseRun(`julia $(@__DIR__)/make_monthly_time.jl --output $(monthly_time_file) --years 1`)

println("Output directory: $(out_dir)")

pleaseRun(`ncks -O -F -v $coord -d z_t,1,$(layers) -d z_w_top,1,$(layers) -d z_w_bot,1,$(layers) -d z_w,1,$(layers) $ref_file $coord_file`)
pleaseRun(`ncap2 -O -s 'z_t=-z_t/100.0;z_w_top=-z_w_top/100.0;z_w_bot=-z_w_bot/100.0;z_w=-z_w/100.0' $coord_file $coord_file`)

output_files = Dict()
output_monthly_files = Dict()

for varname in all_varnames

    output_file = "$(out_dir)/$(varname).nc"
    output_files[varname] = output_file
 
    output_monthly_file = "$(monthly_mean_dir)/$(varname).nc"
    output_monthly_files[varname] = output_monthly_file
    
    println("Averaging var: $varname to $(output_file) and $(output_monthly_file)")

    tmp_dir = "tmp_$(varname)" 
    mkpath(tmp_dir)
    
    fileformat = fileformats[varname]
    filenames = []
    monthly_filenames = []

    for m=1:12
        
        m_str = format("{:02d}", m)
        tmp_file = "$(tmp_dir)/$(varname)_$(m_str).nc"
        tmp_monthly_file = "$(tmp_dir)/$(varname)_monthly_$(m_str).nc"
        files = format(fileformat, casename, year_rng_eval, m_str)
        files = "$in_dir/$files"
        pleaseRun(`bash -c "ncea -O -F -d z_t,1,$(layers) -d z_w_top,1,$(layers) -d z_w_bot,1,$(layers) -v $varname $files $tmp_file"`)
        pleaseRun(`bash -c "ncra -O -F -d z_t,1,$(layers) -d z_w_top,1,$(layers) -d z_w_bot,1,$(layers) -v $varname $tmp_file $tmp_monthly_file"`)

        push!(filenames, tmp_file)
        push!(monthly_filenames, tmp_monthly_file)
    end

    pleaseRun(`bash -c "ncrcat -O -F $(join(filenames, " ")) $(output_file)"`)
    pleaseRun(`bash -c "ncrcat -O -F $(join(monthly_filenames, " ")) $(output_monthly_file)"`)
    
    rm(tmp_dir, recursive=true, force=true)
end

println("Converting units...")
pleaseRun(`ncap2 -O -v -s 'HMXL=HMXL/100.0;' $(output_files["HMXL"]) $(output_files["HMXL"])`)

for varname in varnames_daily
    output_file = output_files[varname]
    println(coord_file, "; ", output_file)
    pleaseRun(`ncks -A -v $coord         $coord_file $output_file`)
    pleaseRun(`ncks -A -v time,time_bound $daily_time_file $output_file`)
end

for varname in varnames_monthly
    output_file = output_files[varname]
    println(coord_file, "; ", output_file)
    pleaseRun(`ncks -A -v $coord         $coord_file $output_file`)
    pleaseRun(`ncks -A -v time,time_bound $monthly_time_file $output_file`)
end


# Get surface U and V
for (varname, old_output_file) in output_monthly_files
    if varname in ["UVEL", "VVEL"]

        new_varname = Dict(
            "UVEL" => "USFC",
            "VVEL" => "VSFC",
        )[varname]

        new_output_file = "$(monthly_mean_dir)/$(new_varname).nc"

        pleaseRun(`bash -c "ncks -O -F -d z_t,1,1 -v $(varname) $(old_output_file) $(new_output_file)"`)
        pleaseRun(`bash -c "ncrename -v $(varname),$(new_varname) $(new_output_file)"`)
        output_files[new_varname] = new_output_file
    end
end

println("Doing 5 day mean of variables: ", join(varnames_daily, ","))
fivedays_mean_dir = "$(out_dir)/fivedays_mean"
for varname in varnames_daily
    daily_output_file = output_files[varname]
    fivedays_mean_output_file = "$(fivedays_mean_dir)/$(varname).nc"
    println("$daily_output_file => $fivedays_mean_output_file")
    pleaseRun(`ncra --mro -d time,0,,5,5 $daily_output_file $fivedays_mean_output_file`)
end



println("All done.")
