function getDriverConfigDescriptors()

    return Dict(
        "DRIVER" => [
            ConfigEntry(
                "casename",
                :required,
                [String,],
                "BLANK",
            ),

            ConfigEntry(
                "caseroot",
                :required,
                [String,],
                "BLANK"
            ),

            ConfigEntry(
                "caserun",
                :required,
                [String,],
                "BLANK"
            ),

            ConfigEntry(
                "archive_root",
                :required,
                [String,],
                "BLANK"
            ),

            ConfigEntry(
                "archive_list",
                :optional,
                [String,],
                "archive_list.txt",
            ),

            ConfigEntry(
                "compute_QFLX_direct_method",
                :optional,
                [Bool,],
                false,
            ),

        ]
    )
end


