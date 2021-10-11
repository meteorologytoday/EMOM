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
varnames = "HMXL,TEMP,SALT,TAUX,TAUY,SHF,SHF_QSW,SFWF"
year_rng      = format( "{:04d}-{:04d}",  beg_year, end_year )
year_rng_eval = format( "{:04d}..{:04d}",  beg_year, end_year )

ref_file="$(in_dir)/$(casename).pop.h.$(format("{:04d}", beg_year))-01.nc"

out_dir="./output_$(year_rng)_layers$(layers)"
coord_file="$(out_dir)/coord.nc"
time_file="$(out_dir)/time.nc"


if isdir(out_dir)
    throw(ErrorException("ERROR: directory $(out_dir) already exists."))
end

#pleaseRun(`rm -rf $(out_dir)`)

pleaseRun(`mkdir -p $(out_dir)`)
pleaseRun(`julia make_monthly_time.jl --output $(time_file) --years $( end_year - beg_year + 1 )`)

println("Output directory: $(out_dir)")

pleaseRun(`ncks -O -F -v $coord -d z_t,1,$(layers) -d z_w_top,1,$(layers) -d z_w_bot,1,$(layers) -d z_w,1,$(layers) $ref_file $coord_file`)
pleaseRun(`ncap2 -O -s 'z_t=-z_t/100.0;z_w_top=-z_w_top/100.0;z_w_bot=-z_w_bot/100.0;z_w=-z_w/100.0' $coord_file $coord_file`)

output_files = Dict()

for varname in split(varnames, ",")
    output_file = "$(out_dir)/$(varname).nc"
    output_files[varname] = output_file

    println("Concatnating var: $varname to $(output_file)")

    if varname != "HMXL"
        pleaseRun(`bash -c "ncrcat -O -F -v $(varname) -d z_t,1,$(layers) -d z_w_top,1,$(layers) -d z_w_bot,1,$(layers) $(in_dir)/$(casename).pop.h.{$(year_rng_eval)}-{01..12}.nc $(output_file)"`)
    else

        # HMXL was output in daily. So we have to average it to monthly

        mkpath("tmp_HMXL")
        for y=beg_year:end_year, m=1:12
            timestr = format("{:04d}-{:02d}", y, m)
            pleaseRun(`ncra -O -F -v HMXL $(in_dir)/$(casename).pop.h.nday1.$(timestr)-01.nc tmp_HMXL/HMXL_$(timestr).nc`)
        end
        pleaseRun(`bash -c "ncrcat -O -F -v HMXL tmp_HMXL/HMXL_{$(year_rng_eval)}-{01..12}.nc $(output_file)"`)

        

    end

end

println("Converting forcing for IOM...")

for varname in ["VSFLX", "HMXL", "SWFLX", "NSWFLX"]
    output_files[varname] = "$(out_dir)/$(varname).nc"
end

pleaseRun(`ncap2 -O -v -s 'VSFLX=SFWF;'      $(output_files["SFWF"]) $(output_files["VSFLX"])`)
pleaseRun(`ncap2 -O -v -s 'HMXL=HMXL/100.0;' $(output_files["HMXL"]) $(output_files["HMXL"])`)
pleaseRun(`ncap2 -O -v -s 'TAUX=TAUX/10.0;'  $(output_files["TAUX"]) $(output_files["TAUX"])`)
pleaseRun(`ncap2 -O -v -s 'TAUY=TAUY/10.0;'  $(output_files["TAUY"]) $(output_files["TAUY"])`)
pleaseRun(`ncap2 -O -v -s 'SWFLX=-SHF_QSW;'  $(output_files["SHF_QSW"]) $(output_files["SWFLX"])`)

pleaseRun(`ncks  -O    -v SHF                      $(output_files["SHF"])     $(output_files["NSWFLX"])`)
pleaseRun(`ncks     -A -v SHF_QSW                  $(output_files["SHF_QSW"]) $(output_files["NSWFLX"])`)
pleaseRun(`ncap2 -O -v -s 'NSWFLX=-(SHF-SHF_QSW);' $(output_files["NSWFLX"])  $(output_files["NSWFLX"])`)


for (_, output_file) in output_files
    println(coord_file, "; ", output_file)
    pleaseRun(`ncks -A -v $coord         $coord_file $output_file`)
    pleaseRun(`ncks -A -v time,time_bound $time_file $output_file`)
end


println("Doing monthly mean:")

out_dir_monthly = "./$(out_dir)/monthly"
tmp_dir = "$(out_dir_monthly)/tmp"
mkpath(tmp_dir)

a_year_time_file = "$(tmp_dir)/time.nc"

pleaseRun(`julia make_monthly_time.jl --output $(a_year_time_file) --years 1`)
    
output_files_monthly = Dict()
for varname in keys(output_files)

    println("Doing variable $(varname)")

    output_files_monthly[varname] = "$(out_dir_monthly)/$(varname)_monthly.nc"

    for m = 1:12
        pleaseRun(`ncra -O -F -d time,$(m),,12 $(output_files[varname]) $tmp_dir/$(varname)_$(format("{:02d}", m)).nc`)
    end
    
    pleaseRun(`bash -c "ncrcat -O -F $tmp_dir/$(varname)_{01..12}.nc $(output_files_monthly[varname])"`)
    pleaseRun(`ncks -A -v time,time_bound $a_year_time_file $(output_files_monthly[varname])`)

end

rm(tmp_dir, recursive=true, force=true)



println("All done.")
