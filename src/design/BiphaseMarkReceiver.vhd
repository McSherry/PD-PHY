-- 2019-20 (c) Liam McSherry
--
-- This file is released under the terms of the GNU Affero GPL 3.0. A copy
-- of the text of this licence is available from 'LICENCE.txt' in the project
-- root directory.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- A control unit which interprets the state of an asynchronous line to
-- retrieve biphase mark code (BMC) transmissions, and exposes received
-- data via a Wishbone bus interface.
entity BiphaseMarkReceiver is
port(
    -- Wishbone and master clock
    WB_CLK      : in    std_logic;
    
    -- Wishbone reset input
    WB_RST_I    : in    std_logic;
    -- Wishbone address bus
    WB_ADR_I    : in    std_logic_vector(1 downto 0);
    -- Wishbone data input bus
    WB_DAT_I    : in    std_logic_vector(7 downto 0);
    -- Wishbone cycle input
    WB_CYC_I    : in    std_logic;
    -- Wishbone strobe (slave select) input
    WB_STB_I    : in    std_logic;
    -- Wishbone write-enable input
    WB_WE_I     : in    std_logic;
    
    -- Receive input
    --      Intended to be connected to the output from a filter and
    --      processing arrangement which extracts a square wave from
    --      the raw state of the line.
    RXIN        : in    std_logic;
    
    -- Wishbone data output bus
    WB_DAT_O    : out   std_ulogic_vector(7 downto 0);
    -- Wishbone acknowledge output
    WB_ACK_O    : out   std_ulogic;
    -- Wishbone error output
    WB_ERR_O    : out   std_ulogic
    );
end BiphaseMarkReceiver;


architecture Impl of BiphaseMarkReceiver is
begin

end;