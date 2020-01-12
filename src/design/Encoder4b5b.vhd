-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides an encoder which translates raw data or USB-PD control signals to
-- a form permitted to be transmitted on the line.
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
    -- Lines providing encodings for both data and K-codes. We determine
    -- both simultaneously and simply mux them on each clock.
    signal SymData, SymK    : std_logic_vector(4 downto 0);
begin
    mux: process(CLK)
    begin
        if rising_edge(CLK) and WE = '1' then
            Q <= SymData when K = '0' else SymK;
        end if;
    end process;
    
    
    with ARG select SymData <=
        "11110" when "0000",    -- 00h
        "01001" when "0001",    -- 01h
        "10100" when "0010",    -- 02h
        "10101" when "0011",    -- 03h
        "01010" when "0100",    -- 04h
        "01011" when "0101",    -- 05h
        "01110" when "0110",    -- 06h
        "01111" when "0111",    -- 07h
        "10010" when "1000",    -- 08h
        "10011" when "1001",    -- 09h
        "10110" when "1010",    -- 0Ah
        "10111" when "1011",    -- 0Bh
        "11010" when "1100",    -- 0Ch
        "11011" when "1101",    -- 0Dh
        "11100" when "1110",    -- 0Eh
        "11101" when "1111",    -- 0Fh
        -- This shouldn't be necessary here as we've enumerated all possible
        -- values, but GHDL is only pleased when it's included.
        "-----" when others;
        
    with ARG select SymK <=
        "11000" when "0000",    -- Sync-1
        "10001" when "0001",    -- Sync-2
        "00110" when "0010",    -- Sync-3
        "00111" when "0011",    -- RST-1
        "11001" when "0100",    -- RST-2
        "01101" when "0101",    -- EOP
        "-----" when others;
end;