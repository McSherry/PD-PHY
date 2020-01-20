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


-- Provides tests for the USB-PD 4b5b encoder and decoder.
entity LineCode4b5b_TB is
    generic(runner_cfg : string := runner_cfg_default);
end LineCode4b5b_TB;

architecture Impl of LineCode4b5b_TB is
    component Encoder4b5b port(
        CLK     : in    std_logic;
        WE      : in    std_logic;
        K       : in    std_logic;
        ARG     : in    std_logic_vector(3 downto 0);
        Q       : out   std_ulogic_vector(4 downto 0)
        );
    end component;
    
    component Decoder4b5b port(
        CLK     : in    std_logic;
        WE      : in    std_logic;
        ARG     : in    std_logic_vector(4 downto 0);
        Q       : out   std_ulogic_vector(3 downto 0);
        K       : out   std_ulogic
        );
    end component;
    
    -- Common signals
    signal CLK          : std_logic := '0';
    
    -- Encoder signals
    signal E_WE, E_K    : std_logic := '0';
    signal E_ARG        : std_logic_vector(3 downto 0) := "0000";
    signal E_Q          : std_ulogic_vector(4 downto 0);
    
    -- Decoder signals
    signal D_WE         : std_logic := '0';
    signal D_ARG        : std_logic_vector(4 downto 0) := "00000";
    signal D_Q          : std_ulogic_vector(3 downto 0);
    signal D_K          : std_ulogic;
    
    -- Internal test signals
    signal Terminate    : std_logic := '0';
    
    -- Timing constants
    constant T          : time := 3.33 us;
begin
    -- 16 values, one cycle delay each ---> 32 cycles
    test_runner_watchdog(runner, 33 * T);
    
    
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
        variable Uncoded        : std_logic_vector(3 downto 0);
        variable ExpCoded       : std_ulogic_vector(4 downto 0);
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
                E_K     <= '0';
                E_WE    <= '1';
                D_WE    <= '1';
            
                while Index < NumCases loop                
                    Uncoded := Vec_RawData((Index * VL) to (Index * VL) + 3);
                    ExpCoded := Vec_RawData((Index * VL) + 4 to (Index * VL) + (VL - 1));
                
                    E_ARG <= Uncoded;
                    D_ARG <= ExpCoded;

                    -- One cycle to register input, one to produce output
                    wait until rising_edge(CLK);                    
                    wait until rising_edge(CLK);
                                    
                    check_equal(E_Q, ExpCoded, "Item " & to_string(Index) & ", encoding");
                    check_equal(D_Q, Uncoded, "Item " & to_string(Index) & ", decoding: Q");
                    check_equal(D_K, '0', "Item " & to_string(Index) & ", decoding: K");
                        
                    Index := Index + 1;
                end loop;
                
                E_WE <= '0';
                D_WE <= '0';
            
            
            -- Tests that all valid K-code inputs produce the expected
            -- outputs given in USB-PD at s. 5.3.
            elsif run("k_codes") then
                NumCases := Vec_Kcodes'length / VL;
            
                -- We're writing a K-code
                E_K     <= '1';
                E_WE    <= '1';
                D_WE    <= '1';
                
                while Index < NumCases loop
                    Uncoded := Vec_Kcodes((Index * VL) to (Index * VL) + 3);
                    ExpCoded := Vec_Kcodes((Index * VL) + 4 to (Index * VL) + (VL - 1));
                    
                    E_ARG <= Uncoded;
                    D_ARG <= ExpCoded;
                            
                    wait until rising_edge(CLK);
                    wait until rising_edge(CLK);
                    
                    check_equal(E_Q, ExpCoded, "Item " & to_string(Index) & ", encoding");
                    check_equal(D_Q, Uncoded, "Item " & to_string(Index) & ", decoding: Q");
                    check_equal(D_K, '1', "Item " & to_string(Index) & ", decoding: K");
                    
                    Index := Index + 1;
                end loop;
                
                E_WE <= '0';
                D_WE <= '0';
            
            
            -- Tests that the expected output is still produced even if the
            -- write-enable signal goes low before it appears on Q.
            elsif run("clock_after_we_low") then
                wait until rising_edge(CLK);
            
                E_K     <= '0';
                E_WE    <= '1';
                D_WE    <= '1';
                E_ARG   <= "1111";
                D_ARG   <= "11101";
                wait until rising_edge(CLK);
                
                E_WE    <= '0';
                D_WE    <= '0';
                wait until rising_edge(CLK);
                
                check_equal(to_string(E_Q), "11101", "Encoding");
                check_equal(to_string(D_Q), "1111", "Decoding: Q");
                check_equal(D_K, '0', "Decoding: K");
                
                
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


    ENC: Encoder4b5b port map(
        CLK => CLK,
        WE  => E_WE,
        K   => E_K,
        ARG => E_ARG,
        Q   => E_Q
        );
        
    DEC: Decoder4b5b port map(
        CLK => CLK,
        WE  => D_WE,
        ARG => D_ARG,
        Q   => D_Q,
        K   => D_K
        );
end;