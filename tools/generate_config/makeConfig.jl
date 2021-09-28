using NCDatasets

using ArgParse, JSON
function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--casename"
            help = "Casename"
            arg_type = String
            default = "Sandbox"


        "--domain-file"
            help = "Horizontal domain file containing z_w_top, z_w_bot in meters with z=0 is the surface."
            arg_type = String
            required = true


        "--zdomain-file"
            help = "Vertical domain file containing z_w_top, z_w_bot in meters with z=0 is the surface."
            arg_type = String
            required = true

        "--topo-file"
            help = "File containing Nz_bot."
            arg_type = String
            required = true

        "--forcing-file-HMXL"
            help = "The forcing file"
            arg_type = String
            default = ""

        "--forcing-file-TEMP"
            help = "The forcing file"
            arg_type = String
            default = ""

        "--forcing-file-SALT"
            help = "The forcing file"
            arg_type = String
            default = ""

        "--forcing-file-QFLXT"
            help = "The forcing file"
            arg_type = String
            default = ""

        "--forcing-file-QFLXS"
            help = "The forcing file"
            arg_type = String
            default = ""

        "--forcing-time"
            help = "Beg, end, align"
            arg_type = String
            nargs = 3
            required = true


        "--init-file"
            help = "The init ocean file."
            arg_type = String
            required = true


        "--ocn-model"
            help = "The name of ocean model. Can be: `SOM`, `MLM`, `EOM` and `EMOM`"
            arg_type = String
            required = true

        "--output-filename"
            help = "The output file name of config in TOML format."
            arg_type = String
            default = "config.toml"

        "--output-path"
            help = "The output path. Default is the same as RUNDIR in env_run.xml"
            arg_type = String
            default = ""

        "--finding-QFLX-timescale"
            help = "If this is set to a real number, finding QFLX mode is on. And timescale is in days."
            arg_type = Float64
            default = NaN




        "--project-root"
            help = "Project root directory."
            arg_type = String
            default = ""

        "--domain-file"
            help = "Horizontal domain file."
            arg_type = String
            required = true

        "--domain-file"
            help = "Horizontal domain file."
            arg_type = String
            required = true


        "--zdomain-file"
            help = "Vertical domain file containing z_w_top, z_w_bot in meters with z=0 is the surface."
            arg_type = String
            required = true

        "--ref-clim-dir"
            help = "The directory containing reference climate data."
            arg_type = String
            required = true

        "--ocn-model"
            help = "The name of ocean model. Can be: `SOM`, `MLM`, `EOM` and `EMOM`"
            arg_type = String
            required = true

    end

    return parse_args(s)
end

parsed = parse_commandline()

JSON.print(parsed,4)

if parsed["project-root"] == ""
    parsed["project-root"] = @__DIR__
end

project_root_dir = parsed["project-root"]

casename = "$(parsed["casename"])"

# Not to confuse casedir with caseroot.
# `casedir` is where I put everything of a casename data inside.
# `caseroot` is in cesm's framework where configuration are stored.
case_dir = joinpath(project_root_dir, casename)
inputdata_dir = joinpath(case_dir, "inputdata")

cdata_var_file_map = Dict()

for varname in ["TEMP", "SALT", "HMXL", "QFLX_TEMP", "QFLX_SALT"]
    cdata_var_file_map[varname] = "$(parsed["ref-clim-dir"])/$(varname).nc"
end

Qflx = "on"
τwk_TEMP = 86400.0 * 365 * 1000
τwk_SALT = 86400.0 * 365 * 1

if parsed["ocn-model"] == "SOM"
    println("You are configuring SOM where topography is set to the mixed-layer thickness. Remember that Nz_bot should be consistent.")
    convective_adjustment = "off"
    Ks_V = 0.0
    advection_scheme = "static"
elseif parsed["ocn-model"] == "MLM"
    convective_adjustment = "on"
    Ks_V = 1e-4
    advection_scheme = "static"
elseif parsed["ocn-model"] == "EMOM"
    convective_adjustment = "on"
    Ks_V = 1e-4
    advection_scheme = "ekman_CO2012"
end

config = Dict{Any, Any}(

    "DRIVER" => Dict(
        "casename"           => casename,
        "caseroot"           => joinpath(case_dir, "caseroot"),
        "caserun"            => joinpath(case_dir, "caserun"),
        "archive_root"       => joinpath(case_dir, "archive"),
    ),

    "MODEL_MISC" => Dict(
        "timetype"               => "DateTimeNoLeap",
        "init_file"              => joinpath(inputdata_dir, "init_ocn.jld2"),
        "rpointer_file"          => "rpointer.iom",
        "daily_record"           => [],
        "monthly_record"         => ["{ESSENTIAL}", "QFLX_TEMP", "QFLX_SALT"],
        "enable_archive"         => true,
    ),

    "MODEL_CORE" => Dict(

        "domain_file"                  => parsed["domain-file"],
        "topo_file"                    => joinpath(inputdata_dir, "Nz_bot.nc"),
        "cdata_var_file_map"           => cdata_var_file_map,

        "cdata_beg_time"               => "0001-01-01 00:00:00",
        "cdata_end_time"               => "0051-01-01 00:00:00",
        "cdata_align_time"             => "0001-01-01 00:00:00",

        "z_w"                          => nothing,

        "substeps"                     => 8,
        "MLD_scheme"                   => "datastream",
        "Qflx"                         => "$(Qflx)",
        "convective_adjustment"        => "$(convective_adjustment)",
        "advection_scheme"             => "$(advection_scheme)",

        "weak_restoring"               => "on",
        "τwk_TEMP"                     => τwk_TEMP,
        "τwk_SALT"                     => τwk_SALT,


        "Ekman_layers"                 => 5,
        "Returnflow_layers"            => 28,
    
        "transform_vector_field"       => true,
    ),

)

Dataset(parsed["zdomain-file"], "r") do ds

    z_w_top = nomissing(ds["z_w_top"][:], NaN)
    z_w_bot = nomissing(ds["z_w_bot"][:], NaN)

    z_w      = zeros(Float64, length(z_w_top)+1)
    z_w[1:end-1]   = z_w_top
    z_w[end] = z_w_bot[end]

    global config["MODEL_CORE"]["z_w"]  = z_w
end


println("Making necessary folders...")
mkpath(inputdata_dir)
mkpath(config["DRIVER"]["caseroot"])
mkpath(config["DRIVER"]["caserun"])
mkpath(config["DRIVER"]["archive_root"])


using TOML
output_config = joinpath("$(config["DRIVER"]["caseroot"])", "config.toml")
println("Output file: $(output_config)")
open(output_config, "w") do io
    TOML.print(io, config; sorted=true)
end

