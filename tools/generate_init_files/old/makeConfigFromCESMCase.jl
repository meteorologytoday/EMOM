using NCDatasets
using ArgParse, JSON
using DataStructures

println("""
This program is run after a CESM case has been setup before execute.
It reads env_build.xml and env_run.xml to fill in paths and files.
""")

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

function getCESMConfig(path, ids)

    println("CESM config path: $(path)")

    wdir = pwd()

    cd(path)

    d = OrderedDict()
    for id in ids
        d[id] = readchomp(`./xmlquery $(id) -silent -valonly`)
    end

    cd(wdir)

    return d
end

#=
function getXML(filename)
    println("Reading XML file $(filename)")
    xml_doc = parse_file(filename)
    entries = get_elements_by_tagname(root(xml_doc), "entry")

    d = OrderedDict()
    for entry in entries
        d[attribute(entry, "id")] = attribute(entry, "value")
    end

    return d 
end
=#

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--caseroot"
            help = "CESM caseroot where env_run.xml and such are placed."
            arg_type = String
            default = ""

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

    end

    return parse_args(s)
end

parsed = parse_commandline()
JSON.print(parsed,4)

if parsed["ocn-model"] == "SOM"
    advection_scheme = "static"
elseif parsed["ocn-model"] == "MLM"
    advection_scheme = "static"
elseif parsed["ocn-model"] in ["EOM", "EMOM"]
    advection_scheme = "ekman_CO2012"
else
    throw(ErrorException("Error: Unknown ocean model `$(parsed["ocn-model"])`."))
end

if parsed["finding-QFLX-timescale"] > 0.0
    println("QFLX finding mode on. Timescale = $(parsed["finding-QFLX-timescale"]) days.")
    Qflx = "off"
    τwk_SALT = 86400.0 * parsed["finding-QFLX-timescale"]
    τwk_TEMP = 86400.0 * parsed["finding-QFLX-timescale"]
elseif isnan(parsed["finding-QFLX-timescale"])
    println("QFLX finding mode off. Timescale = 1000 years and 1 year for TEMP and Salt.")
    Qflx = "on"
    τwk_SALT = 86400.0 * 365 * 100
    τwk_TEMP = 86400.0 * 365 * 100
else
    throw(ErrorException("Unknown scenario: got `finding-QFLX-timescale` = $(parsed["finding-QFLX-timescale"])"))
end


for k in ["env_run.xml", "env_mach_pes.xml", "env_case.xml"]
    if ! isfile(joinpath(parsed["caseroot"], k))
        throw(ErrorException("Error: file $(k) does not exists in caseroot folder $(parsed["caseroot"])"))
    end
end


cesm_config = getCESMConfig(

    parsed["caseroot"],

    [
        "CASE",
        "CASEROOT",
        "RUNDIR",
        "DOUT_S_ROOT",
        "OCN_DOMAIN_PATH",
        "OCN_DOMAIN_FILE",
        "CALENDAR",
    ],
)

calendar = Dict(
    "NO_LEAP"   => "DateTimeNoLeap",
    "GREGORIAN" => "DateTimeProlepticGregorian",
)[cesm_config["CALENDAR"]]


if basename(parsed["domain-file"]) != basename(cesm_config["OCN_DOMAIN_FILE"])
    println("Warning: Input domain file is $(parsed["domain-file"]) but the CESM configureation uses $(cesm_config["OCN_DOMAIN_FILE"])")
end


var_file_map = Dict()

for var in ["HMXL", "TEMP", "SALT", "QFLXT", "QFLXS"]
    file = parsed["forcing-file-$(var)"]
    if file != ""
        var_file_map[var] = file
    end
end



config = Dict{Any, Any}(

    "DRIVER" => Dict(
        "casename"           => cesm_config["CASE"],
        "caseroot"           => cesm_config["CASEROOT"],
        "caserun"            => cesm_config["RUNDIR"],
        "archive_root"       => cesm_config["DOUT_S_ROOT"],
    ),

    "MODEL_MISC" => Dict(
        "timetype"               => calendar,
        "init_file"              => parsed["init-file"],
        "rpointer_file"          => "rpointer.iom",
        "daily_record"           => [],
        "monthly_record"         => ["{ESSENTIAL}", "QFLXT", "QFLXS"],
        "enable_archive"         => true,
    ),

    "MODEL_CORE" => Dict(

        "domain_file"                  => parsed["domain-file"],
        "topo_file"                    => parsed["topo-file"],
        "cdata_var_file_map"           => var_file_map,

        "cdata_beg_time"               => parsed["forcing-time"][1],
        "cdata_end_time"               => parsed["forcing-time"][2],
        "cdata_align_time"             => parsed["forcing-time"][3],

        "z_w"                          => nothing,

        "substeps"                     => 8,
        "MLD_scheme"                   => "datastream",
        "Qflx"                         => Qflx,
        "Qflx_finding"                 => "off",
        "convective_adjustment"        => "on",
        "advection_scheme"             => advection_scheme,

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


using TOML

output_path = ( parsed["output-path"] == "" ) ? config["DRIVER"]["caseroot"] : parsed["output-path"]
output_config = joinpath(output_path, "config.toml")
println("Output file: $(output_config)")
open(output_config, "w") do io
    TOML.print(io, config; sorted=true)
end
