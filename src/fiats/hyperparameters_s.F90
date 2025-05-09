! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt

#include "assert_macros.h"

submodule(hyperparameters_m) hyperparameters_s
  use assert_m
  implicit none

  character(len=*), parameter :: mini_batches_key  = "mini-batches"
  character(len=*), parameter :: learning_rate_key = "learning rate"
  character(len=*), parameter :: optimizer_key     = "optimizer"

contains

  module procedure default_real_from_components
    hyperparameters%mini_batches_ = mini_batches
    hyperparameters%learning_rate_ = learning_rate
    hyperparameters%optimizer_ = optimizer
  end procedure 

  module procedure double_precision_from_components
    hyperparameters%mini_batches_ = mini_batches
    hyperparameters%learning_rate_ = learning_rate
    hyperparameters%optimizer_ = optimizer
  end procedure

  module procedure default_real_equals

    real, parameter :: tolerance = 1.E-08

    call_assert(allocated(lhs%optimizer_) .and. allocated(rhs%optimizer_))

    lhs_equals_rhs = &
      lhs%mini_batches_ == rhs%mini_batches_ .and. &
      lhs%optimizer_ == rhs%optimizer_ .and. &
      abs(lhs%learning_rate_ - rhs%learning_rate_) <= tolerance

  end procedure

  module procedure double_precision_equals

    double precision, parameter :: tolerance = 1.D-15

    call_assert(allocated(lhs%optimizer_) .and. allocated(rhs%optimizer_))

    lhs_equals_rhs = &
      lhs%mini_batches_ == rhs%mini_batches_ .and. &
      lhs%optimizer_ == rhs%optimizer_ .and. &
      abs(lhs%learning_rate_ - rhs%learning_rate_) <= tolerance
     
  end procedure 

  module procedure default_real_from_json
    integer l
    logical hyperparameters_key_found 

    hyperparameters_key_found = .false.

    do l=1,size(lines)
      if (lines(l)%get_json_key() == "hyperparameters") then
        hyperparameters_key_found = .true.
        hyperparameters%mini_batches_  = lines(l+1)%get_json_value(string_t(mini_batches_key), mold=0)
        hyperparameters%learning_rate_ = lines(l+2)%get_json_value(string_t(learning_rate_key), mold=0.)
        hyperparameters%optimizer_ = lines(l+3)%get_json_value(string_t(optimizer_key), mold=string_t(""))
        return
      end if
    end do

    call_assert(hyperparameters_key_found)
  end procedure

  module procedure double_precision_from_json
    integer l
    logical hyperparameters_key_found 

    hyperparameters_key_found = .false.

    do l=1,size(lines)
      if (lines(l)%get_json_key() == "hyperparameters") then
        hyperparameters_key_found = .true.
        hyperparameters%mini_batches_  = lines(l+1)%get_json_value(string_t(mini_batches_key), mold=0)
        hyperparameters%learning_rate_ = lines(l+2)%get_json_value(string_t(learning_rate_key), mold=0.D0)
        hyperparameters%optimizer_ = lines(l+3)%get_json_value(string_t(optimizer_key), mold=string_t(""))
        return
      end if
    end do

    call_assert(hyperparameters_key_found)
  end procedure

  module procedure default_real_to_json
    character(len=*), parameter :: indent = repeat(" ",ncopies=4)
    integer, parameter :: max_width= 18
    character(len=max_width) mini_batches_string, learning_rate_string

    write(mini_batches_string,*) self%mini_batches_
    write(learning_rate_string,*) self%learning_rate_

    lines = [ &
      string_t(indent // '"hyperparameters": {'), &
      string_t(indent // indent // '"' // mini_batches_key  // '" : '  // trim(adjustl(mini_batches_string))  // "," ), &
      string_t(indent // indent // '"' // learning_rate_key // '" : '  // trim(adjustl(learning_rate_string)) // "," ), &
      string_t(indent // indent // '"' // optimizer_key     // '" : "' // trim(adjustl(self%optimizer_     )) // '"'), &
      string_t(indent // '}') &
    ]
  end procedure

  module procedure double_precision_to_json
    character(len=*), parameter :: indent = repeat(" ",ncopies=4)
    integer, parameter :: max_width= 36
    character(len=max_width) mini_batches_string, learning_rate_string

    write(mini_batches_string,*) self%mini_batches_
    write(learning_rate_string,*) self%learning_rate_

    lines = [ &
      string_t(indent // '"hyperparameters": {'), &
      string_t(indent // indent // '"' // mini_batches_key  // '" : '  // trim(adjustl(mini_batches_string))  // "," ), &
      string_t(indent // indent // '"' // learning_rate_key // '" : '  // trim(adjustl(learning_rate_string)) // "," ), &
      string_t(indent // indent // '"' // optimizer_key     // '" : "' // trim(adjustl(self%optimizer_     )) // '"'), &
      string_t(indent // '}') &
    ]
  end procedure

  module procedure default_real_mini_batches
    num_mini_batches = self%mini_batches_
  end procedure

  module procedure double_precision_mini_batches
    num_mini_batches = self%mini_batches_
  end procedure

  module procedure default_real_optimizer_name
    identifier = string_t(self%optimizer_)
  end procedure

  module procedure double_precision_optimizer_name
    identifier = string_t(self%optimizer_)
  end procedure

  module procedure default_real_learning_rate
    rate = self%learning_rate_
  end procedure

  module procedure double_precision_learning_rate
    rate = self%learning_rate_
  end procedure

end submodule hyperparameters_s
