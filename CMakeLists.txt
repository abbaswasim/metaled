# MetalEd Source Code
# Wasim Abbas
# http://www.waZim.com
# Copyright (c) 2021
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the 'Software'),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software
# is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Version: 1.0.0

cmake_minimum_required (VERSION 3.12)

project(MetalEd VERSION 1.1.0.0 LANGUAGES CXX C)
list(APPEND CMAKE_MESSAGE_CONTEXT metaled_Engine)

set(METALED_NAME MetalEd)

set(METALED_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR}) # Always prefer the _LIST_ version FILES/DIRS instead of the _SOURCE_
set(METALED_SOURCE_DIR ${METALED_ROOT_DIR}/src)

include(${METALED_ROOT_DIR}/thirdparty/roar/build.cmake)

# Always generate compile_commands.json
set(CMAKE_EXPORT_COMPILE_COMMANDS 1)

add_subdirectory(${METALED_ROOT_DIR}/thirdparty)
# add_subdirectory(${METALED_SOURCE_DIR})


set(METALED_HEADERS )

set(METALED_SOURCES
  ${METALED_SOURCE_DIR}/camera.cpp
  ${METALED_SOURCE_DIR}/main.mm)

add_executable(${METALED_NAME} ${METALED_SOURCES} ${METALED_HEADERS})
set_target_properties(${METALED_NAME} PROPERTIES VERSION 1.0.0.0 SOVERSION 1)          # TODO: Fix the hardcoded version
set_target_properties(${METALED_NAME} PROPERTIES CMAKE_VISIBILITY_INLINES_HIDDEN true) # Don't export all of those C++ template generated symbols
set_target_properties(${METALED_NAME} PROPERTIES CMAKE_CXX_VISIBILITY_PRESET hidden)   # Set default to hide symbols visibility for Roar
set_target_properties(${METALED_NAME} PROPERTIES CMAKE_C_VISIBILITY_PRESET hidden)     # Set default to hide symbols visibility for Roar

set(CMAKE_VISIBILITY_INLINES_HIDDEN YES)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)    # Set default to hide symbols visibility for all targets
set(CMAKE_C_VISIBILITY_PRESET hidden)      # Set default to hide symbols visibility for all targets

target_include_directories(${METALED_NAME} PUBLIC "${CMAKE_CURRENT_BINARY_DIR}")
target_include_directories(${METALED_NAME} PRIVATE ${METALED_SOURCE_DIR})
target_include_directories(${METALED_NAME} PRIVATE ${METALED_ROOT_DIR})
target_include_directories(${METALED_NAME} PUBLIC ${METALED_SYMBOLS_SOURCE_DIR})

find_library(CARBON_LIBRARY Carbon)
find_library(APPKIT_LIBRARY AppKit)
find_library(METAL_LIBRARY Metal)
find_library(QUARTZCORE_LIBRARY QuartzCore)

set(METALED_REQUIRED_LIBRARIES_SYSTEM
  cimage
  glfw
  roar)

set(METALED_REQUIRED_LIBRARIES
  ${CARBON_LIBRARY}
  ${APPKIT_LIBRARY}
  ${METAL_LIBRARY}
  ${QUARTZCORE_LIBRARY}
  dl)

target_link_libraries(${METALED_NAME} PRIVATE ${METALED_REQUIRED_LIBRARIES})
target_link_libraries_system(${METALED_NAME} PRIVATE ${METALED_REQUIRED_LIBRARIES_SYSTEM})

if (USE_VOLK_INSTEAD)
  target_compile_definitions(${METALED_NAME}
	PRIVATE USE_VOLK_INSTEAD)
endif()

# build_options(${METALED_NAME}) # Set common build options
