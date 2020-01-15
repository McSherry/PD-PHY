-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- Provides two flip-flops to be used to synchronise a specified-width signal.
--
-- Note that, where more than a single bit is synchronised, further steps are
-- necessary to ensure correct synchronisation (such as Gray coding).
entity CD2FF is
    generic(
        -- The width of the flip-flop array, in bits.
        W       : positive := 1;
        -- The default state of the output flip-flops.
        DEFAULT : std_ulogic_vector((W - 1) downto 0) := (others => '0')
    );
    port(
        -- Clock
        --      The clock for the clock domain to which input signal [D] is to
        --      be synchronised.
        CLK     : in    std_logic;
        -- Data input
        --      The data input synchronised to a clock unrelated to [CLK].
        D       : in    std_logic_vector((W - 1) downto 0);
        
        -- Data output
        --      The data output, which reflects the input data but is
        --      synchronised to [CLK].
        Q       : out   std_ulogic_vector((W - 1) downto 0) := DEFAULT
        );
end CD2FF;


architecture Impl of CD2FF is
    signal FF_Intermed  : std_ulogic_vector((W - 1) downto 0) := DEFAULT;
begin

    process(CLK)
    begin
        if rising_edge(CLK) then
            FF_Intermed <= D;
            Q           <= FF_Intermed;
        end if;
    end process;
    
end;