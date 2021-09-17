include("IOM/src/share/constants.jl")
include("IOM/src/share/PolelikeCoordinate.jl")
include("IOM/src/share/BasicMatrixOperators.jl")
include("IOM/src/share/AdvancedMatrixOperators.jl")

using .PolelikeCoordinate
using NCDatasets
using ArgParse, JSON
using Statistics

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--scheme"
            help = "Scheme: AGA2020, KSC2018, CO2012."
            arg_type = String
            required = true
    end

    return parse_args(s)
end

parsed = parse_commandline()

JSON.print(parsed, 4)

scheme = parsed["scheme"]

Nϵx =  11
Nϵy = 11

ϵx_vec  = range(0.01, 100000000.0, length=Nϵx) / 86400.0
ϵy_vec  = range(0.01, 1.0, length=Nϵy) / 86400.0

Δϵx  = ϵx_vec[2] - ϵx_vec[1]
Δϵy  = ϵy_vec[2] - ϵy_vec[1]
lat_rng = [-20.0, 20.0]
yr_rng = [1, 1]
σ_w = 10e-5  # 10m/day tolerance
σ_u = 1e-2  # 1cm/s   tolerance
N_layer = 5

output_file = "epsx_epsy_logpost_$(scheme).nc"

logpost_w = zeros(Float64, Nϵx, Nϵy)
logpost_u = zeros(Float64, Nϵx, Nϵy)
logpost_uw = zeros(Float64, Nϵx, Nϵy)

# Load domain and construct operators
domain_file = "CESM_domains/domain.ocn.gx1v6.090206.nc"
gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
    domain_file;
    R  = Re,
    Ω  = Ω,
)

mask_sT = reshape(gf.mask, 1, size(gf.mask)...)
gd_slab = PolelikeCoordinate.genGrid(gf, [0, -50.0]) 

println("Constructing operators...")
@time amo_slab = AdvancedMatrixOperators(;
    gd     = gd_slab,
    mask_T     = mask_sT,
    deepmask_T = mask_sT,
)


println("Making matrices")

f_sT = 2 * gd_slab.Ω * sin.(gd_slab.ϕ_T)
β_sT = (2 * gd_slab.Ω / gd_slab.R) * cos.(gd_slab.ϕ_T)
f2_sT = f_sT.^2

T_DIVx_T = dropzeros(amo_slab.T_DIVx_U * amo_slab.U_interp_T)
T_DIVy_T = dropzeros(amo_slab.T_DIVy_V * amo_slab.V_interp_T)

files = readdir("hist")

