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


-- Provides test for the USB-PD CRC engine.
entity PDCRCEngine_TB is
    generic(runner_cfg : string := runner_cfg_default);
end PDCRCEngine_TB;


architecture Impl of PDCRCEngine_TB is
    component PDEOPDetector port(
        CLK : in    std_logic;
        EN  : in    std_logic;
        D   : in    std_logic_vector(4 downto 0);
        RST : in    std_logic;
        DET : out   std_ulogic
        );
        
    -- Detector signals
    signal CLK, EN, RST : std_ulogic := '0';
    signal D            : std_ulogic_vector(4 downto 0) := (others => '0');
    signal DET          : std_ulogic;
    
    -- Timing constants
    constant T  : time := 10 ns;
begin
    test_runner_watchdog(runner, 10 * T);
    
    
    -- Test stimulus generation and output capture/comparison
    stimulus: process
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        
        -- The detection signal should always start at zero
        check_equal(DET, '0', "Initial: DET");
        
        -- If we present the 'EOP' K-code, the detected signal should
        -- always be asserted
        if run("kcode_eop") then
            assert false;
        
        -- If we present the full 'Hard_Reset' ordered set as the first
        -- thing to the detector, the detected signal should be asserted
        elsif run("orderedset_hard_reset") then
            assert false;
            
        -- The same is true for the 'Cable_Reset' ordered set
        elsif run("orderedset_cable_reset") then
            assert false;
            
        -- Similarly, an incomplete (3 of 4 K-codes) ordered set should
        -- produce a detection
        elsif run("incomplete_hard_reset") then
            assert false;
            
        -- Ditto
        elsif run("incomplete_cable_reset") then
            assert false;
            
        -- But 'Hard_Reset' signalling which follows some other data
        -- shouldn't produce a signal. We'll conveniently ignore that this
        -- is invalid, and leave that to someone higher up the stack.
        elsif run("prefixed_hard_reset") then
            assert false;
            
        -- Ditto again
        elsif run("prefixed_cable_reset") then
            assert false;
            
        end if;
        
        test_runner_cleanup(runner);
    end process;
    

    -- Master clock generation process
    MCLK: process
    begin
        wait for T/2;
        CLK <= not CLK;
    end process;
    
    UUT: PDEOPDetector port map(
        CLK => CLK,
        EN  => EN,
        D   => D,
        RST => RST,
        DET => DET
        );
end