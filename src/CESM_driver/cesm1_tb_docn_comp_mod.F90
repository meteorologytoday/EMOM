#ifdef AIX
@PROCESS ALIAS_SIZE(805306368)
#endif

! XTT MODIFICATION BEGIN
include "./ProgramTunnel/src/fortran/ProgramTunnelMod_fs_new.f90"
! XTT MODIFICATION ENDS



module docn_comp_mod

! !USES:

  use shr_const_mod
  use shr_sys_mod
  use shr_kind_mod     , only: IN=>SHR_KIND_IN, R8=>SHR_KIND_R8, &
                               CS=>SHR_KIND_CS, CL=>SHR_KIND_CL
  use shr_file_mod     , only: shr_file_getunit, shr_file_getlogunit, shr_file_getloglevel, &
                               shr_file_setlogunit, shr_file_setloglevel, shr_file_setio, &
                               shr_file_freeunit
  use shr_mpi_mod      , only: shr_mpi_bcast
  use mct_mod
  use esmf
  use perf_mod
  use pio, only : iosystem_desc_t, pio_init, pio_rearr_box

  use shr_strdata_mod
  use shr_dmodel_mod
  use shr_pcdf_mod

  use seq_cdata_mod
  use seq_infodata_mod
  use seq_timemgr_mod
  use seq_comm_mct     , only: seq_comm_inst, seq_comm_name, seq_comm_suffix
  use seq_flds_mod     , only: seq_flds_o2x_fields, &
                               seq_flds_x2o_fields


! ===== XTT MODIFIED BEGIN =====

  use ProgramTunnelMod_fs

! ===== XTT MODIFIED END =====


!
! !PUBLIC TYPES:
  implicit none
  private ! except

!--------------------------------------------------------------------------
! Public interfaces
!--------------------------------------------------------------------------

  public :: docn_comp_init
  public :: docn_comp_run
  public :: docn_comp_final

!--------------------------------------------------------------------------
! Private data
!--------------------------------------------------------------------------

  !--- other ---
  type(iosystem_desc_t), pointer :: iosystem
  character(CS) :: myModelName = 'ocn'   ! user defined model name
  integer(IN)   :: mpicom
  integer(IN)   :: my_task               ! my task in mpi communicator mpicom
  integer(IN)   :: npes                  ! total number of tasks
  integer(IN),parameter :: master_task=0 ! task number of master task
  integer(IN)   :: logunit               ! logging unit number
  integer       :: inst_index            ! number of current instance (ie. 1)
  character(len=16) :: inst_name         ! fullname of current instance (ie. "lnd_0001")
  character(len=16) :: inst_suffix       ! char string associated with instance 
                                         ! (ie. "_0001" or "")
  character(CL) :: ocn_mode              ! mode
  integer(IN)   :: dbug = 0              ! debug level (higher is more)
  logical       :: firstcall             ! first call logical
  logical       :: scmMode = .false.     ! single column mode
  real(R8)      :: scmLat  = shr_const_SPVAL  ! single column lat
  real(R8)      :: scmLon  = shr_const_SPVAL  ! single column lon
  logical       :: read_restart          ! start from restart

  character(len=*),parameter :: rpfile = 'rpointer.ocn'
  character(len=*),parameter :: nullstr = 'undefined'

  real(R8),parameter :: cpsw    = shr_const_cpsw    ! specific heat of sea h2o ~ J/kg/K
  real(R8),parameter :: rhosw   = shr_const_rhosw   ! density of sea water ~ kg/m^3
  real(R8),parameter :: rhofw   = shr_const_rhofw   ! density of fresh water ~ kg/m^3
  real(R8),parameter :: TkFrz   = shr_const_TkFrz   ! freezing point, fresh water (Kelvin)
  real(R8),parameter :: TkFrzSw = shr_const_TkFrzSw ! freezing point, sea   water (Kelvin)
  real(R8),parameter :: latice  = shr_const_latice  ! latent heat of fusion
  real(R8),parameter :: ocnsalt = shr_const_ocn_ref_sal  ! ocean reference salinity

  ! ===== XTT MODIFIED BEGIN =====

  integer(IN)   :: kt,ks,ku,kv,kdhdx,kdhdy,kq  ! field indices
  integer(IN)   :: kswnet,klwup,klwdn,ksen,klat,kmelth,ksnow,kroff,kioff,kmeltw,kvsflx


  integer(IN)   :: kmld, kqflx_t, kqflx_s
  ! ===== XTT MODIFIED END =====

  type(shr_strdata_type) :: SDOCN
  type(mct_rearr) :: rearr
  type(mct_avect) :: avstrm   ! av of data from stream
  real(R8), pointer :: somtp(:)
  integer , pointer :: imask(:)

  ! ===== XTT MODIFIED BEGIN =====
  ! OLD code ! character(len=*),parameter :: flds_strm = 'strm_h:strm_qbot'

  ! strm_IF_clim == strm_IFRAC_clim. I trim it to fit character size of 12
  character(len=*),parameter :: flds_strm = 'strm_MLD:strm_Qflx_T:strm_Qflx_S:strm_T_clim:strm_S_clim:strm_IF_clim'



  ! OLD code ktrans = 28, (without tclim, strm_tclim, sclim, strm_sclim)

  integer(IN),parameter :: ktrans = 32
  character(12),parameter  :: avifld(1:ktrans) = &
     (/ "ifrac       ","pslv        ","duu10n      ","taux        ","tauy        ", &
        "swnet       ","lat         ","sen         ","lwup        ","lwdn        ", &
        "melth       ","salt        ","prec        ","snow        ","rain        ", &
        "evap        ","meltw       ","roff        ","ioff        ",                &
        "t           ","u           ","v           ","dhdx        ","dhdy        ", &
        "s           ","q           ","MLD         ","Qflx_T      ","Qflx_S      ", &
        "T_clim      ","S_clim      ","IFRAC_clim  "  /)
  character(12),parameter  :: avofld(1:ktrans) = &
     (/ "Si_ifrac    ","Sa_pslv     ","So_duu10n   ","Foxx_taux   ","Foxx_tauy   ", &
        "Foxx_swnet  ","Foxx_lat    ","Foxx_sen    ","Foxx_lwup   ","Faxa_lwdn   ", &
        "Fioi_melth  ","Fioi_salt   ","Faxa_prec   ","Faxa_snow   ","Faxa_rain   ", &
        "Foxx_evap   ","Fioi_meltw  ","Forr_roff   ","Forr_ioff   ",                &
        "So_t        ","So_u        ","So_v        ","So_dhdx     ","So_dhdy     ", &
        "So_s        ","Fioo_q      ","strm_MLD    ","strm_Qflx_T ","strm_Qflx_S ", &
        "strm_T_clim ","strm_S_clim ","strm_IF_clim"  /)


  ! ===== XTT MODIFIED END =====


