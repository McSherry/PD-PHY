-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides a biphase mark code (BMC) transmitter which complies with the
-- requirements of BS EN IEC 62680-1-2 (USB Power Delivery).
entity BiphaseMarkTx is
port(
    -- Data clock
    --      Expects input at half the output frequency and 50% duty.
    CLK     : in    std_logic;
    -- Data input
    D       : in    std_logic;
    -- Write enable
    --      Asserting this input indicates the beginning of a transmission,
    --      i.e. that the signal on [D] should be heeded.
    WE      : in    std_logic;
    
    -- Data output
    --      Operates at double the rate of the data clock [DCLK]
    Q       : out   std_ulogic;
    -- 'Output enabled' indicator
    --      Asserted when the output on [Q] is valid. When not asserted, the
    --      output on [Q] is undefined.
    OE      : out   std_ulogic  := '0'
    );
end BiphaseMarkTx;

architecture Impl of BiphaseMarkTx is        
    -- Outputs from each logic branch
    --
    -- The transmitter uses dual-edged logic to double the clock rate, and
    -- this enables connection to the output without worrying about contention.
    --
    -- BS EN IEC 62680-1-2 requires at s. 5.8.1 that the output begins low. By
    -- setting the default state high, we can avoid the need for special logic
    -- in an initial state. The [OE] signal means our consumer won't make use
    -- of [Q] until we've indicated it should, so defaulting high is fine.
    --
    -- To default high, the values of the rising-edge and falling-edge outputs
    -- must not equal (because line state is their exclusive-or).
    signal REOut    : std_ulogic := '0';
    signal FEOut    : std_ulogic := '1';
    -- A register for the data input so that a change between the rising and
    -- falling edge doesn't adversely impact operation.
    signal DR       : std_ulogic_vector(1 downto 0);
    
    -- States for the internal state machine
    type State_t is (
        -- State 1: Idling
        --      The transmitter is waiting to receive the 'write enable' signal
        --      which indicates the start of a transmission.
        S1_Idle,
        -- State 2a: Transmitting, normal
        --      The transmitter is in the process of transmitting.
        S2a_Tx,
        -- State 2b: Transmitting, last
        --      The transmitter is transmitting the last items in its register.
        S2b_TxLast,
        -- State 3: Holding line
        --      The transmitter holds the line for a number of unit intervals
        --      as required by BS EN IEC 62680-1-2, s. 5.8.1 and will soon
        --      transition back to idle.
        S3_Hold
        );
        
    -- The current state of the transmitter
    signal State    : State_t   := S1_Idle;
begin
    main: process(CLK)
    begin
        if rising_edge(CLK) then
            case State is
                -- In the idle state, we simply wait for the write-enable
                -- signal to prompt a transition to another state.
                when S1_Idle =>
                    -- If writing is enabled...
                    if WE = '1' then
                        -- Begin transmitting
                        State <= S2a_Tx;
                        -- Store the current input
                        DR(0) <= D;
                    end if;
                
                
                -- In the transmitting state, on the rising edge, we're reading
                -- data in and waiting for the write-enable signal to go low.
                when S2a_Tx | S2b_TxLast =>
                    -- Enable our output
                    OE      <= '1';
                    -- Invert the line at the start of each unit interval.
                    REOut   <= not REOut;
                    
                    -- The one-cycle delay introduced by the idle state means
                    -- we need a two-item register, and so that we need to shift
                    -- the value from previous cycles forward.
                    DR(1)   <= DR(0);
                    -- Allowing us to read in the present value.
                    DR(0)   <= D;
                    
                    -- If writing is no longer enabled, however, we want to
                    -- move to the next state. This indicates that the value we
                    -- just read in is invalid, and so we need a state that is
                    -- aware it shouldn't transmit it.
                    if WE = '0' then
                        State <= S2b_TxLast;
                    end if;
                    
                    if State = S2b_TxLast then
                        State <= S3_Hold;
                    end if;
                
                
                -- USB-PD requires that, if the line finishes a transition
                -- high, it is held high for a period and then held low for a
                -- period before being tristated. If it finishes low, it is
                -- only held low for a period. The standard uses specific
                -- lengths of time, but here we use a single unit interval as
                -- that is permissible and easiest with a single clock.
                --
                -- As implemented here, we simply keep inverting the line until
                -- we end up with it low. The clocked nature of this action
                -- means we get the single-UI periods we want.
                when S3_Hold =>
                    if Q = '0' then
                        State   <= S1_Idle;
                        OE      <= '0';
                        
                        -- Q must start low, and we know that it is low now and
                        -- that it will invert at the beginning of each unit
                        -- interval. By inverting now, it idles high and will
                        -- be inverted to low at the next transmission's start.
                        --
                        -- We're free to do this because of the output enable
                        -- signal, which means a consumer should ignore Q when
                        -- we aren't indicating it should be heeded.
                        REOut   <= not REOut;
                    else
                        State   <= S3_Hold;
                        REOut   <= not REOut;
                    end if;
            end case;
        end if;
        
        if falling_edge(CLK) then
            case State is
                -- There is nothing to do on the falling edge when idle.
                when S1_Idle =>
                    null;
                    
                    
                -- When transmitting, the falling edge is when we make a
                -- mid-interval transition if necessary.
                when S2a_Tx | S2b_TxLast =>                    
                    -- If we're transmitting a '1', BMC demands a transition
                    -- occur mid-interval.
                    if DR(1) = '1' then
                        FEOut   <= not FEOut;
                    end if;
                
                
                -- We don't need to do anything on the falling edge when in one
                -- of the holding states.
                when S3_Hold =>
                    null;
            end case;
        end if;
        
    end process;


    -- As we use double-edged logic, this seems like a suitable way to
    -- ensure the synthesiser doesn't do anything weird. This should prompt
    -- it to produce an inversion of CLK and two chains of logic separately
    -- driven from the normal and inverted clock.
    Q <= REOut xor FEOut;
end;
