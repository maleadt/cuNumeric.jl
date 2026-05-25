#!/bin/bash
# Copyright 2025 Northwestern University,
#                   Carnegie Mellon University University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author(s): David Krasowska <krasow@u.northwestern.edu>
#            Ethan Meitz <emeitz@andrew.cmu.edu>

set -e

# Check if exactly one argument is provided
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

CUNUMERIC_ROOT_DIR=$1  # First argument

# Check if the provided argument is a valid directory
if [[ ! -d "$CUNUMERIC_ROOT_DIR" ]]; then
    echo "Error: '$CUNUMERIC_ROOT_DIR' is not a valid directory."
    exit 1
fi

JULIA='julia'
JULIA_PATH=$(which $JULIA)

if [ -z "$JULIA_PATH" ]; then
  echo "Error: $JULIA is not installed or not in PATH."
  exit 1
fi

echo "Using $JULIA at: $JULIA_PATH"

# find julia dependency path
JULIA_DEP_PATH=$($JULIA -e 'println(DEPOT_PATH[1])')

JULIA_CXXWRAP_DEV=$JULIA_DEP_PATH/dev/libcxxwrap_julia_jll
JULIA_CXXWRAP=$JULIA_CXXWRAP_DEV/override

# Remove existing dev/override to ensure a clean slate.
#* THIS COULD BREAK SOME USERS CODE IF THEY ALREADY OVERRIDE THIS PKG
cd $CUNUMERIC_ROOT_DIR
[ -f Manifest.toml ] && rm Manifest.toml
rm -rf $JULIA_CXXWRAP_DEV

julia -e 'using Pkg; Pkg.activate("."); Pkg.add("Legate")'
julia -e 'using Pkg; Pkg.activate("."); Pkg.precompile(["CxxWrap"])'

# Develop libcxxwrap_julia_jll (creates dev dir without override/).
julia -e 'using Pkg; Pkg.activate("."); Pkg.develop(PackageSpec(name="libcxxwrap_julia_jll"))'

# dev_jll() sees no override/ dir → copies JLL artifact content to override/
# This provides: lib/*.so, lib/cmake/JlCxx/*.cmake, include/jlcxx/*.hpp
# find_package(JlCxx) in the wrapper CMakeLists.txt then resolves via JlCxx_DIR=override/lib/cmake/JlCxx
julia -e 'using Pkg; Pkg.activate("."); import libcxxwrap_julia_jll; libcxxwrap_julia_jll.dev_jll()'

echo "libcxxwrap_julia_jll dev override populated from JLL artifact at $JULIA_CXXWRAP"
