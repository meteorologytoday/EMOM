
_interpolate_helper = (x0, y0, x1, y1, x) -> ( y0 * (x1 - x) + y1 * (x - x0) ) / (x1 - x0)

function interpolate(x0, y0, x1; left_copy::Bool=false, right_copy::Bool=false)
    
    # assuming x0, x1 are both monotonically increasing

    idx0 = 1  # old coordinate
    idx1 = 1  # new coordinate

    N0 = length(x0)

    y1 = copy(x1)
    N1 = length(x1)

    while true

        if idx1 > N1
            break
        end

        lx = x0[idx0  ]
        ly = y0[idx0  ]

        rx = x0[idx0+1]
        ry = y0[idx0+1]
        
        ix = x1[idx1]

        if (idx0 == 1) && (ix < lx)

            y1[idx1] = (left_copy) ? ly : NaN
            idx1 += 1

        elseif (idx0 == N0-1) && (ix > rx)

            y1[idx1] = (right_copy) ? ry : NaN
            idx1 += 1

        elseif lx <= ix <= rx
            
            y1[idx1] = _interpolate_helper(lx, ly, rx, ry, ix)
            idx1 += 1
            
        else
            
            idx0 += 1

        end

    end

    return y1
end
