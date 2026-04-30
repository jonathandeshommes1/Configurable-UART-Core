/*
    I developed a full-duplex UART verification environment using SystemVerilog with a modular agent-based architecture.
    I used a queue-based scoreboard where transmitted data is stored as expected values and compared against received 
    data. This approach naturally handled FIFO buffering and UART latency without requiring cycle-accurate alignment {intentional delay}. 
    I also validated cross-UART communication by connecting two DUT instances and verifying bidirectional data flow
*/

/*
------------------------------------------------------------
UART Full-Duplex Verification Testbench
------------------------------------------------------------
Goal:
    Verify end-to-end bidirectional communication between
    two UART cores operating in full-duplex mode.

Architecture:
    • Two UART DUTs cross-connected (TX ↔ RX)
    • Shared interface connects DUT ↔ testbench
    • UVM-style environment (generator, driver, monitor, scoreboard)

Operation:
    • Both UARTs transmit and receive simultaneously
    • Constrained-random stimulus applied to both TX paths
    • Monitors capture RX data and forward to scoreboard
    • Scoreboard performs cross-UART data comparison

Data Flow:
    Generator → Driver → DUT → Monitor → Scoreboard
------------------------------------------------------------
*/


module testbench();
   // Instantiate interface
   itf itff();
    
    // ---------- Clock Stimuli ----------
    initial begin
        itff.clk1 = 0;      // internal clock
        itff.clk2 = 0;      // user clock
    end
    always begin
        #2.5         // (2.5ns -> 200 MHz)
        itff.clk1 = ~itff.clk2;
        itff.clk2 = ~itff.clk2;
    end
    
    // ------------ UART1 ---------------
    uart_core uart1 (
        .i_Rst(itff.rst),
        .i_Clk_200MHz(itff.clk1),
        .i_Clk_User(itff.clk2),
        .s_tvalid(itff.u1_s_tvalid),
        .s_tdata(itff.u1_s_tdata),
        .s_tready(itff.u1_s_tready),
        .m_tready(1),
        .m_tvalid(itff.u1_m_tvalid),
        .m_tdata(itff.u1_m_tdata),
        .o_PAR_Err(itff.u1_o_PAR_Err),
        .o_FRM_Err(itff.u1_o_FRM_Err),
        .o_OVF_Err(itff.u1_o_OVF_Err),
        .i_RX(itff.u2_o_TX),
        .o_TX(itff.u1_o_TX)
    );    
    
   // ------------ UART2 ---------------
    uart_core uart2 (
        .i_Rst(itff.rst),
        .i_Clk_200MHz(itff.clk1),
        .i_Clk_User(itff.clk2),
        .s_tvalid(itff.u2_s_tvalid),
        .s_tdata(itff.u2_s_tdata),
        .s_tready(itff.u2_s_tready),
        .m_tready(1),
        .m_tvalid(itff.u2_m_tvalid),
        .m_tdata(itff.u2_m_tdata),
        .o_PAR_Err(itff.u2_o_PAR_Err),
        .o_FRM_Err(itff.u2_o_FRM_Err),
        .o_OVF_Err(itff.u2_o_OVF_Err),
        .i_RX(itff.u1_o_TX),
        .o_TX(itff.u2_o_TX)
    );

    // Test program instantiation (verification starts here)
    test tst(itff); 
    
    
endmodule
