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
    -- CRC32 polynomial
    constant POLY : std_ulogic_vector(31 downto 0) := x"04C11DB7";
    
    -- CRC32 initial
    constant INIT : std_ulogic_vector(31 downto 0) := x"FFFFFFFF";

    -- The final CRC transmitted with a USB-PD packet is rearranged from the
    -- value a CRC generator will provide. We use this as our working register
    -- and perform the rearranging when attaching to the output.
    signal CRC_REG : std_ulogic_vector(31 downto 0) := INIT;
    signal nCRC_REG : std_ulogic_vector(31 downto 0) := not CRC_REG;
begin
    process(CLK, RST)
        variable CURRENT_BIT : std_ulogic;
    begin
        if RST = '1' then
            CRC_REG <= INIT;
            
        elsif rising_edge(CLK) and WE = '1' then
            CURRENT_BIT := D xor CRC_REG(31);
        
            -- First bit in the shift register is a special case because of
            -- the loop from the end
            CRC_REG(0) <= CURRENT_BIT;
            
            -- The remaining bits follow a standard pattern
            Gen_CRC_ShiftRegister: for i in 1 to 31 loop
                CRC_REG(i) <= CRC_REG(i - 1) when POLY(i) = '0' else CRC_REG(i - 1) xor CURRENT_BIT;
            end loop;
        end if;
    end process;
    
    -- Invert
    nCRC_REG <= not CRC_REG;
    
    -- And swap
    Gen_Swapper: for i in 0 to Q'left generate
        Q(Q'left - i) <= nCRC_REG(i);
    end generate Gen_Swapper;
end;