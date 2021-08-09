function calFLDOPartition!(
    ocn :: Ocean
)

    @loop_hor ocn i j let 

        FLDO = ocn.FLDO[i, j]

        if FLDO == -1
            ocn.FLDO_ratio_top[i, j] = 0.0
            ocn.FLDO_ratio_bot[i, j] = 1.0
        else
            ocn.FLDO_ratio_top[i, j] = (ocn.h_ML[i, j] + ocn.zs[FLDO, i, j]) / ocn.hs[FLDO, i, j]
            ocn.FLDO_ratio_bot[i, j] = 1.0 - ocn.FLDO_ratio_top[i, j]
        end
    end
end
