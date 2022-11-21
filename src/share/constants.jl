const T_fw_frz_Kelvin = 273.15

const T_fw_frz =  0.0       # Freeze point of freshwater in Celcius
const T_sw_frz = -1.8       # Freeze point of seawater in Celcius

const c_p_sw = 3996.0     # J / kg / C   copied from models/csm_share/shr/shr_const_mod.F90
const ρ_sw   = 1026.0     # kg / m^3     copied from models/csm_share/shr/shr_const_mod.F90
const ρ_si   = 0.917e3    # kg / m^3     copied from models/csm_share/shr/shr_const_mod.F90
const ρ_fw   = 1000.0     # kg / m^3     copied from models/csm_share/shr/shr_const_mod.F90
const g      = 9.80616    # m / s^2      copied from models/csm_share/shr/shr_const_mod.F90
const Re     = 6.37122e6  # m            copied from models/csm_share/shr/shr_const_mod.F90
const Ω      = 2π / (86400 / (1 + 1/365)) # rad / s
const Hf_sw  = 3.337e5     # J / kg  latent heat of fusion  copied from models/csm_share/shr/shr_const_mod.F90 (SHR_CONST_LATICE)
const S_vsref  = 34.7      # PSU  ocean reference salinity used to compute virtual salt flux. This value is copied from models/csm_share/shr/shr_const_mod.F90 (SHR_CONST_OCN_REF_SAL)

const ρcp_sw  = ρ_sw * c_p_sw

const missing_value = 1e20
