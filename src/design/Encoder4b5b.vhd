-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


entity Encoder4b5b is
port(
    -- Data clock
    CLK     : in    std_logic;
    -- Write enable
    --      Indicates when K and ARG provide valid data.
    WE      : in    std_logic;
    -- K-code or Data
    --      Indicates whether ARG provides a K-code number (if high) or raw
    --      data to be encoded (if low).
    K       : in    std_logic;
    -- Data
    --      Four bits which are raw data to be encoded or a K-code number.
    ARG     : in    std_logic_vector(3 downto 0);
    
    -- Output
    --      The line-coded symbol represented by [ARG].
    Q       : out   std_ulogic_vector(4 downto 0)
    );
end Encoder4b5b;

architecture Impl of Encoder4b5b is
begin

end;