cnt = 0
for f in files

    global cnt

    if cnt >= 1
        break
    end
    m = match(r"paper2021_CTL_POP2\.pop\.h\.(?<yr>\d\d\d\d)-\d\d\.nc", f)

    if m == nothing
        println("Skip $(f)")
        continue
    else
        if ! ( yr_rng[1] <= parse(Int64, m[:yr]) <= yr_rng[2] )
            println("Skip $(f)")
            continue
        end
        println("Loading $(f)")
        cnt += 1
    end

    ds = Dataset("hist/$(f)", "r")

    TAUX   = convert(Array{Float64}, nomissing(ds["TAUX"][:, :, 1], NaN)) / 10.0
    TAUY   = convert(Array{Float64}, nomissing(ds["TAUY"][:, :, 1], NaN)) / 10.0
    u_OGCM = convert(Array{Float64}, nomissing(ds["UVEL"][:, :, 1:N_layer, 1], NaN)) / 100.0
    v_OGCM = convert(Array{Float64}, nomissing(ds["VVEL"][:, :, 1:N_layer, 1], NaN)) / 100.0
    w_OGCM = convert(Array{Float64}, nomissing(ds["WVEL"][:, :, 6, 1], NaN)) / 100.0
    z_w_top = - convert(Array{Float64}, nomissing(ds["z_w_top"][1:N_layer], NaN)) / 100.0
    z_w_bot = - convert(Array{Float64}, nomissing(ds["z_w_bot"][1:N_layer], NaN)) / 100.0
    close(ds)

    valid_idx = (lat_rng[1] .<= gf.yc .<= lat_rng[2]) .& (gf.mask .== 1.0) .& ( isfinite.(w_OGCM) )
    


    function checkValid(x, idx)
        valid_x = x[idx]
        isfinite_x = isfinite.(valid_x)

        if all(isfinite_x)
            #println("[checkValid] PASS.")
        else
            println("[checkValid] NOT PASS.")
            throw(ErrorException("There are $(length(valid_x) - sum(isfinit_x)) pts that are not finite."))
        end

    end

    checkValid(TAUX, valid_idx)
    checkValid(TAUY, valid_idx)
    checkValid(w_OGCM, valid_idx)


    TAUX = reshape(TAUX, 1, size(TAUX)...)
    TAUY = reshape(TAUY, 1, size(TAUY)...)

    # process
    TAUX_east, TAUY_north = PolelikeCoordinate.project(
        gd_slab, 
        TAUX,
        TAUY,
        direction=:Backward,
        grid=:T,
    )

    curlτ_sT = reshape(
        amo_slab.T_CURLx_T * view(TAUY, :) + amo_slab.T_CURLy_T * view(TAUX, :),
        1, gd_slab.Nx, gd_slab.Ny,
    )
    

    for (i, ϵx) in enumerate(ϵx_vec), (j, ϵy) in enumerate(ϵy_vec)

        #println("[$i, $j] Doing ϵ = $(ϵ); ϵy = $(ϵp)")
        
        ϵx_sT  = f_sT * 0 .+ ϵx
        ϵy_sT  = f_sT * 0 .+ ϵy
        ϵ2_sT  = ϵx_sT.^ ϵy_sT

        ϵ2invβ_sT = ϵ2_sT * (gd_slab.R / 2.0 / gd_slab.Ω)
        invD_sT   = (f2_sT + ϵ2_sT).^(-1.0)
 
        if scheme == "AGA2020"
            VFX_east   = (   ϵy_sT .* TAUX_east + f_sT      .* TAUY_north  ) .* invD_sT / ρ_sw
            VFY_north  = ( - f_sT .* TAUX_east + ϵ2invβ_sT .* curlτ_sT    ) .* invD_sT / ρ_sw
        elseif scheme == "CO2012"
            VFX_east   = (   ϵx_sT .* TAUX_east +  f_sT .* TAUY_north  ) .* invD_sT / ρ_sw
            VFY_north  = ( -  f_sT .* TAUX_east + ϵy_sT .* TAUY_north  ) .* invD_sT / ρ_sw
        elseif scheme == "KSC2018"
            VFX_east   = (   ϵ_sT .* TAUX_east + f_sT .* TAUY_north  ) .* invD_sT / ρ_sw
            VFY_north  = ( - f_sT .* TAUX_east ) .* invD_sT / ρ_sw
        else
            throw(ErrorException("Unknown scheme."))
        end

        VFX, VFY = PolelikeCoordinate.project(
            gd_slab, 
            VFX_east,
            VFY_north,
            direction=:Forward,
            grid=:T,
        )

        w = reshape(( T_DIVx_T * reshape(VFX,:) + T_DIVy_T * reshape(VFY,:) ), gd_slab.Nx, gd_slab.Ny)

        #println("w size = ", size(w))
        #println("w_OGCM size = ", size(w_OGCM))
        Δw = w .- w_OGCM
        
        tmp = - ( Δw / σ_w ).^2.0 / 2.0
        #println(size(tmp))
        #if ! all( isfinite.(tmp[valid_idx]) )
        #    println(sum(isnan.(tmp[valid_idx])))
        #    throw(ErrorException("Not all is finite"))
        #end

        logpost_w[i, j] += sum(tmp[valid_idx])

        #=
        Dataset("w_check.nc", "c") do ds
            
            defDim(ds, "Nx", gd_slab.Nx)
            defDim(ds, "Ny", gd_slab.Ny)
            for (varname, vardata, vardim, attrib) in [
                ("w",  w,    ("Nx", "Ny",), Dict()),
                ("w_OGCM",  w_OGCM,    ("Nx", "Ny",), Dict()),
            ]

                var = defVar(ds, varname, Float64, vardim)
                var.attrib["_FillValue"] = 1e20
                
                for (k, v) in attrib
                    var.attrib[k] = v
                end

                rng = []
                for i in 1:length(vardim)-1
                    push!(rng, Colon())
                end
                push!(rng, 1:size(vardata)[end])
                var[rng...] = vardata

            end

        end
        break
        =#

        # approximate U
        Δz = reshape(z_w_top - z_w_bot, 1, 1, :)
        H  = sum(Δz[1:N_layer])
        VFX_OGCM = reshape(view(sum(Δz .* u_OGCM, dims=3), :, :, 1), 1, gd_slab.Nx, gd_slab.Ny)
        VFY_OGCM = reshape(view(sum(Δz .* v_OGCM, dims=3), :, :, 1), 1, gd_slab.Nx, gd_slab.Ny)
 
        VFX_east_OGCM, VFY_north_OGCM = PolelikeCoordinate.project(
            gd_slab, 
            VFX_OGCM,
            VFY_OGCM,
            direction=:Backward,
            grid=:T,
        )
        
        Δu  = (VFX_east  - VFX_OGCM) / H
        Δv  = (VFY_north - VFY_OGCM) / H
        tmp = - (Δu.^2 + Δv.^2) / (2 * σ_u^2.0)
        #tmp = - (Δu.^2) / (2 * σ_u^2.0)
        logpost_u[i, j] += sum( view(tmp, 1, :, :)[valid_idx] )
    
    end

