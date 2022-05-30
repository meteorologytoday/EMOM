using Formatting
using ArgParse
using DataStructures, JSON

s = ArgParseSettings()
@add_arg_table s begin

    "--casename"
        help = "Casename"
        arg_type = String
        required = true

    "--year-rng"
        help = "How many years?"
        arg_type = Int64
        nargs = 2
        required = true

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


layers = 33
in_dir = "/glade/u/home/tienyiao/scratch-tienyiao/archive/$(casename)/ocn/hist"

coord = "z_t,z_w,z_w_top,z_w_bot,TAREA"
varnames = "HMXL,TEMP,SALT"
year_rng      = format( "{:04d}-{:04d}",  beg_year, end_year )
year_rng_eval = format( "{:04d}..{:04d}",  beg_year, end_year )

ref_file="$(in_dir)/$(casename).pop.h.daily.$(format("{:04d}", beg_year))-01-01.nc"

out_dir="./output_$(year_rng)_layers$(layers)_daily"
coord_file="$(out_dir)/coord.nc"
time_file="$(out_dir)/time.nc"


if isdir(out_dir)
    throw(ErrorException("ERROR: directory $(out_dir) already exists."))
end

pleaseRun(`mkdir -p $(out_dir)`)
pleaseRun(`julia make_daily_time.jl --output $(time_file) --years 1`)

println("Output directory: $(out_dir)")

pleaseRun(`ncks -O -F -v $coord -d z_t,1,$(layers) -d z_w_top,1,$(layers) -d z_w_bot,1,$(layers) -d z_w,1,$(layers) $ref_file $coord_file`)
pleaseRun(`ncap2 -O -s 'z_t=-z_t/100.0;z_w_top=-z_w_top/100.0;z_w_bot=-z_w_bot/100.0;z_w=-z_w/100.0' $coord_file $coord_file`)

output_files = Dict()

for varname in split(varnames, ",")

    output_file = "$(out_dir)/$(varname).nc"
    output_files[varname] = output_file
    
    println("Averaging var: $varname to $(output_file)")

    tmp_dir = "tmp_$(varname)" 
    mkpath(tmp_dir)
    
    filenames = []
    for m=1:12
        
        m_str = format("{:02d}", m)
        tmp_file = "$(tmp_dir)/$(varname)_$(m_str).nc"
        pleaseRun(`bash -c "ncea -O -F -d z_t,1,$(layers) -d z_w_top,1,$(layers) -d z_w_bot,1,$(layers) -v $varname $(in_dir)/$(casename).pop.h.daily.{$(year_rng_eval)}-$(m_str)-01.nc $tmp_file"`)

        push!(filenames, tmp_file)
    end

    pleaseRun(`bash -c "ncrcat -O -F $(join(filenames, " ")) $(output_file)"`)
    
    rm(tmp_dir, recursive=true, force=true)
end

println("Converting forcing for IOM...")
pleaseRun(`ncap2 -O -v -s 'HMXL=HMXL/100.0;' $(output_files["HMXL"]) $(output_files["HMXL"])`)

for (_, output_file) in output_files
    println(coord_file, "; ", output_file)
    pleaseRun(`ncks -A -v $coord         $coord_file $output_file`)
    pleaseRun(`ncks -A -v time,time_bound $time_file $output_file`)
end


println("Doing 5 day mean")
fivedays_mean_dir = "$(out_dir)/fivedays_mean"
mkpath(fivedays_mean_dir)
for (varname, daily_output_file) in output_files
    fivedays_mean_output_file = "$(fivedays_mean_dir)/$(varname).nc"
    println("$daily_output_file => $fivedays_mean_output_file")
    pleaseRun(`ncra --mro -d time,0,,5,5 $daily_output_file $fivedays_mean_output_file`)
end



println("All done.")
