-- UART_TX (uart transmitter)
-- .. collects 1-byte, transmit 8 bits of serial data, 1 start bit, 1 stop bit

-- FIFO AXI-Stream Interface  {flow control}   
-- .. DATA  -> {i_TX_Byte} : fifo rd_data
-- .. VALID -> {i_TX_DV}   : fifo empty'
-- .. READY -> {o_TX_Idle} : backpressure when active

-- When transmit is complete: 
-- ..{o_TX_Done} pulled high for 1 clk cycle 
-- ..{o_TX_Idle} is pulled high (used by FIFO - to load new data_byte) {READY}
    

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_tx is
    generic (
        g_WIDTH  : integer   :=  8;      -- data width
        g_PAR_EN : std_logic := '0';     -- parity enable (error detection)
        g_PAR_PL : std_logic := '0'      -- parity polarity [{0 -> odd}, {1 -> even}]
    );
    port(
        i_Rst       : in  std_logic;
        i_Clk       : in  std_logic;
        i_TX_DV     : in  std_logic;      -- byte data valid                                 {VALID) 
        i_TX_Tick   : in  std_logic;      -- generated Tick maintains correct baud rate
        i_TX_Byte   : in  std_logic_vector(g_WIDTH-1 downto 0);  -- Parallel Data from FIFO  {DATA}
        
        o_TX_Done   : out std_logic;         -- Status Flag: {done} debugging
        o_TX_Idle   : out std_logic;         -- Status Flag: used by FIFO                    {READY}
        o_TX_Bgen_S : out std_logic;         -- Trigger tx Baud generator start
        o_TX_Serial : out std_logic          -- TX Serial Data Out

    );
end uart_tx;

architecture Behavioral of uart_tx is   
    -- FSM STATES
    type t_FSM_Main is (s_Idle, s_Start_Bit, s_Data_Bits, s_Parity_Bit, s_Stop_Bit);
    signal r_SM_Main : t_FSM_Main := s_Idle; 
    
    -- Internal registers 
    signal r_parity    : std_logic := '0';                                        -- odd parity 
    signal r_Bit_Index : integer range 0 to g_WIDTH-1 := 0;                       -- data bit index {send}
    signal r_TX_Data   : std_logic_vector(g_WIDTH-1 downto 0) := (others => '0'); -- hold parallel data
    
    
begin

    
    -- Purpose: TX state machine    
    process (i_Clk)
        variable v_parity  : std_logic := '0';  --used for immediate update
        variable v_TX_Idle : std_logic := '0';  --used for multiple assignments
    begin
        if rising_edge(i_Clk) then          
            case r_SM_Main is
                when s_Idle => 
                    r_Bit_Index <=  0;
                    v_TX_Idle   := '1';
                    o_TX_Done   <= '0';
                    o_TX_Serial <= '1';
                    o_TX_Bgen_S <= '0';
                    
                    if i_TX_DV = '1' then
                        v_TX_Idle := '0'; 
                        r_TX_Data <= i_TX_Byte;
                        r_SM_Main <= s_Start_Bit;                         
                    end if;
                    
                when s_Start_Bit =>
                    o_TX_Serial  <= '0';    -- pulls serial line low {start bit}
                    o_TX_Bgen_S  <= '1';    -- start baud generator                          
                                    
                    -- wait for T baud to transmit start bit
                    if i_TX_Tick = '1' then                    
                        r_SM_Main   <= s_Data_Bits;
                    end if; 
                
                when s_Data_Bits =>
                    -- data sent from LSB -> MSB
                    o_TX_Serial <= r_TX_Data(r_Bit_Index);

                    -- wait for baud period to transmit each bits
                    if i_TX_Tick = '1' then                  
                        if r_Bit_Index < g_WIDTH-1 then 
                            r_Bit_Index <= r_Bit_Index + 1;
                        else
                            r_Bit_Index <= 0; 
                            if g_PAR_EN = '0' then
                                r_SM_Main   <= s_Stop_Bit;
                            else
                            -- parity calculation
                            v_parity := '0';
                            for i in 0 to g_WIDTH-1 loop
                                v_parity := v_parity xor r_TX_Data(i);
                            end loop;                          
                            r_parity   <= v_parity; 
                            r_SM_Main <= s_Parity_Bit;                              
                            end if;
                        end if;           
                    end if;       
                
                when s_Parity_Bit =>        
                    -- parity bit sent 
                    if g_PAR_PL = '0' then
                        o_TX_Serial <= r_parity;
                    else
                        o_TX_Serial <= not (r_parity);
                    end if; 
                   
                   -- Wait g_CLKS_PER_BIT-1 clock cycles
                   if i_TX_Tick = '1' then  
                        r_SM_Main   <= s_Stop_Bit;   
                    end if;  
                    
                when s_Stop_Bit =>
                    o_TX_Serial <= '1';
                    
                    -- Wait g_CLKS_PER_BIT-1 clock cycles 
                   if i_TX_Tick = '1' then 
                        o_TX_Done   <= '1'; 
                        v_TX_Idle   := '1';                 
                        r_SM_Main   <= s_Idle;
                   end if; 
                    
                when others =>
                    r_SM_Main <= s_Idle;                                         
            end case;
            o_TX_Idle <= v_TX_Idle;
        end if;
    end process;
end Behavioral;
