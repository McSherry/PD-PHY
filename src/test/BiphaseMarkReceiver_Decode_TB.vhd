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


-- Provides an end-to-end test running the BMC transmitter through a Wishbone
-- bus 'single write' transaction which results in line-driven output.
entity BiphaseMarkReceiver_Decode_TB is
    generic(runner_cfg : string := runner_cfg_default);
end BiphaseMarkReceiver_Decode_TB;


architecture Impl of BiphaseMarkReceiver_Decode_TB is
    component BiphaseMarkReceiver port(
        WB_CLK      : in    std_logic;
        WB_RST_I    : in    std_logic;
        WB_ADR_I    : in    std_logic_vector(1 downto 0);
        WB_DAT_I    : in    std_logic_vector(7 downto 0);
        WB_CYC_I    : in    std_logic;
        WB_STB_I    : in    std_logic;
        WB_WE_I     : in    std_logic;
        RXIN        : in    std_logic;
        WB_DAT_O    : out   std_ulogic_vector(7 downto 0);
        WB_ACK_O    : out   std_ulogic;
        WB_ERR_O    : out   std_ulogic
        );
    end component;
    
    -- Wishbone signals
    --
    -- These are named from the perspective of a bus master.
    signal WB_CLK   : std_ulogic := '0';
    signal WB_RST_O : std_ulogic := '0';
    signal WB_CYC_O : std_ulogic := '0';
    signal WB_STB_O : std_ulogic := '0';
    signal WB_WE_O  : std_ulogic := '0';
    signal WB_ADR_O : std_ulogic_vector(1 downto 0) := (others => '0');
    signal WB_DAT_O : std_ulogic_vector(7 downto 0) := (others => '0');
    signal WB_DAT_I : std_ulogic_vector(7 downto 0);
    signal WB_ACK_I : std_ulogic;
    signal WB_ERR_I : std_ulogic;
    
    -- Receiver signals
    --
    -- Signal used as a clock when generating receiver input
    signal RXCLK    : std_ulogic := '0';
    -- The input to the receiver itself.
    --
    -- In a real circuit, this will idle above 0 volts and, in most scenarios,
    -- should idle high enough that a swing to zero can be detected as an edge,
    -- so it makes sense to start it high here.
    signal RXIN     : std_ulogic := '1';
    
    -- Internal test signals
    signal TestBegin    : std_ulogic := '0';
    signal CaptureDone  : std_ulogic := '0';
    
    -- Test data
    --
    -- Kcodes
    constant K_SYNC1    : std_ulogic_vector(4 downto 0) := "11000";
    constant K_SYNC2    : std_ulogic_vector(4 downto 0) := "10001";
    constant K_EOP      : std_ulogic_vector(4 downto 0) := "01101";
    --
    -- This is the 'GoodCRC' message illustrated in Appendix A.2 of USB-PD. It
    -- is given in reverse order here to allow the individual components to be
    -- written big-endian, easing reading.
    constant MSG_GOODCRC : std_ulogic_vector(84 downto 0) := (
        -- EOP
        K_EOP &
    
        -- CRC32 (2FC51328h)
        "10100" & "11101" & "11010" & "01011" & "01001" &
        "10101" & "10100" & "10010" &
    
        -- 'GoodCRC' header (0101h)
        "11110" & "01001" & "11110" & "01001" &
    
        -- Start of Packet
        K_SYNC2 & K_SYNC1 & K_SYNC1 & K_SYNC1
        );
    -- How the above message should decode, in order
    constant DEC_GOODCRC : std_ulogic_vector((9 * 11) - 1 downto 0) := (
        --  K-code?     Value
                '1' &   "00000101"  &   -- EOP
                
                '0' &   x"2F"       &   -- CRC32, high-order byte
                '0' &   x"C5"       &
                '0' &   x"13"       &
                '0' &   x"28"       &   -- CRC32, low-order bye
                
                '0' &   x"01"       &   -- GoodCRC header
                '0' &   x"01"       &   -- GoodCRC header    
                
                '1' &   "00000001"  &   -- Sync-2
                '1' &   "00000000"  &   -- Sync-1
                '1' &   "00000000"  &   -- Sync-1
                '1' &   "00000000"      -- Sync-1
        );
    
    -- Timing constants
    --
    -- Wishbone clock period
    constant T_WB       : time := 10 ns;
    -- Fastest BMC data clock (330kHz)
    constant T_BMC_FAST : time := 3.03 us;
    -- Nominal BMC data clock (300kHz)
    constant T_BMC_REGL : time := 3.33 us;
    -- Slowest BMC data clock (270kHz)
    constant T_BMC_SLOW : time := 3.74 us;
    -- BMC data clock with a frequency that may be awkward to synchronise
    -- with (290.475kHz, selected randomly)
    constant T_BMC_AWKS : time := 3.4426 us;
