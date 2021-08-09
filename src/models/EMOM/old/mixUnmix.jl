function mixFLDO!(;
    qs   :: AbstractArray{Float64, 1},
    zs   :: AbstractArray{Float64, 1},
    hs   :: AbstractArray{Float64, 1},
    q_ML :: Float64,
    FLDO :: Integer,
    FLDO_ratio_top :: Float64,
    FLDO_ratio_bot :: Float64,
)
    
    Δq = 0.0
    
    if FLDO != -1
    
        Δq = q_ML - qs[FLDO]
        qs[FLDO] =  FLDO_ratio_top * q_ML + FLDO_ratio_bot * qs[FLDO]
        
    end
    
    return Δq
    
end

function unmixFLDOKeepDiff!(;
    qs   :: AbstractArray{Float64, 1},
    zs   :: AbstractArray{Float64, 1},
    hs   :: AbstractArray{Float64, 1},
    h_ML :: Float64,
    FLDO :: Integer,
    Nz   :: Integer,
    Δq   :: Float64,
#    verbose = false
)

    int_layer = 0
    integral = 0.0
    new_q_ML = 0.0

    if FLDO == -1

        for k = 1:Nz
            integral += hs[k] * qs[k]
        end 
        new_q_ML = integral / h_ML
        qs[1:Nz] .= new_q_ML

    else

#        verbose && println("FLDO = ", FLDO)
#        verbose && println("Δq: ", Δq)
        for k = 1:FLDO
            integral += hs[k] * qs[k]
#            verbose && println(k, "; hs: ", hs[k], "; qs: ", qs[k])
        end 
#        verbose && println("integral = ", integral)
#        verbose && println("h_ML = ", h_ML, "; zs[FLDO+1] = ", zs[FLDO+1])

        new_q_ML = (integral - Δq * (h_ML + zs[FLDO+1])) / ( - zs[FLDO+1] )
        qs[1:FLDO] .= new_q_ML
        qs[FLDO]    = new_q_ML - Δq


    end

    return new_q_ML

end



function remixML!(;
    qs   :: AbstractArray{Float64, 1},
    zs   :: AbstractArray{Float64, 1},
    hs   :: AbstractArray{Float64, 1},
    h_ML :: Float64,
    FLDO :: Integer,
    Nz   :: Integer,
)

    # no need to remix if h_ML is shallower than the first layer
    if FLDO == 1
        return qs[1]
    end

    int_layer = 0
    new_q_ML = 0.0

    if FLDO == -1
        int_layer = Nz
    else
        int_layer = FLDO - 1
        new_q_ML += ( h_ML + zs[FLDO] ) * qs[FLDO]
    end

    for k = 1:int_layer
        new_q_ML += hs[k] * qs[k]
    end 
    #=
    if go
        println("hs: ", hs)
        println("h_ML: ", h_ML)
        println("FLDO: ", FLDO)
        println("qs[1:FLDO]: ", qs[1:FLDO])
        println("zs[FLDO]: ", zs[FLDO])
        println("int_layer: ", int_layer)
        
    end

=#

    new_q_ML /= h_ML

    qs[1:int_layer] .= new_q_ML
    return new_q_ML

#    qs[1:int_layer] .= qs[1]
    return qs[1]

end

#=

function OC_getIntegratedTemperature(
    ocn      :: Ocean,
    i        :: Integer,
    j        :: Integer;
    target_z :: Float64,
)

    return getIntegratedQuantity(
        zs       = ocn.cols.zs[i, j],
        qs       = ocn.cols.Ts[i, j],
        q_ML     = ocn.T_ML[i, j],
        h_ML     = ocn.h_ML[i, j],
        Nz       = ocn.Nz[i, j],
        target_z = target_z,
    )
end




function OC_getIntegratedSalinity(
    ocn      :: Ocean,
    i        :: Integer,
    j        :: Integer;
    target_z :: Float64,
)

    return getIntegratedQuantity(
        zs       = ocn.cols.zs[i, j],
        qs       = ocn.cols.Ss[i, j],
        q_ML     = ocn.S_ML[i, j],
        h_ML     = ocn.h_ML[i, j],
        Nz       = ocn.Nz[i, j],
        target_z = target_z,
    )
end



function OC_getIntegratedBuoyancy(
    ocn      :: Ocean,
    i        :: Integer,
    j        :: Integer;
    target_z :: Float64,
)

    return getIntegratedQuantity(
        zs       = ocn.cols.zs[i, j],
        qs       = ocn.cols.bs[i, j],
        q_ML     = ocn.b_ML[i, j],
        h_ML     = ocn.h_ML[i, j],
        Nz       = ocn.Nz[i, j],
        target_z = target_z,
    )
end


function getIntegratedQuantity(;
    zs       :: AbstractArray{Float64,1},
    qs       :: AbstractArray{Float64,1},
    q_ML     :: Float64,
    h_ML     :: Float64,
    Nz       :: Integer,
    target_z :: Float64,
)

    if target_z < zs[Nz+1]
        throw(ErrorException(
            format("target_z ({:f}) cannot be deeper than the minimum of zs ({:f}).", target_z, zs[Nz])
        ))
    end


    # Integrate mixed layer
    if -target_z < h_ML
        return q_ML * ( - target_z )
    end

    sum_q = 0.0
    sum_q += h_ML * q_ML


    # Test if entire ocean column is mixed layer
    FLDO = getFLDO(zs=zs, h_ML=h_ML, Nz=Nz)
    if FLDO == -1
        return sum_q
    end

    # Integrate FLDO
    if target_z > zs[FLDO+1]
        sum_q += qs[FLDO] * ( (-h_ML) - target_z)
        return sum_q
    end
    
    sum_q += qs[FLDO] * ( (-h_ML) - zs[FLDO+1]) 

    # Integrate rest layers
    if FLDO < Nz
        for i = FLDO+1 : Nz
            if target_z < zs[i+1]
                sum_q += qs[i] * (zs[i] - zs[i+1])
            else
                sum_q += qs[i] * (zs[i] - target_z)
                return sum_q
            end
        end
    else
        return sum_q
    end

end
=#
