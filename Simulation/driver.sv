/*
------------------------------------------------------------
Driver
------------------------------------------------------------
Purpose:
    Drives DUT input signals using transactions from generator.

Behavior:
    • Receives transaction via mailbox
    • Applies TX data through virtual interface
    • Handles valid/ready handshake
    • Sends expected data to corresponding scoreboard queue 

Notes:
    • Virtual interface (reference to real intf} connects class → DUT signals
    • Classes are dynamic → cannot directly access DUT signals (static)
------------------------------------------------------------
*/


class driver;
    // Internal handle allowing modification of external data
    mailbox gen2drv;        // pointer of intf object (points to nothing) (null) 
    virtual itf vif;        // pointer of mailbox object (points to nothing) (null)
    
    // Which UART instance? 1 or 2
    int uart_id;
    
    //scoreboard handle
    scoreboard scb;         // tells scoreboard (what was transmitted)
    
    // Set internal references equal to passed-in pointers 
    function new (virtual itf vif, mailbox gen2drv, int uart_id, scoreboard scb);
        this.vif = vif;
        this.gen2drv = gen2drv; 
        this.uart_id = uart_id;
        this.scb = scb;   
    endfunction
   
    //Task drives the data to the virtual interface
    task main();
        repeat(10)
        begin
            
            transaction trans;      // Handle (reference) (no object yet) (valid for one iteration)
            gen2drv.get(trans);     // Local trans reference = passed in trans from generator
            
            //Select Correct DUT signals
            case (uart_id)
                1 : begin
                    vif.u1_s_tdata  = trans.tx_data;    // data to write to TX FIFO
                    
                    // handshake -> Flow control
                    wait (vif.u1_s_tready == 1);        // ensure FIFO is not full
 
                    vif.u1_s_tvalid = 1;                // Indicate to DUT to write to FIFO
                    @(posedge vif.clk2);
                    vif.u1_s_tvalid = 0;                // Prevent further writes to FIFO
                    
                    trans.display("DRV U1"); 
                end
                2 : begin           
                    vif.u2_s_tdata  = trans.tx_data;    // data to write to TX FIFO
                    
                    // handshake -> Flow control
                    wait (vif.u2_s_tready == 1);        // ensure FIFO is not full
 
                    vif.u2_s_tvalid = 1;                // Indicate to DUT to write to FIFO
                    @(posedge vif.clk2);
                    vif.u2_s_tvalid = 0;                // Prevent further writes to FIFO   
                    
                    trans.display("DRV U2");                                                
                end 
            endcase           
            
            //tell scoreboard transaction driven and from which core
            trans.uart_id = uart_id;
            scb.write_expected(uart_id, trans.tx_data); //push expected data into correct uart{x} queue
                
        end           
    endtask
endclass