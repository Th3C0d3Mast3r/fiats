! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt
submodule(inputs_m) inputs_s
  implicit none

contains

    module procedure construct_from_components
      inputs_object%inputs_ = inputs
    end procedure

    module procedure inputs 
      my_inputs = self%inputs_
    end procedure

end submodule inputs_s
