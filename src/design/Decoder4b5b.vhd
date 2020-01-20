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
    signal SymData  : std_ulogic_vector(3 downto 0);
    signal SymK     : std_ulogic;
begin

    process(CLK)
    begin
        if rising_edge(CLK) and WE = '1' then
            Q <= SymData;
            K <= SymK;
        end if;
    end process;
    
    
    with ARG select SymData <=
        -- Raw data
        "0000" when "11110",
        "0001" when "01001",
        "0010" when "10100",
        "0011" when "10101",
        "0100" when "01010",
        "0101" when "01011",
        "0110" when "01110",
        "0111" when "01111",
        "1000" when "10010",
        "1001" when "10011",
        "1010" when "10110",
        "1011" when "10111",
        "1100" when "11010",
        "1101" when "11011",
        "1110" when "11100",
        "1111" when "11101",
        -- K codes
        "0000" when "11000",
        "0001" when "10001",
        "0010" when "00110",
        "0011" when "00111",
        "0100" when "11001",
        "0101" when "01101",
        "----" when others;
        
    with ARG select SymK <=
        '1' when "11000" | "10001" | "00110" | "00111" | "11001" | "01101",
        '0' when others;
    
end;
