include "ProgramTunnelMod_fs_new.f90"

program test_TB

    use ProgramTunnelMod_fs
    implicit none
    real(8) :: dat(5) = (/ 1.0, 2.0, 3.0, 4.0 , 5.0 /)

    print *, ptm_calChecksum(dat)



end program

