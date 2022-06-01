function updateUVsfc!(
    mb    :: ModelBlock,
)
    cfg_core        = mb.ev.cfgs["MODEL_CORE"]
    amo_slab = mb.co.amo_slab
    if cfg_core["UV_sfc_scheme"] == "prognostic"
        mb.fi.U_sfc[:] = reshape(amo_slab.T_interp_U * mb.fi.sv[:UVEL_sfc], mb.ev.Nx, mb.ev.Ny)
        mb.fi.V_sfc[:] = reshape(amo_slab.T_interp_V * mb.fi.sv[:VVEL_sfc], mb.ev.Nx, mb.ev.Ny)
    elseif cfg_core["UV_sfc_scheme"] == "static"
        mb.fi.U_sfc .= 0.0
        mb.fi.V_sfc .= 0.0
    end

end
