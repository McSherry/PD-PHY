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


-- Tests the FIFO9 FFREG architecture by taking it through a full cycle of
-- operations.
entity FIFO9_FFREG_Cycle_TB is
    generic(runner_cfg : string := runner_cfg_default);
end FIFO9_FFREG_Cycle_TB;

architecture Impl of FIFO9_FFREG_Cycle_TB is
    component FIFO9 port(
        WRCLK   : in    std_logic;
        WREQ    : in    std_logic;
        DI      : in    std_logic_vector(8 downto 0);
        FULL    : out   std_ulogic;
        FILLING : out   std_ulogic;
        WERR    : out   std_ulogic;
        
        RDCLK   : in    std_logic;
        RREQ    : in    std_logic;
        DO      : out   std_ulogic_vector(8 downto 0);
        EMPTY   : out   std_ulogic;
        RERR    : out   std_ulogic;
        
        RST     : in    std_logic
        );
    end component;
    
    -- FIFO9 signals
    signal WRCLK, WREQ, RDCLK, RREQ, RST    : std_ulogic := '0';
    signal DI                               : std_ulogic_vector(8 downto 0);
    signal FULL, FILLING, WERR, EMPTY, RERR : std_ulogic;
    signal DO                               : std_ulogic_vector(8 downto 0);
    
    -- Test internal signals
    --
    -- Signals indicating to clock-generating processes whether they should
    -- be cycling or not.
    signal Enable_WRCLK, Enable_RDCLK       : std_logic := '0';
    -- Status signals used in running a full cycle of operations on the FIFO,
    -- set to indicate that *W*rite and *R*ead processes have completed.
    signal Stim_Cycle_W, Stim_Cycle_R       : std_logic := '0';
    
    -- Test timing constants
    --
    -- These are chosen to be similar to the intended application.
    constant T_Write    : time := 100 ns;   -- 10MHz
    constant T_Read     : time := 3 us;     -- 300kHz
    
    -- Test configuration constants
    --
    -- The number of writes the 'basic_cycle' test should carry out.
    constant BC_Count   : integer := 40;
begin
    -- We need to take care of at least 40 (BC_Count) read cycles
    -- as well as however long the indeterminate time taken for the
    -- FIFO to release the status flags is. We'll assume a maximum
    -- of five cycles for now, this being the maximum for the hard
    -- block-RAM FIFO.
    test_runner_watchdog(runner, T_Read * (BC_Count + (5 * BC_Count)));


    -- This process produces the general stimulus for the test and controls the
    -- other processes which produce stimulus, where required.
    master: process
    begin
        -- Test runner prerequisites
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        

        -- Performs a full cycle of 40 writes and reads carried out at the
        -- same time with two independent clocks. Although technically FIFO
        -- capacity is unspecified, we intend that FFREG will only hold 16
        -- items and so this should be enough to fill it.
    
        -- Enable the clocks
        Enable_WRCLK    <= '1';
        Enable_RDCLK    <= '1';
        
        -- The read/write logic is in two separate processes. Here, we
        -- just wait for each process to signal completion.
        wait until Stim_Cycle_W and Stim_Cycle_R;
        
        Enable_WRCLK    <= '0';
        Enable_RDCLK    <= '0';
        
        test_runner_cleanup(runner);
    end process;
    
    -- We wire these directly rather than through a clocked process as the
    -- clocked process introduces a cycle's delay, resulting in the error flags
    -- being asserted.
    WREQ <= not FULL;
    RREQ <= not EMPTY;
    
    -- Stimulus processes for the 'basic_cycle' test
    --
    -- The write process produces 40 writes (which should fill the FIFO) and
    -- the read process gradually reads those values out. The number 40 was
    -- chosen because this should be long enough to more than cover a rising
    -- edge of the slow RDCLK.
    --
    -- Write process:
    basic_cycle_write: process
        variable Cycle : integer := 0;
    begin
        while Cycle < BC_Count loop
            -- As we're checking the flow control flags, we should never get
            -- a write error during this test.
            check_equal(WERR, '0',  "Item " & to_string(Cycle) & ", write: WERR");
        
            -- We can't write while the FIFO is full, so we have to wait until
            -- it isn't before we can proceed with our write.
            if FULL then
                wait until not FULL;
            end if;
            
            -- Load the current cycle number as data onto the input and wait
            -- for the next WRCLK cycle.
            DI   <= std_logic_vector(to_unsigned(Cycle, 9));
            wait until rising_edge(WRCLK);
            
            -- Because of how slow the read clock is in this test, once FILLING
            -- becomes asserted (which it should do after the 8th write), it
            -- should never be deasserted.
            if Cycle > 8 then
                check_equal(FILLING, '1', "Item " & to_string(Cycle) & ", write: FILLING");
            end if;
            
            -- We can only advance to the next cycle if we're going to be
            -- writing in that cycle, and we're only going to be writing if
            -- the FIFO isn't full. Avoiding this check leads to data being
            -- skipped occasionally.
            if not FULL then
                Cycle := Cycle + 1;
            end if;
        end loop;
        
        -- Indicate that we've finished.
        Stim_Cycle_W <= '1';
        
        wait;
    end process;
    -- Read process:
    basic_cycle_read: process
        variable Count : integer := 0;
    begin
        -- Rather than count cycles as in the writing process, here we count
        -- number of items we've read out the FIFO. Basically the same, though.
        while Count < BC_Count loop
            check_equal(RERR, '0',  "Item " & to_string(Count) & ", read: RERR");
        
            if not EMPTY then
                wait until rising_edge(RDCLK);
                
                -- The value we read out the FIFO should equal the number of
                -- values we've already read out, as tracked by our count.
                check_equal(DO, std_logic_vector(to_unsigned(Count, 9)), "Item " & to_string(Count) & ", read: Count");
                
                Count := Count + 1;
            end if;
            
            if EMPTY then
                wait until not EMPTY;
                wait until rising_edge(RDCLK);
            end if;
        end loop;
        
        -- Indicate we've finished.
        Stim_Cycle_R <= '1';
        
        wait;
    end process;
    
    
    -- Write clock generation process
    WriteCLK: process
    begin
        wait until Enable_WRCLK = '1';
        
        while Enable_WRCLK = '1' loop
            wait for T_Write/2;
            WRCLK <= not WRCLK;
        end loop;
    end process;
    
    
    -- Read clock generation process
    ReadCLK: process
    begin
        wait until Enable_RDCLK = '1';
        
        while Enable_RDCLK = '1' loop
            wait for T_Read/2;
            RDCLK <= not RDCLK;
        end loop;
    end process;
    
    
    UUT: entity work.FIFO9(FFREG) port map(
        WRCLK   => WRCLK,
        WREQ    => WREQ,
        DI      => DI,
        FULL    => FULL,
        FILLING => FILLING,
        WERR    => WERR,
        RDCLK   => RDCLK,
        RREQ    => RREQ,
        DO      => DO,
        EMPTY   => EMPTY,
        RERR    => RERR,
        RST     => RST
        );
end;
    