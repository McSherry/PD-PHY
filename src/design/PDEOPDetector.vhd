-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Provides a unit for detecting the end of a USB-PD packet.
entity PDEOPDetector is
port(
    -- Master clock
    CLK : in    std_logic;
    -- Enable
    EN  : in    std_logic;
    -- Data input
    D   : in    std_logic_vector(4 downto 0);
    -- Asynchronous reset
    RST : in    std_logic;
    
    -- Detected
    --      Asserted when an end-of-packet condition is detected.
    DET : out   std_ulogic := '0'
    );
end PDEOPDetector;


architecture Impl of PDEOPDetector is
    type State_t is (
        -- The detector has not received input
        S0_NoInput,
        
        -- The detector received a good value for the first K-code, but because
        -- the relevant ordered sets have a common prefix it doesn't know which
        -- to expect yet.
        S1a_GoodK0,
        -- After a good first K-code, the K-code for the 'Hard_Reset' set was
        -- correctly received.
        S2aa_GoodHR1,
        -- After a good first K-code, an incorrect code was received for the
        -- second K-code. The detector is still unsure which to expect.
        S2ab_BadK1,
        -- After a good first but bad second K-code, the detector received a
        -- good third K-code. It remains ambiguous which to expect.
        S3ab_GoodK2,
        -- After a good first K-code, the K-code for the 'Cable_Reset' set
        -- was received.
        S2ac_GoodCR1,
        -- After a well-received first and second K-code, the third K-code for
        -- the 'Hard_Reset' set was received.
        S3aaa_GoodHR2,
        -- After receiving good first and second K-codes for the 'Hard_Reset' set,
        -- a bad third K-code was received. The detector now expects the fourth
        -- K-code in the 'Hard_Reset' set.
        S3aab_HRGood1Bad2,
        -- After well-received first and second K-codes for the 'Cable_Reset' set,
        -- the third was successfully received.
        S3aca_GoodCR2,
        -- After receiving good first and second 'Cable_Reset' K-codes, a bad
        -- third K-code was received. The fourth code from that set is expected.
        S3acb_BadCR2,
        
        -- The detector received a bad value for the first K-code. It doesn't know
        -- which set to expect, but all K-codes from here must be correct.
        S1b_BadK0,
        -- After a bad first K-code, the second K-code for the 'Hard_Reset' set was
        -- received successfully.
        S2ba_HRBad0Good1,
        -- The same, but the second from the 'Cable_Reset' set was received.
        S2bb_CRBad0Good1,
        -- After a bad first K-code, the second and third 'Hard_Reset' K-codes were
        -- successfully received.
        S3ba_HRBad0Good2,
        -- The same, but for the 'Cable_Reset' set.
        S3bb_CRBad0Good2,
        
        -- The detector recognised a sequence that marks the end of a packet.
        S4a_Detected,
        -- The detector failed to recognise an end-of-packet sequence and will
        -- wait to be reset.
        S4b_NoDetection
    );
    
    -- K-codes
    constant K_SYNC1    : std_ulogic_vector(4 downto 0) := "11000";
    constant K_SYNC2    : std_ulogic_vector(4 downto 0) := "10001";
    constant K_RST1     : std_ulogic_vector(4 downto 0) := "00111";
    constant K_RST2     : std_ulogic_vector(4 downto 0) := "11001";
    constant K_EOP      : std_ulogic_vector(4 downto 0) := "01101";
    constant K_SYNC3    : std_ulogic_vector(4 downto 0) := "00110";
begin

    process(CLK, RST)
        variable State : State_t := S0_NoInput;
    begin
            
        if RST = '1' then
            State   := S0_NoInput;
            DET     <= '0';
            
        elsif rising_edge(CLK) and EN = '1' then
        
        
            -- No matter the state we're in, if we encounter an 'EOP' K-code
            -- we want to jump straight to detection.
            if D = K_EOP then
                State := S4a_Detected;
            else
            
                case State is
                    
                    when S0_NoInput =>
                        State := S1a_GoodK0 when D = K_RST1 else S1b_BadK0;
                        
                        
                    when S1a_GoodK0 =>
                        State := S2aa_GoodHR1 when D = K_RST1 else
                                 S2ac_GoodCR1 when D = K_SYNC1 else
                                 S2ab_BadK1;
                                 
                    when S2aa_GoodHR1 =>
                        State := S3aaa_GoodHR2 when D = K_RST1 else S3aab_HRGood1Bad2;
                        
                    when S3aaa_GoodHR2 =>
                        State := S4a_Detected;
                        
                    when S3aab_HRGood1Bad2 =>
                        State := S4a_Detected when D = K_RST2 else S4b_NoDetection;
                    
                    
                    when S2ac_GoodCR1 =>
                        State := S3aca_GoodCR2 when D = K_RST1 else S3acb_BadCR2;
                        
                    when S3aca_GoodCR2 =>
                        State := S4a_Detected;
                        
                    when S3acb_BadCR2 =>
                        State := S4a_Detected when D = K_SYNC3 else S4b_NoDetection;
                    
                    
                    when S2ab_BadK1 =>
                        State := S3ab_GoodK2 when D = K_RST1 else S4b_NoDetection;
                        
                    when S3ab_GoodK2 =>
                        State := S4a_Detected when D = K_RST2 or D = K_SYNC3 else
                                 S4b_NoDetection;
                                 
                    
                    when S1b_BadK0 =>
                        State := S2ba_HRBad0Good1 when D = K_RST1 else
                                 S2bb_CRBad0Good1 when D = K_SYNC1 else
                                 S4b_NoDetection;
                    
                    when S2ba_HRBad0Good1 =>
                        State := S3ba_HRBad0Good2 when D = K_RST1 else S4b_NoDetection;
                        
                    when S2bb_CRBad0Good1 =>
                        State := S3bb_CRBad0Good2 when D = K_RST1 else S4b_NoDetection;
                    
                    when S3ba_HRBad0Good2 =>
                        State := S4a_Detected when D = K_RST2 else S4b_NoDetection;
                        
                    when S3bb_CRBad0Good2 =>
                        State := S4a_Detected when D = K_SYNC3 else S4b_NoDetection;
                    
                    
                    when S4a_Detected =>
                        null;
                        
                    when S4b_NoDetection =>
                        State := S4a_Detected when D = K_EOP;
                end case;
            end if;
            
            -- If we detected something, signal as much
            DET <= '1' when State = S4a_Detected else '0';
            
        end if;
    end process;
    
    

end;