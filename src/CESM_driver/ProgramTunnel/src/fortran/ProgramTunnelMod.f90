module ProgramTunnelMod
implicit none

integer, parameter :: c_send_txt = 1, c_recv_txt = 2, c_send_bin = 3, c_recv_bin = 4
character(len=256), parameter :: keys(4) = (/"X2Y_txt", "Y2X_txt", "X2Y_bin", "Y2X_bin"/)


type ptm_Tunnel
    Integer :: next_idx
    Integer :: fds(2)
    character(len=256) :: fns(2)
end type


type ptm_TunnelSet
    type(ptm_Tunnel) :: tnls(4)
end type


contains

integer function ptm_get_file_unit()
    integer :: lu, iostat
    logical :: opened
      
    do lu = 999, 1,-1
       inquire (unit=lu, opened=opened, iostat=iostat)
       if (iostat.ne.0) cycle
       if (.not.opened) exit
    end do
    
    ptm_get_file_unit = lu
    return
end function 

subroutine ptm_makeFilename(filename, id, n)
    implicit none
    character(len=*) :: filename, id
    integer          :: n

    write (filename, '(A, A, A, I1, A)')  "_", trim(id), "_", n, ".fifo"

end subroutine

subroutine ptm_blockUntilTunnelCreated(TS)
    implicit none
    type(ptm_TunnelSet) :: TS
    integer :: fds(8)
    integer :: i, j
    logical file_exists, all_pass


    all_pass = .false.
    
    do
        all_pass = .true.
        
        do i = 1, 4
            do j = 1, 2
                inquire(file=TS%tnls(i)%fns(j), exist=file_exists)
                all_pass = all_pass .and. file_exists
            end do
        end do

        if (all_pass .eqv. .true.) then
            print *, "Tunnels are created!"
            exit
        else
            print *, "Tunnels are not created, sleep and check again..."
            call sleep(1)
        end if  
    end do
end subroutine 


subroutine ptm_setDefaultTunnelSet(TS, fds)
    implicit none
    type(ptm_TunnelSet) :: TS
    integer :: fds(8)
    integer :: i, j
    do i = 1, 4
        do j = 1, 2
            call ptm_makeFilename(TS%tnls(i)%fns(j), keys(i), j)
            TS%tnls(i)%fds(j) = fds((i-1) * 2 + (j-1) + 1)
            TS%tnls(i)%next_idx = 1
        end do
    end do
end subroutine 

subroutine ptm_appendPath(TS, path)
    implicit none
    type(ptm_TunnelSet) :: TS
    integer :: fds(8)
    integer :: i, j
    character(len=256) :: path
    do i = 1, 4
        do j = 1, 2
            TS%tnls(i)%fns(j) = trim(path) // "/" // trim(TS%tnls(i)%fns(j))
            print *, "FIFO: ", trim(TS%tnls(i)%fns(j) )
        end do
    end do
end subroutine 


subroutine ptm_printSummary(TS)
    implicit none
    type(ptm_TunnelSet) :: TS
    integer :: i, j

    do i = 1, 4
        print *, "keys(", i, ") => ", trim(keys(i))
    end do

    do i = 1, 4
        do j = 1, 2
            print *, trim(keys(i)), "(", TS%tnls(i)%fds(j), ") =>", trim(TS%tnls(i)%fns(j))

        end do
    end do

    print *, "Next sendText   uses idx: ", TS%tnls(c_send_txt)%next_idx
    print *, "Next sendBinary uses idx: ", TS%tnls(c_recv_txt)%next_idx
    print *, "Next recvText   uses idx: ", TS%tnls(c_send_bin)%next_idx
    print *, "Next recvBinary uses idx: ", TS%tnls(c_recv_bin)%next_idx

end subroutine

subroutine ptm_iterTunnel(tnl)
    implicit none
    type(ptm_Tunnel) :: tnl
    integer :: tmp

    !tmp = TS%tnls(n)%next_idx 
    tnl%next_idx = mod(tnl%next_idx, 2) + 1
    !print *, "What is the tunnel file you get? ", trim(TS%tnls(n)%fns(tmp))

end subroutine

subroutine ptm_getTunnelInfo(TS, n, fd, fn, update)
    implicit none
    type(ptm_TunnelSet), target  :: TS
    integer                      :: n
    integer                      :: fd
    character(*), pointer        :: fn
    logical                      :: update

    type(ptm_Tunnel), pointer :: tnl
    integer                   :: idx
    
    tnl => TS%tnls(n)
    idx = tnl%next_idx
 
    fd =  tnl%fds(idx)
    fn => tnl%fns(idx)

    if (update .eqv. .true.) then
        call ptm_iterTunnel(tnl)
    end if

