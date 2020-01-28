-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides a streaming CRC-32 generator.
entity PDCRCEngine is
port(
    -- Data clock
    CLK : in    std_logic;
    -- Write enable
    WE  : in    std_logic;
    -- Data input
    D   : in    std_logic;
    -- Asynchronous reset
    RST : in    std_logic;
    
    Q   : out   std_ulogic_vector(31 downto 0)
    );
end PDCRCEngine;


architecture Impl of PDCRCEngine is
begin

end;