! ===== XTT MODIFIED BEGIN =====
  integer(IN)   :: ktaux, ktauy, kifrac, kprec, kevap, kt_clim, ks_clim, kifrac_clim  ! field indices
 
  character(1024)             :: x_msg, x_datetime_str, x_cwd, x_real_time
  type(ptm_ProgramTunnelInfo) :: x_PTI
  integer                     :: x_curr_ymd

  integer :: x_iostat, x_fds(2)

  real(R8), pointer     :: x_nswflx(:), x_swflx(:), x_taux(:), x_tauy(:),  &
                           x_ifrac(:), x_q(:), x_frwflx(:), x_vsflx(:),    &
                           x_qflx_t(:), x_qflx_s(:),                       &
                           x_t_clim(:),  x_s_clim(:), x_ifrac_clim(:),     &
                           x_mld(:), x_mask(:)

  real(R8), pointer     :: x_blob_send(:), x_blob_recv(:)
  real(R8)              :: x_nullbin(1) = (/ 0.0 /)
  real(R8) :: tmp 
  !--- formats   ---
  character(*), parameter :: x_F00 = "(a, '.ssm.', a, '.', a)" 

! ===== XTT MODIFIED END =====

  !-------------------------------------------------------------------------------




  save

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
CONTAINS
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: docn_comp_init
!
! !DESCRIPTION:
!     initialize data ocn model
!
! !REVISION HISTORY:
!
! !INTERFACE: ------------------------------------------------------------------

subroutine docn_comp_init( EClock, cdata, x2o, o2x, NLFilename )
    use shr_pio_mod, only : shr_pio_getiosys, shr_pio_getiotype
    implicit none

! !INPUT/OUTPUT PARAMETERS:

    type(ESMF_Clock)            , intent(in)    :: EClock
    type(seq_cdata)             , intent(inout) :: cdata
    type(mct_aVect)             , intent(inout) :: x2o, o2x
    character(len=*), optional  , intent(in)    :: NLFilename ! Namelist filename

!EOP

    !--- local variables ---
    integer(IN)   :: n,k         ! generic counters
    integer(IN)   :: ierr        ! error code
    integer(IN)   :: COMPID      ! comp id
    integer(IN)   :: gsize       ! global size
    integer(IN)   :: lsize     ! local size
    integer(IN)   :: shrlogunit, shrloglev ! original log unit and level
    integer(IN)   :: nunit       ! unit number
    integer(IN)   :: kmask       ! field reference
    logical       :: ocn_present    ! flag
    logical       :: ocn_prognostic ! flag
    logical       :: ocnrof_prognostic  ! flag
    character(CL) :: calendar    ! model calendar

    type(seq_infodata_type), pointer :: infodata
    type(mct_gsMap)        , pointer :: gsmap
    type(mct_gGrid)        , pointer :: ggrid

    character(CL) :: filePath    ! generic file path
    character(CL) :: fileName    ! generic file name
    character(CS) :: timeName    ! domain file: time variable name
    character(CS) ::  lonName    ! domain file: lon  variable name
    character(CS) ::  latName    ! domain file: lat  variable name
    character(CS) :: maskName    ! domain file: mask variable name
    character(CS) :: areaName    ! domain file: area variable name

    integer(IN)   :: yearFirst   ! first year to use in data stream
    integer(IN)   :: yearLast    ! last  year to use in data stream
    integer(IN)   :: yearAlign   ! data year that aligns with yearFirst

    character(CL) :: ocn_in      ! dshr ocn namelist
    character(CL) :: decomp      ! decomp strategy
    character(CL) :: rest_file   ! restart filename
    character(CL) :: rest_file_strm   ! restart filename for stream
    character(CL) :: restfilm    ! restart filename for namelist
    character(CL) :: restfils    ! restart filename for stream for namelist
    logical       :: exists      ! file existance
    integer(IN)   :: nu          ! unit number

    !----- define namelist -----
    namelist / docn_nml / &
        ocn_in, decomp, restfilm, restfils

    !--- formats ---
    character(*), parameter :: F00   = "('(docn_comp_init) ',8a)"
    character(*), parameter :: F01   = "('(docn_comp_init) ',a,5i8)"
    character(*), parameter :: F02   = "('(docn_comp_init) ',a,4es13.6)"
    character(*), parameter :: F03   = "('(docn_comp_init) ',a,i8,a)"
    character(*), parameter :: F04   = "('(docn_comp_init) ',2a,2i8,'s')"
    character(*), parameter :: F05   = "('(docn_comp_init) ',a,2f10.4)"
    character(*), parameter :: F90   = "('(docn_comp_init) ',73('='))"
    character(*), parameter :: F91   = "('(docn_comp_init) ',73('-'))"
    character(*), parameter :: subName = "(docn_comp_init) "
