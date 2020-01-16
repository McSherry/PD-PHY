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
entity GrayGenerator4b_TB is
    generic(runner_cfg : string := runner_cfg_default);
end GrayGenerator4b_TB;

architecture Impl of GrayGenerator4b_TB is
    component GrayGenerator4b port(
        CLK     : in    std_logic;
        EN      : in    std_logic;
        Q       : out   std_ulogic_vector(3 downto 0);
        WRAP    : out   std_ulogic
        );
    end component;
    
    -- Generator signals
    signal CLK, EN  : std_logic := '0';
    signal Q        : std_ulogic_vector(3 downto 0);
    signal WRAP     : std_ulogic;
    
    -- Timing constants
    constant T      : time := 1 us;
begin
    test_runner_watchdog(runner, 30 * T);
    
    
    -- Main test process
    stim: process
        variable QHeld, XorQ    : std_ulogic_vector(3 downto 0);
        variable Cycle          : integer := 0;
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        
        -- If we don't enable the generator, its output shouldn't change.
        EN  <= '0';
        QHeld := Q;
        wait until rising_edge(CLK);
        
        check_equal(Q, QHeld, "Static when disabled");
        
        -- As it's a four-bit generator, we should then be able to monitor 
        -- sixteen outputs where the change between each is one bit.
        EN  <= '1';
        wait until rising_edge(CLK);
        
        while Cycle < 15 loop
            wait until rising_edge(CLK);
            
            -- For a Gray code, only one bit should change each cycle. If we
            -- check for inequalities (i.e. XOR), then, we should only ever
            -- have one output that is true.
            XorQ := (
                (QHeld(3) xor Q(3)) & (QHeld(2) xor Q(2)) &
                (QHeld(1) xor Q(1)) & (QHeld(0) xor Q(0))
                );
            
            check_one_hot(XorQ);
            
            QHeld := Q;
            Cycle := Cycle + 1;
        end loop;
        
        
        -- After we've gone through all possible values, the WRAP indicator
        -- should continue to be asserted until we enable the next transition.
        EN <= '0';
        
        wait until rising_edge(CLK);
        
        check_equal(WRAP, '1', "Post-1: WRAP");
        
        -- Change in 'EN' registered after one cycle delay
        wait until rising_edge(CLK);
        
        check_equal(WRAP, '1', "Post-2: WRAP");
        
        
        -- And, on the next transition, 'WRAP' should be deasserted.
        EN  <= '1';
        wait until rising_edge(CLK);
        
        -- Wait for the change to propagate
        wait until rising_edge(CLK);
        
        check_equal(WRAP, '0', "Post-3: WRAP");
        
        
        test_runner_cleanup(runner);
    end process;
    
    
    -- Clock generation process
    DCLK: process
    begin
        wait for T/2;
        CLK <= not CLK;
    end process;


    UUT: GrayGenerator4b port map(
        CLK     => CLK,
        EN      => EN,
        Q       => Q,
        WRAP    => WRAP
        );
end;