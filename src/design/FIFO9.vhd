-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides an asynchronous first-in first-out (FIFO) buffer which stores 9-bit
-- words and exposes an interface largely compatible with Xilinx block RAMs.
entity FIFO9 is
port(
    -- Write clock
    --      Used to synchronise writes to the FIFO.
    WRCLK   : in    std_logic;
    -- Write request
    --      Indicates that data to be written to the FIFO is present on [DI].
    WREQ    : in    std_logic;
    -- Data input
    DI      : in    std_logic_vector(8 downto 0);
    -- FIFO full status indicator
    FULL    : out   std_ulogic;
    -- FIFO filling status indicator
    --      Indicates that the FIFO is half or more full.
    FILLING : out   std_ulogic;
    -- Write error
    --      Asserted when an attempt to write to the FIFO is made while the
    --      FIFO is full.
    WERR    : out   std_ulogic;
    
    -- Read clock
    --      Used to synchronise reads to the FIFO.
    RDCLK   : in    std_logic;
    -- Read request
    --      Signals for data to be read from the FIFO onto [DO].
    RREQ    : in    std_logic;
    -- Data output
    DO      : out   std_ulogic_vector(8 downto 0);
    -- Read error
    --      Asserted when an attempt is made to read from the FIFO while the
    --      FIFO is empty.
    RERR    : out   std_ulogic;
    
    -- Reset
    --      Clears the FIFO and returns it to its initial state.
    RST     : in    std_logic
    );
end FIFO9;


-- Encapsulates a Xilinx 7-series FPGA block RAM.
architecture XBRAM of FIFO9 is
begin
    assert false report "FIFO9<XBRAM> not implemented" severity failure;
end;


-- Implements a FIFO9 where the data storage elements are synthesised in the
-- FPGA fabric rather than in a hardened component.
architecture FFREG of FIFO9 is
begin
    assert false report "FIFO9<FFREG> not implemented" severity failure;
end;