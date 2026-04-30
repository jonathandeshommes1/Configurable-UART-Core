
---------------------------------------------------------------------------
-- UART CORE (Full-Duplex with FIFO Buffering)
---------------------------------------------------------------------------

-- Purpose:
    -- Implements a full-duplex UART core capable of
       -- transmitting and receiving serial data simultaneously.
    -- Provides FIFO buffering on both TX and RX paths.
    -- Supports configurable baud rate, oversampling, and optional parity.


-- Key Features:
    -- Full-duplex communication (independent TX and RX paths)
    -- AXI-Stream-like handshake interface (tvalid / tready / tdata)
    -- FIFO-based buffering for both transmit and receive paths
    
    -- Configurable parameters:
        -- .. Baud rate
        -- .. Data width
        -- .. FIFO depth
        -- .. Parity enable and polarity
        -- .. Oversampling rate (8 or 16)
        
    
    -- Error detection:
        -- .. Parity error
        -- .. Framing error
        -- .. Overflow error


-- Architecture Overview:
    -- Baud Generator:
        -- .. Generates timing ticks for TX (baud rate) and RX (oversampled)

    -- Receiver Path (RX):
        -- .. Serial Input → UART RX → RX FIFO → User Interface
            -- .. Reconstructs serial data into parallel bytes
            -- .. Performs error checking (parity, framing, overflow)
            -- .. Pushes valid bytes into RX FIFO

    -- Transmitter Path (TX):
        -- .. User Interface → TX FIFO → UART TX → Serial Output
            -- .. Buffers user data in TX FIFO
            -- .. Transmits data serially based on baud timing
            -- .. Handles backpressure via ready/valid handshake


-- Clock Domains:
    -- .. i_Clk_200MHz : UART logic clock (baud generation, TX/RX logic)
    -- .. i_Clk_User   : User interface clock (FIFO read/write side)


-- Handshake Protocol (AXI-Stream Style):
    -- TX Input:
        -- .. s_tvalid : Data valid from user
        -- .. s_tready : FIFO ready to accept data
        -- .. s_tdata  : Input data

    -- RX Output:
        -- .. m_tvalid : Data available to user
        -- .. m_tready : User ready to consume data
        -- .. m_tdata  : Output data

-- Data Flow:
    -- TX Path:
        -- .. User → TX FIFO → UART TX → Serial Line (o_TX)

    -- RX Path:
        -- .. Serial Line (i_RX) → UART RX → RX FIFO → User

-- Design Notes:
    -- .. FIFO buffering allows safe clock domain crossing between user logic and UART logic.
    -- .. Oversampling improves RX robustness against noise and timing drift.
    -- .. Backpressure ensures no data loss when FIFOs are full.
    -- .. Error flags indicate invalid or corrupted received data.


-- Usage:
    -- .. Designed for integration into FPGA-based communication systems
    -- .. Suitable for embedded systems, protocol controllers, and SoC designs

---------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity uart_core is
    generic(
        g_PAR_EN        : std_logic := '0';         -- parity enable (error detection)
        g_PAR_PL        : std_logic := '0';         -- parity polarity [0 -> Odd][1 -> Even]
        g_DATA_WIDTH    : integer   := 8;           -- fifo word_size = 1 byte
        g_ADDR_WIDTH    : integer   := 5;           -- fifo depth = 2**4 -> 16         
        g_Oversampling  : integer   := 16;          -- 16x
        g_Baud_Rate_HZ  : integer   := 9600;        -- baud rate
        g_200MHZ_Clk_HZ : integer   := 200000000    -- clk cycles/sec        
    );
    port(
        i_Rst        : in  std_logic;
        i_Clk_200MHz : in  std_logic;
        i_Clk_User   : in  std_logic;  
        
        -- TX side (input interface)   
        s_tvalid     : in  std_logic;                                   
        s_tdata      : in  std_logic_vector(g_DATA_WIDTH-1 downto 0);
        s_tready     : out std_logic; 
        
        -- RX side (output interface)
        m_tready     : in  std_logic;   
        m_tvalid     : out std_logic;   
        m_tdata      : out std_logic_vector(g_DATA_WIDTH-1 downto 0);  
        
        -- Error flags
        o_PAR_Err    : out std_logic;
        o_FRM_Err    : out std_logic; 
        o_OVF_Err    : out std_logic;
        
        -- Serial Lines         
        i_RX         : in  std_logic;
        o_TX         : out std_logic
    );
end uart_core;

architecture Behavioral of uart_core is
    -- Receiver {RX} internal signals
    signal r_RX_Bgen   : std_logic;
    signal r_RX_Tick   : std_logic;
    signal r_RX_frdy  : std_logic;
    signal r_RX_DV     : std_logic;
    signal r_RX_Done   : std_logic; 
    signal r_RX_Byte   : std_logic_vector(g_DATA_WIDTH-1 downto 0); 
   
   -- Receiver {TX} internal signals
    signal r_TX_Bgen   : std_logic;
    signal r_TX_Tick   : std_logic;
    signal r_TX_DV     : std_logic;   
    signal r_TX_Done   : std_logic;
    signal r_TX_Idle   : std_logic; 
    signal r_TX_Byte   : std_logic_vector(g_DATA_WIDTH-1 downto 0);
