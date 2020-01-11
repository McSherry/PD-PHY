-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


entity PDPreambleGen is
port(
    -- Data clock
    --      This should be a clock at the frequency used by the final
    --      output-driving stage.
    CLK     : in    std_logic;
    -- Trigger
    --      When asserted for at least one clock cycle, causes the preamble
    --      generator to begin producing output.
    TRIG    : in    std_logic;
    
    -- Data output
    Q       : out   std_ulogic;
    -- Final bit indicator
    --      Asserted when the value on [Q] is bit 63 of the preamble.
    FIN     : out   std_ulogic
    );
end PDPreambleGen;

architecture Impl of PDPreambleGen is
    -- Accumulator register
    signal ACC          : std_logic_vector(5 downto 0) := "000000";
    
    -- Internal adder wires
    signal ADD_Wire     : std_logic_vector(5 downto 0);
    signal ADD_Carry    : std_logic_vector(5 downto 0);
begin
    -- The design of the preamble generator is relatively straightforward.
    --
    -- A 6-bit adder is permanently wired as an up-counter which begins to
    -- count on a TRIG signal and continues until it overflows. Its LSB is
    -- used to provide an alternating output, while the final-bit signal is
    -- produced by a check that all six bits are logic high.
    main: process(CLK)
    begin
        -- If we've been triggered or we're in the process of counting, latch
        -- in the new count from the adder on each cycle.
        if rising_edge(CLK) and ((TRIG = '1') or (ACC /= "000000")) then
            ACC <= ADD_Wire;
        end if;
    end process;
    
    
    -- The adder is an unclocked ripple-carry adder, which means we need to
    -- have six summing wires. As this is an up-counter, we know only the
    -- the least-significant wire will have an addend and the others will
    -- only work with the carry-in.
    ADD_Wire(5) <= ACC(5) xor ADD_Carry(4);
    ADD_Wire(4) <= ACC(4) xor ADD_Carry(3);
    ADD_Wire(3) <= ACC(3) xor ADD_Carry(2);
    ADD_Wire(2) <= ACC(2) xor ADD_Carry(1);
    ADD_Wire(1) <= ACC(1) xor ADD_Carry(0);
    -- And that the first adder will be hardwired to add '1', and so it will
    -- invert on every cycle.
    ADD_Wire(0) <= not ACC(0);
    
    -- Similarly, as we know all but the least-significant addend will be
    -- zero, we can include only the essential parts of the carry logic.
    ADD_Carry(5) <= ACC(5) and ADD_Carry(4);
    ADD_Carry(4) <= ACC(4) and ADD_Carry(3);
    ADD_Carry(3) <= ACC(3) and ADD_Carry(2);
    ADD_Carry(2) <= ACC(2) and ADD_Carry(1);
    ADD_Carry(1) <= ACC(1) and ADD_Carry(0);
    ADD_Carry(0) <= ACC(0);
    
    
    -- The output is then simply the least-significant bit of the accumulator.
    Q <= ACC(0);
    
    -- And the final-bit signal is asserted just before overflow, when all the
    -- bits of the register are logic high.
    FIN <= '1' when ACC = "111111" else '0';
end;