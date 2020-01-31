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
entity PDEOPDetector_TB is
    generic(runner_cfg : string := runner_cfg_default);
end PDEOPDetector_TB;


architecture Impl of PDEOPDetector_TB is
    component PDEOPDetector port(
        CLK : in    std_logic;
        EN  : in    std_logic;
        D   : in    std_logic_vector(4 downto 0);
        RST : in    std_logic;
        DET : out   std_ulogic
        );
    end component;
        
    -- Detector signals
    signal CLK, EN, RST : std_ulogic := '0';
    signal D            : std_ulogic_vector(4 downto 0) := (others => '0');
    signal DET          : std_ulogic;
    
    -- Data constants
    constant D_07h      : std_ulogic_vector(4 downto 0) := "01111";
    constant D_0Ah      : std_ulogic_vector(4 downto 0) := "10110";
    
    -- K-code constants
    constant K_SYNC1    : std_ulogic_vector(4 downto 0) := "11000";
    constant K_SYNC2    : std_ulogic_vector(4 downto 0) := "10001";
    constant K_RST1     : std_ulogic_vector(4 downto 0) := "00111";
    constant K_RST2     : std_ulogic_vector(4 downto 0) := "11001";
    constant K_EOP      : std_ulogic_vector(4 downto 0) := "01101";
    constant K_SYNC3    : std_ulogic_vector(4 downto 0) := "00110";
    
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
            -- First, we'll just test it on its own
            D   <= K_EOP;
            EN  <= '1';
            wait until rising_edge(CLK);
            EN  <= '0';
            wait until rising_edge(CLK);
            
            check_equal(DET, '1', "Alone, triggered");
            
            RST <= '1';
            
            check_equal(DET, '0', "Alone, reset");
            
            
            -- And then we'll put some data in before it
            EN  <= '1';
            D   <= K_RST1;
            wait until rising_edge(CLK);
            check_equal(DET, '0', "Prefixed, 1");
            wait until rising_edge(CLK);
            check_equal(DET, '0', "Prefixed, 2");
            D   <= K_EOP;
            wait until rising_edge(CLK);
            EN  <= '0';
            check_equal(DET, '0', "Prefixed, 3");
            wait until rising_edge(CLK);
            check_equal(DET, '1', "Prefixed, 4");
            
        
        -- If we present the full 'Hard_Reset' ordered set as the first
        -- thing to the detector, the detected signal should be asserted
        --
        -- But 'Hard_Reset' signalling which follows some other data
        -- shouldn't produce a signal. We'll conveniently ignore that this
        -- is invalid, and leave that to someone higher up the stack.
        elsif run("orderedset_hard_reset") or run("prefixed_hard_reset") then
            -- If we're prefixing data, it's as simple here as clocking
            -- in some data before the ordered set.
            if running_test_case = "prefixed_hard_reset" then
                EN  <= '1';
                D   <= D_0Ah;
                wait until rising_edge(CLK);
            end if;
            
            -- 'Hard_Reset' is three RST-1s followed by a RST-2.
            EN  <= '1';
            D   <= K_RST1;
            wait until rising_edge(CLK);
            wait until rising_edge(CLK);
            wait until rising_edge(CLK);
            
            D   <= K_RST2;
            wait until rising_edge(CLK);
            EN  <= '0';
            wait until rising_edge(CLK);
            
            if running_test_case = "orderedset_hard_reset" then
                check_equal(DET, '1', "Detection");
            elsif running_test_case = "prefixed_hard_reset" then
                check_equal(DET, '0', "Detection");
            else
                assert false;
            end if;
            
        -- The same is true for the 'Cable_Reset' ordered set
        elsif run("orderedset_cable_reset") then
            if running_test_case = "prefixed_cable_reset" then
                EN  <= '1';
                D   <= D_07h;
                wait until rising_edge(CLK);
            end if;
            
            -- 'Cable_Reset' is RST-1, Sync-1, RST-1, Sync-3
            EN  <= '1';
            D   <= K_RST1;
            wait until rising_edge(CLK);
            D   <= K_SYNC1;
            wait until rising_edge(CLK);
            D   <= K_RST1;
            wait until rising_edge(CLK);
            D   <= K_SYNC3;
            wait until rising_edge(CLK);
            EN  <= '0';
            wait until rising_edge(CLK);
            
            if running_test_case = "orderedset_cable_reset" then
                check_equal(DET, '1', "Detection");
            elsif running_test_case = "prefixed_cable_reset" then
                check_equal(DET, '0', "Detection");
            else
                assert false;
            end if;
                
        -- Similarly, an incomplete (3 of 4 K-codes) ordered set should
        -- produce a detection
        elsif run("incomplete_hard_reset") then
            assert false;
            
        -- Ditto
        elsif run("incomplete_cable_reset") then
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
end;