end

println("Processed $(cnt) files.")


function processLogpost(logpost, Δp1, Δp2)
    logpost = logpost .- maximum(logpost)
    Δp2 = Δp1 * Δp2

    post = exp.(logpost)
    post /= sum(post) * Δp2

    return logpost, post
end

logpost_uw = logpost_w + logpost_u

logpost_w, post_w = processLogpost(logpost_w, Δϵx, Δϵy)
logpost_u, post_u = processLogpost(logpost_u, Δϵx, Δϵy)
logpost_uw, post_uw = processLogpost(logpost_uw, Δϵx, Δϵy)



println("Writing output: $(output_file)")
Dataset(output_file, "c") do ds
    
    defDim(ds, "Nepsx", Nϵx)
    defDim(ds, "Nepsy", Nϵy)
    for (varname, vardata, vardim, attrib) in [
        ("logpost_w",  logpost_w,  ("Nepsx", "Nepsy",), Dict()),
        ("post_w",     post_w,     ("Nepsx", "Nepsy"), Dict()),
        ("logpost_u",  logpost_u,  ("Nepsx", "Nepsy",), Dict()),
        ("post_u",     post_u,     ("Nepsx", "Nepsy"), Dict()),
        ("logpost_uw", logpost_uw, ("Nepsx", "Nepsy",), Dict()),
        ("post_uw",    post_uw,    ("Nepsx", "Nepsy"), Dict()),
        ("eps_x",      ϵx_vec,    ("Nepsx",), Dict()),
        ("eps_y",      ϵy_vec,    ("Nepsy",), Dict()),
    ]

        var = defVar(ds, varname, Float64, vardim)
        var.attrib["_FillValue"] = 1e20
        
        for (k, v) in attrib
            var.attrib[k] = v
        end

        rng = []
        for i in 1:length(vardim)-1
            push!(rng, Colon())
        end
        push!(rng, 1:size(vardata)[end])
        var[rng...] = vardata

    end

end









# 1. project TAUX and TAUY to true east and north
# 2. compute curl
# 3. compute horizontal velocity
# 4. compute divergence and thus w_50m

