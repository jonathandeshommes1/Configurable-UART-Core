/*
------------------------------------------------------------
Environment Class
------------------------------------------------------------
Purpose:
    Top-level container that builds and connects all verification components.

Components:
    • Agent (UART1)  → Drives and monitors UART1 traffic
    • Agent (UART2)  → Drives and monitors UART2 traffic
    • Scoreboard     → Compares TX vs RX data for correctness
    • Mailbox        → Transfers observed data from monitor to scoreboard

Behavior:
    • Both agents run concurrently to model full-duplex communication
    • Scoreboard validates cross-UART data integrity
------------------------------------------------------------
*/


`include "transaction.sv"
`include "generator.sv"
`include "scoreboard.sv"
`include "driver.sv"
`include "monitor.sv"
`include "agent.sv"
class environment;
    agent agt1;         // UART1 agent   
    agent agt2;         // UART2 agent
    
    scoreboard scb; 
    
    mailbox mon2scb;   
    
    virtual itf vif;
    
    function new(virtual itf vif);
        this.vif = vif;
        // Shared mailbox
        mon2scb = new();
        
         // Create scoreboard
        scb = new(mon2scb);
        
        // Create agents (both active for full-duplex)
        agt1 = new(vif, mon2scb, scb, 1, 1); 
        agt2 = new(vif, mon2scb, scb, 2, 1); 
    endfunction  
    
    // concurrently run scb and agent {
    task test_run();
        fork
            agt1.run();   // agent handles gen+drv+mon
            agt2.run();   // agent handles gen+drv+mon
            scb.main();   // handles scoreboard
        join
    endtask 
endclass
