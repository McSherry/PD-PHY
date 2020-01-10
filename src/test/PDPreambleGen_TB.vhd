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
entity PDPreambleGen_TB is
    generic(runner_cfg : string := runner_cfg_default);
end PDPreambleGen_TB;


architecture Impl of PDPreambleGen_TB is
    component PDPreambleGen port(
        CLK     : in    std_logic;
        TRIG    : in    std_logic;
        Q       : out   std_ulogic;
        FIN     : out   std_ulogic
        );
    end component;

    -- Generator signals
    signal CLK, TRIG    :   std_logic := '0';
    signal Q, FIN       :   std_ulogic;

    -- Internal test signals
    signal Cycle        : integer := 0;
    constant Cycle_Max  : integer := 65;
    
    -- Timing constants
    constant T          : time := 3.33 us;
begin
    test_runner_watchdog(runner, 220 us);
    
    
    -- UUT stimulus generation
    stimulus: process
    begin
        -- Test runner prerequisites
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        
        -- Wait an empty cycle before we start. May help in verifying the
        -- initial state in a waveform viewer.
        wait until rising_edge(CLK);
        
        -- Then begin the test by triggering the preamble generator.
        TRIG <= '1';
        wait until rising_edge(CLK);
        
        -- Subsequent input depends on the test case
        while test_suite loop
            
            -- In the basic case, we pulse the trigger and that's it.
            if run("basic") then
                null;
            
            -- We might alternatively hold it high for multiple cycles, which
            -- shouldn't cause any issues.
            elsif run("long_trigger") then
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                
            -- Or we might continually alternate it.
            elsif run("alternating_trigger") then
                while Cycle < (Cycle_Max - 1) loop
                    TRIG <= not TRIG;
                    wait until rising_edge(CLK);
                end loop;
                
            else
                assert false report "Invalid test case" severity failure;
            end if;
        end loop;
        
        TRIG <= '0';
        
        -- Once we've provided stimulus, wait for the full preamble to be
        -- generated before we clean up.
        wait until Cycle = Cycle_Max;
        test_runner_cleanup(runner);
    end process;
    
    
    -- UUT output capture and verification
    capture_verify: process
    begin
        wait until TRIG = '1';
        
        -- The output we expect is very simple: every 'even' cycle (where 0 is
        -- counted as even) should output low, and every 'odd' cycle should
        -- output high.
        --
        -- Additionally, in the final cycle, we should see FIN asserted.
        --
        -- We check all but the last cycle in a loop.
        while Cycle < (Cycle_Max - 1) loop
            if (Cycle mod 2) = 0 then
                check_equal(Q, '0');
            else
                check_equal(Q, '1');
            end if;
                
            check_equal(FIN, '0');
            
            wait until rising_edge(CLK);
        end loop;
        
        -- We then manually verify the last cycle with output.
        check_equal(Q, '0');
        check_equal(FIN, '1');
        wait until rising_edge(CLK);
        
        -- And check for deassertion afterwards.
        check_equal(FIN, '0');
        
        wait;
    end process;


    -- Data clock generation
    DCLK: process
    begin
        while Cycle < Cycle_Max loop
            wait for T/2;
            CLK <= not CLK;
            
            if CLK = '0' then
                Cycle <= Cycle + 1;
            end if;
        end loop;
        
        wait;
    end process;


    UUT: PDPreambleGen port map(
        CLK  => CLK,
        TRIG => TRIG,
        Q    => Q,
        FIN  => FIN
        );
end;
