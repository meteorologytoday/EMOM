function appendLine(filename, content)
    open(filename, "a") do io
        write(io, content)
        write(io, "\n")
    end
end

