function updateUVSFC!(
    mb    :: ModelBlock,
)
    cfg_core        = mb.ev.cfgs["MODEL_CORE"]
    amo_slab = mb.co.amo_slab
    if cfg_core["UVSFC_scheme"] == "prognostic"
        mb.fi.USFC[:] = reshape(amo_slab.T_interp_U * mb.fi.sv[:USFC], mb.ev.Nx, mb.ev.Ny)
        mb.fi.VSFC[:] = reshape(amo_slab.T_interp_V * mb.fi.sv[:VSFC], mb.ev.Nx, mb.ev.Ny)
    elseif cfg_core["UVSFC_scheme"] == "static"
        mb.fi.USFC .= 0.0
        mb.fi.VSFC .= 0.0
    end

end
