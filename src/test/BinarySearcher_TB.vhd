-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;


-- Provides test for the USB-PD preamble generator.
entity BinarySearcher_TB is
    generic(runner_cfg : string := runner_cfg_default);
end BinarySearcher_TB;


architecture Impl of BinarySearcher_TB is
    component BinarySearcher port(
        CLK : in    std_logic;
        TRG : in    std_logic;
        CMP : in    std_logic;
        RST : in    std_logic;
        Q   : out   std_ulogic_vector(6 downto 0);
        RDY : out   std_ulogic
        );
    end component;
    
    -- Searcher signals
    signal CLK, TRG, CMP, RST, RDY  : std_ulogic := '0';
    signal Q                        : std_ulogic_vector(6 downto 0);
    
    -- Internal test signals
    
    -- Timing constants
    constant T      : time := 10 ns;
begin
    test_runner_watchdog(runner, 16 * T);


    -- Generates stimulus for the UUT and captures/compares output
    stimulus: process
        variable Target     : real;
        variable Expected   : std_ulogic_vector(6 downto 0);
    begin
        -- Test runner prerequisites
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        -- An integer value, which the block should be able to match exactly.
        if run("exact_match") then
            Target := 29.0;
            
        -- A target which should match on the first check
        elsif run("match_on_msb") then
            Target := 64.0;
        
        -- A target where the output won't be a precise match, here because
        -- of a fractional part
        elsif run("inexact_match") then
            Target := 96.4;
            
        -- A target of the maximum value the output can represent, which should
        -- produce an all-ones output
        elsif run("all_ones") then
            Target := 127.0;
            
        elsif run("all_but_lsb") then
            Target := 126.0;
        
        -- The same as above, but at the lowest value
        elsif run("all_zeroes") then
            Target := 0.0;
            
        elsif run("none_but_msb") then
            Target := 1.0;
        
        end if;
        
        Expected := std_logic_vector(to_unsigned(integer(Target), Q'length));
        
        -- The searcher should start at mid-scale and shouldn't be ready
        check_equal(Q, std_ulogic_vector'("1000000"),   "Initial: Q");
        check_equal(RDY, '0',                           "Initial: RDY");
        
        while RDY /= '1' loop
            TRG <= '1';
            CMP <= '1' when Target < real(to_integer(unsigned(Q))) else '0';
            wait until rising_edge(CLK);
            
            -- We need to insert a cycle's delay. If we don't, the cycle between
            -- input being clocked in and output being clocked out will mean that
            -- a stale 'CMP' will be presented, which will produce incorrect
            -- comparisons.
            TRG <= '0';
            wait until rising_edge(CLK);
        end loop;
        
        check_equal(Q, Expected,    "Refined: Q");
        
        -- And we should return to the initial state when reset
        RST <= '1';
        wait until rising_edge(CLK);
        
        check_equal(Q, std_ulogic_vector'("1000000"),   "Reset: Q");
        check_equal(RDY, '0',                           "Reset: RDY");
        
        
        test_runner_cleanup(runner);
    end process;


    -- Provides the master clock for the searcher
    MCLK: process
    begin
        CLK <= not CLK;
        wait for T/2;
    end process;
    
    UUT: BinarySearcher port map(
        CLK => CLK,
        TRG => TRG,
        CMP => CMP,
        RST => RST,
        Q   => Q,
        RDY => RDY
        );

end;