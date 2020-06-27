This project is part of the work included in a dissertation
for a B.Eng (Hons) in Electronic and Electrical Engineering,
where the overall aim was to design and build a USB Power
Delivery physical layer (PHY) suitable for integration into
a power supply in a conventional plug socket form factor.

Included here are the design and test resources for a system
controller prototyped on a Xilinx Artix-7 XC7A35T. The role
of the system controller is to operate a biphase mark coding
PHY as well as the USB Type-C and USB-PD signalling used in
conjunction with the PHY.

The testing framework, VUnit, relies on having Python and a
suitable simulator installed. Tests are known to work when
using GHDL 0.36 under Ubuntu 18.04 LTS.


STRUCTURE

    src/            - Project source code
        design/     - HDL for the controller design
        test/       - HDL for test benches, etc.
    
    script/         - Scripts related to project development


TAGS

    rev.1           - Controller as at B.Eng (Hons) submission


BRANCHES

    master          - Main development branch
    sync_fifo_tests - Draft changes to test FIFO9 synchronously
    fifo_bram       - Draft FIFO9->Xilinx BRAM mapping


COPYRIGHT & LICENCE

    2019-20 (c) Liam McSherry
    
    Released under the terms of the GNU Affero GPL 3.0. A
    copy of this licence is available in './LICENCE.txt'.
