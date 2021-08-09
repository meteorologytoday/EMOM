include "../../src/fortran/ProgramTunnelMod_fs.f90"

program proc1

    use ProgramTunnelMod_fs

    implicit none
    type(ptm_TunnelSet) :: TS
    integer :: n, stat, i
    real(8), pointer :: dat(:)
    character(256) :: recvmsg, sendmsg

    n = 5
    allocate(dat(n))

    do i = 1, 5
        dat(i) = i
    enddo



    call ptm_setDefaultTunnelSet(TS)
    call ptm_printSummary(TS)



    stat = ptm_recvText(TS, recvmsg)
    print *, trim(recvmsg)

    stat = ptm_sendText(TS, "Msg_from_fortran (CESM) ... ")

    stat = ptm_recvText(TS, recvmsg)
    print *, trim(recvmsg)
 
    stat = ptm_sendText(TS, "Msg_from_fortran (CESM) ... again ...")


    print *, "This is the original data"
    print *, dat

    write (sendmsg, '(I5)') n 
    stat = ptm_sendText(TS, trim(sendmsg))
    stat = ptm_sendBinary(TS, dat, n)

    stat = ptm_recvBinary(TS, dat, n)

    print *, "This is the recieved data"
    print *, dat


end program
