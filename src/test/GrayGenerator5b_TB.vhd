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


-- Provides tests for the 4-bit Gray code generator.
entity GrayGenerator5b_TB is
    generic(runner_cfg : string := runner_cfg_default);
end GrayGenerator5b_TB;

architecture Impl of GrayGenerator5b_TB is
    component GrayGenerator5b port(
        CLK     : in    std_logic;
        EN      : in    std_logic;
        RST     : in    std_logic;
        Q       : out   std_ulogic_vector(4 downto 0)
        );
    end component;
    
    -- Generator signals
    signal CLK, EN, RST : std_logic := '0';
    signal Q            : std_ulogic_vector(4 downto 0);
    signal WRAP         : std_ulogic;
    
    -- Timing constants
    constant T      : time := 1 us;
begin
    test_runner_watchdog(runner, 60 * T);
    
    
    -- Main test process
    stim: process
        variable QHeld, XorQ    : std_ulogic_vector(4 downto 0);
        variable Cycle          : integer := 0;
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        while test_suite loop
            -- Tests the basic functionality of the generator, except the reset
            -- logic (which has its own tests, prefixed 'reset_').
            if run("basic") then
                -- If we don't enable the generator, its output shouldn't change.
                EN  <= '0';
                QHeld := Q;
                wait until rising_edge(CLK);
                
                check_equal(Q, QHeld, "Static when disabled");
                
                -- As it's a five-bit generator, we should then be able to monitor 
                -- 32 outputs where the change between each is one bit.
                EN  <= '1';
                wait until rising_edge(CLK);
                
                while Cycle < 31 loop
                    wait until rising_edge(CLK);
                    
                    -- For a Gray code, only one bit should change each cycle. If we
                    -- check for inequalities (i.e. XOR), then, we should only ever
                    -- have one output that is true.
                    XorQ := (
                        (QHeld(4) xor Q(4)) &
                        (QHeld(3) xor Q(3)) & (QHeld(2) xor Q(2)) &
                        (QHeld(1) xor Q(1)) & (QHeld(0) xor Q(0))
                        );
                    
                    check_one_hot(XorQ);
                    
                    -- We're using this Gray code generator in producing 4-bit
                    -- addresses. This means that, while we produce 32 codes,
                    -- actually producing 16 addresses twice. As described by
                    -- Cummings, we should be able to XOR the two MSBs to
                    -- give the addresses we want. We should therefore produce
                    -- a low XOR-out for the first halves of each 16, and a
                    -- high XOR-out for the second halves.
                    if (Cycle < 7) or (Cycle >= 15 and Cycle < 23) then
                        check_equal(Q(4) xor Q(3), '0', "MSB check, low");
                    else
                        check_equal(Q(4) xor Q(3), '1', "MSB check, high ");
                    end if;
                    
                    QHeld := Q;
                    Cycle := Cycle + 1;
                end loop;
                
            
            -- Tests that the Gray code generator behaves as expected when it
            -- is reset in the middle of its sequence.
            elsif run("reset_midsequence") then
                -- Begin generating
                EN  <= '1';
                
                -- We wait seven cycles, but the number is arbitrary.
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                
                -- When we reset, output should be held low until we release
                -- the reset and should occur even when disabled
                EN  <= '0';
                RST <= '1';
                wait until rising_edge(CLK);
                
                RST <= '0';
                -- Wait for it to propagate
                wait until rising_edge(CLK);
                
                check_equal(Q, std_ulogic_vector'("00000"), "Held: Q");
                
                EN  <= '1';
                RST <= '0';
                wait until rising_edge(CLK);
                wait until rising_edge(CLK);
                
                check_equal(Q, std_ulogic_vector'("00001"), "Reset: Q");
                
            
            -- Tests that asserting the reset such that it is processed when
            -- the WRAP signal should be asserted produces the desired output.
            elsif run("reset_on_wrap") then
                EN <= '1';
            
                -- Because of the 1-cycle delay in input being processed, we
                -- wait for 30 cycles before asserting reset.
                while Cycle < 29 loop
                    wait until rising_edge(CLK);
                    Cycle := Cycle + 1;
                end loop;
                
                -- Asserting the reset and then waiting for the delay to pass
                -- should give us held-low output without a WRAP signal.
                RST <= '1';
                wait until rising_edge(CLK);
                RST <= '0';
                wait until rising_edge(CLK);
                
                check_equal(Q, std_ulogic_vector'("00000"));
            end if;
        end loop;
        
        
        test_runner_cleanup(runner);
    end process;
    
    
    -- Clock generation process
    DCLK: process
    begin
        wait for T/2;
        CLK <= not CLK;
    end process;


    UUT: GrayGenerator5b port map(
        CLK     => CLK,
        EN      => EN,
        RST     => RST,
        Q       => Q
        );
end;