# This file uses constants defined in constant.jl
#
# Follow Bryan and Cox (1972) : An Approximate Equation of State for Numerical Models of Ocean Circulation
# Here we use Table 3, and arbitrary pick Z=0m as the formula.
#

const T_ref =   13.5
const S_ref =   32.6
const ρ_ref = 1024.458

const _ρ1 = -.20134    / ρ_ref
const _ρ2 =  .77096    / ρ_ref
const _ρ3 = -.49261e-2 / ρ_ref
const _ρ4 =  .46092e-3 / ρ_ref
const _ρ5 = -.20105e-2 / ρ_ref
const _ρ6 =  .36597e-4 / ρ_ref
const _ρ7 =  .47371e-5 / ρ_ref
const _ρ8 =  .37735e-4 / ρ_ref
const _ρ9 =  .65493e-5 / ρ_ref


@inline function TS2b(T::Float64, S::Float64)
    ΔT = T - T_ref
    ΔS = S - S_ref
    return - g * ( _ρ1*ΔT + _ρ2*ΔS +  _ρ3*(ΔT^2) + _ρ4*(ΔS^2) + _ρ5*ΔT*ΔS + _ρ6*(ΔT^3) + _ρ7*(ΔS^2)*ΔT + _ρ8*(ΔT^2)*ΔS + _ρ9*(ΔS^3) )
end

@inline function TS2α(T, S)
    ΔT = T - T_ref
    ΔS = S - S_ref
    return  - ( _ρ1 + 2*_ρ3*ΔT + _ρ5*ΔS + 3*_ρ6*(ΔT^2) + _ρ7*(ΔS^2) + 2*_ρ8*ΔS*ΔT )
end

@inline function TS2β(T, S)
    ΔT = T - T_ref
    ΔS = S - S_ref
    return  _ρ2 + 2*_ρ4*ΔS + _ρ5*ΔT + 2*_ρ7*ΔS*ΔT + _ρ8*(ΔT^2) + 3*_ρ9*(ΔS^2)
end








