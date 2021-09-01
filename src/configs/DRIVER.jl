function getDriverConfigDescriptor()

    return [
            ConfigEntry(
                :casename,
                :required,
                [String,],
            ),

            ConfigEntry(
                :caseroot,
                :required,
                [String,],
            ),

            ConfigEntry(
                :caserun,
                :required,
                [String,],
            ),

            ConfigEntry(
                :archive_root,
                :required,
                [String,],
            ),

            ConfigEntry(
                :archive_list,
                :optional,
                [String,],
                "archive_list.txt",
            ),
   ]
end
