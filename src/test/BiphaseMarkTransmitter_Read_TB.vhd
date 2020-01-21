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
-- bus 'single read' transaction.
entity BiphaseMarkTransmitter_Read_TB is
    generic(runner_cfg : string := runner_cfg_default);
end BiphaseMarkTransmitter_Read_TB;


architecture Impl of BiphaseMarkTransmitter_Read_TB is
    component BiphaseMarkTransmitter port(
        -- Wishbone signals
        WB_CLK      : in    std_logic;
        WB_RST_I    : in    std_logic;
        WB_ADR_I    : in    std_logic_vector(1 downto 0);
        WB_DAT_I    : in    std_logic_vector(7 downto 0);
        WB_CYC_I    : in    std_logic;
        WB_STB_I    : in    std_logic;
        WB_WE_I     : in    std_logic;
        WB_DAT_O    : out   std_ulogic_vector(7 downto 0);
        WB_ACK_O    : out   std_ulogic;
        WB_ERR_O    : out   std_ulogic;
        
        -- Line driver signals
        DCLK        : in    std_logic;
        LD_DAT_O    : out   std_ulogic;
        LD_EN_O     : out   std_ulogic
        );
    end component;
    
    -- Wishbone signals
    --
    -- These are named as if they were signals from a bus master, and so the
    -- connecting signals on the transmitter have the opposite polarity.
    signal WB_CLK   : std_logic := '0';
    signal WB_RST_O : std_logic := '0';
    signal WB_CYC_O : std_logic := '0';
    signal WB_STB_O : std_logic := '0';
    signal WB_WE_O  : std_logic := '0';
    signal WB_ADR_O : std_logic_vector(1 downto 0) := (others => '0');
    signal WB_DAT_O : std_logic_vector(7 downto 0) := (others => '0');
    signal WB_DAT_I : std_ulogic_vector(7 downto 0);
    signal WB_ACK_I : std_ulogic;
    signal WB_ERR_I : std_ulogic;
    
    -- Timing constants
    constant T_WB   : time := 100 ns;
begin
    -- This is an arbitrarily chosen value.
    test_runner_watchdog(runner, 40 us);
    
    
    -- Acts as the bus master in carrying out a Wishbone transaction.
    master: process
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);

        
        -- Basic reads
        if run("single_read") or run("block_read") then
            -- First read
            WB_CYC_O    <= '1';     -- Beginning a cycle
            WB_STB_O    <= '1';     -- Selecting the transmitter
            WB_WE_O     <= '0';     -- We're reading
            WB_ADR_O    <= "10";    -- STATUS register
            wait until rising_edge(WB_CLK);
            
            -- We now have to wait for the slave to acknowledge us, which will
            -- indicate the presence of the data we requested.
            info("Read 1, waiting...");
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            info("Read 1, acknowledged");
            
            -- We expect it to report: not FULL, not FILLING, EMPTY, blanks.
            check_equal(WB_DAT_I, std_ulogic_vector'("00100000"), "Read 1, STATUS");
            
            
            -- If we're testing single reads, we deassert WB_CYC_O between
            -- reads. Otherwise, it remains asserted.
            if running_test_case = "single_read" then
                WB_CYC_O <= '0';
            else
                WB_CYC_O <= '1';
            end if;
            
            -- Strobe is always deasserted
            WB_STB_O <= '0';
            wait until rising_edge(WB_CLK);
            
            
            -- Next, we write one value. This should change the value of the
            -- status register to all zeroes.
            WB_CYC_O    <= '1';
            WB_STB_O    <= '1';         -- Selecting the transmitter
            WB_WE_O     <= '1';         -- We're writing
            WB_ADR_O    <= "01";        -- Writing data
            WB_DAT_O    <= "11101110";  -- EEh
            wait until rising_edge(WB_CLK);
            
            info("Write, waiting...");
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            
            
            -- End write
            if running_test_case = "single_read" then
                WB_CYC_O <= '0';
            else
                WB_CYC_O <= '1';
            end if;
            
            WB_STB_O <= '0';
            wait until rising_edge(WB_CLK);
            
            
            -- Now, we read back STATUS again
            WB_CYC_O    <= '1';
            WB_STB_O    <= '1';
            WB_WE_O     <= '0';
            WB_ADR_O    <= "10";
            wait until rising_edge(WB_CLK);
            
            info("Read 2, waiting...");
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            
            
            -- We expect it to report: not FULL, not FILLING, not EMPTY, blank.
            check_equal(WB_DAT_I, std_ulogic_vector'("00000000"), "Read 2, STATUS");
            
            
        -- Reading from an invalid location
        elsif run("read_not_supported") then
            -- Attempt to read from the write-only register KWRITE
            WB_CYC_O    <= '1';
            WB_STB_O    <= '1';
            WB_WE_O     <= '0';
            WB_ADR_O    <= "00";
            wait until rising_edge(WB_CLK);
            
            -- The slave should report an error
            info("Invalid read, waiting...");
            if WB_ERR_I /= '1' then
                wait until WB_ERR_I = '1';
            end if;
            info("Invalid read, error signalled");
            
            
            WB_CYC_O <= '0';
            WB_STB_O <= '0';
            wait until rising_edge(WB_CLK);
            
            
            -- We should now be able to read an error number from the ERRNO
            -- register, and it should correspond to our expected error.
            WB_CYC_O    <= '1';
            WB_STB_O    <= '1';
            WB_WE_O     <= '0';
            WB_ADR_O    <= "11";
            wait until rising_edge(WB_CLK);
            
            info("Errno, waiting...");
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            info("Errno, acknowledged");
            
            
            check_equal(WB_DAT_I, std_ulogic_vector'(x"02"), "Errno check");
        end if;
    end process;


    -- Wishbone bus clock
    WishboneCLK: process
    begin
        wait for T_WB/2;
        WB_CLK <= not WB_CLK;
    end process;
    
    
    UUT: BiphaseMarkTransmitter port map(
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
        
        DCLK        => '0',
        LD_DAT_O    => open,
        LD_EN_O     => open
        );
end;