begin
    
    -- Baud Generator Intantiation
    bgen_inst : entity work.baud_gen
        generic map (
            g_Oversampling  => g_Oversampling,
            g_Baud_Rate_HZ  => g_Baud_Rate_HZ,
            g_System_Clk_HZ => g_200MHZ_Clk_HZ      
        )
        port map (
            i_Clk     => i_Clk_200MHz, --uart clock
            i_rx_Rst  => r_RX_Bgen,    --start rx baud gen
            i_tx_Rst  => r_TX_Bgen,    --start tx baud gen
            o_rx_Tick => r_RX_Tick,    --baud tick 16x baud rate
            o_tx_Tick => r_TX_Tick     --baud tick each baud period  
        );
        
     -- Receiver {RX} Instantiation
     rx_inst : entity work.uart_rx
        generic map (
            g_WIDTH  => g_DATA_WIDTH,
            g_PAR_EN => g_PAR_EN,
            g_PAR_PL => g_PAR_PL
        )
        port map (
            i_Rst        => i_Rst,           
            i_Clk        => i_Clk_200MHz,  --uart clock  
            i_RX_Serial  => i_RX,          --rx serial line  
            i_RX_Tick    => r_RX_Tick,     --baud tick 16x baud rate 
            i_RX_frdy    => r_RX_frdy,     --fifo full (backpressure) {READY}
            o_RX_DV      => r_RX_DV,       --constructed byte valid   {VALID}
            o_PAR_Err    => o_PAR_Err,     --Flag: parity mismatch
            o_FRM_Err    => o_FRM_Err,     --Flag: framing error
            o_OVF_Err    => o_OVF_Err,     --Flag: overflow error
            o_RX_Done    => r_RX_Done,     --Flag: RX finished operation
            o_RX_Bgen_S  => r_RX_Bgen,     --start rx baud gen
            o_RX_Byte    => r_RX_Byte      --constructed byte         {DATA}     
        );
        
        
     -- FIFO {RX} Instantiation
     fifo_rx : entity work.FIFO
        generic map (
            g_DATA_WIDTH => g_DATA_WIDTH,
            g_ADDR_WIDTH => g_ADDR_WIDTH
        )
        port map (
            i_Rst     => i_Rst,     
            -- input from RX {Receiver}
            clk_wr    => i_Clk_200MHz, --uart clock
            s_tvalid  => r_RX_DV,      --constructed byte valid       {VALID}
            s_tready  => r_RX_frdy,    --fifo full (backpressure)     {READY}
            s_tdata   => r_RX_Byte,    --constructed byte to write    {DATA} 
            -- output to User Logic 
            clk_rd    => i_Clk_User,   --user clock
            m_tvalid  => m_tvalid,     --asserted when not empty      {VALID}
            m_tready  => m_tready,     --custom logic (back-pressure) {READY}
            m_tdata   => m_tdata       --data to read from fifo       {DATA}
        );        
        
        
     -- Transmiter {TX} Instantiation
     tx_inst : entity work.uart_tx
        generic map (
            g_WIDTH  => g_DATA_WIDTH,--r_RX_DV,
            g_PAR_EN => g_PAR_EN, --r_RX_Byte,
            g_PAR_PL => g_PAR_PL
        )
        port map (
            i_Rst        => i_Rst,         
            i_Clk        => i_Clk_200MHz,  --uart clock   
            i_TX_DV      => r_TX_DV,       --byte is valid (fifo ~empty)     {VALID}
            i_TX_Tick    => r_TX_Tick,     --baud tick correspond to baud rate  
            i_TX_Byte    => r_TX_Byte,     --data byte read by TX (rd_addr)  {DATA}
            o_TX_Done    => r_TX_Done,     --Flag: operation complete
            o_TX_Idle    => r_TX_Idle,     --Flag: free to accept byte       {READY}  
            o_TX_Bgen_S  => r_TX_Bgen,     --start tx baud gen
            o_TX_Serial  => o_TX           --rx serial line        
        );
        
     -- FIFO {TX} Instantiation
     fifo_tx : entity work.FIFO
        generic map (
            g_DATA_WIDTH => g_DATA_WIDTH,
            g_ADDR_WIDTH => g_ADDR_WIDTH
        )
        port map (
            i_Rst     => i_Rst,     
            -- input from User Logic
            clk_wr    => i_Clk_User,        --user clock
            s_tvalid  => s_tvalid,          --user byte valid              {VALID}
            s_tdata   => s_tdata,           --byte to write to fifo        {DATA} 
            s_tready  => s_tready,          --fifo full (backpressure)     {READY}
            -- output to TX {Transmitter} 
            clk_rd    => i_Clk_200MHz,      --uart clock  
            m_tvalid  => r_TX_DV,           --asserted when not empty      {VALID}              
            m_tready  => r_TX_Idle,         --TX is busy (back-pressure)   {READY}
            m_tdata   => r_TX_Byte          --data read from fifo (rd_addr) {DATA}
            
        );
        

            

end Behavioral;
