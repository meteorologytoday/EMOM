include "ProgramTunnelMod_fs_new.f90"

program test_TB

    use ProgramTunnelMod_fs

    implicit none
    integer, parameter :: nchars = 16
    type(ptm_ProgramTunnelInfo) :: PTI
    integer :: n, stat, i
    real(8), pointer :: dat(:)
    character(len=nchars)      :: msg
    character(256)             :: fn
    integer :: fds(3) = (/11,12,13/)


    fn = "Test.tb"
    n = 10

    allocate(dat(n))


    do i = 1, n
        dat(i) = i
    end do

    msg = "abcdefg"
    i = ptm_writeData(fn, fds(1), msg, nchars, dat)

    print *, "i: ", i

    do i = 1, n
        dat(i) = 0.0
    end do


    msg = ""
    i = ptm_readData(fn, fds(2), msg, nchars, dat)

    print *, "Read message: [", trim(msg), "]"
    do i = 1, n
        print *, dat(i)
    end do





end program

