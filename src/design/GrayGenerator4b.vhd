-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- Provides a utility block which produces a repeating 4-bit Gray code with
-- status signals to indicate when wraparound occurs.
entity GrayGenerator4b is
port(
    -- Clock
    CLK     : in    std_logic;
    -- Enable
    --      When high, indicates that the next Gray code should be produced on
    --      the following rising clock edge.
    EN      : in    std_logic;
    
    -- Data output
    --      Provides the generated Gray codes.
    Q       : out   std_ulogic_vector(3 downto 0) := "0000";
    -- Wraparound indicator
    --      When high, indicates that the currently-presented Gray code is the
    --      first code after a wraparound event.
    WRAP    : out   std_ulogic := '0'
    );
end GrayGenerator4b;


architecture Impl of GrayGenerator4b is
    signal NextQ    : std_ulogic_vector(3 downto 0);
begin

    process(CLK)
    begin
    
        if rising_edge(CLK) and EN = '1' then
            Q <= NextQ;
            
            WRAP <= '1' when NextQ = "0000" else '0';
        end if;
    
    end process;
    
    with Q select NextQ <=
        "0001" when "0000",
        "0011" when "0001",
        "0010" when "0011",
        "0110" when "0010",
        "0111" when "0110",
        "0101" when "0111",
        "0100" when "0101",
        "1100" when "0100",
        "1101" when "1100",
        "1111" when "1101",
        "1110" when "1111",
        "1010" when "1110",
        "1011" when "1010",
        "1001" when "1011",
        "1000" when "1001",
        "0000" when "1000",
        "XXXX" when others;
end;
