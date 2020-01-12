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


-- Provides tests for the USB-PD 4b5b encoder.
entity Encoder4b5b_TB is
    generic(runner_cfg : string := runner_cfg_default);
end Encoder4b5b_TB;

architecture Impl of Encoder4b5b_TB is
    component Encoder4b5b port(
        CLK     : in    std_logic;
        WE      : in    std_logic;
        K       : in    std_logic;
        ARG     : in    std_logic_vector(3 downto 0);
        Q       : out   std_ulogic_vector(4 downto 0)
        );
    end component;
    
    -- Encoder signals
    signal CLK, WE, K   : std_logic := '0';
    signal ARG          : std_logic_vector(3 downto 0) := "0000";
    signal Q            : std_ulogic_vector(4 downto 0);
    
    -- Internal test signals
    signal Terminate    : std_logic := '0';
    
    -- Timing constants
    constant T          : time := 3.33 us;
begin
    -- 16 values, one cycle delay ---> 17 cycles
    test_runner_watchdog(runner, 57 us);
    
    
    -- Stimulus and capture/compare.
    test: process
        -- Test vector length in bits
        constant VL             : integer := 9;
    
        -- Test vectors for the 'raw data' case
        constant Vec_RawData    : std_logic_vector(0 to (16 * VL) - 1) :=
            (
                -- ARG    Q            Vector
                "0000" & "11110" &  -- 0
                "0001" & "01001" &  -- 1
                "0010" & "10100" &  -- 2
                "0011" & "10101" &  -- 3
                "0100" & "01010" &  -- 4
                "0101" & "01011" &  -- 5
                "0110" & "01110" &  -- 6
                "0111" & "01111" &  -- 7
                "1000" & "10010" &  -- 8
                "1001" & "10011" &  -- 9
                "1010" & "10110" &  -- 10
                "1011" & "10111" &  -- 11
                "1100" & "11010" &  -- 12
                "1101" & "11011" &  -- 13
                "1110" & "11100" &  -- 14
                "1111" & "11101"    -- 15
            );
            
        -- Test vectors for the K-code case
        constant Vec_Kcodes     : std_logic_vector(0 to (6 * VL) - 1) :=
            (
                -- ARG    Q            Vector
                "0000" & "11000" &  -- 0    Sync-1
                "0001" & "10001" &  -- 1    Sync-2
                "0010" & "00110" &  -- 2    Sync-3
                "0011" & "00111" &  -- 3    RST-1
                "0100" & "11001" &  -- 4    RST-2
                "0101" & "01101"    -- 5    EOP
            );
            
        variable Index          : integer := 0;
        variable NumCases       : integer;
    begin
        -- Test runner prerequisites
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
    
        while test_suite loop
        
            -- Tests that all the 'raw data' inputs produce the output
            -- given in USB-PD at s. 5.3.
            if run("data") then
                NumCases := Vec_RawData'length / VL;
            
                -- Indicate input is data and enable writing
                K   <= '0';
                WE  <= '1';
            
                while Index <= NumCases loop
                    -- Because there's a cycle delay between input and output,
                    -- we don't want to assign on the last cycle because we'll
                    -- produce a bounds violation.
                    ARG <= Vec_RawData((Index * VL) to (Index * VL) + 3)
                            when Index < NumCases;
                            
                    wait until rising_edge(CLK);
                    
                    -- Output will be invalid on the first cycle because there
                    -- will have been no starting input, so we delay our checks
                    -- by a cycle to match unit behaviour.
                    if Index /= 0 then
                        check_equal(
                            Q, Vec_RawData(((Index - 1) * VL) + 4 to ((Index - 1) * VL) + (VL - 1))
                            );
                    end if;
                        
                    Index := Index + 1;
                end loop;
                
                WE <= '0';
            
            
            -- Tests that all valid K-code inputs produce the expected
            -- outputs given in USB-PD at s. 5.3.
            elsif run("k_codes") then
                NumCases := Vec_Kcodes'length / VL;
            
                -- We're writing a K-code
                K   <= '1';
                WE  <= '1';
                
                while Index <= NumCases loop
                    ARG <= Vec_Kcodes((Index * VL) to (Index * VL) + 3)
                            when Index < NumCases;
                            
                    wait until rising_edge(CLK);                    
                    
                    if Index /= 0 then
                        check_equal(
                            Q, Vec_Kcodes(((Index - 1) * VL) + 4 to ((Index - 1) * VL) + (VL - 1))
                            );
                    end if;
                    
                    Index := Index + 1;
                end loop;
                
                WE <= '0';
            
            
            -- Tests that the expected output is still produced even if the
            -- write-enable signal goes low before it appears on Q.
            elsif run("clock_after_we_low") then
                wait until rising_edge(CLK);
            
                K   <= '0';
                WE  <= '1';
                ARG <= "1111";
                wait until rising_edge(CLK);
                
                WE  <= '0';
                wait until rising_edge(CLK);
                
                check_equal(to_string(Q), "11101");
                
                
            else
                assert false report "Invalid test case" severity failure;
            end if;
        
        end loop;
        
        Terminate <= '1';
        test_runner_cleanup(runner);
    end process;
    

    -- Data clock
    DCLK: process
    begin
        while Terminate /= '1' loop
            wait for T/2;
            CLK <= not CLK;
        end loop;
        
        wait;
    end process;


    UUT: Encoder4b5b port map(
        CLK => CLK,
        WE  => WE,
        K   => K,
        ARG => ARG,
        Q   => Q
        );
end;