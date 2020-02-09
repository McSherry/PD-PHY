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


-- Provides a set of tests which seek to cause the BMC receiver to detect an
-- error.
entity BiphaseMarkReceiver_Errors_TB is
    generic(runner_cfg : string := runner_cfg_default);
end BiphaseMarkReceiver_Errors_TB;


architecture Impl of BiphaseMarkReceiver_Errors_TB is
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
    
    -- Timing constants
    constant T_WB   : time := 10 ns;
    constant T_BMC  : time := 3.3 us;
    
    -- Test internal signals
    signal TestBegin    : std_ulogic := '0';
    signal CaptureDone  : std_ulogic := '0';
    
    -- Test data
    --
    -- K-codes
    constant K_SYNC1    : std_ulogic_vector(4 downto 0) := "11000";
    constant K_SYNC2    : std_ulogic_vector(4 downto 0) := "10001";
    constant K_SYNC3    : std_ulogic_vector(4 downto 0) := "00110";
    constant K_RST1     : std_ulogic_vector(4 downto 0) := "00111";
    constant K_RST2     : std_ulogic_vector(4 downto 0) := "11001";
    constant K_EOP      : std_ulogic_vector(4 downto 0) := "01101";
    --
    -- This is the 'GoodCRC' message illustrated in Appendix A.2 of USB-PD. It
    -- is given in reverse order here to allow the individual components to be
    -- written big-endian, easing reading.
    
    -- This is the 'GoodCRC' message from the 'Decode' test, except that the
    -- header is changed to '0102h' to throw off the CRC.
    constant MSG_GOODCRC : std_ulogic_vector((17 * 5) - 1 downto 0) := (
        -- EOP
        K_EOP &
    
        -- CRC32 (2FC51328h)
        "10100" & "11101" & "11010" & "01011" & "01001" &
        "10101" & "10100" & "10010" &
    
        -- Bad 'GoodCRC' header (0102h, should be 0101h)
        "10100" & "01001" & "11110" & "01001" &
    
        -- Start of Packet
        K_SYNC2 & K_SYNC1 & K_SYNC1 & K_SYNC1
        );
        
    -- This is the 'Hard_Reset' message, which doesn't include a CRC.
    constant MSG_HARDRST : std_ulogic_vector((4 * 5) - 1 downto 0) := (
        K_RST2 & K_RST1 & K_RST1 & K_RST1
        );
    -- This is the decoded output as it will appear in the RX queue
    constant DEC_HARDRST : std_ulogic_vector((4 * 8) - 1 downto 0) := (
            x"04" & -- RST-2
            x"03" & -- RST-1
            x"03" & -- RST-1
            x"03"   -- RST-1
        );
    -- This is the 'Cable_Reset' message, which doesn't include a CRC.
    constant MSG_CABLERST : std_ulogic_vector((4 * 5) - 1 downto 0) := (
        K_SYNC3 & K_RST1 & K_SYNC1 & K_RST1
        );
    -- This is the decoded output as it will appear in the RX queue
    constant DEC_CABLERST : std_ulogic_vector((4 * 8) - 1 downto 0) := (
            x"02" & -- Sync-3
            x"03" & -- RST-1
            x"00" & -- Sync-1
            x"03"   -- RST-1
        );
