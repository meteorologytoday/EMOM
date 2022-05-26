using NCDatasets
using DataStructures
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
            default = ["", "", ""]


        "--init-file"
            help = "The init ocean file."
            arg_type = String
            required = true


        "--ocn-model"
            help = "The name of ocean model. Can be: `SOM`, `MLM`, `EOM` and `EMOM`"
            arg_type = String
            required = true

        "--output-file"
            help = "The output file."
            arg_type = String
            default = "config.toml"

        "--finding-QFLX-timescale"
            help = "If this is set to a real number, finding QFLX mode is on. And timescale is in days."
            arg_type = Float64
            default = NaN

        "--casename"
            help = "Casename. Default: UNSET"
            arg_type = String
            default = "UNSET"

        "--caseroot"
            help = "Caseroot. Default: UNSET"
            arg_type = String
            default = "UNSET"

        "--caserun"
            help = "Caserun. Default: UNSET"
            arg_type = String
            default = "UNSET"

        "--archive-root"
            help = "Archive root. Default: UNSET"
            arg_type = String
            default = "UNSET"

        "--calendar"
            help = "Calendar type. Two possible choices: NO_LEAP, GREGORIAN. Default: NO_LEAP"
            arg_type = String
            default = "NO_LEAP"

    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
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
    println("QFLX finding mode off. Weak restoring timescale = 100 years for TEMP and Salt.")
    Qflx = "on"
    τwk_SALT = 86400.0 * 365 * 100
    τwk_TEMP = 86400.0 * 365 * 100
else
    throw(ErrorException("Unknown scenario: got `finding-QFLX-timescale` = $(parsed["finding-QFLX-timescale"])"))
end

calendar = Dict(
    "NO_LEAP"   => "DateTimeNoLeap",
    "GREGORIAN" => "DateTimeProlepticGregorian",
)[parsed["calendar"]]


var_file_map = Dict()

for var in ["HMXL", "TEMP", "SALT", "QFLXT", "QFLXS"]
    file = parsed["forcing-file-$(var)"]
    if file != ""
        var_file_map[var] = file
    end
end



config = DataStructures.OrderedDict{Any, Any}(

    "DRIVER" => DataStructures.OrderedDict(
        "casename"           => parsed["casename"],
        "caseroot"           => parsed["caseroot"],
        "caserun"            => parsed["caserun"],
        "archive_root"       => parsed["archive-root"],
    ),

    "MODEL_MISC" => DataStructures.OrderedDict(
        "timetype"               => calendar,
        "init_file"              => parsed["init-file"],
        "rpointer_file"          => "rpointer.iom",
        "daily_record"           => [],
        "monthly_record"         => ["{ESSENTIAL}", "QFLXT", "QFLXS"],
        "enable_archive"         => true,
    ),

    "MODEL_CORE" => DataStructures.OrderedDict(

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

output_config = parsed["output-file"]
println("Output file: $(output_config)")
open(output_config, "w") do io
    TOML.print(io, config; sorted=true)
end
