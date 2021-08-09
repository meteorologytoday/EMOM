include "ProgramTunnelMod_fs_new.f90"

program test_TB

    use ProgramTunnelMod_fs

    implicit none
    integer, parameter :: nchars = 512
    type(ptm_ProgramTunnelInfo) :: PTI
    integer :: n, stat, i, t
    real(8), pointer :: dat(:)
    character(len=nchars)      :: msg
    character(256)             :: fn
    integer :: fds(2) = (/11,12/)

    call ptm_setDefault(PTI, fds)
    PTI%rotate = 30
 
    n = 20

    allocate(dat(n))
    do t = 1, 100
        print *, t
        do i = 1, n
            dat(i) = t*100 + i
        end do

        write (msg, '("This is the ", I, " time.")') t

        print *, "Sending data: ", trim(msg)
        i = ptm_sendData(PTI, msg, dat(1:10))
        print *, "i: ", i

        do i = 1, n
            dat(i) = 0.0
        end do
        msg = ""
        i = ptm_recvData(PTI, msg, dat(1:10))
        print *, "Read message: [", trim(msg), "]"
        do i = 1, n
            print *, dat(i)
        end do

!        call sleep(1)
    end do



end program

