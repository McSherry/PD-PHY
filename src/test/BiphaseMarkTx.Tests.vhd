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


entity BiphaseMarkTx_TB is
    generic(runner_cfg : string := runner_cfg_default);
end BiphaseMarkTx_TB;


architecture Impl of BiphaseMarkTx_TB is
    component BiphaseMarkTx port(
        CLK     : in    std_logic;
        D       : in    std_logic;
        WE      : in    std_logic;
        Q       : out   std_logic;
        OE      : out   std_logic
        );
    end component;
    
    -- Transmitter signals
    signal CLK, D, WE   : std_logic := '0';
    signal Q, OE        : std_logic;
    
    -- Test internal signals variables
    signal CapCLK       : std_logic := '0';
    signal Terminate    : std_logic := '0';
    signal Cycle        : integer := 0;
    -- Register to hold captured data
    --      As BMC may produce multiple transitions per bit,
    --      we need more register locations than bits
    signal R            : std_logic_vector(0 to 11);
    
    -- Timing constants
    constant T  : time := 3.33 us;
    
begin    
    process
        -- Arguments to produce the test waveform from figure B2, which
        -- is the transmission of the sequence "10"
        constant Arg_TX_10  : std_logic_vector(0 to 5) :=
            (
                --   D     WE       Cycle
                    "1" & "1" & --  0
                    "0" & "1" & --  1
                    "0" & "0"   --  2

            );
        -- Similarly, arguments for the waveform from B3, transmitting "11"
        constant Arg_TX_11  : std_logic_vector(0 to 5) :=
            (
                --   D     WE       Cycle
                    "1" & "1" & --  0
                    "1" & "1" & --  1
                    "0" & "0"   --  2
            );
            
        variable Args       : std_logic_vector(0 to 5);
        
        
        -- Arguments to produce the inversion of the waveform in figure 3,
        -- which is for the sequence "01101"
        constant Arg_TX_01101   : std_logic_vector(0 to 11) :=
            (
                --   D     WE       Cycle
                    "0" & "1" & --  0
                    "1" & "1" & --  1
                    "1" & "1" & --  2
                    "0" & "1" & --  3
                    "1" & "1" & --  4
                    "0" & "0"
            );
    begin
        test_runner_setup(runner, runner_cfg);
        
        while test_suite loop
            
            -- Test waveforms, transmitting "10" and "11"
            --
            -- This provides a general functional test but also verifies that
            -- the transmitter ends a transmission correctly (i.e. holds the
            -- line at the appropriate value) in both possible ways.
            if run("TX_10") or run("TX_11") then
                Args := Arg_TX_10 when running_test_case = "TX_10"
                                  else Arg_TX_11;
                
                -- Write the test argumentss on each cycle
                while Cycle < 3 loop
                    wait until rising_edge(CLK);
                
                    case Cycle is
                        when 0 | 1 | 2 =>
                            D   <= Args((Cycle * 2) + 0);
                            WE  <= Args((Cycle * 2) + 1);
                            
                        when others =>
                            null;
                    end case;
                    
                    Cycle <= Cycle + 1;
                end loop;
            
            
            -- Test waveform transmitting "01101", which should be the
            -- inversion of report figure 3.
            --
            -- This primarily verifies that the transmitter produces output
            -- of either 'sign' as appropriate. As BMC doesn't rely on the
            -- absolute state of the line but the presence or absence of a
            -- transition, logic low can be line-high or line-low. Similarly,
            -- logic high can have a high-to-low or low-to-high transition.
            elsif run("TX_01101") then
                while Cycle < 6 loop
                    wait until rising_edge(CLK);
                    
                    case Cycle is
                        when 0 | 1 | 2 | 3 | 4 | 5 =>
                            D   <= Arg_TX_01101((Cycle * 2) + 0);
                            WE  <= Arg_TX_01101((Cycle * 2) + 1);
                            
                        when others =>
                            null;
                    end case;
                    
                    Cycle <= Cycle + 1;
                end loop;
            end if;
            
            
            -- As the transmitter is specified with indeterminate delay
            -- between input and output, we rely on its OE signal to determine
            -- when it starts and finishes. In these tests, deassertion of OE
            -- triggers a comparison against registered output.
            --
            -- To prevent simulation ending early, we wait for the comparison
            -- to indicate that it has completed.
            wait until Terminate = '1';
            
        end loop;
        
        test_runner_cleanup(runner);
    end process;
    
        
    -- Transmitter data clock
    DCLK: process
    begin
        if (Terminate /= '1') then
            wait for T/2;
            CLK <= not CLK;
        end if;
    end process;
    
    
    -- Test capture clock
    --      Double the frequency of the data clock, as this is the
    --      frequency of the BMC data we're looking for
    CCLK: process
    begin
        if (Terminate /= '1') then
            wait for T/4;
            CapCLK <= not CapCLK;
        end if;
    end process;
    
    
    -- Logic responsible for capturing output from the UUT into a
    -- register and comparing it with the ressults we expect, for the
    -- test cases which cover full transactions.
    capture_compare: process(CapCLK, OE)
        -- Current index into the register
        variable Index  : integer := 0;
        
        -- Test vectors
        constant Vec_TX_10  : std_logic_vector(0 to 7) :=
            (
                "01" &  -- first bit (high)
                "00" &  -- second bit (low)
                "11" &  -- hold line high
                "00"    -- hold line low
            );
            
        constant Vec_TX_11  : std_logic_vector(0 to 5) :=
            (
                "01" &  -- first bit (high)
                "01" &  -- second bit (high)
                "00"    -- hold line low
            );
            
        constant Vec_TX_01101   : std_logic_vector(0 to 11) :=
            (
                "00" &  -- first bit (logic low, line low)
                "10" &  -- second bit (logic high, H->L)
                "10" &  -- third bit (logic high, H->L)
                "11" &  -- fourth bit (logic low, line high)
                "01" &  -- fifth bit (logic high, L->H)
                "00"    -- hold line low
            );
    begin    
        -- We shouldn't produce more output than the register can hold
        check(Index <= (R'length - 1), 
            "Register overflow (may indicate OE never deasserted)");
    
        -- Capture Q on every clock where OE is high, as that is
        -- the only time output can be valid
        if rising_edge(CapCLK) and OE = '1' then
            R(Index) <= Q;
            Index := Index + 1;
        end if;
        
        -- If OE goes low after producing output, we want to compare
        -- against the output we expect.
        if (Index /= 0) and OE = '0' then
            
            -- See report figure B2
            if running_test_case = "TX_10" then
                check(R(0 to 7) = Vec_TX_10(0 to 7),
                    "Expected " & to_string(Vec_TX_10) &
                    "; Got " & to_string(R(0 to 7))
                    );
                    
            -- See report figure B3
            elsif running_test_case = "TX_11" then
                check(R(0 to 5) = Vec_TX_11(0 to 5),
                    "Expected " & to_string(Vec_TX_11) &
                    "; Got " & to_string(R(0 to 5))
                    );
                        
            
            -- See the inversion of report figure 3
            elsif running_test_case = "TX_01101" then
                check(R(0 to 11) = Vec_TX_01101(0 to 11),
                    "Expected " & to_string(Vec_TX_01101) &
                    "; Got " & to_string(R(0 to 11))
                    );
                        
            else
                check(false, "Test with no results check");
            end if;
            
            Terminate <= '1';
            
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
