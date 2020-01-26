-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- A control unit which translates requests from a Wishbone bus into the form
-- required to operate a biphase mark code transmitter.
--
-- Related:
--      ./BiphaseMarkDriver.vhd
--      ./PDPreambleGen.vhd
--      ./Encoder4b5b.vhd
--      ./FIFO9.vhd
entity BiphaseMarkTransmitter is
port(
    -- Wishbone clock
    --      The clock used by the Wishbone bus, equivalent to 'CLK_I' in the
    --      Wishbone B4 specification.
    WB_CLK      : in    std_logic;
    -- Data clock
    --      The clock which sets the data rate at which the BMC transmitter
    --      operates. One clock cycle is one unit interval.
    DCLK        : in    std_logic;
    
    -- Wishbone reset input
    WB_RST_I    : in    std_logic;
    
    -- Wishbone address input port
    WB_ADR_I    : in    std_logic_vector(1 downto 0);
    -- Wishbone data input port
    WB_DAT_I    : in    std_logic_vector(7 downto 0);
    -- Wishbone cycle input
    WB_CYC_I    : in    std_logic;
    -- Wishbone strobe (slave select) input
    WB_STB_I    : in    std_logic;
    -- Wishbone write-enable input
    WB_WE_I     : in    std_logic;
    
    -- Wishbone data output port
    WB_DAT_O    : out   std_ulogic_vector(7 downto 0) := (others => '-');
    -- Wishbone acknowledge output
    WB_ACK_O    : out   std_ulogic := '0';
    -- Wishbone error output
    WB_ERR_O    : out   std_ulogic := '0';
    
    -- Line driver data output
    --      A data output which, when enabled, indicates the output that should
    --      be driven onto the line. Operates at double the data clock rate.
    LD_DAT_O    : out   std_ulogic := '-';
    -- Line driver enable
    --      Indicates when the line driver should be enabled. In a practical
    --      application, disabling the line driver may tristate it.
    LD_EN_O     : out   std_ulogic := '0'
    );
end BiphaseMarkTransmitter;

