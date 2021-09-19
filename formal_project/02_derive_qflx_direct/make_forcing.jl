using Formatting
using ArgParse, JSON
using NCDatasets

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

function makeTimeFile(output_file, years)

    dom = [31.0, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    sum_dom = sum(dom)
    sum_dom == 365 || throw(ErrorException("Sum of dom is $(sum_dom) rather than 365."))

    _t    = zeros(Float64, length(dom))
    _bnds = zeros(Float64, 2, length(dom))

    for m=1:length(dom)
        #bnds[m, 1] = beg of month  m
        #bnds[m, 2] = end of month  m
        if m==1
            _bnds[1, m] = 0.0
        else
            _bnds[1, m] = _bnds[2, m-1]
        end

        _bnds[2, m] = _bnds[1, m] + dom[m]

        _t[m] = (_bnds[1, m] + _bnds[2, m]) / 2.0
    end

    t    = zeros(Float64, 12 * years)
    bnds = zeros(Float64, 2, 12 * years)


    for y = 1:years
        i_offset = (y-1)*12
        t_offset = (y-1)*sum_dom
        t[i_offset+1:i_offset+12]       .+= _t    .+ t_offset
        bnds[:, i_offset+1:i_offset+12] .+= _bnds .+ t_offset
    end

    Dataset(output_file, "c") do ds

        defDim(ds, "time", Inf)
        defDim(ds, "d2", 2)

        defVar(ds, "time", t, ("time", ), ; attrib = Dict(
            "long_name" => "time",
            "bounds"    => "time_bound",
            "calendar"  =>  "noleap",
            "units"     => "days since 0001-01-01 00:00:00",
        ))

        defVar(ds, "time_bound", bnds, ("d2", "time"), ; attrib = Dict(
            "long_name" => "boundaries for time-averaging interval",
            "units"     => "days since 0001-01-01 00:00:00",
        ))
    end
end


function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--hist-dir"
            help = "Casename"
            arg_type = String
            required = true

        "--data-dir"
            help = "Casename"
            arg_type = String
            required = true

        "--year-rng"
            help = "Casename"
            arg_type = Int64
            nargs    = 2
            required = true



    end

    return parse_args(s)
end

parsed = parse_commandline()

JSON.print(parsed,4)

beg_yr, end_yr = parsed["year-rng"]
println("Beg year: $(beg_yr)")
println("End year: $(end_yr)")

yr_rng_str  = format( "{:04d}-{:04d}", beg_yr, end_yr )
yr_rng_eval = format( "{:04d}..{:04d}", beg_yr, end_yr )


output_file = "$(parsed["data-dir"])/forcing_cyclic.nc"

println("Make time file: tmp_time.nc")
makeTimeFile("tmp_time.nc", 1)


println("Making mean profile")

mkpath("tmp")
for m = 1:12
    m_str = format( "{:02d}", m)
    pleaseRun(`bash -c "ncra -v WKRSTT,WKRSTS,dz_cT,area_sT -O $(parsed["hist-dir"])/*.h0.*.{$(yr_rng_eval)}-$(m_str).nc tmp/monthly_mean_$(m_str).nc"`)
end

println("Output file : $(output_file)")
pleaseRun(`bash -c "ncrcat -O tmp/monthly_mean_{01..12}.nc $output_file"`)
pleaseRun(`ncks -O -3 $output_file $output_file`)
pleaseRun(`ncrename -d Nx,nlon -d Ny,nlat -d Nz,z_t -v WKRSTT,QFLX_TEMP -v WKRSTS,QFLX_SALT $output_file`)
pleaseRun(`ncap2 -O -s 'QFLX_TEMP=QFLX_TEMP*3996*1026;' $output_file $output_file`)
pleaseRun(`ncks -A -v SALT,z_w_top,z_w_bot  $(parsed["data-dir"])/monthly/SALT_monthly.nc $output_file`)
pleaseRun(`ncks -A -v TEMP                  $(parsed["data-dir"])/monthly/TEMP_monthly.nc $output_file`)
pleaseRun(`ncks -A -v HMXL                  $(parsed["data-dir"])/monthly/HMXL_monthly.nc $output_file`)
pleaseRun(`ncks -A -v time                  tmp_time.nc $output_file`)
rm("tmp_time.nc", force=true)

