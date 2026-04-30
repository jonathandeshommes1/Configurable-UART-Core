-- Two Stage Synchronizer: 
-- .. Used for RX serial line CDC {prevent metastability in RX logic)
-- .. Adds 2-clk cycle latency {delay}

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity two_stage_sync is
    port(
        i_Clk  : in  std_logic;
        i_Rst  : in  std_logic;
        i_sync : in  std_logic;
        o_sync : out std_logic
    );
end two_stage_sync;

architecture Behavioral of two_stage_sync is
    --intermediate signals
    signal stage : std_logic_vector(0 to 1) := (others => '1');
begin   
   process(i_Clk, i_Rst)
   begin
      if i_Rst = '1' then
        stage <= (others => '1');
      elsif rising_edge(i_Clk) then
         stage(0) <= i_sync;
         stage(1) <= stage(0);
      end if;
   end process; 
   
   o_sync <= stage(1);
end Behavioral;
