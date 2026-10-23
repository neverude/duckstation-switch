add_executable(duckstation-switch
  frontend_host.cpp
  frontend_host.h
  frontend_platform.h
)

target_precompile_headers(duckstation-switch PRIVATE "pch.h")
target_link_libraries(duckstation-switch PRIVATE core util common imgui scmversion)

add_core_resources(duckstation-switch)

if(NINTENDO_SWITCH)
  enable_language(ASM)

  target_sources(duckstation-switch PRIVATE
    switch_frontend_platform.cpp
    switch_frontend_platform.h
    switch_asm.s
  )
  target_link_libraries(duckstation-switch PUBLIC "${NX_LIBRARIES}")

  nx_generate_nacp (duckstation.nacp
    NAME    "duckstation"
    AUTHOR  "Stenzek, RSDuck (port)"
    VERSION "pre-release 1"
  )

  # Create folder early otherwise the CMake script complains
  file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/romfs)

  if (CMAKE_BUILD_TYPE STREQUAL Debug)
    nx_create_nro(duckstation-switch
      OUTPUT ${CMAKE_BINARY_DIR}/duckstation.nro
      NACP  duckstation.nacp
      ICON  "${CMAKE_SOURCE_DIR}/extras/icons/icon-switch.jpg"
    )
  else()
    nx_create_nro(duckstation-switch
      OUTPUT ${CMAKE_BINARY_DIR}/duckstation.nro
      NACP  duckstation.nacp
      ICON  "${CMAKE_SOURCE_DIR}/extras/icons/icon-switch.jpg"
      ROMFS ${CMAKE_BINARY_DIR}/romfs
    )
  endif()
endif()
