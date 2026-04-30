-- Baud Generator module
-- .. configurable counter {generates a baud tick after each baud period}{max val reached} 
-- .. used but transmitter and receiver to sample or transmit data at fixed baud period
 
-- DVSR (Divisor)programmable baud-rate register 
-- .. Number of FPGA clock cycles before a tick -> per 1 UART bit
-- .. DVSR = Clock Frequency / (Baud Rate × Oversampling)

-- .. Example: 200 MHz Clock, 9600 baud UART, 16 oversampling
-- .. dvsr = (200,000,000)/(9600) = 20833,  oversampling -> 1302 {clk cycles per bit}
-- .. baud tick (s) = 20833 x 5ns = 104165 ns

-- .. Example: 200 MHz Clock, 115200 baud UART, 16 oversampling
-- .. dvsr = (200,000,000)/(115200) = 1736, oversampling -> 108 {clk cycles per bit}
-- .. baud tick (s) = 1736 x 5ns = 8680 ns

-- Frequency Divisor Register
-- .. Used to divide FPGA input clock to produce baud clock.
-- .. Baud Clock is 16x the baud rate (data last for 16 baud clock cycles) 
-- .. Higher uart Freq -> results in more accurate Dividers (less affected by integer rounding)

library ieee;
use ieee.std_logic_1164.all;

entity baud_gen is
    generic (
        g_Oversampling  : integer := 16;            -- 16x
        g_Baud_Rate_HZ  : integer := 9600;          -- baud rate
        g_System_Clk_HZ : integer := 200000000      -- clk cycles/sec
    );
    port(
        i_Clk      : in  std_logic;    -- clk -> 200 MHz
        i_rx_Rst   : in  std_logic;    -- start rx baud generator counter  {active low reset} 
        i_tx_Rst   : in  std_logic;    -- start tx baud generator counter  {active low reset} 
        o_rx_Tick  : out std_logic;    -- baud tick asserted after rx_CLKS_PER_BIT cycles
        o_tx_Tick  : out std_logic     -- baud tick asserted after tx_CLKS_PER_BIT cycles    
    );
end baud_gen;

architecture Behavioral of baud_gen is
    --divisor
    constant c_tx_CLKS_PER_BIT : integer := g_System_Clk_HZ / (g_Baud_Rate_HZ);                    -- matches baud rate
    constant c_rx_CLKS_PER_BIT : integer := g_System_Clk_HZ / (g_Baud_Rate_HZ * g_Oversampling);   -- matches baud rate x 16
   
    --counter
    signal r_rx_Clock_Count : integer range 0 to c_rx_CLKS_PER_BIT := 0;   
    signal r_tx_Clock_Count : integer range 0 to c_tx_CLKS_PER_BIT := 0;   
begin

    -- RX counter     
    process (i_Clk, i_rx_Rst) 
    begin
        if i_rx_Rst = '0' then
            o_rx_Tick <= '0';     
            r_rx_Clock_Count <= 0;       
        elsif rising_edge(i_Clk) then
            if r_rx_Clock_Count < c_rx_CLKS_PER_BIT-1 then
                o_rx_Tick <= '0';
                r_rx_Clock_Count <= r_rx_Clock_Count + 1;
            else
                o_rx_Tick <= '1'; 
                r_rx_Clock_Count <= 0; 
            end if;         
        end if;
    end process;
    
    -- TX counter
    process (i_Clk, i_tx_Rst) 
    begin
        if i_tx_Rst = '0' then
            o_tx_Tick <= '0';     
            r_tx_Clock_Count <= 0;       
        elsif rising_edge(i_Clk) then
            if r_tx_Clock_Count < c_tx_CLKS_PER_BIT-1 then
                o_tx_Tick <= '0';
                r_tx_Clock_Count <= r_tx_Clock_Count + 1;
            else
                o_tx_Tick <= '1'; 
                r_tx_Clock_Count <= 0; 
            end if;         
        end if;
    end process;     
end Behavioral;
