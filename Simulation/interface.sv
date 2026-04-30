/*
------------------------------------------------------------
UART Interface
------------------------------------------------------------
Purpose:
    Bundles DUT signals into a shared structure.

Usage:
    • Driver → writes TX signals
    • Monitor → reads RX signals

Features:
    • Supports two UART instances
    • Includes control, data, and error signals
    • Enables full-duplex cross-connection

Notes:
    • Accessed via virtual interface in classes
------------------------------------------------------------
*/


interface itf();
    
    // ------- Shared Signals ----------
    logic  rst;
    logic  clk1;
    logic  clk2;
   
  // ------------ UART1 ---------------
    // TX side (input interface) {driver -> DUT}
    logic        u1_s_tvalid;
    logic [7:0]  u1_s_tdata;      
    logic        u1_s_tready;   
   
    // RX side (DUT -> monitor) 
    logic        u1_m_tready;
    logic        u1_m_tvalid;
    logic [7:0]  u1_m_tdata;
    
    logic        u1_o_PAR_Err;
    logic        u1_o_FRM_Err;
    logic        u1_o_OVF_Err;
    
    // Serial Lines {cross connected -> full-duplex}
    logic        u1_i_RX;  
    logic        u1_o_TX;



  // ------------ UART2 ---------------
    // TX side (input interface) {driver -> DUT}
    logic        u2_s_tvalid;
    logic [7:0]  u2_s_tdata;      
    logic        u2_s_tready;   
   
    // RX side (DUT -> monitor) 
    logic        u2_m_tready;
    logic        u2_m_tvalid;
    logic [7:0]  u2_m_tdata;
    
    logic        u2_o_PAR_Err;
    logic        u2_o_FRM_Err;
    logic        u2_o_OVF_Err;    
    
        // Serial Lines {cross connected -> full-duplex}
   // logic        u2_i_RX;  
   //  logic        u2_o_TX;                            
 
endinterface