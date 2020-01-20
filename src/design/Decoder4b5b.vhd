-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides an decoder which translates 4b5b line-coded raw data or USB-PD
-- control signals into their raw binary or numbered form.
entity Decoder4b5b is
port(
    -- Data clock
    CLK     : in    std_logic;
    -- Write enable
    --      Indicates when ARG provides valid data.
    WE      : in    std_logic;
    -- Data
    --      Five bits which are 4b5b-coded data to be decoded into either
    --      raw data or a K-code number.
    ARG     : in    std_logic_vector(4 downto 0);
    
    -- Output
    --      The line-coded symbol represented by [ARG].
    Q       : out   std_ulogic_vector(3 downto 0);
    -- K-code or Data
    --      Indicates whether the output on Q is a K-code (if high) or raw
    --      binary data (if low).
    K       : out   std_ulogic
    );
end Decoder4b5b;

architecture Impl of Decoder4b5b is
begin

end;