!-------------------------------------------------------------------------------


    call t_startf('DOCN_INIT')

    firstcall = .true.

    ! Set cdata pointers

    call seq_cdata_setptrs(cdata, ID=COMPID, mpicom=mpicom, &
         gsMap=gsmap, dom=ggrid, infodata=infodata)

    ! Determine communicator groups and sizes

    call mpi_comm_rank(mpicom, my_task, ierr)
    call mpi_comm_size(mpicom, npes, ierr)

    inst_name   = seq_comm_name(COMPID)
    inst_index  = seq_comm_inst(COMPID)
    inst_suffix = seq_comm_suffix(COMPID)

    !--- open log file ---
    if (my_task == master_task) then
       logUnit = shr_file_getUnit()
       call shr_file_setIO('ocn_modelio.nml'//trim(inst_suffix),logUnit)
    else
       logUnit = 6
    endif

    !----------------------------------------------------------------------------
    ! Reset shr logging to my log file
    !----------------------------------------------------------------------------
    call shr_file_getLogUnit (shrlogunit)
    call shr_file_getLogLevel(shrloglev)
    call shr_file_setLogUnit (logUnit)

    !----------------------------------------------------------------------------
    ! Set a Few Defaults
    !----------------------------------------------------------------------------

    call seq_infodata_getData(infodata,single_column=scmMode, &
   &                          scmlat=scmlat, scmlon=scmLon)

    ocn_present = .false.
    ocn_prognostic = .false.
    ocnrof_prognostic = .false.
    call seq_infodata_GetData(infodata,read_restart=read_restart)

    !----------------------------------------------------------------------------
    ! Read docn_in
    !----------------------------------------------------------------------------

    call t_startf('docn_readnml')

    filename = "docn_in"//trim(inst_suffix)
    ocn_in = "unset"
    decomp = "1d"
    restfilm = trim(nullstr)
    restfils = trim(nullstr)
    if (my_task == master_task) then
       nunit = shr_file_getUnit() ! get unused unit number
       open (nunit,file=trim(filename),status="old",action="read")
       read (nunit,nml=docn_nml,iostat=ierr)
       close(nunit)
       call shr_file_freeUnit(nunit)
       if (ierr > 0) then
          write(logunit,F01) 'ERROR: reading input namelist, '//trim(filename)//' iostat=',ierr
          call shr_sys_abort(subName//': namelist read error '//trim(filename))
       end if
       write(logunit,F00)' ocn_in = ',trim(ocn_in)
       write(logunit,F00)' decomp = ',trim(decomp)
       write(logunit,F00)' restfilm = ',trim(restfilm)
       write(logunit,F00)' restfils = ',trim(restfils)
    endif
    call shr_mpi_bcast(ocn_in,mpicom,'ocn_in')
    call shr_mpi_bcast(decomp,mpicom,'decomp')
    call shr_mpi_bcast(restfilm,mpicom,'restfilm')
    call shr_mpi_bcast(restfils,mpicom,'restfils')
 
    rest_file = trim(restfilm)
    rest_file_strm = trim(restfils)

    !----------------------------------------------------------------------------
    ! Read dshr namelist
    !----------------------------------------------------------------------------

    call shr_strdata_readnml(SDOCN,trim(ocn_in),mpicom=mpicom)

    !----------------------------------------------------------------------------
    ! Validate mode
    !----------------------------------------------------------------------------

    ocn_mode = trim(SDOCN%dataMode)

    ! check that we know how to handle the mode

    if (trim(ocn_mode) == 'NULL' .or. &
        trim(ocn_mode) == 'SSTDATA' .or. &
        trim(ocn_mode) == 'COPYALL' .or. &
        trim(ocn_mode) == 'SOM') then
      if (my_task == master_task) &
         write(logunit,F00) ' ocn mode = ',trim(ocn_mode)
    else
      write(logunit,F00) ' ERROR illegal ocn mode = ',trim(ocn_mode)
      call shr_sys_abort()
    endif

    call t_stopf('docn_readnml')

    !----------------------------------------------------------------------------
    ! Initialize datasets
    !----------------------------------------------------------------------------

    call t_startf('docn_strdata_init')

    if (trim(ocn_mode) /= 'NULL') then
       ocn_present = .true.
       call seq_timemgr_EClockGetData( EClock, calendar=calendar )
       iosystem => shr_pio_getiosys(trim(inst_name))
       
       call shr_strdata_pioinit(SDOCN, iosystem, shr_pio_getiotype(trim(inst_name)))

       if (scmmode) then
          if (my_task == master_task) &
             write(logunit,F05) ' scm lon lat = ',scmlon,scmlat
          call shr_strdata_init(SDOCN,mpicom,compid,name='ocn', &
                      scmmode=scmmode,scmlon=scmlon,scmlat=scmlat, &
                      calendar=calendar)
       else
          call shr_strdata_init(SDOCN,mpicom,compid,name='ocn', &
                      calendar=calendar)
       endif
    endif

    if (trim(ocn_mode) == 'SOM') then
       ocn_prognostic = .true.
    endif

    if (my_task == master_task) then
       call shr_strdata_print(SDOCN,'SDOCN data')
    endif

    call t_stopf('docn_strdata_init')

    !----------------------------------------------------------------------------
    ! Set flag to specify data components
    !----------------------------------------------------------------------------

    call seq_infodata_PutData(infodata, ocnrof_prognostic=ocnrof_prognostic, &
      ocn_present=ocn_present, ocn_prognostic=ocn_prognostic, &
      ocn_nx=SDOCN%nxg, ocn_ny=SDOCN%nyg )

    !----------------------------------------------------------------------------
    ! Initialize MCT global seg map, 1d decomp
    !----------------------------------------------------------------------------

    call t_startf('docn_initgsmaps')
    if (my_task == master_task) write(logunit,F00) ' initialize gsmaps'
    call shr_sys_flush(logunit)

    call shr_dmodel_gsmapcreate(gsmap,SDOCN%nxg*SDOCN%nyg,compid,mpicom,decomp)
    lsize = mct_gsmap_lsize(gsmap,mpicom)

    if (ocn_present) then
       call mct_rearr_init(SDOCN%gsmap,gsmap,mpicom,rearr)
    endif

    call t_stopf('docn_initgsmaps')

    !----------------------------------------------------------------------------
    ! Initialize MCT domain
    !----------------------------------------------------------------------------

    call t_startf('docn_initmctdom')
    if (my_task == master_task) write(logunit,F00) 'copy domains'
    call shr_sys_flush(logunit)

    if (ocn_present) call shr_dmodel_rearrGGrid(SDOCN%grid, ggrid, gsmap, rearr, mpicom)

    call t_stopf('docn_initmctdom')

    !----------------------------------------------------------------------------
    ! Initialize MCT attribute vectors
    !----------------------------------------------------------------------------

    call t_startf('docn_initmctavs')
    if (my_task == master_task) write(logunit,F00) 'allocate AVs'
    call shr_sys_flush(logunit)

    call mct_aVect_init(o2x, rList=seq_flds_o2x_fields, lsize=lsize)
    call mct_aVect_zero(o2x)

    kt    = mct_aVect_indexRA(o2x,'So_t')
    ks    = mct_aVect_indexRA(o2x,'So_s')
    ku    = mct_aVect_indexRA(o2x,'So_u')
    kv    = mct_aVect_indexRA(o2x,'So_v')
    kdhdx = mct_aVect_indexRA(o2x,'So_dhdx')
    kdhdy = mct_aVect_indexRA(o2x,'So_dhdy')
    kq    = mct_aVect_indexRA(o2x,'Fioo_q')

    call mct_aVect_init(x2o, rList=seq_flds_x2o_fields, lsize=lsize)
    call mct_aVect_zero(x2o)

    kswnet = mct_aVect_indexRA(x2o,'Foxx_swnet')
    klwup  = mct_aVect_indexRA(x2o,'Foxx_lwup')
    klwdn  = mct_aVect_indexRA(x2o,'Faxa_lwdn')
    ksen   = mct_aVect_indexRA(x2o,'Foxx_sen')
    klat   = mct_aVect_indexRA(x2o,'Foxx_lat')
    kmelth = mct_aVect_indexRA(x2o,'Fioi_melth')
    kmeltw = mct_aVect_indexRA(x2o,'Fioi_meltw')
    ksnow  = mct_aVect_indexRA(x2o,'Faxa_snow')
    kioff  = mct_aVect_indexRA(x2o,'Forr_ioff')
    kroff  = mct_aVect_indexRA(x2o,'Forr_roff')

    call mct_aVect_init(avstrm, rList=flds_strm, lsize=lsize)
    call mct_aVect_zero(avstrm)


    ! ===== XTT MODIFIED BEGIN =====
    

    ! Virtual Salt Flux in kg/s/m^2 (varname in CESM SFWF)
    kvsflx = mct_aVect_indexRA(x2o,'Fioi_salt')
    
    kmld         = mct_aVect_indexRA(avstrm,'strm_MLD')
    kqflx_t      = mct_aVect_indexRA(avstrm,'strm_Qflx_T')
    kqflx_s      = mct_aVect_indexRA(avstrm,'strm_Qflx_S')
    kt_clim      = mct_aVect_indexRA(avstrm,'strm_T_clim')
    ks_clim      = mct_aVect_indexRA(avstrm,'strm_S_clim')
    kifrac_clim  = mct_aVect_indexRA(avstrm,'strm_IF_clim')
    
    ! ===== XTT MODIFIED END =====


    allocate(somtp(lsize))
    allocate(imask(lsize))

    kmask = mct_aVect_indexRA(ggrid%data,'mask')
    imask(:) = nint(ggrid%data%rAttr(kmask,:))

    call t_stopf('docn_initmctavs')

    !----------------------------------------------------------------------------
    ! Read restart
    !----------------------------------------------------------------------------

    if (read_restart) then
       if (trim(rest_file) == trim(nullstr) .and. &
           trim(rest_file_strm) == trim(nullstr)) then
          if (my_task == master_task) then
             write(logunit,F00) ' restart filenames from rpointer'
             call shr_sys_flush(logunit)
             inquire(file=trim(rpfile)//trim(inst_suffix),exist=exists)
             if (.not.exists) then
                write(logunit,F00) ' ERROR: rpointer file does not exist'
                call shr_sys_abort(trim(subname)//' ERROR: rpointer file missing')
             endif
             nu = shr_file_getUnit()
             open(nu,file=trim(rpfile)//trim(inst_suffix),form='formatted')
             read(nu,'(a)') rest_file
             read(nu,'(a)') rest_file_strm
             close(nu)
             call shr_file_freeUnit(nu)
             inquire(file=trim(rest_file_strm),exist=exists)
          endif
          call shr_mpi_bcast(rest_file,mpicom,'rest_file')
          call shr_mpi_bcast(rest_file_strm,mpicom,'rest_file_strm')
       else
          ! use namelist already read
          if (my_task == master_task) then
             write(logunit,F00) ' restart filenames from namelist '
             call shr_sys_flush(logunit)
             inquire(file=trim(rest_file_strm),exist=exists)
          endif
       endif
       call shr_mpi_bcast(exists,mpicom,'exists')
       if (trim(ocn_mode) == 'SOM') then
          if (my_task == master_task) write(logunit,F00) ' reading ',trim(rest_file)
          call shr_pcdf_readwrite('read',iosystem,SDOCN%io_type,trim(rest_file),mpicom,gsmap,rf1=somtp,rf1n='somtp')
       endif
       if (exists) then
          if (my_task == master_task) write(logunit,F00) ' reading ',trim(rest_file_strm)
          call shr_strdata_restRead(trim(rest_file_strm),SDOCN,mpicom)
       else
          if (my_task == master_task) write(logunit,F00) ' file not found, skipping ',trim(rest_file_strm)
       endif
       call shr_sys_flush(logunit)
    endif

    !----------------------------------------------------------------------------
    ! Set initial ocn state, needed for CCSM atm initialization
    !----------------------------------------------------------------------------

    call t_adj_detailf(+2)
    call docn_comp_run( EClock, cdata,  x2o, o2x)
    call t_adj_detailf(-2)

    !----------------------------------------------------------------------------
    ! Reset shr logging to original values
    !----------------------------------------------------------------------------

    if (my_task == master_task) write(logunit,F00) 'docn_comp_init done'
    call shr_sys_flush(logunit)

    call shr_file_setLogUnit (shrlogunit)
    call shr_file_setLogLevel(shrloglev)
    call shr_sys_flush(logunit)

    call t_stopf('DOCN_INIT')

end subroutine docn_comp_init

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: docn_comp_run
!
! !DESCRIPTION:
!     run method for dead ocn model
!
! !REVISION HISTORY:
!
! !INTERFACE: ------------------------------------------------------------------

subroutine docn_comp_run( EClock, cdata,  x2o, o2x)

   implicit none

! !INPUT/OUTPUT PARAMETERS:

   type(ESMF_Clock)            ,intent(in)    :: EClock
   type(seq_cdata)             ,intent(inout) :: cdata
   type(mct_aVect)             ,intent(inout) :: x2o        ! driver -> dead
   type(mct_aVect)             ,intent(inout) :: o2x        ! dead   -> driver

!EOP

   !--- local ---
   type(mct_gsMap)        , pointer :: gsmap
   type(mct_gGrid)        , pointer :: ggrid

   integer(IN)   :: CurrentYMD        ! model date
   integer(IN)   :: CurrentTOD        ! model sec into model date
   integer(IN)   :: yy,mm,dd          ! year month day
   integer(IN)   :: n                 ! indices
   integer(IN)   :: nf                ! fields loop index
   integer(IN)   :: nl                ! ocn frac index
   integer(IN)   :: lsize           ! size of attr vect
   integer(IN)   :: shrlogunit, shrloglev ! original log unit and level
   logical       :: glcrun_alarm      ! is glc going to run now
   logical       :: newdata           ! has newdata been read
   logical       :: mssrmlf           ! remove old data
   integer(IN)   :: idt               ! integer timestep
   real(R8)      :: dt                ! timestep
   real(R8)      :: hn                ! h field
   logical       :: write_restart     ! restart now
   character(CL) :: case_name         ! case name
   character(CL) :: rest_file         ! restart_file
   character(CL) :: rest_file_strm    ! restart_file for stream
   integer(IN)   :: nu                ! unit number
   integer(IN)   :: nflds_x2o
   type(seq_infodata_type), pointer :: infodata

   character(*), parameter :: F00   = "('(docn_comp_run) ',8a)"
   character(*), parameter :: F04   = "('(docn_comp_run) ',2a,2i8,'s')"
   character(*), parameter :: subName = "(docn_comp_run) "
!-------------------------------------------------------------------------------

   call t_startf('DOCN_RUN')

   call t_startf('docn_run1')

  !----------------------------------------------------------------------------
  ! Reset shr logging to my log file
  !----------------------------------------------------------------------------
   call shr_file_getLogUnit (shrlogunit)
   call shr_file_getLogLevel(shrloglev)
   call shr_file_setLogUnit (logUnit)

   call seq_cdata_setptrs(cdata, gsMap=gsmap, dom=ggrid)

   call seq_cdata_setptrs(cdata, infodata=infodata)

   call seq_timemgr_EClockGetData( EClock, curr_ymd=CurrentYMD, curr_tod=CurrentTOD)
   call seq_timemgr_EClockGetData( EClock, curr_yr=yy, curr_mon=mm, curr_day=dd)
   call seq_timemgr_EClockGetData( EClock, dtime=idt)
   dt = idt * 1.0_r8
   write_restart = seq_timemgr_RestartAlarmIsOn(EClock)

   call t_stopf('docn_run1')

   !--------------------
   ! UNPACK
   !--------------------

   call t_startf('docn_unpack')

!  lsize = mct_avect_lsize(x2o)
!  nflds_x2o = mct_avect_nRattr(x2o)

!   do nf=1,nflds_x2o
!   do n=1,lsize
!     ?? = x2o%rAttr(nf,n)
!   enddo
!   enddo

   call t_stopf('docn_unpack')

   !--------------------
   ! ADVANCE OCN
   !--------------------

   call t_barrierf('docn_BARRIER',mpicom)
   call t_startf('docn')

   !--- copy all fields from streams to o2x as default ---

   if (trim(ocn_mode) /= 'NULL') then
      call t_startf('docn_strdata_advance')
      call shr_strdata_advance(SDOCN,currentYMD,currentTOD,mpicom,'docn')
      call t_stopf('docn_strdata_advance')
      call t_barrierf('docn_scatter_BARRIER',mpicom)
      call t_startf('docn_scatter')
      do n = 1,SDOCN%nstreams
         call shr_dmodel_translateAV(SDOCN%avs(n),o2x,avifld,avofld,rearr)
      enddo
      call t_stopf('docn_scatter')
   else
      call mct_aVect_zero(o2x)
   endif

   call t_startf('docn_mode')

   select case (trim(ocn_mode))

   case('COPYALL') 
      ! do nothing extra

   case('SSTDATA')
      lsize = mct_avect_lsize(o2x)
      do n = 1,lsize
         o2x%rAttr(kt   ,n) = o2x%rAttr(kt,n) + TkFrz
         o2x%rAttr(ks   ,n) = ocnsalt
         o2x%rAttr(ku   ,n) = 0.0_r8
         o2x%rAttr(kv   ,n) = 0.0_r8
         o2x%rAttr(kdhdx,n) = 0.0_r8
         o2x%rAttr(kdhdy,n) = 0.0_r8
         o2x%rAttr(kq   ,n) = 0.0_r8
      enddo


! ===== XTT MODIFIED BEGIN =====

    case('SOM_AQUAP', 'SOM')
 
      !call GETCWD(x_cwd) 
      !print *, "Current working directory: ", trim(x_cwd)
      ! CESM 1 does not provide shr_cal_ymdtod2string

    
      ! The following line is CESM 2 only 
      !call shr_cal_ymdtod2string(x_datetime_str, yy, mm, dd, currentTOD)


      call current_time(x_real_time) 
      write(x_datetime_str, '(i0.8, A, i0.8)') currentYMD, "-", currentTOD
      print *, "############################" 
      print *, "# Real  time: ", trim(x_datetime_str)
      print *, "# Model time: ", trim(x_real_time)
      print *, "############################" 

      
      lsize = mct_avect_lsize(o2x)
      ! XTT: This line dumps every stream data from `SDOCN%avs(n)` into `avstrm`
      ! where dumped variables are specified by `avifld` and its mapping `avofld`.
      do n = 1,SDOCN%nstreams
        call shr_dmodel_translateAV(SDOCN%avs(n),avstrm,avifld,avofld,rearr)
      enddo


      if (firstcall) then

        ! I put all extra initialization here to avoid complication


        ! variable name are refereced from
        ! $CESM1_root/models/drv/shr/seq_flds_mod.F90 (line 1101)
        ktaux  = mct_aVect_indexRA(x2o,'Foxx_taux')
        ktauy  = mct_aVect_indexRA(x2o,'Foxx_tauy')
        kifrac = mct_aVect_indexRA(x2o,'Si_ifrac')
        kprec  = mct_aVect_indexRA(x2o,'Faxa_prec')
        kevap  = mct_aVect_indexRA(x2o,'Foxx_evap')


        allocate(x_qflx_t(lsize))
        allocate(x_qflx_s(lsize))
        allocate(x_t_clim(lsize))
        allocate(x_s_clim(lsize))
        allocate(x_ifrac_clim(lsize))
        allocate(x_mld(lsize))
        allocate(x_nswflx(lsize))
        allocate(x_swflx(lsize))
        allocate(x_taux(lsize))
        allocate(x_tauy(lsize))
        allocate(x_ifrac(lsize))
        allocate(x_q(lsize))
        allocate(x_mask(lsize))
        allocate(x_frwflx(lsize))
        allocate(x_vsflx(lsize))

        allocate(x_blob_send(lsize*13))
        allocate(x_blob_recv(lsize*2))

        do n = 1,lsize
            if (.not. read_restart) then
                somtp(n) = o2x%rAttr(kt,n) + TkFrz
            end if

            x_qflx_t(n)    = 0.0_R8
            x_qflx_s(n)    = 0.0_R8
            x_t_clim(n)   = 0.0_R8
            x_s_clim(n)   = 0.0_R8
            x_ifrac_clim(n)   = 0.0_R8
            x_mld(n)     = 0.0_R8
            x_q(n)       = 0.0_R8 
            x_nswflx(n)  = 0.0_R8
            x_swflx(n)   = 0.0_R8
            x_taux(n)    = 0.0_R8
            x_tauy(n)    = 0.0_R8
            x_ifrac(n)   = 0.0_R8
            x_frwflx(n)  = 0.0_R8
            x_vsflx(n)  = 0.0_R8
            x_mask(n)    = 0.0_R8

            o2x%rAttr(kt,n) = somtp(n)
            o2x%rAttr(kq,n) = x_q(n)

        end do
        
        ! CESM has a speicial function to manage
        ! Input/output file units 
        do n = 1, 2
            x_fds(n) = shr_file_getUnit()
        enddo

        call ptm_setDefault(x_PTI, x_fds)

        write(x_msg, '(A, i8, A)') "LSIZE:", lsize, ";"
        x_msg = "MSG:INIT;CESMTIME:"//trim(x_datetime_str)//";"//trim(x_msg)
   
        ! Variable order matters
        x_msg = trim(x_msg)//"VAR2D:QFLX_T,QFLX_S,T_CLIM,S_CLIM,IFRAC_CLIM,MLD,NSWFLX,SWFLX,TAUX,TAUY,IFRAC,FRWFLX,VSFLX;"
        if (read_restart) then
            x_msg = trim(x_msg)//"READ_RESTART:TRUE;"
        else
            x_msg = trim(x_msg)//"READ_RESTART:FALSE;"
        endif
        print *, "Going to send: " // trim(x_msg)
        call stop_if_bad(ptm_sendData(x_PTI, x_msg, x_nullbin), "INIT_SEND")
        
        print *, "Init msg sent: ", trim(x_msg), "."
        print *, "Now receiving..."
        call stop_if_bad(ptm_recvData(x_PTI, x_msg, x_blob_recv), "INIT_RECV")

        if (ptm_messageCompare(x_msg, "OK") .neqv. .true.) then
            print *, "SSM init failed. Recive message: ", x_msg
            call shr_sys_abort ('SSM init failed.')
        end if
        
        call copy_from_blob(x_blob_recv, lsize, 1, somtp) 
        call copy_from_blob(x_blob_recv, lsize, 2, x_q)
        
        call stop_if_bad(ptm_recvData(x_PTI, x_msg, x_blob_recv(1:lsize)), "INIT_RECV_MASK")
        call copy_from_blob(x_blob_recv, lsize, 1, x_mask)

        do n = 1, lsize
            if (imask(n) /= x_mask(n)) then
                call shr_sys_abort ('SSM init failed: mask does not match')
            end if
        end do

        do n = 1, lsize
          if (imask(n) /= 0) then
            somtp(n) = somtp(n) + TkFrz
            o2x%rAttr(kt,n) = somtp(n)
            o2x%rAttr(kq,n) = x_q(n)
          end if
        end do

      else  ! if NOT first call

        x_msg = "MSG:RUN;CESMTIME:"//trim(x_datetime_str)//";"
        if (write_restart) then
            x_msg = trim(x_msg)//"WRITE_RESTART:TRUE;"
        else
            x_msg = trim(x_msg)//"WRITE_RESTART:FALSE;"
        endif
        
        write (x_msg, "(A, A, F10.2, A)") trim(x_msg), "DT:", dt, ";"

        tmp = 0.0
        do n = 1,lsize
          if (imask(n) /= 0) then

            !
            ! 2020/03/30
            ! Change swflx and nswflx to be positive if the ocean is
            ! losing energy, negative if the ocean is gaining energy.
            !

            x_swflx(n)  = - x2o%rAttr(kswnet, n) 

            x_nswflx(n) = - (                                   &
                              x2o%rAttr(klwup, n)               &    ! upward longwave
                            + x2o%rAttr(klwdn, n)               &    ! downward longwave
                            + x2o%rAttr(ksen, n)                &    ! sensible heat flux
                            + x2o%rAttr(klat, n)                &    ! latent heat flux
                            + x2o%rAttr(kmelth, n)              &    ! ice melt
                            - (   x2o%rAttr(ksnow,n)            & 
                                + x2o%rAttr(kioff,n) ) * latice & ! latent by snow and roff
            )
 
            ! ===================================================================
            ! The info is given from:
            !   (1) ocn/pop2/source/forcing_coupled.F90 [Line 800]
            !   (2) ocn/pop2/source/constants.F90
            !   (3) ocn/pop2/drivers/cpl_mct/ocn_comp_mct.F90
            !
            ! fresh water flux in unit of kg / m^2 / s.
            ! Positive means upward (loss), negative means downward (gain)
            x_frwflx(n) = - ( x2o%rAttr(kevap, n)  &
                            + x2o%rAttr(kprec, n)  &
                            + x2o%rAttr(kmeltw, n) &
                            + x2o%rAttr(kroff, n)  &
                            + x2o%rAttr(kioff, n) )
                         
            ! Virtual salt flux in unit of kg / m^2 / s.
            ! Positive means upward (loss), negative means downward (gain)
            x_vsflx(n) =  - ( x2o%rAttr(kvsflx, n) + x_frwflx(n) * ocnsalt / rhofw )
            
            ! ===================================================================
                       
            x_taux(n)  = x2o%rAttr(ktaux,n)
            x_tauy(n)  = x2o%rAttr(ktauy,n)
            x_ifrac(n) = x2o%rAttr(kifrac,n)

            x_qflx_t(n)     = avstrm%rAttr(kqflx_t,n)
            x_qflx_s(n)     = avstrm%rAttr(kqflx_s,n)
            x_t_clim(n)     = avstrm%rAttr(kt_clim,n)
            x_s_clim(n)     = avstrm%rAttr(ks_clim,n)
            x_ifrac_clim(n) = avstrm%rAttr(kifrac_clim,n)
            x_mld(n)        = avstrm%rAttr(kmld,n)
           
            tmp = tmp + x_ifrac_clim(n) 
          end if
        end do
        
        print *, "sum of ifrac_clim: ", tmp
        call copy_into_blob(x_blob_send, lsize, 1, x_qflx_t) 
        call copy_into_blob(x_blob_send, lsize, 2, x_qflx_s) 
        call copy_into_blob(x_blob_send, lsize, 3, x_t_clim) 
        call copy_into_blob(x_blob_send, lsize, 4, x_s_clim) 
        call copy_into_blob(x_blob_send, lsize, 5, x_ifrac_clim) 
        call copy_into_blob(x_blob_send, lsize, 6, x_mld) 
        call copy_into_blob(x_blob_send, lsize, 7, x_nswflx) 
        call copy_into_blob(x_blob_send, lsize, 8, x_swflx) 
        call copy_into_blob(x_blob_send, lsize, 9, x_taux) 
        call copy_into_blob(x_blob_send, lsize, 10, x_tauy) 
        call copy_into_blob(x_blob_send, lsize, 11, x_ifrac) 
        call copy_into_blob(x_blob_send, lsize, 12, x_frwflx) 
        call copy_into_blob(x_blob_send, lsize, 13, x_vsflx) 
 
        call stop_if_bad(ptm_sendData(x_PTI, x_msg, x_nullbin),  "RUN_SEND")
        call stop_if_bad(ptm_sendData(x_PTI, "DATA", x_blob_send), "RUN_SEND_DATA")
                

        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        !! Ocean model is doing some MAGICAL calculation...!!
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        call stop_if_bad(ptm_recvData(x_PTI, x_msg, x_blob_recv), "RUN_RECV")
        if (ptm_messageCompare(x_msg, "OK") .neqv. .true.) then
            if (ptm_messageCompare(x_msg, "OK") .neqv. .true.) then
                print *, "Ocean model calculation failed. Recive message: [", trim(x_msg), "]"
                call shr_sys_abort ('Ocean model calculation failed.')
            end if
        end if
        
        call copy_from_blob(x_blob_recv, lsize, 1, somtp) 
        call copy_from_blob(x_blob_recv, lsize, 2, x_q)

        do n = 1, lsize
          if (imask(n) /= 0) then
            if (isnan(somtp(n))) then
                stop 'NAN found!'
            end if
            somtp(n) = somtp(n) + TkFrz
            o2x%rAttr(kt,n) = somtp(n)
            o2x%rAttr(kq,n) = x_q(n)
          end if
        end do
     
      endif

! ===== XTT MODIFIED END =====

   case('XSOM')
      lsize = mct_avect_lsize(o2x)
      do n = 1,SDOCN%nstreams
         call shr_dmodel_translateAV(SDOCN%avs(n),avstrm,avifld,avofld,rearr)
      enddo
      if (firstcall) then
         do n = 1,lsize
            if (.not. read_restart) then
               somtp(n) = o2x%rAttr(kt,n) + TkFrz
            endif
            o2x%rAttr(kt,n) = somtp(n)
            o2x%rAttr(kq,n) = 0.0_r8
         enddo
      else   ! firstcall
         do n = 1,lsize
         if (imask(n) /= 0) then
            !--- pull out h from av for resuse below ---
            hn = avstrm%rAttr(kmld,n)
            !--- compute new temp ---
            o2x%rAttr(kt,n) = somtp(n) + &
               (x2o%rAttr(kswnet,n) + &  ! shortwave 
                x2o%rAttr(klwup ,n) + &  ! longwave
                x2o%rAttr(klwdn ,n) + &  ! longwave
                x2o%rAttr(ksen  ,n) + &  ! sensible
                x2o%rAttr(klat  ,n) + &  ! latent
                x2o%rAttr(kmelth,n) - &  ! ice melt
                avstrm%rAttr(kqflx_t ,n) - &  ! flux at bottom
                (x2o%rAttr(ksnow,n)+x2o%rAttr(kioff,n))*latice) * &  ! latent by prec and roff
                dt/(cpsw*rhosw*hn)
             !--- compute ice formed or melt potential ---
            o2x%rAttr(kq,n) = (TkFrzSw - o2x%rAttr(kt,n))*(cpsw*rhosw*hn)/dt  ! ice formed q>0
            o2x%rAttr(kt,n) = max(TkFrzSw,o2x%rAttr(kt,n))                    ! reset temp
            somtp(n) = o2x%rAttr(kt,n)                                        ! save temp
         endif
         enddo
      endif   ! firstcall

   end select

   call t_stopf('docn_mode')

   if (write_restart) then
      call t_startf('docn_restart')
      call seq_infodata_GetData( infodata, case_name=case_name)
      write(rest_file,"(2a,i4.4,a,i2.2,a,i2.2,a,i5.5,a)") &
        trim(case_name), '.docn'//trim(inst_suffix)//'.r.', &
        yy,'-',mm,'-',dd,'-',currentTOD,'.nc'
      write(rest_file_strm,"(2a,i4.4,a,i2.2,a,i2.2,a,i5.5,a)") &
        trim(case_name), '.docn'//trim(inst_suffix)//'.rs1.', &
        yy,'-',mm,'-',dd,'-',currentTOD,'.bin'
      if (my_task == master_task) then
         nu = shr_file_getUnit()
         open(nu,file=trim(rpfile)//trim(inst_suffix),form='formatted')
         write(nu,'(a)') rest_file
         write(nu,'(a)') rest_file_strm
         close(nu)
         call shr_file_freeUnit(nu)
      endif
      if (trim(ocn_mode) == 'SOM') then
         if (my_task == master_task) write(logunit,F04) ' writing ',trim(rest_file),currentYMD,currentTOD
         call shr_pcdf_readwrite('write',iosystem,SDOCN%io_type,trim(rest_file),mpicom,gsmap,clobber=.true., &
            rf1=somtp,rf1n='somtp')
      endif
      if (my_task == master_task) write(logunit,F04) ' writing ',trim(rest_file_strm),currentYMD,currentTOD
      call shr_strdata_restWrite(trim(rest_file_strm),SDOCN,mpicom,trim(case_name),'SDOCN strdata')
      call shr_sys_flush(logunit)
      call t_stopf('docn_restart')
   endif

   call t_stopf('docn')

   !----------------------------------------------------------------------------
   ! Log output for model date
   ! Reset shr logging to original values
   !----------------------------------------------------------------------------

   call t_startf('docn_run2')
   if (my_task == master_task) then
      write(logunit,F04) trim(myModelName),': model date ', CurrentYMD,CurrentTOD
      call shr_sys_flush(logunit)
   end if
   firstcall = .false.
      
   call shr_file_setLogUnit (shrlogunit)
   call shr_file_setLogLevel(shrloglev)
   call shr_sys_flush(logunit)
   call t_stopf('docn_run2')

   call t_stopf('DOCN_RUN')

end subroutine docn_comp_run

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: docn_comp_final
!
! !DESCRIPTION:
!     finalize method for dead ocn model
!
! !REVISION HISTORY:
!
! !INTERFACE: ------------------------------------------------------------------
!
subroutine docn_comp_final()

   implicit none

!EOP

   !--- formats ---
   character(*), parameter :: F00   = "('(docn_comp_final) ',8a)"
   character(*), parameter :: F91   = "('(docn_comp_final) ',73('-'))"
   character(*), parameter :: subName = "(docn_comp_final) "
   integer :: rcode

! ===== XTT MODIFIED BEGIN =====
   integer :: n
! ===== XTT MODIFIED END =====



!-------------------------------------------------------------------------------
!
!-------------------------------------------------------------------------------

   call t_startf('DOCN_FINAL')
   if (my_task == master_task) then
      write(logunit,F91) 
      write(logunit,F00) trim(myModelName),': end of main integration loop'
      write(logunit,F91)

! ===== XTT MODIFIED BEGIN =====

      x_msg = "MSG:END"
      call stop_if_bad(ptm_sendData(x_PTI, x_msg, x_nullbin), "FINAL")

      do n = 1, 2
          call shr_file_freeUnit(x_fds(n))
      enddo

! ===== XTT MODIFIED END =====
 
   end if
      
   call t_stopf('DOCN_FINAL')

end subroutine docn_comp_final
!===============================================================================
!===============================================================================

! ===== XTT MODIFIED BEGIN =====
subroutine test_weird_number(num, stage)
    real(8)      :: num
    character(*) :: stage

    if ((isnan(num) .eqv. .true.) .or. &
         (num .gt. huge(num))) then
                print *, stage, " got werid number: ", num
        call shr_sys_abort ('Got non-real number')
    end if
end subroutine test_weird_number

subroutine stop_if_bad(stat, stage)
    integer      :: stat
    character(*) :: stage

    if (stat .lt. 0) then
          print *, 'MailBox got negative io state during stage ['//trim(stage)//']. Error state: ', stat
          print *, 'This error does not cause shutdown'
    else if (stat .gt. 0) then
          print *, 'MailBox error during stage ['//trim(stage)//']. Error state: ', stat
          call shr_sys_abort('MailBox error during stage ['//trim(stage)//']')
    end if
end subroutine stop_if_bad

subroutine write_1Dfield(fd, filename, f, nx) 
    character(len=*) :: filename
    real(8), intent(in) :: f(nx)
    integer, intent(in):: fd, nx
    integer :: i,eflag


    open (fd, file=filename, access="DIRECT", status='REPLACE', &
    &       form='UNFORMATTED', recl=8*nx, iostat=eflag, convert='LITTLE_ENDIAN')

    if(eflag .ne. 0) then
        print *, "Writing field error. File name: ", trim(filename)
    end if


    write(fd,rec=1) (f(i),i=1,nx,1)
    close(fd)

    if(eflag .ne. 0) then
        print *, "Writing field error. File name: ", trim(filename)
    end if

end subroutine

subroutine read_1Dfield(fd, filename, f, nx) 
    implicit none
    character(len=*) :: filename
    real(8), intent(inout) :: f(nx)
    integer, intent(in)    :: fd, nx
    integer :: i, eflag


    open (fd, file=filename, access="DIRECT", status='OLD', &
    &       form='UNFORMATTED', recl=8*nx, iostat=eflag, convert='LITTLE_ENDIAN')

    if(eflag .ne. 0) then
        print *, "Reading field error. File name: ", trim(filename)
        print *, "Error number: ", eflag
    end if

    read(fd, rec=1) (f(i),i=1,nx,1)
    close(fd)

    if(eflag .ne. 0) then
        print *, "Reading field error. File name: ", trim(filename)
    end if

end subroutine

subroutine copy_into_blob(blob, blksize, blkid, dat)
    implicit none
    real(8) :: blob(:), dat(:)
    integer :: blksize, blkid
    
    blob((blkid-1) * blksize + 1: blkid * blksize) = dat(1:blksize) 
end subroutine

subroutine copy_from_blob(blob, blksize, blkid, dat)
    implicit none
    real(8) :: blob(:), dat(:)
    integer :: blksize, blkid
    
    dat(1:blksize) = blob((blkid-1) * blksize + 1: blkid * blksize)

end subroutine

subroutine current_time(str)
    implicit none
    character(len=*)      :: str
    integer, dimension(8) :: t             ! arguments for date_and_time
   
    call date_and_time(values=t)

    write (str, '(i0.4, "/", i0.2, "/", i0.2, " ", i0.2, ":", i0.2, ":", i0.2, " ", i0.3)') &
        t(1), t(2), t(3), t(5), t(6), t(7), t(8)

end subroutine

! ===== XTT MODIFIED END   =====

end module docn_comp_mod
