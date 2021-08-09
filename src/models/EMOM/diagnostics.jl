function calDiagnostics!(
    ocn :: Ocean
)
    
    ocn.diag[:total_heat][1] = (c_p_sw * ocn.ASUM.sumΔvol_T * reshape(ocn.Ts_mixed, :, 1))[1]
    ocn.diag[:total_salt][1] =          (ocn.ASUM.sumΔvol_T * reshape(ocn.Ss_mixed, :, 1))[1]
    
    
end
