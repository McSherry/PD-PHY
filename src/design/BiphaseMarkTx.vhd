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
    OE      : out   std_ulogic
    );
end BiphaseMarkTx;

architecture Impl of BiphaseMarkTx is        
begin

end;
