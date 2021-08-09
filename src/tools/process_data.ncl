begin

varnames = (/                        \
    "omlmax",                        \
    "tos",                           \
    "hfds"                           \
/)


var_comps_list = NewList("lifo")
ListAppend(var_comps_list, (/"omlmax"/)) 
ListAppend(var_comps_list, (/"tos"/)) 
ListAppend(var_comps_list, (/"hfds"/)) 


year_interval = 200
beg_years = ispan(96, 295, year_interval)
;beg_years := ispan(1861, 1891, year_interval)
;beg_years := ispan(1861, 1866, year_interval)

signature = "_Omon_CESM1-WACCM_piControl_r1i1p1_"

ref_fh = addfile("hfds" + signature + "009601-029512.nc", "r")
dim = dimsizes(ref_fh->hfds)
lat2d = ref_fh->lat
lon2d = ref_fh->lon
tmp = new(dim, "float")
tmp@_FillValue = ref_fh->hfds@_FillValue
tmp@missing_value = tmp@_FillValue
copy_VarCoords(ref_fh->hfds, tmp)


time = todouble(ispan(1, year_interval * 12 * dimsizes(beg_years), 1))
delete_VarAtts(time, -1)

time!0 = "time"
time&time = time
time@unit = "month"
time@long_name = "month"


dim := (/dimsizes(time), dim(1), dim(2)/)
output_var = new(dim, "float")
output_var = 0


new_lat = fspan(-90.0, 90.0, 192/3)
new_lon = fspan(0, 360, 321/3)
new_lon := new_lon(0:dimsizes(new_lon)-1)

new_lat!0 = "lat"
new_lat&lat = new_lat
new_lat@unit = "degree_north"
new_lat@long_name = "latitude coordinate"

new_lon!0 = "lon"
new_lon&lon = new_lon
new_lon@unit = "degree_east"
new_lon@long_name = "longitude coordinate"

print("Begin loop")
do j = 0, dimsizes(varnames) - 1

    do i = 0, dimsizes(beg_years) - 1
        beg_year = beg_years(i)
        end_year = beg_year + year_interval - 1

        varname = varnames(j)
        var_comps := var_comps_list[j]
        tmp = 0 ; clear all value
        
        do k = 0, dimsizes(var_comps) - 1
        
            var_comp = var_comps(k)
            filename = var_comp + signature + sprinti("%0.4i", beg_year) + "01-" + sprinti("%0.4i", end_year) + "12.nc"
            print("Reading file:" + filename)
            fh = addfile(filename, "r")

            ; Notice when LHS involves more than two variables
            ; it does not copy attributes such as missing_value, _FillValue
            tmp = tmp + fh->$var_comp$

            delete(fh)

        end do

        output_var(year_interval * 12 * i : year_interval * 12 * (i+1) - 1, :, :) = tmp

    end do


    print("Remapping data.")
    ; Remapping data
    output_var_remap = rcm2rgrid(lat2d, lon2d, output_var, new_lat, new_lon, 1)

    ; Output var
    fout_name = "SMART_3deg_" + varname + signature + sprinti("%0.4i", beg_years(0)) + "01-" + sprinti("%0.4i", beg_years(dimsizes(beg_years)-1) + year_interval - 1) + "12.nc"
    system("rm -f " + fout_name)
    print("Writing " + varname + " to " + fout_name)

    fout = addfile(fout_name, "c")
    fout->lat = new_lat
    fout->lon = new_lon
    fout->time = time

    output_var_remap!0 = "time"
    output_var_remap!1 = "lat"
    output_var_remap!2 = "lon"
    output_var_remap&time = time
    output_var_remap&lat  = new_lat
    output_var_remap&lon  = new_lon
    fout->$varname$ = output_var_remap

    delete(fout)

end do


delete(ref_fh)

end 
