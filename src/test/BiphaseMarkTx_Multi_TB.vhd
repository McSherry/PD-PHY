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


-- Tests that the BMC transmitter can perform multiple transmissions in the
-- manner expected.
--
-- Tests of basic functionality are in './BiphaseMarkTx_Single_TB.vhd'.
entity BiphaseMarkTx_Multi_TB is
    generic(runner_cfg  : string := runner_cfg_default);
end BiphaseMarkTx_Multi_TB;

architecture Impl of BiphaseMarkTx_Multi_TB is
    component BiphaseMarkTx port(
        CLK     : in    std_logic;
        D       : in    std_logic;
        WE      : in    std_logic;
        Q       : out   std_ulogic;
        OE      : out   std_ulogic
        );
    end component;
    
    -- Transmitter signals
    signal CLK, D, WE   : std_logic := '0';
    signal Q, OE        : std_ulogic;
    
    -- Test internal signals
    type State_t is (
        S_Startup,      -- Startup state
        S_FirstTx,      -- Run the first transmission
        S_SecondTx,     -- Run the second transmission
        S_Terminate     -- Terminate the test
        );
        
    signal State        : State_t := S_Startup;
    
    -- Output-capture registers
    signal RFirst       : std_logic_vector(0 to 13);
    signal RSecond      : std_logic_vector(0 to 13);
    
    -- Timing constants
    constant T          : time := 3.33 us;
begin
    test_runner_watchdog(runner, 200 us);
    
    
    -- Generates the stimulus for the BMC transmitter
    --
    -- The setup here is generally the same as for the single-transmission
    -- tests, except that the testbench now uses a state value to sequence
    -- the multiple processes rather than having them all run at once.
    stimulus: process
        constant Arg_First  : std_logic_vector(0 to 13) :=
            (
                --   D     WE       Cycle
                    "1" & "1" & --  0
                    "1" & "1" & --  1
                    "0" & "1" & --  2
                    "0" & "1" & --  3
                    "0" & "1" & --  4
                    "0" & "1" & --  5
                    "0" & "0"   --  6
            );
            
        constant Arg_Second : std_logic_vector(0 to 11) :=
            (
                --   D     WE       Cycle
                    "0" & "1" & --  n+0
                    "1" & "1" & --  n+1
                    "0" & "1" & --  n+2
                    "0" & "1" & --  n+3
                    "1" & "1" & --  n+4
                    "0" & "0"   --  n+5
            );
            
        variable Index  : integer;
    begin
        -- Test runner prerequisites
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        Index := 0;
        
        while Index < (Arg_First'length/2) loop
            wait until rising_edge(CLK);
            
            D   <= Arg_First((Index * 2) + 0);
            WE  <= Arg_First((Index * 2) + 1);
            
            Index := Index + 1;
        end loop;
        
        
        wait until State = S_SecondTx;
        Index := 0;
        
        while Index < (Arg_Second'length/2) loop
            wait until rising_edge(CLK);
            
            D   <= Arg_Second((Index * 2) + 0);
            WE  <= Arg_Second((Index * 2) + 1);
            
            Index := Index + 1;
        end loop;
        
        
        -- Once we've provided all our stimulus, we're basically done. All
        -- that remains is to indicate for the test runner to clean up.
        wait until State = S_Terminate;
        test_runner_cleanup(runner);
    end process;
    
    
    -- Captures the data produced by the transmitter for the first
    -- transmission.
    capture_1: process
        variable Index      : integer := 0;
    begin
        wait until State = S_FirstTx;
        -- The time between stimulus and output is indeterminate, so we wait
        -- for the transmitter to signal its output is enabled.
        wait until OE = '1';
        
        -- As in the single-transmission tests, we delay outside first so that
        -- mistiming at a signal edge doesn't result in a bounds violation from
        -- erroneous sampling of an extra value.
        wait for T/2;
        
        -- Output can change every half unit interval, so we capture data
        -- at twice the data clock rate.
        while OE = '1' loop            
            RFirst(Index)   <= Q;
            Index           := Index + 1;
            
            wait for T/2;
        end loop;
        
        -- We then have nothing to do.
        wait;
    end process;
    
    
    -- Captures data from the second transmission.
    capture_2: process
        variable Index      : integer := 0;
    begin
        wait until State = S_SecondTx;
        wait until OE = '1';
        
        wait for T/2;
        
        while OE = '1' loop
            RSecond(Index)  <= Q;
            Index           := Index + 1;
        
            wait for T/2;
        end loop;
        
        wait;
    end process;
    
    
    -- Compares the captured output against expected test vectors.
    compare: process
        constant Vec_First  : std_logic_vector(0 to 13) :=
            (
                "01" &  -- First bit (logic high, L->H)
                "01" &  -- Second bit (logic high, L->H)
                "00" &  -- Third bit (logic low, L)
                "11" &  -- Fourth bit (logic low, H)
                "00" &  -- Fifth bit (logic low, L)
                "11" &  -- Sixth bit (logic low, L)
                "00"    -- Hold low
            );
            
        constant Vec_Second : std_logic_vector(0 to 13) :=
            (
                "00" &  -- First bit (logic low, L)
                "10" &  -- Second bit (logic high, H->L)
                "11" &  -- Third bit (logic low, H)
                "00" &  -- Fourth bit (logic low, L)
                "10" &  -- Fifth bit (logic high, H->L)
                "11" &  -- Hold high
                "00"    -- Hold low
            );
    begin
        State <= S_FirstTx;
    
        -- In the first instance, we wait until stimulus starts and then
        -- until OE has been asserted then deasserted. This will ensure that
        -- output has ceased and so has all been captured.
        wait until State = S_FirstTx;
        wait until OE = '1';
        wait until OE = '0';
        
        check_equal(RFirst, Vec_First);
        
        State <= S_SecondTx;
        
        -- In the second instance, as we prompt the start of stimulus, we
        -- only wait for assertion then deassertion.
        wait until OE = '1';
        wait until OE = '0';
        
        check_equal(RSecond, Vec_Second);
        
        State <= S_Terminate;
        
        -- Once we've given the signal to terminate, do nothing.
        wait;
    end process;
    
    
    -- Transmitter data clock
    DCLK: process
    begin
        wait for T/2;
        CLK <= not CLK;
        
        if State = S_Terminate then
            wait;
        end if;
    end process;

    
    UUT: BiphaseMarkTx port map(
        CLK => CLK,
        D   => D,
        WE  => WE,
        Q   => Q,
        OE  => OE
        );
end;