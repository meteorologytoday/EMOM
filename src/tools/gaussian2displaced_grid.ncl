begin

varnames = (/                        \
    "Q_mean",                        \
    "h_mean"                         \
/)


fin_file = "stanfit_MLM2L_strong_NCAR_5deg_c4_s1000_w200.nc"
fout_file = "gx3v7_" + fin_file
domain_file = "/home/tienyiah/cesm_inputdata/cesm1/share/domains/domain.ocn.gx3v7.120323.nc"

din_fh = addfile(fin_file, "r")

domain_fh = addfile(domain_file, "r")
lat2d = domain_fh->yc
lon2d = domain_fh->xc

lat = din_fh->lat
lon = din_fh->lon

; Clear output file
system("rm -f " + fout_file)
print("Remove " + fout_file)

dout_fh = addfile(fout_file, "c")

domain_varnames = (/"xc", "yc", "xv", "yv", "mask", "frac"/)
do j = 0, dimsizes(domain_varnames) - 1
    dout_fh->$domain_varnames(j)$ = domain_fh->$domain_varnames(j)$
end do

do j = 0, dimsizes(varnames) - 1

    varname = varnames(j)
    print("Remapping variable: " + varname)

    output_var = din_fh->$varname$

    ; Remapping data
    output_var_remap = rgrid2rcm(lat, lon, output_var, lat2d, lon2d, 1)
    output_var_remap!0 = "time"
    output_var_remap!1 = "nj"
    output_var_remap!2 = "ni"

    dout_fh->$varname$ = output_var_remap

end do


delete(din_fh)
delete(dout_fh)
delete(domain_fh)






end
