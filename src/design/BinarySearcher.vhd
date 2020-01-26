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
    Q   : out   std_ulogic_vector(6 downto 0) := (6 => '1', others => '0');
    -- Ready signal
    --      Indicates that the output on Q is ready for use.
    RDY : out   std_ulogic := '0'
    );
end BinarySearcher;


architecture Impl of BinarySearcher is
    signal BitIndex : integer range 0 to Q'left := Q'left;
    signal IsReady  : std_ulogic := '0';
begin

    process(CLK, RST)
    begin
        if RST = '1' then
            IsReady <= '0';
            Q       <= (Q'left => '1', others => '0');
        end if;
    
        if rising_edge(CLK) and TRG = '1' and IsReady = '0' and RST = '0' then
            -- Our output on Q will be ready when we process the least
            -- significant bit.
            IsReady <= '1' when BitIndex = 0 else '0';
            
            if CMP = '1' then
                Q(BitIndex) <= '0';
            end if;
            
            if BitIndex /= 0 then
                Q(BitIndex - 1) <= '1';
                
                BitIndex <= BitIndex - 1;
            end if;
        end if;
    end process;
    
    RDY <= IsReady;

end;
    