architecture Impl of BiphaseMarkTransmitter is
    component CD2FF
        generic(
            W       : integer;
            INITIAL : std_ulogic_vector((W - 1) downto 0)
            );
        port(
            CLK     : in    std_logic;
            D       : in    std_logic_vector((W - 1) downto 0);
            Q       : out   std_ulogic_vector((W - 1) downto 0)
            );
    end component;

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

    component PDPreambleGen port(
        CLK     : in    std_logic;
        TRIG    : in    std_logic;
        RST     : in    std_logic;
        Q       : out   std_ulogic;
        FIN     : out   std_ulogic
        );
    end component;

    component Encoder4b5b port(
        CLK     : in    std_logic;
        WE      : in    std_logic;
        K       : in    std_logic;
        ARG     : in    std_logic_vector(3 downto 0);
        Q       : out   std_ulogic_vector(4 downto 0)
        );
    end component;

    component BiphaseMarkDriver port(
        CLK     : in    std_logic;
        D       : in    std_logic;
        WE      : in    std_logic;
        Q       : out   std_ulogic;
        OE      : out   std_ulogic
        );
    end component;
    
    -- Wishbone-readable registers
    signal REG_STATUS, REG_ERRNO    : std_ulogic_vector(7 downto 0) := (others => '0');
    
    -- Used to pre-set the 'EMPTY' flag before changes propagate across a clock
    -- domain boundary.
    --
    -- This allows the 'EMPTY' flag in the STATUS register to change
    -- immediately on a write. Without this, it would take at least one data
    -- clock cycle and two Wishbone clock cycles before a change could occur
    -- and be registered in the Wishbone domain.
    --
    -- Forces 'EMPTY' low when set.
    signal EMPTY_PRE    : std_ulogic := '0';
    
    -- Wishbone-domain-synchronised signals
    --
    -- The FIFO 'EMPTY' status flag.
    signal WBS_EMPTY    : std_logic := '1';
    -- The line driver 'output enable' signal.
    signal WBS_LD_EN    : std_logic := '0';
    
    -- FIFO write-domain signals
    signal BUF_WREQ     : std_ulogic := '0';
    signal BUF_DI       : std_ulogic_vector(8 downto 0);
    signal BUF_FULL     : std_logic;
    signal BUF_FILLING  : std_logic;
    signal BUF_WERR     : std_logic;
    
    -- FIFO read-domain signals
    signal BUF_RREQ     : std_ulogic := '0';
    signal BUF_DO       : std_ulogic_vector(8 downto 0);
    signal BUF_EMPTY    : std_logic;
    signal BUF_RERR     : std_logic;
    
    -- Line driver-domain preamble generator signals
    --
    -- Trigger, starts the generator
    signal PAG_TRIG     : std_ulogic := '0';
    -- Final bit, indicates when the last bit in the preamble is on the
    -- generator's output.
    signal PAG_FINAL    : std_logic;
    -- Generator output
    signal PAG_OUTPUT   : std_logic;
    
    -- Line driver-domain line coder signals
    --
    -- Write enable
    signal LENC_WE      : std_ulogic := '0';
    -- K-code or data indicator
    signal LENC_IS_K    : std_ulogic := '0';
    -- Half-byte to encode
    signal LENC_IN      : std_ulogic_vector(3 downto 0) := "0000";
    -- Line encoder multiplexer control
    --      '0' connects to the lower half of the TX buffer output, and '1'
    --      connects to the upper half.
    signal LENC_MUX     : std_ulogic := '0';
    -- Encoder output
    signal LENC_OUT     : std_ulogic_vector(4 downto 0);
    -- Encoder output shift register
    --      Because we can only send one bit at a time, we need to work through
    --      the output of the encoder bit by bit. This is easiest if we add a
    --      shift register onto the encoder's output.
    signal LENC_OUT_SR  : std_ulogic_vector(4 downto 0);
    
    -- Line driver control signals
    --
    -- Line driver data input
    signal LD_IN        : std_ulogic := '0';
    -- Line driver write enable
    signal LD_WE        : std_ulogic := '0';
    -- Line driver multiplexer control
    --      '0' connects to the preamble generator, '1' to the shift register.
    signal LD_MUX       : std_ulogic := '0';
    
    -- Line driver-synchronised reset
    signal LDS_WB_RST_I : std_ulogic := '0';
    
    -- Status flag offsets
    constant FLAG_FULL      : integer := 0;
    constant FLAG_FILLING   : integer := 1;
    constant FLAG_EMPTY     : integer := 2;
    
    -- Multiplexer addresses
    constant LD_MUX_PREAMBLE    : std_logic := '0';
    constant LD_MUX_ENCODE_REG  : std_logic := '1';
    constant LENC_MUX_LO        : std_logic := '0';
    constant LENC_MUX_HI        : std_logic := '1';
