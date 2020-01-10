-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


entity PDPreambleGen is
port(
    -- Data clock
    --      This should be a clock at the frequency used by the final
    --      output-driving stage.
    CLK     : in    std_logic;
    -- Trigger
    --      When asserted for at least one clock cycle, causes the preamble
    --      generator to begin producing output.
    TRIG    : in    std_logic;
    
    -- Data output
    Q       : out   std_ulogic;
    -- Final bit indicator
    --      Asserted when the value on [Q] is bit 63 of the preamble.
    FIN     : out   std_ulogic
    );
end PDPreambleGen;

architecture Impl of PDPreambleGen is
begin

end;