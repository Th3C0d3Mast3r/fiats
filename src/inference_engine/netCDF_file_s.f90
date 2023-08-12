! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt
#ifndef __INTEL_FORTRAN
!! Due to a suspected bug in the Intel ifx compiler, the above C preprocessor macro
!! effectively eliminates this file's source code when building with an Intel compiler.
submodule(netCDF_file_m) netCDF_file_s
  use netcdf, only : &
     nf90_create, nf90_def_dim, nf90_def_var, nf90_enddef, nf90_put_var, nf90_inquire_dimension, & ! functions
     nf90_close, nf90_open, nf90_inq_varid, nf90_get_var, nf90_inquire_variable, &
     nf90_clobber, nf90_noerr, nf90_strerror, nf90_int, nf90_nowrite ! constants
  use assert_m, only : assert, intrinsic_array_t
  implicit none

contains

  module procedure construct
   netCDF_file%file_name_ = file_name
  end procedure

  function get_shape(ncid, varname) result(array_shape)
    implicit none
    character(len=*), intent(in) :: varname
    integer, intent(in) :: ncid
    integer, allocatable :: array_shape(:)
    character(len=32) varid_string
    integer varid, dimlen, i, var_rank
    integer, parameter :: max_rank=15
    integer,dimension(max_rank+1) :: dims, dimIds
    associate(nf_status => nf90_inq_varid(ncid, varname, varid))
      write(varid_string, *) varid
      call assert(nf_status == nf90_noerr, "nf90_noerr == nf90_inq_varid(ncid, varname, varid) (" // &
        trim(nf90_strerror(nf_status)) // "(" // trim(varid_string)// ")")
    end associate
    associate(nf_status => nf90_inquire_variable(ncid, varid, ndims = var_rank))
      call assert(nf_status == nf90_noerr, "nf90_noerr == nf90_inquire_variable(ncid, varid, ndims = var_rank) (" // &
        trim(nf90_strerror(nf_status)) // "(" // varname // ")")
    end associate
    associate(nf_status => nf90_inquire_variable(ncid, varid, dimids = dimIds(:var_rank)))
      call assert(nf_status == nf90_noerr, "nf90_noerr == nf90_inquire_variable(ncid, varid, dimids = dimIds(:var_rank))", &
        trim(nf90_strerror(nf_status)) // "(" // varname // ")")
    end associate
    do i=1,var_rank
      associate(nf_status => nf90_inquire_dimension(ncid, dimIds(i), len = dimlen))
        call assert(nf_status == nf90_noerr, "nf90_noerr == nf90_inquire_dimension(ncid, dimIds(i), len = dimlen)", &
          trim(nf90_strerror(nf_status)) // "(" // varname // ")")
      end associate
      dims(i+1)=dimlen
    end do
    array_shape = dims(2:var_rank+1)
  end function 

  module procedure input_2D_integer

    integer ncid, varid

    associate( nf_status => nf90_open(self%file_name_, nf90_nowrite, ncid) ) ! open file with read-only acces
      call assert(nf_status == nf90_noerr, "nf90_open(self%file_name_, NF90_NOWRITE, ncid) succeeds", trim(nf90_strerror(nf_status)))
    end associate

    associate( nf_status => nf90_inq_varid(ncid, varname, varid)) ! get variable's ID
      call assert(nf_status == nf90_noerr, 'nf90_inq_varid(ncid, varname, varid) succeeds', trim(nf90_strerror(nf_status)))
    end associate

    associate(array_shape => get_shape(ncid, varname))
      call assert(size(array_shape)==rank(values), "netCDF_file_s(input_2D_integer): size(array_shape)==rank(values)")
      allocate(values(array_shape(1), array_shape(2)))
      associate( nf_status => nf90_get_var(ncid, varid, values)) ! read data
        call assert(nf_status == nf90_noerr, "nf90_get_var(ncid, varid, array) succeeds", trim(nf90_strerror(nf_status)))
      end associate
    end associate

  end procedure 

end submodule netCDF_file_s
#endif // __INTEL_FORTRAN