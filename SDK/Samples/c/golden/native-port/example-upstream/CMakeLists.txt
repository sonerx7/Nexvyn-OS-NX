cmake_minimum_required(VERSION 3.13)
project(stand_in LANGUAGES CXX)
add_executable(native-port main.cpp)
target_include_directories(native-port PRIVATE ../src)
