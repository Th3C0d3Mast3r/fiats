! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt
program write_read_infer
  !! This program demonstrates how to write a neural network to a JSON file,
  !! read the same network from the written file, query the network object for
  !! some of its properties, print those properties, and use the network to
  !! perform inference.  The network performs an identity mapping from any
  !! non-negative inputs to the corresponding outputs using a RELU activation
  !! function.
  use fiats_m, only : neural_network_t, tensor_t
  use julienne_m, only : string_t, command_line_t, file_t
  implicit none

  type(string_t) file_name
  type(command_line_t) command_line

  file_name = string_t(command_line%flag_value("--output-file"))

  if (len(file_name%string())==0) then
    error stop new_line('a') // new_line('a') // &
      'Usage: fpm run --example write-read-infer --profile release --flag "-fopenmp" -- --output-file "<file-name>"' 
  end if

  call write_read_query_infer(file_name)

contains

  function identity_network() result(neural_network)
    type(neural_network_t) neural_network
    integer, parameter :: nodes_per_layer(*) = [2, 2, 2]
    integer, parameter :: max_n = maxval(nodes_per_layer), layers = size(nodes_per_layer)
#ifdef _CRAYFTN
    real, allocatable :: weights(:,:,:)
    weights = reshape([real :: [1,0, 0,1], [1,0, 0,1]], [max_n, max_n, layers-1])
    neural_network = neural_network_t( &
      metadata = [string_t("Identity"), string_t("Damian Rouson"), string_t("2023-09-18"), string_t("relu"), string_t("false")], &
      weights = weights, &
      biases = reshape([real:: [0,0], [0,0]], [max_n, layers-1]), &
      nodes = nodes_per_layer &
    )
#else
    neural_network = neural_network_t( &
      metadata = [string_t("Identity"), string_t("Damian Rouson"), string_t("2023-09-18"), string_t("relu"), string_t("false")], &
      weights = reshape([real :: [1,0, 0,1], [1,0, 0,1]], [max_n, max_n, layers-1]), &
      biases = reshape([real :: [0,0], [0,0]], [max_n, layers-1]), &
      nodes = nodes_per_layer &
    )
#endif
  end function

  subroutine write_read_query_infer(output_file_name)
    type(string_t), intent(in) :: output_file_name
    type(string_t) activation_name
    integer i, j
    integer, parameter :: num_neurons = 3, num_hidden_layers = 2
    type(neural_network_t) network, neural_network
    type(file_t) json_output_file, json_input_file
    type(tensor_t) inputs, outputs 

    print *, "Constructing a neural_network_t neural-network object from scratch."
    network = identity_network()

    print *, "Converting a neural_network_t object to a file_t object."
    json_output_file = network%to_json()

    print *, "Writing a neural_network_t object to the file '"//output_file_name%string()//"' in JSON format."
    call json_output_file%write_lines(output_file_name)

    print *, "Reading a neural_network_t object from the same JSON file '"//output_file_name%string()//"'."
    json_input_file = file_t(output_file_name)

    print *, "Constructing a new neural_network_t object from the parameters read."
    neural_network = neural_network_t(json_input_file)

    print *, "Querying the new neural_network_t object for several properties:"
    print *, "Number of outputs:", neural_network%num_outputs()
    print *, "Number of inputs:", neural_network%num_inputs()
    print *, "Nodes per layer:", neural_network%nodes_per_layer()
    activation_name = neural_network%activation_function_name()
    print *, "Activation function: ", activation_name%string()
    print *, "Performing inference:"
    inputs = tensor_t([2.,3.])
    print *, "Inputs: ", inputs%values()
    outputs = neural_network%infer(inputs)
    print *, "Actual outputs: ", outputs%values()
    print *, "Correct outputs:  ", inputs%values()
  end subroutine write_read_query_infer

end program
