using Formatting
using JSON, ArgParse

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config-file"
            help = "Configuration file."
            arg_type = String
            required = true

        "--forcing-file"
            help = "Annual forcing file. It should contain: TAUX, TAUY, SWFLX, NSWFLX, VSFLX"
            arg_type = String
            required = true

        "--nudging-timescale-day"
            help = "Nudging timescale used to replace weak restoring timescale when finding Q-flux in days. Default is 5 days."
            arg_type = Float64
            default = 5.0

        "--stop-n"
            help = "Core of the model."
            arg_type = Int64

        
        "--time-unit"
            help = "."
            arg_type = String

    end

    return parse_args(s)
end

parsed = parse_commandline()



