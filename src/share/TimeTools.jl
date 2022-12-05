
module TimeTools
    
    function parseDateTime(
        timetype,
        str :: String,
    )

        m = match(r"(?<year>[0-9]+)-(?<month>[0-9]{2})-(?<day>[0-9]{2})\s+(?<hour>[0-9]{2}):(?<min>[0-9]{2}):(?<sec>[0-9]{2})", str)
        if m == nothing
            throw(ErrorException("Unknown time format: " * (str)))
        end

        return timetype(
            parse(Int64, m[:year]),
            parse(Int64, m[:month]),
            parse(Int64, m[:day]),
            parse(Int64, m[:hour]),
            parse(Int64, m[:min]),
            parse(Int64, m[:sec]),
        )
    end

end
