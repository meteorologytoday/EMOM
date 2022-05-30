#!/bin/bash


ncap2 -v -s '*dz=dz_cT(:, 0, 0); *da=area_sT(0, :, :); *dvol[$z_t,$nlat,$nlon]=dz*da; ttl_vol=dvol.ttl();' \
         -s '*dzQFLXT[$time,$z_t,$nlat,$nlon]=dz*QFLXT; int_QFLXT=dzQFLXT.ttl($z_t);' \
         -s 'defdim("z_t_partial",10); *iii[$time,$z_t_partial,$nlat,$nlon]=dzQFLXT(:,0:9,:,:);int_QFLXT_partial=iii.ttl($z_t_partial)' \
         -s '*dzQFLXS[$time,$z_t,$nlat,$nlon]=dz*QFLXS; int_QFLXS=dzQFLXS.ttl($z_t);' \
         -s '*dvolQFLXT[$time,$nlat,$nlon]=da*int_QFLXT; mean_QFLXT=dvolQFLXT.ttl($nlon,$nlat)/ttl_vol;' \
         -s '*dvolQFLXS[$time,$nlat,$nlon]=da*int_QFLXS; mean_QFLXS=dvolQFLXS.ttl($nlon,$nlat)/ttl_vol;' \
         -s 'avgmean_QFLXT=mean_QFLXT.avg();' \
         -s 'avgmean_QFLXS=mean_QFLXT.avg();' \
         $1 $2
