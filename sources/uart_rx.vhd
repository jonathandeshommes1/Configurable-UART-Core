-- UART_RX (uart receiver)
-- .. Collects 1 start-bit, 8 data-bits, 1 stop bit
-- .. After stop bit is processed data_valid line is asserted {o_RX_DV} for 1 clk cycle
-- .. Indicates that byte of data (across shift register) is valid. (trigger FIFO wr)    

-- Oversampling
-- .. Receiver samples incoming data at a rate 16x faster than the baud {transmitting} rate   
-- .. Accurate start bit {falling-edge} and center bit detection (ensures correct timing)
-- .. Precise clock alignment to center of bit (reliable sampling despite clock mismatch)
-- .. Improved tolerance to noise and clock mismatch (robust)(edge drift)(sampling close to edge)

-- Operation
-- .. Detect falling edge of start bit  
-- .. Wait 8 samples {baud ticks} {half-bit} reach center of start bit
-- .. Samples every 16 ticks -> center of each data bit

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        g_WIDTH  : integer   :=  8;
        g_PAR_EN : std_logic := '0';     -- parity enable (error detection)
        g_PAR_PL : std_logic := '0'      -- parity polarity [0 -> Odd][1 -> Even]
    );
    port(
        i_Clk       : in  std_logic;          
        i_Rst       : in  std_logic;          
        i_RX_Serial : in  std_logic;     -- RX Serial Data In
        i_RX_Tick   : in  std_logic;     -- generated Tick maintains correct baud rate (16x sampling)  
        i_RX_frdy   : in  std_logic;     -- overflow_err, (fifo is full)(mapped -> READY)  
        
        o_RX_DV     : out std_logic;           -- Flag: constructed byte is valid (mapped -> VALID) 
        o_PAR_Err   : out std_logic;           -- Flag: indicating parity error (mismatch)
        o_FRM_Err   : out std_logic;           -- Flag: indicating framing error (stop-bit is 0)
        o_OVF_Err   : out std_logic;           -- Flag: indicating overflow error, constructed byte ignored
        o_RX_Done   : out std_logic;           -- Flag: {done} debugging 
        o_RX_Bgen_S : out std_logic;           -- Trigger rx Baud generator start
        o_RX_Byte   : out std_logic_vector(g_WIDTH-1 downto 0) -- RX Constructed byte {feed to FIFO}     
    );
end uart_rx;

architecture Behavioral of uart_rx is        
    -- FSM STATES
    type t_FSM_Main is (s_Idle, s_Start_Bit, s_Data_Bits, s_Parity_Bit, s_Stop_Bit);
    signal r_SM_Main : t_FSM_Main := s_Idle;  
    
    -- Internal registers 
    signal r_Bit_Index  : integer range 0 to g_WIDTH-1 := 0;                       -- data bit index {received}
    signal r_RX_Byte    : std_logic_vector(g_WIDTH-1 downto 0) := (others => '0'); -- holds constructed parallel data 
    signal r_PAR_Err    : std_logic := '0';                                -- hold flag signal {used for comparison during stop state}     --
    signal r_Tick_Count : integer range 0 to 15;                           -- keep count of baud tick 
    
    -- two-stage synchronizer signal
    signal r_sync_serial : std_logic := '1';
