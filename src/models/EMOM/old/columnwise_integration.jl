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
