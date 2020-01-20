-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- Decodes a Gray code of a specified width into an equivalent binary value.
entity GrayDecoder is
    generic(
        -- The width of the input Gray code, in bits.
        W   : positive := 1
        );
    port(
        -- Data input
        --      The Gray code to be decoded.
        D       : in    std_logic_vector((W - 1) downto 0);
        
        -- Data output
        --      The binary equivalent of the provided Gray code.
        Q       : out   std_ulogic_vector((W - 1) downto 0) := (others => '0')
        );
end GrayDecoder;


architecture Impl of GrayDecoder is
    signal Decode   : std_ulogic_vector((W - 1) downto 0);
begin

    Q <= Decode;
    
    -- The most significant bit remains unchanged.
    Decode(Q'left)  <= D(D'left);
    
    -- And every less significant bit is a cumulative XOR of the next most
    -- significant bit's binary value.
    Gen_OnlyIfMultibit: if W /= 1 generate
        Gen_LowOrderDecoders: for i in (Q'left - 1) downto 0 generate
            Decode(i)   <= Decode(i + 1) xor D(i);
        end generate Gen_LowOrderDecoders;
    end generate Gen_OnlyIfMultibit;

end;