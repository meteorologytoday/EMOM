module NewtonMethod

using Printf

export NotConvergeException, Newton

struct NotConvergeException <: Exception
end

function fit1(;
    f_and_∇f  :: Function,    # Target function g and its Jacobian
    η         :: T,           # Threshold
    x0        :: T,           # Initial guess
    max       :: Integer,     # Maximum iteration
) where T <: AbstractFloat
    
    local x = x0
    local if_converge = false

    local rchg = 0.0
    local prev_eulen_Δx = 0.0

    for i = 1:max
        f, ∇f = f_and_∇f(x)
        Δx = - ∇f \ f

        eulen_Δx = (Δx' * Δx)^0.5
        rchg = abs((eulen_Δx - prev_eulen_Δx) / prev_eulen_Δx)

        if rchg >= η
            x += Δx
            prev_eulen_Δx = eulen_Δx
        else
            if_converge = true
            break
        end
    end

    if if_converge == false
       throw(NotConvergeException()) 
    end

    return x
end


function fitN(;
    f_and_∇f  :: Function,    # Target function g and its Jacobian
    η         :: T,           # Threshold
    x0        :: Array{T, 1}, # Initial guess
    max       :: Integer,     # Maximum iteration
    verbose   :: Bool=false
) where T <: AbstractFloat
    #println("Newton method!")
    #println(typeof(f_and_∇f))
    local x = x0 * 1.0
    local if_converge = false


    local rchg = 0.0
    local prev_eulen_Δx = 0.0

    for i = 1:max
        if verbose
            println("Newton method iteration: ", i)
            println("x: ", x)
        end
        f, ∇f = f_and_∇f(x)
        Δx = - ∇f \ f

        eulen_Δx = (Δx' * Δx)^0.5
        rchg = abs((eulen_Δx - prev_eulen_Δx) / prev_eulen_Δx)

        verbose && @printf("|Δx| = %f, Old |Δx| = %f, relative chg = %f\n", eulen_Δx, prev_eulen_Δx, rchg)
        if rchg >= η
            x += Δx
            prev_eulen_Δx = eulen_Δx
        else
            if_converge = true
            break
        end
    end

    if if_converge == false
       throw(NotConvergeException()) 
    end

    return x
end


end
