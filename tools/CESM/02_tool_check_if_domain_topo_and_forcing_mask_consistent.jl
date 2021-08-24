include("IOM/src/models/EMOM/Topography.jl")

using Formatting
using NCDatasets
using ArgParse
using JSON

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--domain-file"
            help = "Domain file."
            arg_type = String
            required = true

        "--zdomain-file"
            help = "NetCDF file containing z_w information"
            arg_type = String
            required = true

        "--topo-file"
            help = "Topography file."
            arg_type = String
            default = ""

        "--forcing-file"
            help = "Annual forcing file. It should contain: TAUX, TAUY, SWFLX, NSWFLX, VSFLX"
            arg_type = String
            default = ""

        "--forcing-file-varnames"
            help = "Variables that should be checked (comma separated). Default: TAUX,TAUY,SWFLX,NSWFLX,VSFLX,TEMP,SALT,QFLX_TEMP,QFLX_SALT. Unexisted variables will be skipped."
            arg_type = String
            default = "TAUX,TAUY,SWFLX,NSWFLX,VSFLX,TEMP,SALT,QFLX_TEMP,QFLX_SALT"

        "--forcing-file-xdim"
            help = "Varname of x dimension in the forcing file"
            arg_type = String
            default = "Nx"

        "--forcing-file-ydim"
            help = "Varname of y dimension in the forcing file"
            arg_type = String
            default = "Ny"

        "--forcing-file-zdim"
            help = "Varname of z dimension in the forcing file"
            arg_type = String
            default = "Nz"

        "--forcing-file-tdim"
            help = "Varname of time dimension in the forcing file"
            arg_type = String
            default = "time"


    end

    return parse_args(s)
end

parsed = parse_commandline()

print(json(parsed,4))


println("This program is used to see if")
println("1. Surface mask in the `domain-file` matches the surface mask in the topography created by `topo-file` and `zdomain-file`.")
println("2. If `forcing-file` is given, the program checks if 3D mask (T-grid) implied by `topo-file` is consistent with `forcing-file` (i.e. if mask[k,i,j] == 1, then forcing[k,i,j] should not be missing value).")

Dataset(parsed["domain-file"], "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask_sT = ds["mask"][:]

    if length(size(mask_sT)) == 2
        mask_sT = reshape(mask_sT, 1, size(mask_sT)...)
    end
end

Dataset(parsed["zdomain-file"], "r") do ds
    global z_w = ds["z_w"][:]
    global Nz = length(z_w) - 1
end

Dataset(parsed["topo-file"], "r") do ds
    global Nz_bot = ds["Nz_bot"][:]
end

topo = Topography(
    Nz_bot, Nx, Ny, z_w
)

flag_check1_pass = true
flag_check2_pass = true


print("### Check 1 : mask in domain-file should match topo.mask_T[1, :, :]. Answer: ")
if all(mask_sT .== topo.mask_T[1:1, :, :])
    println("Yes. It is consistent")
    flag_check1_pass = true
else
    println("*** Error: No, they are not. Please check. ***")
end

if parsed["forcing-file"] != ""
    println("`forcing-file` is given.")
    print("### Check 2 : If topo.mask_T[k,i,j] == 1 then forcing[k,i,j] should be finite. Answer: ")

    mask_sT_idx = mask_sT .== 1.0
    mask_T_idx  = topo.mask_T  .== 1.0

    Dataset(parsed["forcing-file"], "r") do ds

        Nt = ds.dim[parsed["forcing-file-tdim"]]

        for varname in split(parsed["forcing-file-varnames"], ",")
            if haskey(ds, varname)
                print(format("Check variable `{:s}`... ", varname))
                v = ds[varname]

                sdim = 0

                if dimnames(v) == (parsed["forcing-file-xdim"], parsed["forcing-file-ydim"], parsed["forcing-file-zdim"],  parsed["forcing-file-tdim"])
                    sdim = 3
                elseif dimnames(v) == (parsed["forcing-file-xdim"], parsed["forcing-file-ydim"], parsed["forcing-file-tdim"])
                    sdim = 2
                else
                    println("*** Error : Unrecognized dimensions: ", dimnames(v), ". Please check. ***")
                    global flag_check2_pass = false
                    continue
                end

                if sdim == 3
                    mask_idx_used = mask_T_idx
                    mask_used = topo.mask_T
                    spatial_slice = (Colon(), Colon(), Colon())
                    reshape_dim   = (Nx, Ny, Nz) # reshape before permute
                elseif sdim == 2
                    mask_idx_used = mask_sT_idx
                    mask_used = mask_sT
                    spatial_slice = (Colon(), Colon())
                    reshape_dim   = (Nx, Ny, 1) # reshape before permute
                else
                    throw(ErrorException("Unknown situation. sdim = " * string(sdim)))
                end

                mask_used_cnt = sum(mask_used)

                for t = 1:Nt
                    var  = permutedims(reshape(nomissing(ds[varname][spatial_slice..., t],  NaN), reshape_dim...), [3, 1, 2])
                    var_isfinite_cnt = sum( isfinite.(var) )

                    if all(isfinite.(var[mask_idx_used]))
                        println(format("Pass")) 
                        if var_isfinite_cnt != mask_used_cnt
                            println("Some of the data might not be used. (Forcing data has it but will not be used).")
                        else
                            println("All the data match the mask completely.")
                        end
                    else
                        println(format("*** Error: Variable `{:s}` is having missing values where mask is not zero. Please check. ***", varname))
                        println("var_isfinite_cnt = ", var_isfinite_cnt, "; mask_used_cnt = ", mask_used_cnt)
                        flag_check2_pass = false
                    end
                end

            end
        end
    end
end

println("### Summary ### ")

all_pass = flag_check1_pass
println("Check 1: ", flag_check1_pass)

if parsed["forcing-file"] != ""
    println("Check 2: ", flag_check2_pass)
    all_pass &= flag_check2_pass
end

println("All pass? ", all_pass)


