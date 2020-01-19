-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides a utility block which produces a repeating 5-bit Gray code.
entity GrayGenerator5b is
port(
    -- Clock
    CLK     : in    std_logic;
    -- Enable
    --      When high, indicates that the next Gray code should be produced on
    --      the following rising clock edge.
    EN      : in    std_logic;
    -- Reset
    --      Returns the generator to the start of its sequence.
    RST     : in    std_logic;
    
    -- Data output
    --      Provides the generated Gray codes.
    Q       : out   std_ulogic_vector(4 downto 0) := "00000"
    );
end GrayGenerator5b;


architecture Impl of GrayGenerator5b is
    signal CurrentQ : std_ulogic_vector(4 downto 0) := "00000";
    signal NextQ    : std_ulogic_vector(4 downto 0);
begin

    process(CLK)
    begin
    
        if rising_edge(CLK) then
            -- If we aren't being reset, we simply proceed as normal by
            -- latching in the next item in the sequence.
            if EN = '1' then
                CurrentQ    <= NextQ;
            end if;
            
            -- Otherwise, if we are being reset, we just put everything back
            -- to the start.
            if RST = '1' then
                CurrentQ    <= "00000";
            end if;
        end if;
    
    end process;
    
    -- Although GHDL seemed fine with it, Vivado complained that we were
    -- attempting to read from an output-only signal. Changing to an internal
    -- signal as here seems to please it and should give the same result.
    Q <= CurrentQ;
    
    -- We produce our Gray code sequence manually. Perhaps it would be better
    -- to automate the algorithm, but as at this stage we only require a fixed
    -- code size (and don't foresee needing other sizes), this is enough.
    --
    -- A lookup table like this appears to be relatively resource-intensive,
    -- and so replacing this with a computed output could probably save LUTs
    -- and FFs in a resource-constrained design.
    with CurrentQ select NextQ <=
        "00001" when "00000",
        "00011" when "00001",
        "00010" when "00011",
        "00110" when "00010",
        "00111" when "00110",
        "00101" when "00111",
        "00100" when "00101",
        
        "01100" when "00100",
        "01101" when "01100",
        "01111" when "01101",
        "01110" when "01111",
        "01010" when "01110",
        "01011" when "01010",
        "01001" when "01011",
        "01000" when "01001",
        
        "11000" when "01000",
        "11001" when "11000",
        "11011" when "11001",
        "11010" when "11011",
        "11110" when "11010",
        "11111" when "11110",
        "11101" when "11111",
        "11100" when "11101",
        
        "10100" when "11100",
        "10101" when "10100",
        "10111" when "10101",
        "10110" when "10111",
        "10010" when "10110",
        "10011" when "10010",
        "10001" when "10011",
        "10000" when "10001",
        
        "00000" when "10000",
        "XXXXX" when others;
end;
