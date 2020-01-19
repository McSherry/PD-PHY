-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;


-- Provides an asynchronous first-in first-out (FIFO) buffer which stores 9-bit
-- words and exposes an interface largely compatible with Xilinx block RAMs.
entity FIFO9 is
port(
    -- Write clock
    --      Used to synchronise writes to the FIFO.
    WRCLK   : in    std_logic;
    -- Write request
    --      Indicates that data to be written to the FIFO is present on [DI].
    WREQ    : in    std_logic;
    -- Data input
    DI      : in    std_logic_vector(8 downto 0);
    -- FIFO full status indicator
    FULL    : out   std_ulogic := '0';
    -- FIFO filling status indicator
    --      Indicates that the FIFO is half or more full.
    FILLING : out   std_ulogic := '0';
    -- Write error
    --      Asserted when an attempt to write to the FIFO is made while the
    --      FIFO is full.
    WERR    : out   std_ulogic := '0';
    
    -- Read clock
    --      Used to synchronise reads to the FIFO.
    RDCLK   : in    std_logic;
    -- Read request
    --      Signals for data to be read from the FIFO onto [DO].
    RREQ    : in    std_logic;
    -- Data output
    DO      : out   std_ulogic_vector(8 downto 0) := (others => '0');
    -- FIFO empty status indicator
    EMPTY   : out   std_ulogic := '1';
    -- Read error
    --      Asserted when an attempt is made to read from the FIFO while the
    --      FIFO is empty.
    RERR    : out   std_ulogic := '0';
    
    -- Reset
    --      Clears the FIFO and returns it to its initial state.
    RST     : in    std_logic
    );
end FIFO9;


-- Encapsulates a Xilinx 7-series FPGA block RAM.
architecture XBRAM of FIFO9 is
begin
    assert false report "FIFO9<XBRAM> not implemented" severity failure;
end;


-- Implements a FIFO9 where the data storage elements are synthesised in the
-- FPGA fabric rather than in a hardened component.
architecture FFREG of FIFO9 is
    -- Synchronising FFs
    component CD2FF
        generic(
            W       : integer;
            DEFAULT : std_ulogic_vector((W - 1) downto 0)
            );
        port(
            CLK     : in    std_logic;
            D       : in    std_logic_vector((W - 1) downto 0);
            Q       : out   std_ulogic_vector((W - 1) downto 0)
            );
    end component;
    
    -- Gray code generation
    component GrayGenerator5b port(
        CLK     : in    std_logic;
        EN      : in    std_logic;
        RST     : in    std_logic;
        Q       : out   std_ulogic_vector(4 downto 0)
        );
    end component;


    -- The size of the words stored by the FIFO, in bits.
    constant WordSize   : integer := 9;
    -- The number of words the FIFO can store.
    constant Depth      : integer := 16;
    
    -- The backing register that forms the storage for the FIFO.
    signal RAM      : std_ulogic_vector((WordSize * Depth) - 1 downto 0) := (others => '0');
    
    -- Write-domain signals
    --
    -- The pointer to the next location in the FIFO to be written to.
    signal WPtr_Next    : std_ulogic_vector(4 downto 0);
    -- A signal, connected to the address generator, which indicates whether
    -- the next write address is to be generated.
    signal WPtr_Gen     : std_ulogic := '0';
    -- A synchronised version of the read pointer 'RPtr_Next'.
    signal WS_RPtr_Next : std_ulogic_vector(4 downto 0);
    -- Whether the write pointer has wrapped around; alternates with each wrap.
    signal W_Wrapped    : std_ulogic;
    -- A synchronised version of the 'R_Wrapped' signal.
    signal WS_R_Wrapped : std_ulogic;
    
    -- Read-domain signals
    --
    -- The pointer to the next location in the FIFO to read.
    signal RPtr_Next    : std_ulogic_vector(4 downto 0);
    -- A signal, connected to the address generator, which indicates whether
    -- the next read address is to be generated.
    signal RPtr_Gen     : std_ulogic := '0';
    -- A synchronised version of the write pointer 'WPtr_Next'.
    signal RS_WPtr_Next : std_ulogic_vector(4 downto 0) := "00000";
    -- A synchronised version of the 'WPtr_Reset' signal, used to reset the
    -- read pointer 'RPtr_Next' to zero.
    signal RS_RST       : std_ulogic;
    -- Whether the read pointer has wrapped around; alternates with each wrap.
    signal R_Wrapped    : std_ulogic;
    
