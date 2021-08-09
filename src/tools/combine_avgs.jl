using NCDatasets
using Formatting

macro pf(exps...)
    return :(print(format($(eval(exps)...))))
end

macro pfln(exps...)
    return :(println(format($(eval(exps)...))))
end


filename = ARGS[1]
output_filename = ARGS[2]

@pfln("Input file: {}", filename)
@pfln("Output file: {}", output_filename)

first_file = true

ds_o = Dataset(output_filename, "c")

cnt = 1
for line in eachline(filename)
    global first_file, cnt, missing_value
    
    println("Reading data: ", line)

    ds_i = Dataset(line, "r")


    if first_file
        
        first_file = false

        missing_value = ds_i["T_ML"].attrib["_FillValue"]
        Nx = ds_i.dim["Nx"]
        Ny = ds_i.dim["Ny"]
        
        defDim(ds_o, "Nx", Nx)
        defDim(ds_o, "Ny", Ny)
        defDim(ds_o, "time", Inf)
        
        defVar(ds_o, "T_ML", Float64, ("Nx", "Ny", "time"), fillvalue=missing_value)

        global buffer = zeros(Float64, Nx, Ny)
    end

    buffer[:, :] = nomissing( ds_i["T_ML"][:, :], missing_value)

    ds_o["T_ML"][:, :, cnt] = buffer
    close(ds_i)

    cnt += 1
end



close(ds_o)

