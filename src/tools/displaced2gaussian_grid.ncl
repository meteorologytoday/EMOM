begin


varnames = (/                        \
    "mld",                           \
    "sst",                           \
    "fric_u",                        \
    "sumflx"                         \
/)


fin = "SSM_output_002.nc"
fout = "Gaussian_" + fin

d_in = addfile(fin, "r")

lat2d = d_in->yc
lon2d = d_in->xc

new_lat = fspan(-90.0, 90.0, 100)
new_lon = fspan(0, 360, 101)
new_lon := new_lon(0:dimsizes(new_lon)-2) ; since it is periodic, must drop one point.

new_lat!0 = "lat"
new_lat&lat = new_lat
new_lat@unit = "degree_north"
new_lat@long_name = "latitude coordinate"

new_lon!0 = "lon"
new_lon&lon = new_lon
new_lon@unit = "degree_east"
new_lon@long_name = "longitude coordinate"


; Clear output file
system("rm -f " + fout)
print("Remove " + fout)

d_out = addfile(fout, "c")
d_out->lat = new_lat
d_out->lon = new_lon
;d_out->time = d_in->time

do j = 0, dimsizes(varnames) - 1

    varname = varnames(j)
    print("Remapping variable: " + varname)

    output_var = d_in->$varname$

    ; Remapping data
    output_var_remap = rcm2rgrid(lat2d, lon2d, output_var, new_lat, new_lon, 1)

    output_var_remap!0 = "time"
    output_var_remap!1 = "lat"
    output_var_remap!2 = "lon"
    ;output_var_remap&time = d_in->time
    output_var_remap&lat  = new_lat
    output_var_remap&lon  = new_lon
    d_out->$varname$ = output_var_remap

end do


delete(d_in)
delete(d_out)






end