begin

    -- The design of the transmitter is relatively simple. The two main pieces
    -- are divided across clock domains and communicate through the FIFO, and
    -- so they can operate entirely independently of one another.
    --
    -- The Wishbone-side logic is only responsible for interpreting activity on
    -- the bus, shuffling data into the FIFO, and maintaining status registers.
    wishbone_slave: process(WB_CLK)    
        -- Error codes
        constant ERR_BUS        : std_ulogic_vector(7 downto 0) := x"00";
        constant ERR_BADREG     : std_ulogic_vector(7 downto 0) := x"01";
        constant ERR_NOTSUPPT   : std_ulogic_vector(7 downto 0) := x"02";
        constant ERR_BADKCODE   : std_ulogic_vector(7 downto 0) := x"80";
        constant ERR_TXOVERFL   : std_ulogic_vector(7 downto 0) := x"81";
    begin
    
        if rising_edge(WB_CLK) then
            -- We reset internal control signals on every cycle. This may not
            -- be the most elegant way of doing it, but it saves repeating the
            -- same logic over and over.
            --
            -- Wishbone signals are dealt with further down as the Wishbone
            -- specification sets requirements as to their deassertion (see,
            -- for example, rule 3.50).
            BUF_WREQ    <= '0';
            
            -- If the synchronised 'EMPTY' signal is now low, we can clear our
            -- override and let the synchronised value be used.
            if WBS_EMPTY = '0' then
                EMPTY_PRE <= '0';
            end if;
        
        
            -- If we're being reset...
            if WB_RST_I = '1' then
                WB_ACK_O    <= '0';
                WB_ERR_O    <= '0';
                EMPTY_PRE   <= '0';
                
                
            -- If a cycle is ongoing and our strobe input has been asserted,
            -- then a Wishbone master has requested we do something.
            elsif WB_CYC_I = '1' and WB_STB_I = '1' then
            
                -- We expose a set of registers to the bus, so what we do
                -- depends on which register the master wants to access.
                case WB_ADR_I is
                
                    -- KWRITE is used to write K-codes to the transmit buffer
                    when "00" =>
                        -- If this isn't a write request, it is invalid. Reads
                        -- from the KWRITE register aren't permitted.
                        if WB_WE_I /= '1' then
                            WB_ERR_O    <= '1';
                            REG_ERRNO   <= ERR_NOTSUPPT;
                    
                        -- Only six K-codes are defined, so if we get any other
                        -- value it's invalid.
                        elsif unsigned(WB_DAT_I) >= 6 then
                            WB_ERR_O    <= '1';
                            REG_ERRNO   <= ERR_BADKCODE;
                                
                        -- Otherwise, we should have a valid request to write to
                        -- the register. We simply write our input to the FIFO
                        -- and set the MSB to indicate it's a K-code.
                        else
                            -- We're writing a K-code, so we store a high MSB in
                            -- the FIFO to indicate to the line driver's encoder.
                            BUF_DI(8)   <= '1';
                            -- We want to request a write to the FIFO
                            BUF_WREQ    <= '1';
                            -- We want to acknowledge the request
                            WB_ACK_O    <= '1';
                            -- We want to pre-change the 'EMPTY' flag, so that
                            -- our consumer sees an instant change.
                            EMPTY_PRE   <= '1';
                        end if;
                        
                    -- DWRITE is used to add raw data to the transmit buffer
                    when "01" =>
                        -- As above, DWRITE is write-only and so a request to
                        -- read from it is invalid.
                        if WB_WE_I /= '1' then
                            WB_ERR_O    <= '1';
                            REG_ERRNO   <= ERR_NOTSUPPT;
                        
                        -- But, otherwise, any data is permitted.
                        else
                            -- We're writing raw data, so the K-code flag in
                            -- the FIFO word is unset.
                            BUF_DI(8)   <= '0';
                            -- We're writing to the FIFO
                            BUF_WREQ    <= '1';
                            -- And we want to acknowledge the request
                            WB_ACK_O    <= '1';
                            -- We want to pre-change the 'EMPTY' flag, so that
                            -- our consumer sees an instant change.
                            EMPTY_PRE   <= '1';
                        end if;
                        
                    -- We reuse this address depending on the operation. It is
                    -- either the STATUS register, or the BIST register.
                    when "10" =>
                        -- If a write has been requested, we're accessing the
                        -- BIST register. This isn't functionality we really
                        -- need at the moment, so it is unimplemented for now.
                        if WB_WE_I = '1' then
                            assert false report "Not yet implemented.";
                            
                        -- Otherwise, we're reading the current STATUS register
                        -- and so just place it on the data bus.
                        else
                            -- Write the status register to the bus
                            WB_DAT_O    <= REG_STATUS;
                            -- Acknowledge the request
                            WB_ACK_O    <= '1';
                        end if;
                        
                    -- The ERRNO register stores an error code indicating the
                    -- last reason 'WB_ERR_O' was asserted. It is read-only.
                    when "11" =>
                        if WB_WE_I = '1' then
                            WB_ERR_O    <= '1';
                            REG_ERRNO   <= ERR_NOTSUPPT;
                        else
                            WB_ACK_O    <= '1';
                            WB_DAT_O    <= REG_ERRNO;
                        end if;
                        
                    when others =>
                        assert false report "Invalid address value";
                        
                end case;
            
            -- If STB_I is deasserted, the Wishbone spec requires that we
            -- deassert some of our bus signals.
            elsif WB_STB_I = '0' then
                WB_ACK_O    <= '0';
                WB_ERR_O    <= '0';
            end if;
        end if;
    end process;
    
    -- We permanently connect the 7 LSBs of our FIFO's data input to the
    -- equivalent bits of our Wishbone data bus.
    BUF_DI(7 downto 0) <= WB_DAT_I;
    
    -- Our status flags register
    --
    -- FULL and FILLING we can simply connect directly to the FIFO.
    REG_STATUS(FLAG_FULL)       <= BUF_FULL;
    REG_STATUS(FLAG_FILLING)    <= BUF_FILLING;    
    -- We only want to indicate empty (i.e. that a transaction has ended) if
    -- the TX buffer is empty and the line driver is no longer driving. This
    -- isn't necessary internally, but may be useful for any external logic.
    REG_STATUS(FLAG_EMPTY)      <= '0' when EMPTY_PRE = '1' 
                                       else WBS_EMPTY and not WBS_LD_EN;
    -- The remaining bits we keep held at zero.
    REG_STATUS(7 downto 3)      <= (others => '0');
    
    
    
    -- The line driver-side logic, while relatively more complex, remains quite
    -- simple. The core of its job is pulling data from the FIFO and directing
    -- it to the line driver. However, it must co-ordinate with the premable
    -- generator, and needs to stall FIFO reads as appropriate--the FIFO has a
    -- 9-bit data output, up to eight bits of which are data. That data must be
    -- line-coded in two four-bit halves and, because the line driver transmits
    -- only a single bit at a time, it must wait until each half is transmitted
    -- before advancing.
    line_driving: process(DCLK)
        type LDState_t is (
            -- State 1: Idle
            --      The line-driving domain is waiting until a write is made to
            --      the TX buffer, which will signal transmission start.
            S1_Idle,
            
            -- State 2: Preamble wait
            --      The line-driving domain is waiting for the USB-PD preamble
            --      to complete before it begins sending data.
            S2_PreWaiting,
            
            -- State 3: Shifting out data
            --      The line-driving domain is working through the encoded
            --      output in the shift register.
            --
            --      It isn't very elegant, but we have one state for each shift
            --      that we perform. This should avoid a completely separate
            --      counter just for this.
            S3_ShiftOut1,
            S3_ShiftOut2,
            S3_ShiftOut3,
            S3_ShiftOut4,
            S3_ShiftOut5,
            
            -- State 4: Waiting for complete
            --      The line-driving domain is waiting for the line driver to
            --      finish the transmission before it returns to idle.
            S4_FinishWait
            );
            
        variable State : LDState_t := S1_Idle;
        
        -- Indicates whether, during a transmission, the shift-to-output loop
        -- is on the higher half of the last word read from the TX buffer. This
        -- aids in determining when to end a transmission.
        variable IS_LAST : std_logic := '0';
    begin
    
        if rising_edge(DCLK) then
        
            case State is
                
                -- #########
                --
                -- When we're idling, we're waiting for a transmission to
                -- start. This is indicated by a write to the TX buffer.
                when S1_Idle =>
                    -- If we're no longer empty, then our transmission has
                    -- started.
                    if BUF_EMPTY = '0' then
                        -- As each transmission starts with a premable, we now
                        -- have to transition to a state where we wait for it
                        -- to finish.
                        State       := S2_PreWaiting;
                        -- We trigger the preamble generator so it can begin
                        -- our transmission.
                        PAG_TRIG    <= '1';
                        -- We connect the preamble generator to the line driver
                        -- and indicate that a write is present.
                        LD_MUX      <= LD_MUX_PREAMBLE;
                        LD_WE       <= '1';
                        -- So we can begin preparing our output, we request the
                        -- first byte of data from the buffer.
                        BUF_RREQ    <= '1';
                    end if;
                    
                -- ##########
                --
                -- When we're waiting for the preamble to complete, there isn't
                -- really anything for us to do.
                when S2_PreWaiting =>
                    -- We deassert the trigger. It only needs to be asserted
                    -- for a single cycle.
                    PAG_TRIG    <= '0';
                    
                    -- We've got the first byte of data to prepare with, but
                    -- we can't move on until the preamble is finished. We
                    -- don't want to read out any more data for now.
                    BUF_RREQ    <= '0';
                    
                    -- We feed the lowest four bits of our data into our line
                    -- encoder so its output is ready well in advance.
                    LENC_WE     <= '1';
                    LENC_MUX    <= LENC_MUX_LO;
                    -- And load our shift register with its output.
                    LENC_OUT_SR <= LENC_OUT;
                
                    -- Otherwise, all we need to do is wait for the preamble to
                    -- complete, which is indicated by the 'FINAL' output from
                    -- the generator. The next cycle after that is asserted is
                    -- when we should begin sending data.
                    if PAG_FINAL = '1' then
                        -- Move into a transmitting state. As we're setting up
                        -- the first bit, we move into the second of the
                        -- shifting states.
                        State   := S3_ShiftOut1;
                        -- We now connect the line driver to the LSB of our
                        -- shift register containing encoder output.
                        LD_MUX  <= LD_MUX_ENCODE_REG;
                        -- And shift.
                        -- LENC_OUT_SR <= "0" & LENC_OUT_SR(4 downto 1);
                    end if;
                
                -- ##########
                --
                -- We can only transmit one bit at a time, so we need to work
                -- through each 5-bit symbol using a shift register.
                when S3_ShiftOut1 to S3_ShiftOut5 =>
                    -- All we do in this state, really, is shift the output
                    -- register by one position.
                    LENC_OUT_SR <= "0" & LENC_OUT_SR(4 downto 1);
                    
                    if State = S3_ShiftOut1 then
                        State       := S3_ShiftOut2;
                        
                    -- Loading data ready for transmission has a few cycles of
                    -- delay, so we need to start preparing when we reach the
                    -- second bit of five in the shift register.
                    elsif State = S3_ShiftOut2 then
                        -- If we're dealing with a K-code, we need to request
                        -- the next word to be transmitted from the buffer.
                        --
                        -- Alternatively, if we're dealing with raw data and
                        -- we're on the upper half of the current byte, we need
                        -- to do the same.
                        if BUF_EMPTY = '0' and (LENC_IS_K = '1' or LENC_MUX = LENC_MUX_HI) then
                            BUF_RREQ    <= '1';
                            -- If we're loading in a new word of data, we want
                            -- its lower half to be encoded, so we need to
                            -- switch the encoder's mux back. If we're on a
                            -- K-code, this is redundant and has no effect.
                            LENC_MUX    <= LENC_MUX_LO;
                        
                        -- If we're dealing with raw data and we're on the
                        -- lower half of the byte, we just need to switch the
                        -- line encoder's MUX so it encodes the right part.
                        --
                        -- Although we'll also reach this point if the buffer
                        -- is empty, it will either switch the mux from low to
                        -- high (for data) or have no effect (for K-codes), and
                        -- so we'll continue correctly.
                        else
                            LENC_MUX    <= LENC_MUX_HI;
                            
                            -- If the buffer is empty, we've just switched to
                            -- the higher half of the last word. We need to
                            -- indicate that this is the last bit of data so
                            -- that we can finish up the transaction.
                            IS_LAST     := BUF_EMPTY;
                        end if;
                        
                        State       := S3_ShiftOut3;
                    
                    -- If we're getting a new value from the TX buffer, we only
                    -- want one. We need to expressly stop requesting data.
                    elsif State = S3_ShiftOut3 then
                        BUF_RREQ    <= '0';
                        State       := S3_ShiftOut4;
                        
                    elsif State = S3_ShiftOut4 then
                        State       := S3_ShiftOut5;
                    
                    -- When we're sending the final bit in the shift register,
                    -- there are several possible situations we could be in:
                    --
                    --  o If we were sending a K-code, we will have loaded in
                    --    new data from the buffer and it will be ready
                    --
                    --  o If we're sending raw data, we could have finished
                    --    sending its lower half and the encoder will have its
                    --    higher half ready for us
                    --
                    --  o If we're sending raw data, we could have finished
                    --    sending its higher half and we may have more data to
                    --    send, which will be ready encoded for us
                    --
                    --  o If we're sending raw data, we could have finished
                    --    its higher half and emptied the TX buffer, meaning we
                    --    now need to end the transmission
                    --
                    -- Thankfully, our previous states mean that handling the
                    -- first three situations is simple: as the data is ready
                    -- for us, we reload the shift register and repeat.
                    --
                    -- The last situation will have been detected in a previous
                    -- state, setting a flag. In that case, we start cleaning
                    -- up and wait for the driver to finish. Depending on what
                    -- we sent, the driver may hold the line active for a
                    -- number of cycles, and we can't start a new transmission
                    -- until that process has completed.
                    elsif State = S3_ShiftOut5 then
                        -- If this isn't the higher half of the last word out
                        -- of the buffer...
                        if IS_LAST = '0' then
                            -- Then either we've loaded new data or have moved
                            -- onto the higher half of existing data, and so
                            -- we just reload the shift register and repeat.
                            LENC_OUT_SR <= LENC_OUT;
                            State       := S3_ShiftOut1;
                            
                        -- Alternatively, if it is...
                        else
                            -- -- We disable the line driver and encoder
                            LD_WE   <= '0';
                            LENC_WE <= '0';
                            -- -- Reset the 'is last' flag
                            IS_LAST := '0';
                            -- -- And wait for the driver to finish up
                            State   := S4_FinishWait;
                        end if;
                    end if;
                
                
                -- ##########
                --
                -- Waits for the line driver to end the transmission.
                when S4_FinishWait =>
                    -- Although this will introduce a cycle's delay extra into
                    -- returning to idle, it's safe to do because writing to
                    -- the TX buffer happens independently of our state and the
                    -- trigger event ('EMPTY' being asserted) will persist
                    -- until we do something about it.
                    if LD_EN_O = '0' then
                        State := S1_Idle;
                    end if;
            end case;
            
            
            -- If we're being reset, return to the idle state and reset all
            -- our control signals
            if LDS_WB_RST_I = '1' then
                State       := S1_Idle;
                IS_LAST     := '0';
                BUF_RREQ    <= '0';
                PAG_TRIG    <= '0';
                LD_WE       <= '0';
                LD_MUX      <= LD_MUX_PREAMBLE;
                LENC_WE     <= '0';
                LENC_MUX    <= LENC_MUX_LO;
            end if;
        end if;
    
    end process;
    
    -- Our TX buffer stores 9-bit words, and we use the MSB to indicate whether
    -- the lower 8 bits contain raw data or a K-code. This means we can connect
    -- that bit to our line encoder permanently.
    LENC_IS_K   <= BUF_DO(8);
    
    -- The line encoder can encode either the lower or upper half-byte of the TX
    -- buffer's output
    LENC_IN     <= BUF_DO(3 downto 0) when LENC_MUX = LENC_MUX_LO
                                      else BUF_DO(7 downto 4);
    
    -- The line driver can be connected either to the preamble generator or to
    -- the line encoder's shift register.
    LD_IN       <= PAG_OUTPUT when LD_MUX = LD_MUX_PREAMBLE else LENC_OUT_SR(0);


    -- The FIFO that provides the TX buffer
    BUF: entity work.FIFO9(FFREG) port map(
        WRCLK   => WB_CLK,
        WREQ    => BUF_WREQ,
        DI      => BUF_DI,
        FULL    => BUF_FULL,
        FILLING => BUF_FILLING,
        WERR    => BUF_WERR,
        
        RST     => WB_RST_I,
        
        RDCLK   => DCLK,
        RREQ    => BUF_RREQ,
        DO      => BUF_DO,
        EMPTY   => BUF_EMPTY,
        RERR    => BUF_RERR
        );
        
    -- Wishbone-domain synchroniser for the FIFO 'EMPTY' status flag
    Sync_WBS_EMPTY: CD2FF
        generic map(W => 1, INITIAL => (others => '1'))
        port map(
            CLK  => WB_CLK,
            D(0) => BUF_EMPTY,
            Q(0) => WBS_EMPTY
            );
            
    -- Wishbone-domain synchroniser for the 'line driver output enable' signal.
    Sync_WBS_LD_EN: CD2FF
        generic map(W => 1, INITIAL => (others => '0'))
        port map(
            CLK  => WB_CLK,
            D(0) => LD_EN_O,
            Q(0) => WBS_LD_EN
            );
    
    -- Line driving-domain preamble generator
    PreambleGen: PDPreambleGen port map(
        CLK     => DCLK,
        TRIG    => PAG_TRIG,
        RST     => LDS_WB_RST_I,
        Q       => PAG_OUTPUT,
        FIN     => PAG_FINAL
        );
        
    -- Line-driving domain 4b5b encoder
    LineCoder: Encoder4b5b port map(
        CLK => DCLK,
        WE  => LENC_WE,
        K   => LENC_IS_K,
        ARG => LENC_IN,
        Q   => LENC_OUT
        );
    
    -- Line driver controller
    BMCDriver: BiphaseMarkDriver port map(
        CLK => DCLK,
        D   => LD_IN,
        WE  => LD_WE,
        Q   => LD_DAT_O,
        OE  => LD_EN_O
        );
        
    Sync_LDS_WB_RST_I: CD2FF
        generic map(W => 1, INITIAL => (others => '0'))
        port map(
            CLK     => DCLK,
            D(0)    => WB_RST_I,
            Q(0)    => LDS_WB_RST_I
            );
end;