end subroutine


integer function ptm_sendText(TS, msg)
    implicit none
    type(ptm_TunnelSet)  :: TS
    character(len=*)     :: msg

    character(len=256), pointer :: fn
    integer :: fd

    call ptm_getTunnelInfo(TS, c_send_txt, fd, fn, .true.)

    print *, "ptm_sendText: [" , trim(msg) , "]"
    print *, "Filename: ", trim(fn)

    ptm_sendText = 0
    open(unit=fd, file=fn, form="formatted", access="stream", action="write", iostat=ptm_sendText, status="OLD")
    if (ptm_sendText .gt. 0) then
        print *, "[ptm_sendText] Error during open."
        close(fd)
        return
    end if

    ptm_sendText = 0
    write (fd, *, iostat=ptm_sendText) msg
    if (ptm_sendText .gt. 0) then
        print *, "[ptm_sendText] Error during write."
        close(fd)
        return
    end if
   
    close(fd)
    
end function

integer function ptm_recvText(TS, msg)
    implicit none
    type(ptm_TunnelSet)  :: TS
    character(len=*)     :: msg
 
    character(len=256), pointer :: fn
    integer :: fd

    call ptm_getTunnelInfo(TS, c_recv_txt, fd, fn, .true.)

    ptm_recvText = 0
    open(unit=fd, file=fn, form="formatted", access="stream", action="read", iostat=ptm_recvText, status="OLD")
    if (ptm_recvText .gt. 0) then
        print *, "ERROR OPENING RECV TXT PIPE, errcode:", ptm_recvText
        close(fd)
        return
    end if

    ptm_recvText = 0
    read (fd, '(A)', iostat=ptm_recvText) msg
    if (ptm_recvText .gt. 0) then
        print *, msg
        print *, "ERROR READING RECV TXT PIPE, errcode:", ptm_recvText
        close(fd)
        return
    end if

    close(fd)
    
    msg = trim(msg)

end function

integer function ptm_sendBinary(TS, dat, n)
    implicit none
    type(ptm_TunnelSet)  :: TS
    real(8), intent(in)  :: dat(n)
    integer, intent(in)  :: n
    integer              :: i

    character(len=256), pointer :: fn
    integer :: fd

    call ptm_getTunnelInfo(TS, c_send_bin, fd, fn, .true.)
    
    ptm_sendBinary = 0
    open(unit=fd, file=fn, form="unformatted", status="OLD", &
         access="stream", action="write", iostat=ptm_sendBinary,  &
         convert='LITTLE_ENDIAN')

    if (ptm_sendBinary .gt. 0) then
        print *, "[_ptm_sendBinary] Error during open."
        close(fd)
        return
    end if

    ptm_sendBinary = 0
    write (fd, iostat=ptm_sendBinary) (dat(i), i=1,n,1)
    if (ptm_sendBinary .gt. 0) then
        print *, "[_ptm_sendBinary] Error during write, err code: ", ptm_sendBinary
        close(fd)
        return
    end if
   
    close(fd)

end function



integer function ptm_recvBinary(TS, dat, n)
    implicit none
    type(ptm_TunnelSet)    :: TS
    real(8), intent(inout) :: dat(n)
    integer, intent(in)    :: n
    integer                :: i

    character(len=256), pointer :: fn
    integer :: fd

    call ptm_getTunnelInfo(TS, c_recv_bin, fd, fn, .true.)

    ptm_recvBinary = 0
    open(unit=fd, file=fn, form="unformatted", status="OLD", &
         access="stream", action="read", iostat=ptm_recvBinary,  &
         convert='LITTLE_ENDIAN')

    if (ptm_recvBinary .gt. 0) then
        print *, "ERROR OPENING RECV BIN PIPE, errcode: ", ptm_recvBinary
        close(fd)
        return
    end if

    ptm_recvBinary = 0
    read (fd, iostat=ptm_recvBinary) (dat(i),i=1,n,1)
    if (ptm_recvBinary .gt. 0) then
        print *, "ERROR READING RECV BIN PIPE, errcode:", ptm_recvBinary
        close(fd)
        return
    end if

    close(fd)
    
end function




logical function ptm_messageCompare(msg1, msg2)
    implicit none
    character(*) :: msg1, msg2

    if (msg1 .eq. msg2) then
        ptm_messageCompare = .true.
    else
        ptm_messageCompare = .false.
    end if

end function




end module 
