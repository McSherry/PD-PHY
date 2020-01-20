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
entity BiphaseMarkTransmitter_SingleWrite_TB is
    generic(runner_cfg : string := runner_cfg_default);
end BiphaseMarkTransmitter_SingleWrite_TB;


architecture Impl of BiphaseMarkTransmitter_SingleWrite_TB is
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
    
    -- Line driver signals
    signal DCLK     : std_logic := '0';
    signal LD_DAT_I : std_ulogic;
    signal LD_EN_I  : std_ulogic;
    
    -- Test internal signals
    signal CaptureDone : std_logic := '0';
    
    -- Timing constants
    constant T_WB   : time := 100 ns;
    constant T_DAT  : time := 1 us;
    
    -- Test data
    constant NumCases : integer := 4;
    constant DatWidth : integer := 10;
    constant WrData : std_logic_vector((NumCases * DatWidth) - 1 downto 0) := (
        --  ADDR    DATA
            "00" &  "00000010" &    -- Write 0, K-code Sync-3
            "01" &  "10100101" &    -- Write 1, Data A5h
            "01" &  "11100111" &    -- Write 2, Data E7h
            "00" &  "00000101"      -- Write 3, K-code EOP
        );
begin
    -- This is an arbitrarily chosen high value.
    test_runner_watchdog(runner, 100 us);
    

    -- Generates the stimulus that simulates a Wishbone bus transaction.
    stimulus: process
        variable Cycle  : integer := 0;
        variable OFFSET : integer;
        variable ADDR   : std_logic_vector(1 downto 0);
        variable DATA   : std_logic_vector(7 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
    
        
        while Cycle < NumCases loop
            -- This just allows us to have the test data laid out intuitively,
            -- the typical MSB-to-the-left order means we have to address items
            -- in reverse order to have them sent in the order written.
            OFFSET := (NumCases - Cycle - 1) * DatWidth;
            
            ADDR := WrData(OFFSET + (DatWidth - 1) downto OFFSET + (DatWidth - 2));
            DATA := WrData(OFFSET + (DatWidth - 3) downto OFFSET);
        
            -- Set up our transaction
            WB_CYC_O    <= '1';     -- We're beginning a cycle
            WB_STB_O    <= '1';     -- Transmitter is the selected slave
            WB_WE_O     <= '1';     -- We're going to write
            WB_ADR_O    <= ADDR;    -- To the specified address
            WB_DAT_O    <= DATA;    -- With the specified data
            wait until rising_edge(WB_CLK);
            
            -- The slave should now acknowledge us
            info("Write " & to_string(Cycle) & ", waiting...");
            if WB_ACK_I /= '1' then
                wait until WB_ACK_I = '1';
            end if;
            info("Write " & to_string(Cycle) & ", acknowledged");
            
            -- End the current bus cycle
            WB_CYC_O <= '0';
            WB_STB_O <= '0';
            wait until rising_edge(WB_CLK);
            
            Cycle := Cycle + 1;
        end loop;
        
        
        -- Once we've fed it all the input we have, wait for all of the
        -- transsmitter's output to be captured.
        wait until CaptureDone = '1';

        test_runner_cleanup(runner);
    end process;
    
    
    -- Captures the output from the BMC transmitter and compares it against
    -- the anticipated output.
    capture: process
        -- Tracks the current clock cycle
        variable Cycle : integer := 0;
        variable Txt : string;
        
        -- Stores the inversion state of the line. 
        variable LInvert : std_logic;
    begin        
        -- The first thing transmitted should be a preamble of alternating
        -- ones and zeroes, BMC-coded, for 64 cycles.
        while Cycle < 64 loop
            Txt := "Cycle " & to_string(Cycle) & ", ";
        
            wait on DCLK;
            
            -- We don't want to proceed until the line driver has enabled its
            -- output, as before then the output is invalid. This is only
            -- relevant until we get started.
            next when Cycle = 0 and LD_EN_I = '0';
        
            -- We start on zero, and as the driver starts low this should be
            -- an actual zero as well as a logical one.
            check_equal(LD_DAT_I, LInvert, Txt & "PRE logic 0, first half");

            -- As it's logic zero it's unchanging, so it should still be low
            -- output on the second edge.
            wait on DCLK;
            check_equal(LD_DAT_I, LInvert, Txt & "PRE logic 0, second half");
            
            -- Next cycle
            Cycle := Cycle + 1;
            LInvert := not LInvert;
            
            
            -- The next value is a one, so we should see a maintained first
            -- half followed by an inversion on the second half.
            wait on DCLK;
            check_equal(LD_DAT_I, LInvert, Txt & "PRE logic 1, first half");
            
            wait on DCLK;
            check_equal(LD_DAT_I, not LInvert, Txt & "PRE logic 1, second half");
            
            -- Next cycle
            Cycle := Cycle + 1;
            LInvert := not LInvert;
        end loop;
        
        
        -- TODO: use the test data to automate checking
    end process;


    -- Wishbone bus clock
    WishboneCLK: process
    begin
        wait for T_WB/2;
        WB_CLK <= not WB_CLK;
    end process;
    
    -- Line driver data clock
    DataCLK: process
    begin
        wait for T_DAT/2;
        DCLK <= not DCLK;
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
        
        DCLK        => DCLK,
        LD_DAT_O    => LD_DAT_I,
        LD_EN_O     => LD_EN_I
        );
        
end;