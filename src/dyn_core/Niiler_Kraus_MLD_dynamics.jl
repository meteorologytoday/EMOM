"""

    calNewMLD(; h, B, fric_u, Δb, f, Δt, m=0.8, n=0.2)

# Description


 The calculation follows eqn (30) of Gasper (1988). The changes are:

   1. We assume that all sunlight is absorbed at the very surface. According to Paulson and James (1988), in upper ocean
      90% of the radiation is absorbed within the first 10 meters. Since even POP has the resultion of 10m, it is reasonable
      that we ignore the structrue of light absorbtion in sea-water.

   2. Turbulent kinetic energy is added into the equation to avoid the case Δb = 0 which results in we → ∞. This follows
      the reasoning in Alexander et al. (2000)

 References: 

   Gaspar, Philippe. "Modeling the seasonal cycle of the upper ocean." Journal of Physical Oceanography 18.2 (1988): 161-180.

   Paulson, Clayton A., and James J. Simpson. "Irradiance measurements in the upper ocean." 
   Journal of Physical Oceanography 7.6 (1977): 952-956.

   Alexander, Michael A., James D. Scott, and Clara Deser. "Processes that influence sea surface temperature and ocean mixed 
   layer depth variability in a coupled model." Journal of Geophysical Research: Oceans 105.C7 (2000): 16823-16842.


# Return values
This function returns a list with two elements. The first is a symbol. ``:we`` indicates the second value is the entrainment speed whereas ``:MLD`` indicates the second value is the diagnosed MLD.

"""
function calNewMLD(;
    h_ML   :: Float64,
    Bf     :: Float64,    # sum of sensible heat fluxes and longwave radiation flux
    J0     :: Float64,    # shortwave radiation flux (converted to buoyancy flux)
    fric_u :: Float64,
    Δb     :: Float64,
    f      :: Float64,
    Δt     :: Float64,
    ζ      :: Float64,    # decay scale length of shortwave penetration
    m::Float64 = 0.8,
    n::Float64 = 0.20,
    h_max  :: Float64,
    we_max :: Float64,
)

    if Δb < 0
        throw(ErrorException("Δb cannot be negative. Right now Δb = " * string(Δb)))
    end

    #
    # Transform the equation of entrainment into the form
    # we (h_ML × Δb + k) =  a exp(-h / λ) + b h + c S(h, ζ) := Δ
    #
    # where Δ is called "determinant"
    #       a       = 2 m u_fric^3
    #       b       = Bf
    #       c       = J0
    #       S(h, γ) = h - 2 ζ + exp(-h/ζ) (h + 2 ζ)
    #       λ       = fric_u / abs(f)
    #
    
    a, λ = calΔCoefficients(fric_u, f, m)
    Δ, _ = calΔ_and_∂Δ∂h(h_ML, a, Bf, J0, λ, ζ, n; need_∂Δ∂h=false)

    h_MO = solveMoninObuhkovLength_bisection(h_max, a, Bf, J0, λ, ζ, n)
    
    # 2019/08/05 Newton method. Not a robust way
    # h_MO = solveMoninObuhkovLength(h_max, a, Bf, J0, λ, ζ, n)

    if Δ >= 0
        k = getTKE(fric_u=fric_u)
        we = Δ / (h_ML * Δb + k)

        # First min function restrict the maximum of entrainment speed
        # Second min function restrict the maximum of MLD

        return min(h_ML + Δt * min(we, we_max), h_MO), h_MO
    else

        # h becomes diagnostic.
        # Notice that if Δ < 0, then finite positive solution of h_MO exists
        return h_MO, h_MO
    end

end

@inline function calΔCoefficients(
    u_fric::Float64,
    f::Float64,
    m::Float64,
)
    return 2.0 * m * u_fric^3.0, u_fric / abs(f) 
end

function calΔ_and_∂Δ∂h(
    h::Float64,
    a::Float64,
    b::Float64,
    c::Float64,
    λ::Float64,
    ζ::Float64,
    n::Float64;
    need_∂Δ∂h=true,
)
    Bh = b * h + c * S(h, ζ)
    ( Bh < 0.0 ) && ( n = 1.0 )
    exponential = exp(-h / λ)
    return ( ( λ == 0.0 ) ? 0.0 : a * exponential ) + n * Bh,
           ( need_∂Δ∂h ) ? ( ( λ == 0.0 ) ? 0.0 : - a / λ * exponential ) + n * (b + c * ∂S∂h(h, ζ)) : 0.0
end

@inline function S(h::Float64, ζ::Float64)
    return h - 2.0 * ζ + exp(-h / ζ) * (h + 2.0 * ζ)
end

@inline function ∂S∂h(h::Float64, ζ::Float64)
    return 1 - exp(-h / ζ) * (1 + h / ζ)
end

# it is possible to have multisolution but we ignore this problem
function solveMoninObuhkovLength_bisection(
    h_max  :: Float64,
    a      :: Float64,
    b      :: Float64,
    c      :: Float64,
    λ      :: Float64,
    ζ      :: Float64,
    n      :: Float64;
    δh_max :: Float64 = 0.01,  # absolute increment threshold = 1cm
    max    :: Integer = 100,
)

    Δ, _ = calΔ_and_∂Δ∂h(h_max, a, b, c, λ, ζ, n; need_∂Δ∂h = false)

    if Δ > 0
        return h_max
    end

    bot = 0.0
    top = h_max

    local h

    for t = 1:max

        h = (bot + top) / 2.0
        Δ, _ = calΔ_and_∂Δ∂h(h, a, b, c, λ, ζ, n; need_∂Δ∂h = false)
        
        if Δ < 0
            top = h
        elseif Δ > 0
            bot = h
        else # Δ = 0 which is rare
            return h
        end
        
        if (top - bot) < δh_max   
            return h
        end
    end
        
    throw(ErrorException("Monin-Obuhkov length iteration reached max before δh gets below δh_max."))
end


function solveMoninObuhkovLength(
    h      :: Float64,   # initial guess
    a      :: Float64,
    b      :: Float64,
    c      :: Float64,
    λ      :: Float64,
    ζ      :: Float64,
    n      :: Float64;
    η      :: Float64 = 0.01,  # relative increment threshold = 1%
    δh_max :: Float64 = 0.01,  # absolute increment threshold = 1cm
    max    :: Integer = 100,
)

    if_converge = false
    prev_δh = 0.0

    # The only contribution of negativity comes from b + c
    if b + c > 0
#        println("MO Length Inf!", h, ",", a, ",", b, ",", c, ",", λ)
        return Inf
    end

    for i=1:max
        Δ, ∂Δ∂h = calΔ_and_∂Δ∂h(h, a, b, c, λ, ζ, n)
        δh = - Δ / ∂Δ∂h
        #println(i, ":", h, "; δh=",δh, ", Δ=", Δ, "; ∂Δ∂h=", ∂Δ∂h)
        if abs((δh - prev_δh) / prev_δh) >= η && abs(δh) >= δh_max
            h, prev_δh = h + δh, δh
        else
            if_converge = true
#            if h < 10.0
#                println("Converge!", h, ",", a, ",", b, ",", c, ",", λ)
#            end
            break
        end
    end
    
    if if_converge
        return h
    else
        throw(ErrorException("Monin-Obuhkov length iteration cannot converge"))
    end
end
