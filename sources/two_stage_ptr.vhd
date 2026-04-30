-- Two Stage Synchronizer 
-- .. Used for adress_pointer CDC {prevent metastability in read and write logic)
-- .. Adds 2-clk cycle latency {delay}

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity two_stage_ptr is
    generic(
        g_ADDR_WIDTH : integer := 4
    );
    port(
        i_Clk  : in  std_logic;
        i_Rst  : in  std_logic;
        i_sync : in  unsigned(g_ADDR_WIDTH downto 0);
        o_sync : out unsigned(g_ADDR_WIDTH downto 0)
    );
end two_stage_ptr;

architecture Behavioral of two_stage_ptr is
    type stage_t is array (0 to 1) of unsigned(g_ADDR_WIDTH downto 0);
    
    --intermediate signals
    signal stage : stage_t := (others => (others => '0'));
begin   
   process(i_Clk, i_Rst)
   begin
      if i_Rst = '1' then 
         stage    <= (others => (others => '0'));
      elsif rising_edge(i_Clk) then
         stage(0) <= i_sync;
         stage(1) <= stage(0);
      end if;
   end process; 
   
   o_sync <= stage(1);
end Behavioral;
