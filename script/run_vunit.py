# 2019-20 (c) Liam McSherry
#
# This file is released under the terms of the GNU Affero GPL 3.0. A copy
# of the text of this licence is available from 'LICENCE.txt' in the project
# root directory.
from vunit import VUnit

vu = VUnit.from_argv()

lib = vu.add_library("lib");

# Add design and test sources
lib.add_source_files("../src/design/*.vhd")
lib.add_source_files("../src/test/*.vhd")

vu.main()
