-- Asynchronous dual-port FIFO:
-- .. Data read and write operations w 2 clock frequency {simultaneous }
-- .. Array storage 32x8RAM {bandwidth}{through}{elastic buffer}
-- .. Depth -> 32, Address bit -> 5, Data bit -> 8, Total bit -> 256
-- .. Binary pointer (for memory addressing) vs Gray pointer (for CDC)
-- .. Unsigned allows direct addition and wrap around logic
-- .. Standard Logic has 4 states: '0', '1', 'X', 'Z'

-- Buffering: 
-- .. Provide storage for RX output -> store constructed byte 
-- .. Provide storage for TX input  -> store parallel byte to transmit

-- Clock Domain Crossing:
-- .. Resolves CDC {metastability} between external module and UART core
-- .. Module reading from RX or writing to TX at a dif frequency
-- .. Gray Coded Pointers passed through {2_stage_sync} for {full} and {empty} flag evaluation
-- .. Gray Encoding: ensures a single bit changes b/t consecutive states {race condition} {corruption}

-- Flow Control:
-- .. Contains (Implements) AXI-Stream interface
-- .. Uses {tvalid}, {tready} handshake -> prevent (overflow) (underflow) {back-pressure}
-- .. If the FIFO is full or empty, {READY}{VALID} will deassert accordingly. (data integrity)(corruption)
-- .. Stalls halt data transfers, lower risk of {data corruption} and {data integrity}

-- Memory Usage: 
-- .. Distributed (LUT-based) storage used for memory less than 1 kilo Bits {KB}
-- .. Distributed RAM used for {small} {asynchronous read} {low latency -> combinational access} {flexible}


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FIFO is
    generic (
        g_DATA_WIDTH : integer := 8;    -- word_size = 1 byte
        g_ADDR_WIDTH : integer := 3     -- depth = 2**4 -> 16 
    );
    port ( 
        i_Rst : in std_logic;
        
        -- input from RX {Receiver} or User Logic
        clk_wr   : in  std_logic;
        s_tvalid : in  std_logic;
        s_tdata  : in  std_logic_vector(g_DATA_WIDTH-1 downto 0);
        s_tready : out std_logic;
        
        -- output to TX {Transmitter} or User Logic
        clk_rd   : in  std_logic;
        m_tready : in  std_logic;   -- used to increment rd_ptr
        m_tvalid : out std_logic;   -- asserted when not empty
        m_tdata  : out std_logic_vector(g_DATA_WIDTH-1 downto 0)       
    );
end FIFO;