begin
            
                   
   -- Two Stage Synchronizer Instantiation (adds 2-clk cycle delay ~10ns)
   sync_inst : entity work.two_stage_sync
        port map (i_Clk, i_Rst, i_RX_Serial, r_sync_serial);
 
        
    -- Purpose: RX state machine
    process (i_Clk, i_Rst) 
        variable v_parity : std_logic := '0';
    begin
        if i_Rst = '1' then
            r_Bit_Index  <=  0;
            r_Tick_Count <=  0;
            o_RX_DV      <= '0';
            o_FRM_Err    <= '0';
            r_PAR_Err    <= '0';
            o_OVF_Err    <= '0';
            o_RX_Bgen_S   <= '0';
            o_RX_Done    <= '0';
            r_RX_Byte    <= (others => '0');
        elsif rising_edge(i_clk) then
            case r_SM_MAIN is
               
                when s_Idle =>
                    r_Bit_Index  <=  0;
                    r_Tick_Count <=  0;
                    o_RX_DV      <= '0';
                    o_FRM_Err    <= '0';
                    r_PAR_Err    <= '0';
                    o_OVF_Err    <= '0';
                    o_RX_Bgen_S  <= '0';
                    o_RX_Done    <= '0';
                    r_RX_Byte    <= (others => '0');
                    
                    -- start bit detection {falling_edge}
                    if r_sync_serial = '0' then
                        o_RX_Bgen_S <= '1';   -- start baud genetor (16x -> for oversampling)
                        r_SM_Main <= s_Start_Bit;
                    end if;
           
                when s_Start_Bit =>
                    -- locate middle of bit (ensure stable) {glitch-free}
                    if i_RX_Tick = '1' then
                        if r_Tick_Count = 7 then
                          if r_sync_serial = '0' then 
                            r_Tick_Count <= 0; 
                            r_SM_Main    <= s_Data_Bits;
                          else
                            r_SM_Main  <= s_Idle;
                          end if;
                        else
                            r_Tick_Count <= r_Tick_Count + 1;                  
                        end if;
                    end if;          
 
                 when s_Data_Bits =>
                    -- sample each bit after {baud period}{16 baud ticks}
                    if i_RX_Tick = '1' then
                        if r_Tick_Count = 15 then
                            r_Tick_Count <= 0; 
                            r_RX_Byte(r_Bit_Index) <= r_sync_serial;
               
                            -- check if all data bits have been captured {shift-register}
                            if r_Bit_Index < g_WIDTH-1 then
                                r_Bit_Index <= r_Bit_Index + 1;
                            else
                                r_Bit_Index <= 0;
                                if g_PAR_EN = '1' then
                                    r_SM_Main <= s_Parity_Bit;
                                else   
                                    r_SM_Main   <= s_Stop_Bit;
                                end if;
                            end if;
                         else
                            r_Tick_Count <= r_Tick_Count + 1; 
                        end if;
                    end if;
                 
                 when s_Parity_Bit =>
                    -- sample parity bit after baud period {g_CLKS_PER_BIT-1} 
                    if i_RX_Tick = '1' then
                        if r_Tick_Count = 15 then
                            r_Tick_Count <= 0;  
                            r_SM_Main  <= s_Stop_Bit;
                        
                            -- parity calculation
                            v_parity := '0';
                            for i in 0 to g_WIDTH-1 loop
                                v_parity := v_parity xor r_RX_Byte(i);
                            end loop;
                            
                            -- check parity bit vs calculation
                            if g_PAR_PL = '0' then
                                if r_sync_serial /= v_parity then
                                    r_PAR_Err <= '1';
                                end if;
                            else
                                if r_sync_serial = v_parity then
                                   r_PAR_Err <= '1';
                                end if; 
                            end if;
                        else
                           r_Tick_Count <= r_Tick_Count + 1;  
                        end if; 
                    end if;                    
                      
                 when s_Stop_Bit =>
                    -- sample stop bit after baud period {g_CLKS_PER_BIT-1} 
                    if i_RX_Tick = '1' then
                        if r_Tick_Count = 15 then
                            o_RX_Done   <= '1';
                            r_SM_Main   <= s_Idle;
                            
                            -- error detection
                            if r_sync_serial = '1' then
                                -- frame error logic
                                if r_PAR_Err = '0' then
                                    o_RX_DV   <= '1'; 
                                    -- overflow error logic 
                                    if i_RX_frdy = '0' then
                                        o_OVF_Err <= '1';
                                    end if; 
                                end if;                      
                            else
                                o_FRM_Err <= '1';
                           end if;
                       else
                           r_Tick_Count <= r_Tick_Count + 1; 
                       end if;                 
                    end if;
                    
                 when others =>
                    r_SM_Main <= s_Idle;                                
            end case;
        end if;
    end process;
    
    -- map internal registers to ouput signals
    o_RX_Byte <= r_RX_Byte;
    o_PAR_Err <= r_PAR_Err;
end Behavioral;