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


-- Provides tests for the FIFO9 entity's FFREG architecture.
--
-- It is likely that, when the XBRAM architecture is implemented, many of
-- these tests will be suitable for relocation into a generalised testbench.
entity FIFO9_FFREG_TB is
    generic(runner_cfg : string := runner_cfg_default);
end FIFO9_FFREG_TB;

architecture Impl of FIFO9_FFREG_TB is
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
    -- Main tests are unlikely take more than tens of read-clock cycles.
    test_runner_watchdog(runner, T_Read * 80);


    -- This process produces the general stimulus for the test and controls the
    -- other processes which produce stimulus, where required.
    master: process
    begin
        -- Test runner prerequisites
        test_runner_setup(runner, runner_cfg);
        show(get_logger(default_checker), display_handler, pass);
        
        
        -- Before we've produced any stimulus, the status flags should start
        -- at valid defaults. We don't check 'DO' because its value isn't
        -- specified before 'RREQ' has been successfully asserted.
        check_equal(FULL,       '0',    "Initial state: FULL");
        check_equal(FILLING,    '0',    "Initial state: FILLING");
        check_equal(EMPTY,      '1',    "Initial state: EMPTY");
        check_equal(WERR,       '0',    "Initial state: WERR");
        check_equal(RERR,       '0',    "Initial state: RERR");
        
        while test_suite loop
        
            -- ##########
            --
            -- A basic writing test, which first writes a single value to the
            -- FIFO and then reads it out again.
            if run("simple_write_read") then
                -- Set up write
                Enable_WRCLK    <= '1';
                WREQ            <= '1';
                DI              <= "1" & "1111" & "1001"; -- 1F9h
                
                wait until rising_edge(WRCLK);
                
                -- Clear input
                WREQ            <= '0';
                
                -- Wait to propagate
                wait until rising_edge(WRCLK);
                
                Enable_WRCLK    <= '0';
                
                -- Status check
                check_equal(FULL,       '0',    "First write: FULL");
                check_equal(FILLING,    '0',    "First write: FILLING");
                check_equal(WERR,       '0',    "First write: WERR");
                
                -- EMPTY is synchronised to RDCLK, so we need to wait for it. A
                -- signal has to pass across clock domains twice, so it will
                -- take four cycles (two per synchroniser, twice) to update.
                Enable_RDCLK    <= '1';
                wait until rising_edge(RDCLK);
                wait until rising_edge(RDCLK);
                wait until rising_edge(RDCLK);
                wait until rising_edge(RDCLK);
                Enable_RDCLK    <= '0';
                check_equal(EMPTY,      '0',    "First write: EMPTY");
                
                --Set up read
                Enable_RDCLK    <= '1';
                RREQ            <= '1';
                
                wait until rising_edge(RDCLK);
                RREQ            <= '0';
                wait until rising_edge(RDCLK);
                
                -- Clear inputs
                Enable_RDCLK    <= '0';
                
                -- Output check
                check_equal(DO, std_ulogic_vector'("111111001"), "First read: DO");
                check_equal(FULL,       '0',    "First read: FULL");
                check_equal(FILLING,    '0',    "First read: FILLING");
                check_equal(RERR,       '0',    "First read: RERR");
                
                -- Again, EMPTY is synchronised to RDCLK.
                Enable_RDCLK    <= '1';
                wait until rising_edge(RDCLK);
                check_equal(EMPTY,      '1',    "First read: EMPTY");
                Enable_RDCLK    <= '0';
                
            
            -- ##########
            --
            -- Verifies that a read error occurs if an attempt is made to read
            -- from the FIFO whilst it's empty.
            elsif run("read_error") then
                Enable_RDCLK    <= '1';
                RREQ            <= '1';
                
                -- One clock to register inputs, one to generate output.
                wait until rising_edge(RDCLK);
                wait until rising_edge(RDCLK);
                
                -- First we verify that an error is indicated
                check_equal(RERR,   '1',    "Read on empty: RERR");
                check_equal(EMPTY,  '1',    "Read on empty: EMPTY");
                
                wait until rising_edge(RDCLK);
                wait until rising_edge(RDCLK);
                
                Enable_RDCLK    <= '0';
                
                -- That the error persists while the FIFO is empty.
                check_equal(RERR, '1', "Read on empty: RERR, contd.");
                
                -- And, next, that the error disappears on a write to the FIFO.
                Enable_WRCLK    <= '1';
                WREQ            <= '1';
                DI              <= "0" & "1000" & "1111"; -- 08Fh
                
                wait until rising_edge(WRCLK);
                WREQ <= '0';
                wait until rising_edge(WRCLK);
                
                Enable_WRCLK    <= '0';
                Enable_RDCLK    <= '1';
                
                -- The functional description says that this period does not
                -- have a specified duration, so we need to clock the reading
                -- side and wait for it to release the error state.
                --
                -- A stall here will cause the watchdog to trigger, so this
                -- test remains safe even with an indeterminate wait.
                wait until RERR = '0';
                
                -- We've now written to the FIFO, so it isn't empty.
                check_equal(EMPTY, '0', "Refilled: EMPTY");
                
                -- And if we try to read, we should now get the value written
                -- above on the output.
                RREQ <= '1';
                wait until rising_edge(RDCLK);
                RREQ <= '0';
                wait until rising_edge(RDCLK);
                
                Enable_RDCLK <= '0';
                
                check_equal(EMPTY, '1', "Read after refill: EMPTY");
                check_equal(DO, std_ulogic_vector'("010001111"), "Read after refill: DO");
               
               
            -- ##########
            --
            -- Verifies that a write error occurs if an attempt is made to
            -- write to the FIFO when it is full.
            elsif run("write_error") then
                Enable_WRCLK    <= '1';
                WREQ            <= '1';
                DI              <= "111000101"; -- 1A5h
                
                -- Capacity is unspecified, so we keep writing until we receive
                -- the 'FULL' signal from the FIFO.
                wait until FULL = '1';
                
                -- check_equal(FILLING,    '1',    "Write to filled: FILLING");
                check_equal(WERR,       '0',    "Write to filled: WERR");

                -- Then, with 'WREQ' still asserted, we wait another write
                -- cycle, which should prompt a write error.
                wait until rising_edge(WRCLK);
                
                check_equal(FULL,       '1',    "Write on full: FULL");
                -- check_equal(FILLING,    '1',    "Write on full: FILLING");
                check_equal(WERR,       '1',    "Write on full: WERR");
                
                -- Similarly to the read-on-empty test, we check that the error
                -- persists while the FIFO is full.
                wait until rising_edge(WRCLK);
                
                Enable_WRCLK    <= '0';
                
                check_equal(WERR, '1', "Write on full: WERR, contd.");
                
                -- And we then read an item from the FIFO to check that this
                -- causes the error signal to be released.
                Enable_RDCLK    <= '1';
                
                -- Wait for values to cross into the read domain.
                wait until rising_edge(RDCLK);
                wait until rising_edge(RDCLK);
                
                -- Initiate read
                RREQ            <= '1';
                wait until rising_edge(RDCLK);
                RREQ            <= '0';
                wait until rising_edge(RDCLK);
                
                Enable_RDCLK    <= '0';
                Enable_WRCLK    <= '1';
                
                wait until WERR = '0';
                
                Enable_WRCLK    <= '0';
                
                -- Just helps us see the end of the wave
                wait for 1 us;
                
                check_equal(FULL, '0', "Unfilled: FULL");
                check_equal(DO, std_ulogic_vector'("111000101"), "Unfilled: DO");
                
                
            -- ##########
            --
            -- Performs a full cycle of 40 writes and reads carried out at the
            -- same time with two independent clocks. Although technically FIFO
            -- capacity is unspecified, we intend that FFREG will only hold 16
            -- items and so this should be enough to fill it.
            elsif run("basic_cycle") then
                -- We need to take care of at least 40 (BC_Count) read cycles
                -- as well as however long the indeterminate time taken for the
                -- FIFO to release the status flags is. We'll assume a maximum
                -- of five cycles for now, this being the maximum for the hard
                -- block-RAM FIFO.
                set_timeout(runner, T_Read * (BC_Count + (5 * BC_Count)));
            
                -- Enable the clocks
                Enable_WRCLK    <= '1';
                Enable_RDCLK    <= '1';
                
                -- Ensure we aren't driving DI, allowing our other processes to
                -- drive it for us.
                DI              <= (others => 'Z');
                WREQ            <= 'Z';
                RREQ            <= 'Z';
                RST             <= 'Z';
                
                -- The read/write logic is in two separate processes. Here, we
                -- just wait for each process to signal completion.
                wait until Stim_Cycle_W and Stim_Cycle_R;
                
                Enable_WRCLK    <= '0';
                Enable_RDCLK    <= '0';
            
            
            -- ##########
            --
            -- Loads a single value into the FIFO and resets it, testing that the
            -- FIFO is cleared in the manner expected.
            elsif run("reset_basic") then
                Enable_WRCLK    <= '1';
                WREQ            <= '1';
                DI              <= "101010101"; -- 155h
                
                wait until rising_edge(WRCLK);
                
                WREQ    <= '0';
                RST     <= '1';
                
                check_equal(EMPTY, '0', "Basic reset, pre-signal: EMPTY");
                
                -- The time for a reset to take effect is indeterminate, so we
                -- have to wait for the FIFO to indicate it is empty.
                wait until not EMPTY;
                
                -- There isn't really anything to test. Nothing externally
                -- indicates that the FIFO has returned to its initial state.
                
                Enable_WRCLK    <= '0';
            end if;
        
        end loop;
        
        test_runner_cleanup(runner);
    end process;
    
    
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
        -- if running_test_case = "basic_cycle" then
            -- while Cycle < BC_Count loop
                -- -- We should never prompt a write error while doing this.
                -- check_equal(WERR, '0', "Basic cycle, write: WERR");
            
                -- -- We simply keep writing until we fill the FIFO.
                -- if not FULL then
                    -- -- We write a value equivalent to the cycle number each time.
                    -- WREQ <= '1';
                    -- DI   <= std_logic_vector(to_unsigned(Cycle, 9));
                    
                    -- wait until rising_edge(WRCLK);
                -- else
                    -- WREQ <= '0';
                -- end if;
                
                -- Cycle := Cycle + 1;
                
                -- -- If the FIFO is full but we haven't finished, wait until it is no
                -- -- longer full before we continue to write.
                -- if FULL then
                    -- wait until not FULL;
                -- end if;
            -- end loop;
        -- else
            -- DI <= (others => 'Z');
            -- WREQ <= 'Z';
            -- RREQ <= 'Z';
            -- RST <= 'Z';
        -- end if;
        
        wait;
    end process;
    -- Read process:
    basic_cycle_read: process
        variable Count : integer := 0;
    begin
        -- if running_test_case = "basic_cycle" then
            -- -- Rather than count cycles as in the writing process, here we count
            -- -- number of items we've read out the FIFO. Basically the same, though.
            -- while Count /= BC_Count - 1 loop
                -- check_equal('0', RERR,  "Basic cycle, read: RERR");
            
                -- if not EMPTY then
                    -- RREQ <= '1';
                    
                    -- wait until rising_edge(RDCLK);
                    
                    -- -- The value we read out the FIFO should equal the number of
                    -- -- values we've already read out, as tracked by our count.
                    -- check_equal(DO, std_logic_vector(to_unsigned(Count, 9)), "Basic cycle, read: Count");
                    
                    -- Count := Count + 1;
                -- else
                    -- RREQ <= '0';
                -- end if;
                
                -- if EMPTY then
                    -- wait until not EMPTY;
                -- end if;
            -- end loop;
        -- else
            -- RREQ            <= 'Z';
            -- RST             <= 'Z';
        -- end if;
        
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
    