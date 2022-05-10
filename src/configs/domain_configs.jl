
function getDomainConfigDescriptors()

    return Dict(
        
        "DOMAIN" => [

            ConfigEntry(
                "domain_file",
                :required,
                [String,],
                "",
            ),

            ConfigEntry(
                "topo_file",
                :optional,
                [String,],
                "",
            ),

            ConfigEntry(
                "z_w",
                :optional,
                [AbstractArray{Float64, 1}],
                [0.0, -10.0, -20.0, -30.0, -40.0, -50.0];
                desc = "Will be overwritten if `init_file` is used.",
            ),

        ],
    )
end
