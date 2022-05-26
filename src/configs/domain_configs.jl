
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
                "z_w_file",
                :required,
                [String,],
                "",
                desc = "Will be overwritten if `init_file` is used.",
            ),

        ],
    )
end
