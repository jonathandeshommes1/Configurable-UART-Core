/*
------------------------------------------------------------
Agent (Per UART)
------------------------------------------------------------
Purpose:
    Encapsulates all verification components for a single UART instance.

Components:
    • Generator → creates randomized transactions
    • Driver    → drives DUT inputs (TX path)
    • Monitor   → observes DUT outputs (RX path)

Modes:
    • Active  → generates stimulus and monitors DUT
    • Passive → monitors DUT only

Key Field:
    • uart_id → identifies which UART instance (1 or 2) the agent controls

Behavior:
    • Each UART is assigned its own agent via uart_id
    • Enables independent stimulus and monitoring per DUT
    • Supports full-duplex verification (both UARTs active simultaneously)
------------------------------------------------------------
*/

 

class agent;   
    // Handles of components inside agent
    generator gen;
    driver    drv;
    monitor   mon;
    scoreboard scb;
    
    //Mailboxes
    mailbox gen2drv;
    mailbox mon2scb;  //external -> environment {scb}
    
    // Virtual Interface  {differentiate}
    virtual itf vif;
    
    // handle for control flag
    bit is_active;
    
    //uart type
    int uart_id;
    
    //Instantiates of UVM components with required {references}
    function new(virtual itf vif, mailbox mon2scb,scoreboard scb, int uart_id, bit is_active = 1);
        //Set handles = to passed in references {for access}
        this.scb = scb;
        this.vif = vif;
        this.mon2scb = mon2scb;
        this.uart_id = uart_id;
        this.is_active = is_active;
        
        //create internal mailbox
        gen2drv = new();
        
        //Instantiate components; 
        mon = new(vif, mon2scb, uart_id); 
        //active agent drives stimulus                           
        if(is_active) begin               
            gen = new(gen2drv, uart_id);
            drv = new(vif, gen2drv, uart_id, scb);       
        end
       
    endfunction
    
    //concurrently execute the task of all components
    task run();
        fork
            if(is_active) begin
                gen.main();     //produces transaction
                drv.main();     //apply signals to DUT
            end 
            mon.main();         //observes DUT signals {always monitoring}
        join
    endtask  
endclass