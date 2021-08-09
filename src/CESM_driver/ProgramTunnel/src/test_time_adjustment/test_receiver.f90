include "../fortran/ProgramTunnelMod_fs.f90"

program test_receiver_f90

    use ProgramTunnelMod_fs

    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    integer :: n, stat, i
    real(8), pointer :: dat(:)
    character(256) :: recvmsg, sendmsg
    integer :: fds(3) = (/11,12,13/)

    call ptm_setDefault(PTI, fds)
    PTI%recv_first_sleep=2000
    call ptm_autoCalculateCnt(PTI)

    call ptm_printSummary(PTI)

    do i=1,100
        stat = ptm_recvText(PTI, recvmsg)
        print *, "[",i,"]", trim(recvmsg)
    end do

end program