begin
    -- This is an arbitrary high value
    test_runner_watchdog(runner, 200 * T_BMC);

    
    -- Generates stimulus for the BMC receiver, consisting of a preamble and
    -- then test-specific sequences.
    stimulus: process
        variable PreambleCount  : integer := 0;
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        -- We start with the 64-bit preamble, which is common to almost all
        -- of the tests that we're looking to perform here.
        info("TX - Beginning preamble...");
        
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
        
        info("TX - Preamble finished.");
        
        TestBegin <= '1';
        
        -- If one of the line symbols provided to the receiver doesn't decode
        -- to a recognised value, that should prompt an error.
        if run("bad_line_symbol") then
            -- We transmit a good symbol first as that allows us to detect when
            -- a bad one is read in by monitoring the 'TYPE' register.
            --
            -- '01001' --> 01h
            
            PreambleCount := 0;
            
            -- We loop to give ourselves enough time to detect that data is
            -- available before the error. Two seems to be enough.
            info("TX - Writing good data...");
            while PreambleCount < 2 loop
                -- 1
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                wait until falling_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                -- 1
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                wait until falling_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                
                PreambleCount := PreambleCount + 1;
            end loop;
        
            -- '00100' is a reserved symbol. This should probably be revised to
            -- test all invalid line symbols at some point.
            info("TX - Writing bad symbol...");
            --
            -- 0
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            -- 0
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            -- 1
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            wait until falling_edge(RXCLK);
            RXIN <= not RXIN;
            -- 0
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            -- 0
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
        
        
        -- If the RX queue fills to capacity and data is still to be written,
        -- that should result in an error.
        elsif run("buffer_overflow") then
            PreambleCount := 0;
            
            -- The 'FFREG' FIFO architecture has a capacity of 16, plus one for
            -- the item that will be read out the front of the FIFO automatically,
            -- and then another to cause overflow.
            while PreambleCount < 19 loop
                info("TX - Writing symbol #" & to_string(PreambleCount) & "...");
            
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                -- 1
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                wait until falling_edge(RXCLK);
                RXIN <= not RXIN;
                -- 1
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                wait until falling_edge(RXCLK);
                RXIN <= not RXIN;
                
                PreambleCount := PreambleCount + 1;
            end loop;
        
        -- If the data received by the BMC receiver does not match the CRC at
        -- the end of a message, that's an error.
        elsif run("crc_failure") then
            -- Transmit our 'GoodCRC' message. This is effectively the same as
            -- the 'Decode' test
            PreambleCount := 0;
            info("TX - Writing GoodCRC...");
            while PreambleCount < MSG_GOODCRC'length loop
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                
                if MSG_GOODCRC(PreambleCount) = '1' then
                    wait until falling_edge(RXCLK);
                    RXIN <= not RXIN;
                end if;
                
                PreambleCount := PreambleCount + 1;
            end loop;
            
            -- Hold the line
            info("TX - Holding line...");
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            
            if not RXIN = '1' then
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
            end if;
            
            info("TX - Transmission complete.");
            
        -- If the message shouldn't include a CRC, the receiver shouldn't
        -- indicate CRC failure when receiving it.
        elsif run("crc_hard_reset") or run("crc_cable_reset") then
            -- Transmit 'Cable_Reset'
            PreambleCount := 0;
            info("TX - Writing Cable_Reset...");
            while PreambleCount < MSG_CABLERST'length loop
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                
                if running_test_case = "crc_cable_reset" then
                    if MSG_CABLERST(PreambleCount) = '1' then
                        wait until falling_edge(RXCLK);
                        RXIN <= not RXIN;
                    end if;
                else
                    if MSG_HARDRST(PreambleCount) = '1' then
                        wait until falling_edge(RXCLK);
                        RXIN <= not RXIN;
                    end if;
                end if;
                
                PreambleCount := PreambleCount + 1;
            end loop;
            
            -- Hold the line
            info("TX - Holding line...");
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            
            if not RXIN = '1' then
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
            end if;
            
            info("TX - Transmission complete.");
        
        -- If a pulse is much longer than it should be, that's an error we
        -- should detect as it probably indicates the data is malformed. If
        -- it's only slightly longer, we're not too fussed.
        elsif run("overlong_pulse_low") or run("overlong_pulse_high_first") or
              run("overlong_pulse_high_second") then
            
            -- Start by writing some good data, to give our capture process
            -- time to detect that we've started a transmission
            info("TX - Writing good data...");
            while PreambleCount < 2 loop
                -- 1
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                wait until falling_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                -- 1
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                wait until falling_edge(RXCLK);
                RXIN <= not RXIN;
                -- 0
                wait until rising_edge(RXCLK);
                RXIN <= not RXIN;
                
                PreambleCount := PreambleCount + 1;
            end loop;
            
            -- And then some bad (10010b --> 08h)
            --      We make the data bad simply by inserting an extra
            --      wait before the state of the line changes.
            --
            -- 1
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;            
            wait until falling_edge(RXCLK);
            if running_test_case = "overlong_pulse_high_first" then
                wait for T_BMC/4;
            end if;
            RXIN <= not RXIN;
            -- 0
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            -- 0
            wait until rising_edge(RXCLK);
            RXIN <= not RXIN;
            -- 1
            wait until rising_edge(RXCLK);
            if running_test_case = "overlong_pulse_low" then
                wait for T_BMC/2;
            end if;
            RXIN <= not RXIN;
            wait until falling_edge(RXCLK);
            RXIN <= not RXIN;
            -- 0
            wait until rising_edge(RXCLK);
            if running_test_case = "overlong_pulse_high_second" then
                wait for T_BMC/2;
            end if;
            RXIN <= not RXIN;
            
        end if;
        

        if CaptureDone /= '1' then
            wait until CaptureDone = '1';
        end if;
        test_runner_cleanup(runner);
    end process;
    
    
    -- Carries out Wishbone transactions with the receiver so as to capture
    -- its output 
    capture: process
        variable Index    : integer := 0;
        variable ExpError : std_ulogic_vector(7 downto 0);
    begin
        wait until TestBegin = '1';
        
        -- We can test each of these in the same way: monitoring for data,
        -- then an error. We just need to change the error code each time.
        if running_test_case = "bad_line_symbol" or
           running_test_case = "buffer_overflow" or
           running_test_case = "crc_failure" or
           running_test_case = "overlong_pulse_low" or
           running_test_case = "overlong_pulse_high_first" or
           running_test_case = "overlong_pulse_high_second" then
            -- First, we wait for the receiver to indicate it has data
            info("RX - Waiting for data...");
            while true loop
                WB_CYC_O    <= '1';
                WB_STB_O    <= '1';
                WB_WE_O     <= '0';
                WB_ADR_O    <= "01";
                wait until rising_edge(WB_CLK);
                
                if WB_ACK_I /= '1' then
                    wait until WB_ACK_I = '1';
                end if;
                
                WB_STB_O    <= '0';
                wait until rising_edge(WB_CLK);
                    
                -- If we have data, move on.
                if WB_DAT_I = x"01" or WB_DAT_I = x"03" then
                    exit;
                end if;
            end loop;
            
            -- Then, without reading, we wait for it to indicate that it no
            -- longer has data. This is a sign it's detected an error.
            info("RX - Waiting for error...");
            while true loop
                WB_CYC_O    <= '1';
                WB_STB_O    <= '1';
                WB_WE_O     <= '0';
                WB_ADR_O    <= "01";
                wait until rising_edge(WB_CLK);
                
                if WB_ACK_I /= '1' then
                    wait until WB_ACK_I = '1';
                end if;
                
                WB_STB_O    <= '0';
                wait until rising_edge(WB_CLK);
                    
                if WB_DAT_I = x"00" then
                    exit;
                end if;
            end loop;
            
            -- And we now read from RXQ, which should generate an error signal.
            WB_CYC_O    <= '1';
            WB_STB_O    <= '1';
            WB_WE_O     <= '0';
            WB_ADR_O    <= "00";
            wait until rising_edge(WB_CLK);
            
            if WB_ERR_I /= '1' then
                wait until WB_ERR_I = '1';
            end if;
            
            WB_STB_O    <= '0';
            wait until rising_edge(WB_CLK);
            
            -- And read from ERRNO to get the error value.
            WB_CYC_O    <= '1';
            WB_STB_O    <= '1';
            WB_WE_O     <= '0';
            WB_ADR_O    <= "10";
            wait until rising_edge(WB_CLK);
            
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            
            WB_STB_O <= '0';
            WB_CYC_O <= '0';
            
            if running_test_case = "bad_line_symbol" then
                ExpError := x"80";
            elsif running_test_case = "buffer_overflow" then
                ExpError := x"81";
            elsif running_test_case = "crc_failure" then
                ExpError := x"83";
            else
                ExpError := x"82";
            end if;
            
            check_equal(WB_DAT_I, ExpError, "Error code");
        
        
        -- In this case, we're looking for the absence of an error. We
        -- should be able to read the four expected values out, and then
        -- a subsequent read should error due to the RX queue being empty.
        elsif running_test_case = "crc_hard_reset" or
              running_test_case = "crc_cable_reset" then
            info("RX - Waiting for data...");
            while Index < 4 loop
                -- First, we check 'TYPE' to make sure data is available
                WB_CYC_O    <= '1';
                WB_STB_O    <= '1';
                WB_WE_O     <= '0';
                WB_ADR_O    <= "01";
                wait until rising_edge(WB_CLK);
                
                if WB_ACK_I /= '1' then
                    wait until WB_ACK_I = '1';
                end if;
                
                WB_STB_O    <= '0';
                wait until rising_edge(WB_CLK);
                
                -- If we don't get a K-code, we go back and check again.
                if WB_DAT_I /= x"03" then
                    next;
                end if;
                
                -- If we do get a K-code, we try to read it out.
                WB_CYC_O    <= '1';
                WB_STB_O    <= '1';
                WB_WE_O     <= '0';
                WB_ADR_O    <= "00";
                wait until rising_edge(WB_CLK);
                
                if WB_ACK_I /= '1' then
                    wait until WB_ACK_I = '1';
                end if;
                
                WB_STB_O    <= '0';
                wait until rising_edge(WB_CLK);
                
                -- Then check it equals what we expect
                if running_test_case = "crc_hard_reset" then
                    check_equal(
                        WB_DAT_I,
                        DEC_HARDRST((Index * 8) + 7 downto (Index * 8)),
                        "Symbol #" & to_string(Index)
                        );
                else
                    check_equal(
                        WB_DAT_I,
                        DEC_CABLERST((Index * 8) + 7 downto (Index * 8)),
                        "Symbol #" & to_string(Index)
                        );
                end if;
                    
                Index := Index + 1;
            end loop;
        end if;
        
        -- After the transmission ends, we should be able to read back a
        -- different error code from RXQ.
        info("RX - Waiting for end of transmission...");
        wait for 24 us;
        
        WB_CYC_O    <= '1';
        WB_STB_O    <= '1';
        WB_WE_O     <= '0';
        WB_ADR_O    <= "00";
        wait until rising_edge(WB_CLK);
        
        if WB_ERR_I /= '1' then
            wait until WB_ERR_I = '1';
        end if;
        
        WB_STB_O    <= '0';
        wait until rising_edge(WB_CLK);
        
        WB_CYC_O    <= '1';
        WB_STB_O    <= '1';
        WB_WE_O     <= '0';
        WB_ADR_O    <= "10";
        wait until rising_edge(WB_CLK);
        
        if WB_ACK_I /= '1' then
            wait until WB_ACK_I = '1';
        end if;
        
        WB_CYC_O    <= '0';
        WB_STB_O    <= '0';
        
        -- As RXQ should now be empty, we should get 'not supported' when
        -- we attempt to read a value from it.
        check_equal(WB_DAT_I, std_ulogic_vector'(x"02"), "Error cleared");
        
        info("RX - Done.");
        CaptureDone <= '1';
        wait;
    end process;
    
    
    WishboneCLK: process
    begin
        wait for T_WB/2;
        WB_CLK <= not WB_CLK;
    end process;
    
    BmcCLK: process
    begin
        wait for T_BMC/2;
        RXCLK <= not RXCLK;
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
