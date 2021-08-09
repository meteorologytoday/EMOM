function stepRadiation!(
    mb :: ModelBlock,
    Δt :: Float64,
)


    fi = mb.fi
    co = mb.co

    fi._X_[:, 1] .+= Δt * ( co.mtx[:T_swflxConv_sT] * view(fi.SWFLX, :) + co.mtx[:T_nswflxConv_sT] * view(fi.NSWFLX, :)) / ρcp_sw
    
end
