function calTsSsMixed!(
    ocn  :: Ocean;
)
    calFLDOPartition!(ocn)
    ocn.Ts_mixed .= ocn.Ts 
    ocn.Ss_mixed .= ocn.Ss
 
    @loop_hor ocn i j let

        mixFLDO!(
            qs   = ocn.cols.Ts_mixed[i, j],
            zs   = ocn.cols.zs[i, j],
            hs   = ocn.cols.hs[i, j],
            q_ML = ocn.T_ML[i, j],
            FLDO = ocn.FLDO[i, j],
            FLDO_ratio_top = ocn.FLDO_ratio_top[i, j],
            FLDO_ratio_bot = ocn.FLDO_ratio_bot[i, j],
        )

        mixFLDO!(
            qs   = ocn.cols.Ss_mixed[i, j],
            zs   = ocn.cols.zs[i, j],
            hs   = ocn.cols.hs[i, j],
            q_ML = ocn.S_ML[i, j],
            FLDO = ocn.FLDO[i, j],
            FLDO_ratio_top = ocn.FLDO_ratio_top[i, j],
            FLDO_ratio_bot = ocn.FLDO_ratio_bot[i, j],
        )

    end

end
