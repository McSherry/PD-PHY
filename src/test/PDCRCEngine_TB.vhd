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
    component PDCRCEngine port(
        CLK : in    std_logic;
        WE  : in    std_logic;
        D   : in    std_logic;
        RST : in    std_logic;
        Q   : out   std_ulogic_vector(31 downto 0)
        );
    end component;
    
    -- Engine signals
    signal CLK, WE, D, RST  : std_ulogic := '0';
    signal Q                : std_ulogic_vector(31 downto 0);
    
    -- USB-PD constants
    constant CRC_INITIAL      : std_ulogic_vector(31 downto 0) := x"FFFFFFFF";
    constant CRC_RESIDUAL     : std_ulogic_vector(31 downto 0) := x"C704DD7B";
    constant CRC_EXAMPLE      : std_ulogic_vector(31 downto 0) := x"2FC51328";
    
    -- Timing constants
    constant T  : time := 10 ns;
begin
    test_runner_watchdog(runner, 80 * T);
    
    -- Generates test stimulus and captures component output
    stimulus: process
        variable Index  : natural := 0;
        
        -- The CRC generator inverts and bitwise-reverses its output so that it
        -- produces the codes USB-PD requires. This means its residual will also
        -- be inverted and swapped.
        --
        -- We invert and swap the received residual so we can compare it to the
        -- constant value specified above.
        variable RESID_INV : std_ulogic_vector(31 downto 0);
        
        -- GoodCRC example data
        --
        -- Two set bits are the 'GoodCRC' message type, and the 'Source' power
        -- role indicator.
        constant EX_GOODCRC : std_ulogic_vector(15 downto 0) := x"0101";
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        
        -- The engine should begin with USB-PD's defined initial value
        --
        -- The CRC engine inverts and swaps its output, so all ones should
        -- become all zeroes.
        check_equal(not Q, CRC_INITIAL, "Initial value");
        
        -- We test CRC generation by feeding through the example data from
        -- the USB-PD standard, Appendix A.2.
        --
        -- First, the 'GoodCRC' example message to check the CRC itself.
        while Index < EX_GOODCRC'length loop
            WE  <= '1';
            D   <= EX_GOODCRC(Index);
            wait until rising_edge(CLK);
            
            Index := Index + 1;
        end loop;
        
        -- Wait for the effect of the last-written data bit
        WE  <= '0';
        wait until rising_edge(CLK);
        
        check_equal(Q, CRC_EXAMPLE, "Check code");
        
        
        -- And then write the CRC itself through, which should produce the
        -- standard-specified residual value
        Index := 0;
        while Index < CRC_EXAMPLE'length loop
            WE  <= '1';
            D   <= CRC_EXAMPLE(Index);
            wait until rising_edge(CLK);
            
            Index := Index + 1;
        end loop;

        
        -- Wait for the effect of the last data bit
        WE  <= '0';
        wait until rising_edge(CLK);
        
        -- Invert, reverse residual
        for i in 0 to Q'left loop
            RESID_INV(i) := not Q(Q'left - i);
        end loop;
        
        check_equal(RESID_INV, CRC_RESIDUAL, "Residual");
        
        
        -- Then we reset and check for the initial value
        RST <= '1';
        wait until rising_edge(CLK);
        
        -- The CRC engine inverts and swaps its output, so all ones should
        -- become all zeroes.
        check_equal(not Q, CRC_INITIAL, "Reset");
        
        
        test_runner_cleanup(runner);
    end process;

    -- Data clock generation
    DCLK: process
    begin
        wait for T/2;
        CLK <= not CLK;
    end process;

    UUT: PDCRCEngine port map(
        CLK => CLK,
        WE  => WE,
        D   => D,
        RST => RST,
        Q   => Q
        );
end;