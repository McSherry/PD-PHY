-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;


-- A control unit which translates requests from a Wishbone bus into the form
-- required to operate a biphase mark code transmitter.
--
-- Related:
--      ./BiphaseMarkTx.vhd
--      ./PDPreambleGen.vhd
--      ./Encoder4b5b.vhd
entity BiphaseMarkCU is
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
    WB_DAT_O    : in    std_logic_vector(7 downto 0);
    -- Wishbone acknowledge output
    WB_ACK_O    : in    std_logic;
    -- Wishbone error output
    WB_ERR_O    : in    std_logic;
    
    -- Other signals to be added later, initial development effort will be on
    -- ensuring that the Wishbone interface is functional.
    );
end BiphaseMarkCU;

architecture Impl of BiphaseMarkCU is
begin
    -- ...
end;