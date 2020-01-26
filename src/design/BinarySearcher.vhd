-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- Provides a binary search function based on the output from a comparator.
entity BinarySearcher is
port(
    -- Clock
    CLK : in    std_logic;
    -- Trigger
    --      When asserted, prompts the block to evaluate CMP.
    TRG : in    std_logic;
    -- Comparator
    --      The output of a comparator which compares the target value and
    --      the output on Q. High indicates that Q exceeds the target, low
    --      indicates that the target exceeds Q.
    CMP : in    std_logic;
    -- Reset
    RST : in    std_logic;
    
    -- Data output
    --      The output over which a binary search is performed.
    Q   : out   std_ulogic_vector(6 downto 0);
    -- Ready signal
    --      Indicates that the output on Q is ready for use.
    RDY : out   std_ulogic
    );
end BinarySearcher;


architecture Impl of BinarySearcher is
begin

end;
    