architecture Behavioral of FIFO is
    --fifo depth constant
    constant c_FIFO_DEPTH : integer := 2**g_ADDR_WIDTH;
    
    --memory array (uses distributed memories)
    type mem_type is array (0 to (c_FIFO_DEPTH)-1) of std_logic_vector(g_DATA_WIDTH-1 downto 0);
    signal mem_array : mem_type := (others => (others => '0'));
    
    --write and read  pointers (extra bit for full evaluation)(circular)
    signal r_wr_ptr : unsigned(g_ADDR_WIDTH downto 0) := (others => '0');  
    signal r_rd_ptr : unsigned(g_ADDR_WIDTH downto 0) := (others => '0');       
    
    --gray encoded address pointers to pass through 2-stage synchronizer
    type gray_sync is array (0 to 1) of unsigned(g_ADDR_WIDTH downto 0);
    signal wr_ptr_gray : gray_sync := (others => (others => '0'));
    signal rd_ptr_gray : gray_sync := (others => (others => '0'));
    
    -- synchronized  pointers for empty and full flag evaluation
    signal sync_wr_ptr : unsigned(g_ADDR_WIDTH downto 0) := (others => '0');  
    signal sync_rd_ptr : unsigned(g_ADDR_WIDTH downto 0) := (others => '0');
    
    --next pointers for full flag evaluation
    signal r_wr_ptr_next : unsigned(g_ADDR_WIDTH downto 0):= (others => '0');
    
    --fifo status flags 
    signal full  : std_logic := '0';
    signal empty : std_logic := '1';
    
    --function: Perfrom Gray -> Binary Conversion
    function gray_to_bin(g : unsigned) return unsigned is
        variable b : unsigned (g'range);
    begin
        b(b'high) := g(g'high);
        for i in b'high-1 downto 0 loop
            b(i) := b(i+1) xor g(i);
        end loop;
        return b;
    end function;
    
begin
   
   -- Convert: Binary Pointers to Gray-coded Pointers
   wr_ptr_gray(0) <= r_wr_ptr xor (r_wr_ptr srl 1);
   rd_ptr_gray(0) <= r_rd_ptr xor (r_rd_ptr srl 1);
    
   -- Pass {wr_addr} gc pointer from clk_wr to clk_rd domain 
   sync_inst1 : entity work.two_stage_ptr
        generic map ( g_ADDR_WIDTH => g_ADDR_WIDTH)
        port map (clk_rd, i_Rst, wr_ptr_gray(0), wr_ptr_gray(1) );    --implicit mapping {positional}
   
   -- Pass {rd_addr} gc pointer from clk_rd to clk_wr domain 
   sync_inst2 : entity work.two_stage_ptr
        generic map ( g_ADDR_WIDTH => g_ADDR_WIDTH)
        port map (clk_wr, i_Rst, rd_ptr_gray(0), rd_ptr_gray(1));    --implicit mapping
    
   -- Convert: Sync Gray Pointers to Binary Pointers
   sync_wr_ptr <= gray_to_bin(wr_ptr_gray(1));
   sync_rd_ptr <= gray_to_bin(rd_ptr_gray(1));
    
    
    ------------------------------- write logic process  -----------------------------------
    process (clk_wr, i_Rst)
    begin
        if i_Rst = '1' then
            full          <= '0'; 
            r_wr_ptr      <= (others => '0');          
            --clear fifo
            for i in 0 to c_FIFO_DEPTH-1 loop
                mem_array(i) <= (others => '0');
            end loop;
        elsif rising_edge(clk_wr) then 
            -- write byte, advance wr_ptr, update full flag 
            if            (r_wr_ptr_next(g_ADDR_WIDTH) /= sync_rd_ptr(g_ADDR_WIDTH))            and
                (r_wr_ptr_next(g_ADDR_WIDTH-1 downto 0) = sync_rd_ptr(g_ADDR_WIDTH-1 downto 0)) then
                full <= '1';
            else
                full <= '0'; 
                --update addr_wr 
                if s_tvalid = '1' then
                    mem_array(to_integer(r_wr_ptr(g_ADDR_WIDTH-1 downto 0))) <= s_tdata;
                    r_wr_ptr <= r_wr_ptr + 1; 
                end if;                       
            end if;                   
        end if;
    end process;
    
    
    --------------------------------- read logic processes  -----------------------------------------------
    process (clk_rd, i_Rst)
    begin
        if i_Rst = '1' then
            empty         <= '1'; 
            r_rd_ptr      <= (others => '0');
        elsif rising_edge(clk_rd) then
            -- update empty flag and advance rd_ptr
            if r_rd_ptr = sync_wr_ptr then
                empty <= '1'; 
            else           
                empty <= '0';                           
                -- update addr_rd (ensure fifo is not currently empty)
                if m_tready = '1' and empty = '0' then
                     r_rd_ptr   <= r_rd_ptr + 1;            
                end if;             
            end if;       
        end if;
    end process;
    
    -- Next Pointer update (look-ahead comparison){overflow prevention}
    r_wr_ptr_next <= r_wr_ptr + 1;
    
    -- AXI Stream Master Interface Signals Update
    s_tready <= not (full);
    m_tvalid <= '1' when ((empty = '0') and (r_rd_ptr /= sync_wr_ptr)) else '0'; 
    m_tdata  <= mem_array(to_integer(r_rd_ptr(g_ADDR_WIDTH-1 downto 0)));
end Behavioral;