begin
    -- This is an arbitrary high value
    test_runner_watchdog(runner, 200 * T_BMC_SLOW);


    -- Generates stimulus for the BMC receiver, emulating a typical transaction
    -- where a 'GoodCRC' message is sent.
    stimulus: process
        variable PreambleCount  : integer := 0;
        variable MessageCount   : integer := 0;
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        -- We're ready to begin
        TestBegin <= '1';
        
        
        -- We start with the 64-bit preamble
        info("Beginning preamble...");
        
        while PreambleCount < 32 loop
            -- To transmit the logic lows in the preamble, we simply invert on
            -- the rising edge of the data clock.
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            
            -- Then, to transmit logic low, we invert on both rising and falling
            -- edges of the data clock.
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            wait until falling_edge(RXCLK);
            RXIN <= not RXIN;
            
            PreambleCount := PreambleCount + 1;
        end loop;
        info("Preamble finished.");
        
        
        -- Followed by a message
        info("Beginning GoodCRC...");
        
        while MessageCount < MSG_GOODCRC'length loop
            -- This is basically the same as the preamble, except we
            -- conditionally invert on the falling edge based on the data
            -- we have to transmit.
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            
            if MSG_GOODCRC(MessageCount) = '1' then
                wait until falling_edge(RXCLK);
                RXIN <= not RXIN;
            end if;
            
            MessageCount := MessageCount + 1;
        end loop;
        info("GoodCRC sent.");
        
        
        -- And, finally, we hold the line before returning it to high.
        info("Holding line...");
        
        wait until rising_edge(RXCLK);
        RXIN <= not RXIN;
        
        if not RXIN = '1' then
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
        end if;
        
        info("Transmission completed.");
        
        wait until rising_edge(RXCLK);
        RXIN <= '1';
        
        if CaptureDone /= '1' then
            wait until CaptureDone = '1';
        end if;
        test_runner_cleanup(runner);
    end process;
    
    
    -- Interacts with the control unit over its Wishbone interface and
    -- verifies that it decodes the data in the way expected
    capture: process
        variable CaptureIndex : integer := 0;
    begin
        wait until TestBegin = '1';
        
        -- We continually request the control unit's 'TYPE' register until
        -- it indicates that data is present. When it is, we read it and
        -- compare against the test data constant.
        while CaptureIndex < (DEC_GOODCRC'length / 9) loop
            -- Set up the Wishbone request
            WB_CYC_O    <= '1';
            WB_STB_O    <= '1';
            WB_WE_O     <= '0';
            WB_ADR_O    <= "01";
            wait until rising_edge(WB_CLK);
            
            -- The slave should always acknowledge an attempt to read from
            -- its 'TYPE' register
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            
            -- If there isn't any data available from the receiver, we'll
            -- wait and try again
            if WB_DAT_I = x"00" then
                WB_STB_O <= '0';
                wait until rising_edge(WB_CLK);
                next;
            end if;
            
            
            -- If we do get data, then we'll try to compare it
            info("Reading RX byte " & to_string(CaptureIndex) & "...");
            
            -- First, it should be the data type we expect (K-code or raw data)
            if DEC_GOODCRC((CaptureIndex * 9) + 8) = '1' then
                check_equal(WB_DAT_I, std_logic_vector'(x"03"), "Data type indication");
            else
                check_equal(WB_DAT_I, std_logic_vector'(x"01"), "Data type indication");
            end if;
            
            -- End current request
            WB_STB_O <= '0';
            wait until rising_edge(WB_CLK);
            
            -- Try to read from the RX FIFO
            WB_STB_O    <= '1';
            WB_WE_O     <= '0';
            WB_ADR_O    <= "00";
            wait until rising_edge(WB_CLK);
            
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            
            -- And second, it should have the value we expect
            check_equal(
                WB_DAT_I,
                DEC_GOODCRC((CaptureIndex * 9) + 7 downto (CaptureIndex * 9)),
                "Data value"
                );
                
            -- End request
            WB_STB_O    <= '0';
            wait until rising_edge(WB_CLK);
            
            -- And repeat
            CaptureIndex := CaptureIndex + 1;
        end loop;
        
        info("Capture complete.");
        CaptureDone <= '1';
        wait;
    end process;


    -- Wishbone clock generation
    WBCLK: process
    begin
        if TestBegin /= '1' then
            wait until TestBegin = '1';
        end if;
        
        wait for T_WB/2;
        WB_CLK <= not WB_CLK;
    end process;

    -- BMC data clock generation
    DCLK: process
        variable T_BMC : time;
    begin
        wait until TestBegin = '1';
    
        if run("fast_bmc") then
            T_BMC := T_BMC_FAST;
            
        elsif run("nominal_bmc") then
            T_BMC := T_BMC_REGL;
            
        elsif run("slow_bmc") then
            T_BMC := T_BMC_SLOW;
            
        elsif run("awkward_bmc") then
            T_BMC := T_BMC_AWKS;
        end if;
        
        while true loop
            wait for T_BMC/2;
            RXCLK <= not RXCLK;
        end loop;
    end process;

    UUT: BiphaseMarkReceiver port map(
        WB_CLK      => WB_CLK,
        WB_RST_I    => WB_RST_O,
        WB_CYC_I    => WB_CYC_O,
        WB_STB_I    => WB_STB_O,
        WB_WE_I     => WB_WE_O,
        WB_ADR_I    => WB_ADR_O,
        WB_DAT_I    => WB_DAT_O,
        WB_DAT_O    => WB_DAT_I,
        WB_ACK_O    => WB_ACK_I,
        WB_ERR_O    => WB_ERR_I,
        
        RXIN        => RXIN
        );
end;
