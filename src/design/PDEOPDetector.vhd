-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides a unit for detecting the end of a USB-PD packet.
entity PDEOPDetector is
port(
    -- Master clock
    CLK : in    std_logic;
    -- Enable
    EN  : in    std_logic;
    -- Data input
    D   : in    std_logic_vector(4 downto 0);
    -- Asynchronous reset
    RST : in    std_logic;
    
    -- Detected
    --      Asserted when an end-of-packet condition is detected.
    DET : out   std_ulogic
    );
end PDEOPDetector;


architecture Impl of PDEOPDetector is
begin

end;