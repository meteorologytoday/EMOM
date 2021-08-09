function OC_doConvectiveAdjustment!(
        ocn :: Ocean,
        i   :: Integer,
        j   :: Integer,
    )


    if_adjust, ocn.b_ML[i, j], ocn.T_ML[i, j], ocn.S_ML[i, j], ocn.h_ML[i, j], ocn.FLDO[i, j] = doConvectiveAdjustment!(
        zs       = ocn.cols.zs[i, j],
        bs       = ocn.cols.bs[i, j],
        Ts       = ocn.cols.Ts[i, j],
        Ss       = ocn.cols.Ss[i, j],
        h_ML     = ocn.h_ML[i, j],
        b_ML     = ocn.b_ML[i, j],
        T_ML     = ocn.T_ML[i, j],
        S_ML     = ocn.S_ML[i, j],
        FLDO     = ocn.FLDO[i, j],
        Nz       = ocn.Nz[i, j],
        h_ML_max = ocn.h_ML_max[i, j],
    )

    return if_adjust
end


"""

This function only do convective adjustment for the upper most mixed layer.
It searches for the lowest layer that has larger buoyancy than mixed-layer then mixed all layers above it.

By default it only mixes T and S but not b


"""
function doConvectiveAdjustment!(;
    zs   :: AbstractArray{Float64, 1},
    bs   :: AbstractArray{Float64, 1},
    Ts   :: AbstractArray{Float64, 1},
    Ss   :: AbstractArray{Float64, 1},
    h_ML :: Float64,
    b_ML :: Float64,
    T_ML :: Float64,
    S_ML :: Float64,
    FLDO :: Integer,
    Nz   :: Integer,
    h_ML_max :: Float64,
)
    
    if_adjust = false

    if FLDO == -1
        return if_adjust, b_ML, T_ML, S_ML, h_ML, FLDO 
    end

    # 1. Search from bottom to see if buoyancy is monotically increasing
    # 2. If not, record the peak, then keep detecting until hitting the 
    #    layer X_top having equal or greater buoyancy. Record this interval.
    # 3. Find the minimum value in this interval b_min.
    # 4. Use b_min to decide the bottom layer X_bot going to be mixed (Search 
    #    downward).
    # 5. Mix layers between X_bot ~ X_top.

    new_b_ML = b_ML
    new_T_ML = T_ML
    new_S_ML = S_ML
    new_h_ML = h_ML
    new_FLDO = FLDO

    stage = :reset
    peak_layer = 0
    top_layer = 0
    bot_layer = 0
    b_peak = 0.0

    ok = false
    last_top_layer = Nz

    while !ok

        ok = true

        for i = last_top_layer:-1:FLDO


            if stage == :reset
                peak_layer = 0
                top_layer = 0
                bot_layer = 0
                b_peak = 0.0
                stage = :search_peak_layer
            end

            if stage == :search_peak_layer

                Δb = bs[i] - ((i==FLDO) ? new_b_ML : bs[i-1])
                #println("FLDO:", FLDO, "; i:", i, "; Δb:", Δb)
                if Δb > 0.0  # Instability
                    #println("i = ", i, ", FLDO = ", FLDO, ", bs[i] = ", bs[i], ", b_ML = ", b_ML)
                    #println(bs)
                    #throw(ErrorException("Instability!"))
                    if_adjust = true
                    stage = :search_top_layer
                    peak_layer = i
                    b_peak = bs[peak_layer]

                    ok = false
                else
                    continue
                end
            end

            if stage == :search_top_layer

                #println(":search_top_layer")
                if i == FLDO
                    top_layer = (new_b_ML > b_peak) ? FLDO : -1
                    stage = :search_bot_layer
                elseif bs[i-1] > b_peak
                    top_layer = i
                    stage = :search_bot_layer
                else
                    continue
                end
            end

            if stage == :search_bot_layer

                #println(":search_bot_layer")

                if peak_layer == Nz

                    bot_layer = peak_layer
                    stage = :start_adjustment

                else
                    b_min = 0.0
                    if top_layer == -1
                        b_min = min(new_b_ML, minimum(bs[FLDO:peak_layer]))
                    else
                        b_min = minimum(bs[top_layer:peak_layer])
                    end 

                    
                    # Need to note that bot_layer is allow to be the same as peak_layer
                    # It is possible that this expansion of bot_layer don't stop and
                    # create a iteration time dependent behavior.
                    bot_layer = peak_layer
                    while true
                        if bs[bot_layer+1] >= b_min

                            bot_layer += 1
                            if bot_layer == Nz
                                stage = :start_adjustment
                                break
                            end
                        else
                            stage = :start_adjustment
                            break
                        end
                    end
                end 
            end


            if stage == :start_adjustment
                #println(":start_adjustment")

                
                bot_z = zs[bot_layer+1]
                #println(zs[bot_layer+1]," v.s.  ", -h_ML_max, "; bot_z: ", bot_z)
                top_z = (top_layer == -1) ? 0.0 : (
                     (top_layer == FLDO) ? -h_ML : zs[top_layer]
                )
                Δz = top_z - bot_z

                mixed_T = (getIntegratedQuantity(
                    zs       =  zs,
                    qs       =  Ts,
                    q_ML     =  new_T_ML,
                    h_ML     =  h_ML,
                    Nz       =  Nz,
                    target_z =  bot_z
                ) - getIntegratedQuantity(
                    zs       =  zs,
                    qs       =  Ts,
                    q_ML     =  new_T_ML,
                    h_ML     =  h_ML,
                    Nz       =  Nz,
                    target_z =  top_z
                ))  / Δz
     
                mixed_S = (getIntegratedQuantity(
                    zs       =  zs,
                    qs       =  Ss,
                    q_ML     =  new_S_ML,
                    h_ML     =  h_ML,
                    Nz       =  Nz,
                    target_z =  bot_z
                ) - getIntegratedQuantity(
                    zs       =  zs,
                    qs       =  Ss,
                    q_ML     =  new_S_ML,
                    h_ML     =  h_ML,
                    Nz       =  Nz,
                    target_z =  top_z
                ))  / Δz
               
                if top_layer == -1  # Even the mixed layer is mixed

                    # 2019/08/04 Decide that convective adjustment does not change MLD.
                    # This makes ML dynamic less complicated

                    new_T_ML = mixed_T 
                    new_S_ML = mixed_S
                    new_b_ML = TS2b(new_T_ML, new_S_ML)
                    
                    # update T, S profile but do not update h_ML and FLDO 
                    setMixedLayer!(Ts=Ts, Ss=Ss, zs=zs, T_ML=new_T_ML, S_ML=new_S_ML, h_ML= - bot_z, Nz=Nz)


                else
                   
                    Ts[top_layer:bot_layer] .= mixed_T
                    Ss[top_layer:bot_layer] .= mixed_S

                end 

                # update buoyancy
                for k=1:Nz
                    bs[k] = TS2b(Ts[k], Ss[k])
                end

                if top_layer == -1   # Everything is done
                    ok = true
                else
                    last_top_layer = top_layer
                end

                stage = :reset 
            end

        end

    end

    return if_adjust, new_b_ML, new_T_ML, new_S_ML, new_h_ML, new_FLDO
end

           

