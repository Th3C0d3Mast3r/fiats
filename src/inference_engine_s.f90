! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt
submodule(inference_engine_m) inference_engine_s
  use assert_m, only : assert
  use intrinsic_array_m, only : intrinsic_array_t
  use matmul_m, only : matmul_t
  use step_m, only : step_t
  use layer_m, only : layer_t
  use neuron_m, only : neuron_t
  use file_m, only : file_t
  use formats_m, only : separated_values
  use iso_fortran_env, only : iostat_end
  implicit none

contains

  module procedure construct_from_components

    real(rkind), allocatable :: transposed(:,:,:)
    integer layer

    allocate(transposed(size(hidden_weights,2), size(hidden_weights,1), size(hidden_weights,3)))
    do concurrent(layer = 1:size(hidden_weights,3))
      transposed(:,:,layer) = transpose(hidden_weights(:,:,layer))
    end do

    inference_engine%input_weights_ = transpose(input_weights)
    inference_engine%hidden_weights_ = transposed
    inference_engine%output_weights_ = output_weights
    inference_engine%biases_ = biases
    inference_engine%output_biases_ = output_biases

    if (present(activation_strategy)) then
      inference_engine%activation_strategy_ = activation_strategy
    else
      inference_engine%activation_strategy_ = step_t()
    end if

    if (present(inference_strategy)) then
      inference_engine%inference_strategy_ = inference_strategy
    else
      inference_engine%inference_strategy_ = matmul_t()
    end if

    call assert_consistent(inference_engine)

  end procedure

  module procedure construct_from_json

    type(string_t), allocatable :: lines(:)
    type(layer_t) hidden_layers
    type(neuron_t) output_neuron
    real(rkind), allocatable :: hidden_weights(:,:,:)
    integer l
    character(len=:), allocatable :: quoted_value, line
    
    lines = file_%lines()

    l = 1
    call assert(adjustl(lines(l)%string())=="{", "construct_from_json: expecting '{' to start outermost object", lines(l)%string())
    l = 2
    if (adjustl(lines(l)%string()) /= '"metadata": {') then
      inference_engine%metadata_ = metadata_t(modelName="",modelAuthor="",compilationDate="", usingSkipConnections=.false.)
    else
      l = l + 1
      inference_engine%metadata_%modelName = get_string_value(adjustl(lines(l)%string()), key="modelName")

      l = l + 1
      inference_engine%metadata_%modelAuthor = get_string_value(adjustl(lines(l)%string()), key="modelAuthor")

      l = l + 1
      inference_engine%metadata_%compilationDate = get_string_value(adjustl(lines(l)%string()), key="compilationDate")

      l = l + 1
      inference_engine%metadata_%usingSkipConnections = get_logical_value(adjustl(lines(l)%string()), key="usingSkipConnections")

      l = l + 1
      call assert(adjustl(lines(l)%string())=="},", "construct_from_json: expecting '},' to end metadata object", lines(l)%string())

      l = l + 1
    end if

    call assert(adjustl(lines(l)%string())=='"hidden_layers": [', 'from_json: expecting "hidden_layers": [', lines(l)%string())
    l = l + 1

    block 
       integer, parameter :: lines_per_neuron=4, bracket_lines_per_layer=2
       character(len=:), allocatable :: output_layer_line
       
       hidden_layers = layer_t(lines, start=l)

       associate( output_layer_line_number => l + lines_per_neuron*sum(hidden_layers%count_neurons()) &
         + bracket_lines_per_layer*hidden_layers%count_layers() + 1)

         output_layer_line = lines(output_layer_line_number)%string()
         call assert(adjustl(output_layer_line)=='"output_layer": [', 'from_json: expecting "output_layer": [', &
           lines(output_layer_line_number)%string())

         output_neuron = neuron_t(lines, start=output_layer_line_number + 1)
       end associate
    end block

    inference_engine%input_weights_ = transpose(hidden_layers%input_weights())
    call assert(hidden_layers%next_allocated(), "inference_engine_t%from_json: next layer exists")

    block 
      type(layer_t), pointer :: next_layer
      real(rkind), allocatable :: transposed(:,:,:)
      integer layer

      next_layer => hidden_layers%next_pointer()
      hidden_weights = next_layer%hidden_weights()
      inference_engine%biases_ = hidden_layers%hidden_biases()

      allocate(transposed(size(hidden_weights,2), size(hidden_weights,1), size(hidden_weights,3)))
      do concurrent(layer = 1:size(hidden_weights,3)) 
        transposed(:,:,layer) = transpose(hidden_weights(:,:,layer))
      end do
      inference_engine%hidden_weights_ = transposed
    end block

    associate(output_weights => output_neuron%weights())
      inference_engine%output_weights_ = reshape(output_weights, [1, size(output_weights)])
      inference_engine%output_biases_ = [output_neuron%bias()]
    end associate

    if (present(activation_strategy)) then
      inference_engine%activation_strategy_  = activation_strategy
    else
      inference_engine%activation_strategy_  = step_t()
    end if
 
    if (present(inference_strategy)) then
      inference_engine%inference_strategy_  = inference_strategy
    else
      inference_engine%inference_strategy_  = matmul_t()
    end if

    call assert_consistent(inference_engine)

  contains

    pure function get_string_value(line, key) result(value_)
      character(len=*), intent(in) :: line, key
      character(len=:), allocatable :: value_

      associate(opening_key_quotes => index(line, '"'), separator => index(line, ':'))
        associate(closing_key_quotes => opening_key_quotes + index(line(opening_key_quotes+1:), '"'))
          associate(unquoted_key => line(opening_key_quotes+1:closing_key_quotes-1), remainder => line(separator+1:))
            call assert(unquoted_key == key,"construct_from_json(get_string_value): unquoted_key == key ", unquoted_key)
            associate(opening_value_quotes => index(remainder, '"'))
              associate(closing_value_quotes => opening_value_quotes + index(remainder(opening_value_quotes+1:), '"'))
                value_ = remainder(opening_value_quotes+1:closing_value_quotes-1)
              end associate
            end associate
          end associate
        end associate
      end associate
    end function

    pure function get_logical_value(line, key) result(value_)
      character(len=*), intent(in) :: line, key
      logical value_
      character(len=:), allocatable :: remainder ! a gfortran bug prevents making this an association

      associate(opening_key_quotes => index(line, '"'), separator => index(line, ':'))
        associate(closing_key_quotes => opening_key_quotes + index(line(opening_key_quotes+1:), '"'))
          associate(unquoted_key => line(opening_key_quotes+1:closing_key_quotes-1))
            call assert(unquoted_key == key,"construct_from_json(get_string_value): unquoted_key == key ", unquoted_key)
            remainder = adjustl(line(separator+1:))
            call assert(any(remainder == ["true ", "false"]), "construct_from_json(get_logical_value): valid value", remainder)
            value_ = remainder == "true"
          end associate
        end associate
      end associate
    end function

  end procedure construct_from_json


  module procedure conformable_with
    call assert_consistent(self)
    call assert_consistent(inference_engine)
    
    conformable = &
      same_type_as(self%activation_strategy_, inference_engine%activation_strategy_) .and. &
      same_type_as(self%inference_strategy_, inference_engine%inference_strategy_) .and. &
      all( &
        [ shape(self%input_weights_ ) == shape(inference_engine%input_weights_ ), &
          shape(self%hidden_weights_) == shape(inference_engine%hidden_weights_), &
          shape(self%output_weights_) == shape(inference_engine%output_weights_), &
          shape(self%biases_        ) == shape(inference_engine%biases_        ), &
          shape(self%output_biases_ ) == shape(inference_engine%output_biases_ )  &
        ] )
  end procedure

  module procedure subtract
    call assert(self%conformable_with(rhs), "inference_engine_t%subtract: conformable operands", &
      intrinsic_array_t([shape(self%biases_), shape(rhs%biases_)]))
    
    difference%input_weights_  = self%input_weights_  - rhs%input_weights_ 
    difference%hidden_weights_ = self%hidden_weights_ - rhs%hidden_weights_
    difference%output_weights_ = self%output_weights_ - rhs%output_weights_
    difference%biases_         = self%biases_         - rhs%biases_         
    difference%output_biases_  = self%output_biases_  - rhs%output_biases_ 
    difference%inference_strategy_ = self%inference_strategy_
    difference%activation_strategy_ = self%activation_strategy_

    call assert_consistent(difference)
  end procedure

  module procedure norm 
    call assert_consistent(self)
    norm_of_self = maxval(abs(self%input_weights_)) + maxval(abs(self%hidden_weights_)) + maxval(abs(self%output_weights_)) + & 
           maxval(abs(self%biases_)) + maxval(abs(self%output_biases_))
  end procedure

  pure subroutine assert_consistent(self)
    type(inference_engine_t), intent(in) :: self

    call assert(allocated(self%inference_strategy_), "inference_engine%assert_consistent: allocated(self%inference_strategy_)")
    call assert(allocated(self%activation_strategy_), "inference_engine%assert_consistent: allocated(self%activation_strategy_)")

    associate(allocated_components => &
      [allocated(self%input_weights_), allocated(self%hidden_weights_), allocated(self%output_weights_), &
       allocated(self%biases_), allocated(self%output_biases_)] &
    )
      call assert(all(allocated_components), "inference_engine_s(assert_consistent): fully allocated object", &
        intrinsic_array_t(allocated_components))
    end associate

    associate(num_neurons => 1 + &
      [ ubound(self%biases_,         1) - lbound(self%biases_,         1), & 
        ubound(self%hidden_weights_, 1) - lbound(self%hidden_weights_, 1), &
        ubound(self%hidden_weights_, 2) - lbound(self%hidden_weights_, 2), &
        ubound(self%input_weights_,  1) - lbound(self%input_weights_,  1), &
        ubound(self%output_weights_, 2) - lbound(self%output_weights_, 2)  &
    ] ) 
      call assert(all(num_neurons == num_neurons(1)), "inference_engine_s(assert_consistent): num_neurons", &
        intrinsic_array_t(num_neurons) &
      )
    end associate

    associate(output_count => 1 + &
      [ ubound(self%output_weights_, 1) - lbound(self%output_weights_, 1), & 
        ubound(self%output_biases_,  1) - lbound(self%output_biases_,  1)  &
    ] )
      call assert(all(output_count == output_count(1)), "inference_engine_s(assert_consistent): output_count", &
        intrinsic_array_t(output_count) &
      )
    end associate
  end subroutine

  module procedure num_outputs
    call assert_consistent(self)
    output_count = ubound(self%output_weights_,1) - lbound(self%output_weights_,1) + 1
  end procedure

  module procedure num_inputs
    call assert_consistent(self)
    input_count = ubound(self%input_weights_,2) - lbound(self%input_weights_,2) + 1
  end procedure

  module procedure neurons_per_layer
    call assert_consistent(self)
    neuron_count = ubound(self%input_weights_,1) - lbound(self%input_weights_,1) + 1
  end procedure

  module procedure num_hidden_layers
    call assert_consistent(self)
    hidden_layer_count = ubound(self%hidden_weights_,3) - lbound(self%hidden_weights_,3) + 1
  end procedure

  module procedure infer_from_array_of_inputs
    integer layer

    call assert_consistent(self)

    output = self%inference_strategy_%infer(input, &
      self%input_weights_, self%hidden_weights_, self%biases_, self%output_biases_, self%output_weights_, self%activation_strategy_&
    )
  end procedure

  module procedure infer_from_inputs_object
    integer layer

    call assert_consistent(self)

    outputs%outputs_ = self%inference_strategy_%infer(inputs%inputs_, &
      self%input_weights_, self%hidden_weights_, self%biases_, self%output_biases_, self%output_weights_, self%activation_strategy_&
      
    )
  end procedure

  module procedure write_network
    integer file_unit, io_status, input, layer, neuron

    open(newunit=file_unit, file=file_name%string(), form='formatted', status='unknown', iostat=io_status, action='write')
    call assert(io_status==0,"write_network: io_status==0 after 'open' statement", file_name%string())
 
    call assert_consistent(self)

    write_input_layer : &
    block
      input = 1
      write(file_unit,*) "[[", self%input_weights_(:,input), trim(merge("]]", "] ", self%num_inputs()==1))

      do input = 2, self%num_inputs() - 1
        write(file_unit,*) "[", self%input_weights_(:,input),"]"
      end do

      input = self%num_inputs()
      if (input>1) write(file_unit,*) "[",self%input_weights_(:, self%num_inputs()),"]]"

      write(file_unit,*)
      write(file_unit,*) "[",self%biases_(:,1),"]"
    end block write_input_layer

    write_hidden_layers: &
    do layer = 1, self%num_hidden_layers()

      write(file_unit,*)

      neuron = 1
      write(file_unit,*) "[[", self%hidden_weights_(:, neuron, layer), trim(merge("]]", "] ", self%neurons_per_layer()==1))

      do neuron = 2, self%neurons_per_layer()-1
        write(file_unit,*) "[",self%hidden_weights_(: , neuron, layer),"]"
      end do

      neuron = self%neurons_per_layer()
      if (neuron>1) write(file_unit,*) "[",self%hidden_weights_(:, neuron, layer),"]]"

      write(file_unit,*)
      write(file_unit,*) "[",self%biases_(:,layer+1),"]"

    end do write_hidden_layers
    
    write_output_layer: &
    block
      write(file_unit, *)

      neuron = 1
      write(file_unit,*) "[[", self%output_weights_(:, neuron), trim(merge("]]", "] ", self%neurons_per_layer()==1))

      do neuron = 2, self%neurons_per_layer()-1
        write(file_unit,*) "[",self%output_weights_(:, neuron),"]"
      end do

      neuron = self%neurons_per_layer()
      if (neuron>1) write(file_unit,*) "[",self%output_weights_(:, neuron),"]]"

      write(file_unit,*)
      write(file_unit,*) "[",self%output_biases_(:),"]"

    end block write_output_layer

    close(file_unit)
  end procedure write_network

  module procedure read_network

    integer file_unit, io_status, num_inputs, num_hidden_layers, num_outputs
    character(len=:), allocatable :: line

    open(newunit=file_unit, file=file_name%string(), form='formatted', status='old', iostat=io_status, action='read')
    call assert(io_status==0,"read_network: io_status==0 after 'open' statement", file_name%string())

    call read_line_and_count_inputs(file_unit, line, num_inputs)
    call count_hidden_layers(file_unit, len(line), num_hidden_layers)
    call count_outputs(file_unit, len(line), num_hidden_layers, num_outputs)

    associate(last_opening_bracket => index(line, "[", back=.true.), first_closing_bracket => index(line, "]"))
      associate(unbracketed_line => line(last_opening_bracket+1:first_closing_bracket-1))
        associate(neurons_per_layer=> num_array_elements_in(unbracketed_line))
          call read_weights_and_biases(file_unit, len(line), num_inputs, neurons_per_layer, num_hidden_layers, num_outputs, self)
        end associate
      end associate
    end associate

    if (present(activation_strategy)) then
      self%activation_strategy_  = activation_strategy
    else
      self%activation_strategy_  = step_t()
    end if
 
    if (present(inference_strategy)) then
      self%inference_strategy_  = inference_strategy
    else
      self%inference_strategy_  = matmul_t()
    end if

    close(file_unit)

    call assert_consistent(self)

  contains

    function line_length(file_unit) result(length)
      integer, intent(in) :: file_unit
      integer length, io_status
      character(len=1) c

      io_status = 0
      length = 1
      do 
        read(file_unit, '(a)',advance='no',iostat=io_status) c
        if (io_status/=0) exit
        length = length + 1
      end do
      backspace(file_unit)
    end function

    subroutine read_line_and_count_inputs(file_unit, line, input_count)
      integer, intent(in) :: file_unit
      character(len=:), intent(out), allocatable :: line
      integer, intent(out) :: input_count
      integer io_status

      rewind(file_unit)
      allocate(character(len=line_length(file_unit)):: line)
      input_count = 0
      do 
        read(file_unit,'(a)', iostat=io_status) line
        call assert(io_status==0, "read_line_and_count_inputs: io_status==0", io_status ) 
        input_count = input_count + 1
        if (index(line, "]]", back=.true.) /= 0) exit
      end do
      rewind(file_unit)
    end subroutine

    pure function num_array_elements_in(space_delimited_reals) result(array_size)
      character(len=*), intent(in) :: space_delimited_reals
      real(rkind), allocatable :: array(:)
      integer array_size, io_status
      
      io_status = 0
      array_size = 1
      do while (io_status==0)
        if (allocated(array)) deallocate(array)
        allocate(array(array_size))
        read(space_delimited_reals, *, iostat=io_status) array
        array_size = array_size + 1
      end do
      array_size = size(array)-1
    end function

    subroutine read_weights_and_biases( &
       file_unit, buffer_size, num_inputs, neurons_per_layer, num_hidden_layers, num_outputs, self &
    )
      integer, intent(in) :: file_unit, buffer_size, num_inputs, neurons_per_layer, num_hidden_layers, num_outputs
      type(inference_engine_t), intent(out) :: self
      character(len=buffer_size) line_buffer
      integer input, io_status, layer, neuron
      integer, parameter :: input_layer = 1
      
      rewind(file_unit)

      allocate(self%input_weights_(neurons_per_layer, num_inputs))

      read_input_weights: &
      do input = 1, size(self%input_weights_,2)
        read(file_unit,'(a)', iostat=io_status) line_buffer
        call assert(io_status==0, "read_input_weights: io_status==0", io_status ) 
        associate(last_opening_bracket => index(line_buffer, "[", back=.true.), first_closing_bracket => index(line_buffer, "]"))
          associate(unbracketed_line => line_buffer(last_opening_bracket+1:first_closing_bracket-1))
            read(unbracketed_line,*) self%input_weights_(:, input)
          end associate
        end associate
      end do read_input_weights

      allocate(self%biases_(neurons_per_layer, num_hidden_layers+input_layer))
      allocate(self%hidden_weights_(neurons_per_layer, neurons_per_layer, num_hidden_layers))

      find_input_layer_biases: &
      do 
        read(file_unit,'(a)', iostat=io_status) line_buffer
        call assert(io_status==0, "find_input_layer_biases: io_status==0", io_status ) 
        if (index(line_buffer, "[")/=0) exit
      end do find_input_layer_biases

      read_input_layer_biases: &
      associate(last_opening_bracket => index(line_buffer, "[", back=.true.), first_closing_bracket => index(line_buffer, "]"))
        associate(unbracketed_line => line_buffer(last_opening_bracket+1:first_closing_bracket-1))
          read(unbracketed_line,*) self%biases_(:,input_layer)
        end associate
      end associate read_input_layer_biases

      read_hidden_layer_weights_biases: &
      do layer = 1, num_hidden_layers

        find_weights: &
        do 
          read(file_unit,'(a)', iostat=io_status) line_buffer
          call assert(io_status==0, "find_weights: io_status==0", io_status ) 
          if (index(line_buffer, "[[")/=0) exit
        end do find_weights

        read_weights: &
        do neuron = 1, size(self%hidden_weights_,2)
          if (neuron/=1) read(file_unit,'(a)', iostat=io_status) line_buffer
          associate(last_opening_bracket => index(line_buffer, "[", back=.true.), first_closing_bracket => index(line_buffer, "]"))
            associate(unbracketed_line => line_buffer(last_opening_bracket+1:first_closing_bracket-1))
              read(unbracketed_line,*) self%hidden_weights_(:,neuron,layer)
            end associate
          end associate
        end do read_weights

        find_biases: &
        do 
          read(file_unit,'(a)', iostat=io_status) line_buffer
          call assert(io_status==0, "read_biases: io_status==0", io_status ) 
          if (index(line_buffer, "[")/=0) exit
        end do find_biases

        read_biases: &
        associate(last_opening_bracket => index(line_buffer, "[", back=.true.), first_closing_bracket => index(line_buffer, "]"))
          associate(unbracketed_line => line_buffer(last_opening_bracket+1:first_closing_bracket-1))
            read(unbracketed_line,*) self%biases_(:,input_layer+layer)
          end associate
        end associate read_biases
        
      end do read_hidden_layer_weights_biases

      allocate(self%output_weights_(num_outputs, neurons_per_layer))
      allocate(self%output_biases_(num_outputs))

      find_output_weights: &
      do 
        read(file_unit,'(a)', iostat=io_status) line_buffer
        call assert(io_status==0, "find_outut_layer_weights: io_status==0", io_status ) 
        if (index(line_buffer, "[[")/=0) exit
      end do find_output_weights

      read_output_weights: &
      do neuron = 1, size(self%hidden_weights_,2)
        if (neuron/=1) read(file_unit,'(a)', iostat=io_status) line_buffer
        associate(last_opening_bracket => index(line_buffer, "[", back=.true.), first_closing_bracket => index(line_buffer, "]"))
          associate(unbracketed_line => line_buffer(last_opening_bracket+1:first_closing_bracket-1))
            read(unbracketed_line,*) self%output_weights_(:,neuron)
          end associate
        end associate
      end do read_output_weights

      find_output_biases: &
      do 
        read(file_unit,'(a)', iostat=io_status) line_buffer
        call assert(io_status==0, "find_outut_layer_weights: io_status==0", io_status ) 
        if (index(line_buffer, "[")/=0) exit
      end do find_output_biases

      associate(last_opening_bracket => index(line_buffer, "[", back=.true.), first_closing_bracket => index(line_buffer, "]"))
        associate(unbracketed_line => line_buffer(last_opening_bracket+1:first_closing_bracket-1))
          read(unbracketed_line,*) self%output_biases_(:)
        end associate
      end associate

      rewind(file_unit)
    end subroutine read_weights_and_biases

    subroutine count_hidden_layers(file_unit, buffer_size, hidden_layers)
      integer, intent(in) :: file_unit, buffer_size
      integer, intent(out) :: hidden_layers
      integer, parameter :: input_layer=1, output_layer=1
      integer layers, io_status
      character(len=buffer_size) line_buffer

      rewind(file_unit)
      layers = 0
      io_status=0
      do while(io_status==0)
        read(file_unit, '(a)', iostat=io_status) line_buffer
        if (index(line_buffer, "[[") /= 0) layers = layers +1
      end do
      hidden_layers = layers - (input_layer + output_layer)
      rewind(file_unit)
    end subroutine

    subroutine count_outputs(file_unit, buffer_size, num_hidden_layers, output_count)
      integer, intent(in) :: file_unit, buffer_size, num_hidden_layers
      integer, intent(out) :: output_count
      character(len=buffer_size) line_buffer
      integer, parameter :: input_layer=1, output_layer=1
      integer layer

      rewind(file_unit)

      layer = 0

      find_end_of_hidden_layers: &
      do
        read(file_unit, '(a)', iostat=io_status) line_buffer
        call assert(io_status==0, "read_hidden_layers: io_status==0", io_status ) 
        if (index(line_buffer, "]]") /= 0) layer = layer + 1
        if (layer == input_layer  + num_hidden_layers + output_layer) exit
      end do find_end_of_hidden_layers

      find_and_read_output_biases: &
      do 
        read(file_unit,'(a)', iostat=io_status) line_buffer
        call assert(io_status==0, "find_output_biases: io_status==0", io_status ) 
        if (index(line_buffer, "[")/=0) exit
      end do find_and_read_output_biases

      associate(last_opening_bracket => index(line_buffer, "[", back=.true.), first_closing_bracket => index(line_buffer, "]"))
        associate(unbracketed_line => line_buffer(last_opening_bracket+1:first_closing_bracket-1))
          output_count = num_array_elements_in(unbracketed_line)
        end associate
      end associate

      rewind(file_unit)
    end subroutine

  end procedure read_network

  module procedure to_json

    type(string_t), allocatable :: lines(:)
    integer layer, neuron, line
    integer, parameter :: characters_per_value=17
    character(len=:), allocatable :: comma_separated_values, csv_format
    character(len=17) :: single_value
    integer, parameter :: &
      outer_object_braces = 2, hidden_layer_outer_brackets = 2, lines_per_neuron = 4, inner_brackets_per_layer  = 2, &
      output_layer_brackets = 2, comma = 1

    call assert_consistent(self)

    csv_format = separated_values(separator=",", mold=[real(rkind)::])

    associate(num_hidden_layers => self%num_hidden_layers(),  neurons_per_layer => self%neurons_per_layer(), &
      num_outputs => self%num_outputs(), num_inputs => self%num_inputs())
      associate(num_lines => &
        outer_object_braces + hidden_layer_outer_brackets &
        + (num_hidden_layers + 1)*(inner_brackets_per_layer + neurons_per_layer*lines_per_neuron) &
        + output_layer_brackets + num_outputs*lines_per_neuron &
      )
        allocate(lines(num_lines))

        line = 1
        lines(line) = string_t('{')

        line = line + 1
        lines(line) = string_t('     "hidden_layers": [')

        layer = 1 
        line = line + 1
        lines(line) = string_t('         [')
        do neuron = 1, neurons_per_layer
          line = line + 1
          lines(line) = string_t('             {')
          line = line + 1
          allocate(character(len=num_inputs*(characters_per_value+1)-1)::comma_separated_values)
          write(comma_separated_values, fmt = csv_format) self%input_weights_(neuron,:)
          lines(line) = string_t('                "weights": [' // trim(comma_separated_values) // '],')
          deallocate(comma_separated_values)
          line = line + 1
          write(single_value, fmt = csv_format) self%biases_(neuron,layer)
          lines(line) = string_t('                 "bias": ' // trim(single_value))
          line = line + 1
          lines(line) = string_t("             }" // trim(merge(' ',',',neuron==neurons_per_layer)))
        end do
        line = line + 1
        lines(line) = string_t(trim(merge("         ],", "         ] ", line/=num_hidden_layers + 1)))

        do layer = 1, num_hidden_layers
          line = line + 1
          lines(line) = string_t('         [')
          do neuron = 1, neurons_per_layer
            line = line + 1
            lines(line) = string_t('             {')
            line = line + 1
            allocate(character(len=neurons_per_layer*(characters_per_value+1)-1)::comma_separated_values)
            write(comma_separated_values, fmt = csv_format) self%hidden_weights_(:, neuron, layer)
            lines(line) = string_t('                "weights": [' // trim(comma_separated_values) // '],')
            deallocate(comma_separated_values)
            line = line + 1
            write(single_value, fmt = csv_format) self%biases_(neuron,layer+1)
            lines(line) = string_t('                 "bias": ' // trim(single_value))
            line = line + 1
            lines(line) = string_t("             }" // trim(merge(' ',',',neuron==neurons_per_layer)))
          end do
          line = line + 1
          lines(line) = string_t("         ]" // trim(merge(' ',',',layer==num_hidden_layers)))
        end do

        line = line + 1
        lines(line) = string_t("     ],")

        line = line + 1
        lines(line) = string_t('     "output_layer": [')

        do neuron = 1, num_outputs
          line = line + 1
          lines(line) = string_t('             {')
          line = line + 1
          allocate(character(len=neurons_per_layer*(characters_per_value+1)-1)::comma_separated_values)
          write(comma_separated_values, fmt = csv_format) self%output_weights_(neuron,:)
          lines(line) = string_t('                "weights": [' // trim(comma_separated_values) // '],')
          deallocate(comma_separated_values)
          line = line + 1
          write(single_value, fmt = csv_format) self%output_biases_(neuron)
          lines(line) = string_t('                 "bias": ' // trim(single_value))
          line = line + 1
          lines(line) = string_t("             }")
        end do

        line = line + 1
        lines(line) = string_t('     ]')

        line = line + 1
        lines(line) = string_t('}')

        call assert(line == num_lines, "inference_engine_t%to_json: all lines defined", intrinsic_array_t([num_lines, line]))
      end associate
    end associate

    json_file = file_t(lines)

  end procedure to_json

end submodule inference_engine_s
