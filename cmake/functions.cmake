#------------------------------------------------------------------------------
# Add a test to the drake project to be run by ctest.
#
#   drake_add_test(NAME <name> COMMAND <command> [<arg>...]
#                  [CONFIGURATIONS <configuration>...]
#                  [SIZE <small | medium | large | enormous>]
#                  [WORKING_DIRECTORY <directory>])
#
# Arguments:
#   SIZE
#     Set the size of the test. Test sizes are primarily defined by the number
#     of seconds to allow for the test execution. If not specified, the size of
#     the test will be set to small. The LABEL test property will be set to the
#     size of the test.
#------------------------------------------------------------------------------
function(drake_add_test)
  cmake_parse_arguments("" "" "NAME;SIZE" "" ${ARGN})

  if(NOT _SIZE)
    set(_SIZE small)
  endif()

  drake_compute_test_timeout("${_SIZE}")

  if(LONG_RUNNING_TESTS OR _SIZE MATCHES "(small|medium)")
    add_test(NAME ${_NAME} ${_UNPARSED_ARGUMENTS})
    set_tests_properties(${_NAME} PROPERTIES LABELS ${_SIZE} TIMEOUT ${_TIMEOUT})
  else()
    message(STATUS "Not running ${_NAME} because ${_SIZE} tests are not enabled")
  endif()
endfunction()

option(TEST_TIMEOUT_MULTIPLIER "Positive integer by which to multiply test timeouts" 1)
mark_as_advanced(TEST_TIMEOUT_MULTIPLIER)

#------------------------------------------------------------------------------
# Compute the timeout of a test given its size.
#
# Arguments:
#   <_SIZE> - The size of the test.
#------------------------------------------------------------------------------
function(drake_compute_test_timeout _SIZE)
  # http://googletesting.blogspot.com/2010/12/test-sizes.html
  if(_SIZE STREQUAL small)
    set(_TIMEOUT 60)
  elseif(_SIZE STREQUAL medium)
    set(_TIMEOUT 300)
  elseif(_SIZE STREQUAL large)
    set(_TIMEOUT 900)
  elseif(_SIZE STREQUAL enormous)
    set(_TIMEOUT 2700)
  else()
    set(_SIZE small)
    set(_TIMEOUT 60)
  endif()

  if(TEST_TIMEOUT_MULTIPLIER GREATER 1)
    math(EXPR test_timeout "${_TIMEOUT} * ${TEST_TIMEOUT_MULTIPLIER}")
  endif()

  set(_SIZE ${_SIZE} PARENT_SCOPE)
  set(_TIMEOUT ${_TIMEOUT} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Add a MATLAB test to the drake project to be run by ctest.
#
#   add_matlab_test(NAME <name> COMMAND <matlab_string_to_evaluate>
#                  [CONFIGURATIONS <configuration>...]
#                  [REQUIRES <external>...]
#                  [OPTIONAL <external>...]
#                  [SIZE <small | medium | large | enormous>]
#                  [WORKING_DIRECTORY <directory>])
#
# Arguments:
#   COMMAND
#     Specify the MATLAB string to evaluate.
#   REQUIRES
#     Declare required external dependencies. Each required dependency must
#     write a file named addpath_<external>.m to CMAKE_INSTALL_PREFIX/matlab or
#     set WITH_<external> or <external>_FOUND to ON. If a required
#     dependency is not available, the test will not be run.
#   OPTIONAL
#     Optional external dependency. Reserved for future use.
#   SIZE
#     Set the size of the test. Test sizes are primarily defined by the number
#     of seconds to allow for the test execution. If not specified, the size of
#     the test will be set to medium. The LABEL test property will be set to
#     the size of the test.
#   WORKING_DIRECTORY
#     Set the WORKING_DIRECTORY test property to specify the working directory
#     in which to execute the test. If not specified, the test will be run with
#     the working directory set to CMAKE_CURRENT_SOURCE_DIR.
#------------------------------------------------------------------------------
function(add_matlab_test)
  if(NOT MATLAB_FOUND)
    return()
  endif()

  cmake_parse_arguments("" "" "COMMAND;NAME;SIZE;WORKING_DIRECTORY" "OPTIONAL;REQUIRES" ${ARGN})

  if(NOT _SIZE)
    set(_SIZE medium)
  endif()

  drake_compute_test_timeout("${_SIZE}")

  if(NOT LONG_RUNNING_TESTS AND NOT _SIZE MATCHES "(small|medium)")
    message(STATUS "Not running ${_NAME} because ${_SIZE} tests are not enabled")
    return()
  endif()

  if(_REQUIRES)
    foreach(_require ${_REQUIRES})
      string(TOUPPER ${_require} _require_upper)
      if(NOT WITH_${_require_upper} AND NOT ${_require}_FOUND AND NOT EXISTS "${CMAKE_INSTALL_PREFIX}/matlab/addpath_${_require}.m")
        message(STATUS "Not running ${_NAME} because ${_require} was not installed")
        return()
      endif()
    endforeach()
  endif()

  string(REPLACE ' '' _COMMAND ${_COMMAND}) # turn ' into '' so we can eval it in MATLAB
  if(NOT _WORKING_DIRECTORY)
    set(_WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  set(_additional_paths "${CMAKE_INSTALL_PREFIX}/matlab;${_WORKING_DIRECTORY};")
  set(_test_precommand "addpath_drake; global g_disable_visualizers; g_disable_visualizers=true;")

  set(_exit_status "~strncmp(ex.identifier,'Drake:MissingDependency',23)")  # missing dependency => pass
  set(_test_command "try, eval('${_COMMAND}'); catch ex, disp(getReport(ex,'extended')); disp(' '); force_close_system; exit(${_exit_status}); end; force_close_system; exit(0)")

  if(RANDOMIZE_MATLAB_TESTS)
    set(_test_command "rng('shuffle'); rng_state=rng; disp(sprintf('To reproduce this test use rng(%d,''%s'')',rng_state.Seed,rng_state.Type)); disp(' '); ${_test_command}")
  endif()

  set(_test_args TEST_ARGS ${_UNPARSED_ARGUMENTS})

  matlab_add_unit_test(
    NAME ${_NAME}
    ADDITIONAL_PATH ${_additional_paths}
    UNITTEST_PRECOMMAND ${_test_precommand}
    CUSTOM_TEST_COMMAND \"${_test_command}\"
    TIMEOUT -1
    WORKING_DIRECTORY ${_WORKING_DIRECTORY}
    ${_test_args})
  set_tests_properties(${_NAME} PROPERTIES LABELS ${_SIZE} TIMEOUT ${_TIMEOUT})
endfunction()