begin
    -- This process provides clocked write-domain functionality.
    write_domain: process(WRCLK)
        variable ADDRESS    : integer;
    begin
        if rising_edge(WRCLK) then
            -- If we're full and receive a write request, that's an error.
            WERR <= FULL and WREQ;

            -- If we receive a request to write while we're not full, we
            -- service it.
            if WREQ = '1' and FULL = '0' then
                ADDRESS := WordSize * to_integer(unsigned(
                    -- To produce 4-bit Gray-coded addresses from 5-bit Gray
                    -- codes, the resulting MSB is the XOR of the two input
                    -- MSBs. This is a result of the 'reflect and prepend'
                    -- method used to generate the codes.
                    (WPtr_Next(4) xor WPtr_Next(3)) &
                    -- The remaining bits of the Gray code are used as-is.
                    WPtr_Next(2 downto 0)
                    ));
                    
                RAM(ADDRESS + WordSize - 1 downto ADDRESS) <= DI;
            end if;
        end if;
    end process;
    
    -- The wrap indicator is encoded in the Gray code MSB.
    W_Wrapped <= WPtr_Next(4);
    
    -- Detecting the 'full' condition is more complex. As Cummings sets
    -- out, there are three criteria to be fulfilled:
    --
    --                  1. The write pointer has wrapped one more time
    --                     than the read pointer (so the wrap indicators
    --                     are not equal)
    FULL <= '1' when (W_Wrapped /= WS_R_Wrapped) and
    --                  2. The 2nd MSBs of the pointers are not the same,
    --                     which is a necessary part of a Gray equality
    --                     test. Generating a Gray code requires reversing
    --                     the bit order of less-significant bits before
    --                     adding a '1' MSB. Thus, as the order of the
    --                     second half is the reverse of the first, and
    --                     because the reverse-append process is performed
    --                     iteratively, wrapped and unwrapped pointers will
    --                     differ only by their 1st and 2nd MSBs.
                     (WPtr_Next(3) /= WS_RPtr_Next(3)) and
    --                  3. Hence, the remaining comparison is to check the
    --                     equality of the remaining low-order bits.
                     (WPtr_Next(2 downto 0) = WS_RPtr_Next(2 downto 0))
                else '0';
    
    -- We only want to advance the write pointer if a write is successful, and
    -- we can tell when that happens by looking for write requests which don't
    -- prompt the generation of an error signal.
    WPtr_Gen <= '1' when WREQ = '1' and WERR = '0' else '0';
    
    
    -- This process provides clocked read-domain functionality.
    read_domain: process(RDCLK)
    
        variable ADDRESS    : integer;
    begin
        if rising_edge(RDCLK) then
            
            -- The wrap indicator is encoded in the Gray code MSB.
            R_Wrapped <= RPtr_Next(4);            
            
            -- If we receive a request to read and we aren't empty, service
            -- the request.
            if RREQ = '1' and EMPTY = '0' then
                ADDRESS := WordSize * to_integer(unsigned(
                    -- To produce 4-bit Gray-coded addresses from 5-bit Gray
                    -- codes, the resulting MSB is the XOR of the two input
                    -- MSBs. This is a result of the 'reflect and prepend'
                    -- method used to generate the codes.
                    (RPtr_Next(4) xor RPtr_Next(3)) &
                    -- The remaining bits of the Gray code are used as-is.
                    RPtr_Next(2 downto 0)
                    ));
                    
                DO <= RAM(ADDRESS + WordSize - 1 downto ADDRESS);
            end if;
        end if;
    end process;
    
    -- We're empty if the read and write pointers are equal, because this
    -- indicates that the read pointer has 'caught' the write pointer.
    EMPTY <= '0' when RST = '1'                 else
             '1' when RPtr_Next = RS_WPtr_Next  else
             '0';

    -- If we're empty and receive a read request, that's an error.
    RERR <= '0' when RST = '1'      else
            '1' when EMPTY and RREQ else
            '0';
    
    -- We want to advance the read pointer after a successful read, i.e. after
    -- we have a read request that didn't result in an error being generated.
    RPtr_Gen <= '1' when RREQ = '1' and RERR = '0' else '0';


    -- Gray code generator to produce the next value of the write pointer
    WPtrNextGen: GrayGenerator5b port map(
        CLK     => WRCLK,
        EN      => WPtr_Gen,
        Q       => WPtr_Next,
        RST     => RST
        );
        
    -- Gray code generator to produce the next value of the read pointer
    RPtrNextGen: GrayGenerator5b port map(
        CLK     => RDCLK,
        EN      => RPtr_Gen,
        Q       => RPtr_Next,
        RST     => RS_RST
        );
        
    -- Write-domain synchroniser for the read pointer
    Sync_WS_RPtr_Next: CD2FF
        generic map(W => 5, DEFAULT => (others => '0'))
        port map(
            CLK => WRCLK,
            D   => RPtr_Next,
            Q   => WS_RPtr_Next
            );
            
    -- Write-domain synchroniser for the read-wrapped signal
    Sync_WS_R_Wrapped: CD2FF
        generic map(W => 1, DEFAULT => (others => '0'))
        port map(
            CLK  => WRCLK,
            D(0) => R_Wrapped,
            Q(0) => WS_R_Wrapped
            );
        
    -- Read-domain synchroniser for the reset signal
    Sync_RS_WPtr_Reset: CD2FF
        generic map(W => 1, DEFAULT => (others => '0'))
        port map(
            CLK  => RDCLK,
            D(0) => RST,
            Q(0) => RS_RST
            );
            
    -- Read-domain synchroniser for the write pointer
    Sync_RS_WPtr_Next: CD2FF
        generic map(W => 5, DEFAULT => (others => '0'))
        port map(
            CLK => RDCLK,
            D   => WPtr_Next,
            Q   => RS_WPtr_Next
            );
end;
