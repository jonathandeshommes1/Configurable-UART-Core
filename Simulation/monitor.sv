/*
------------------------------------------------------------
Monitor
------------------------------------------------------------
Purpose:
    Observes DUT outputs and captures received data.

Behavior:
    • Samples RX data when valid {rx fifo not empty} is asserted
    • Packages data into new transaction
    • Sends transaction to scoreboard (for comparison vs expected)

Notes:
    • Passive component (no signal driving)
    • Each sample stored in a unique object
------------------------------------------------------------
*/
class monitor;
    
    // Internal references allowing modification of external data
    mailbox mon2scb;
    virtual itf vif;
    int uart_id;
    
    function new(virtual itf vif, mailbox mon2scb, int uart_id);
        this.vif = vif;         //pointer {alias} to the current class
        this.mon2scb = mon2scb;
        this.uart_id = uart_id;
    endfunction
    
    task main();
        repeat(10)
        begin       
            // creates new transaction object with unique memory
            transaction trans;           
            trans = new();
            
            // observe DUT signals and package them into trans object
            case (uart_id)
                1 : begin
                    @(posedge vif.u1_m_tvalid);         //uart1_rx fifo not_empty
                    trans.rx_data  = vif.u1_m_tdata;
                    trans.par_err  = vif.u1_o_PAR_Err;
                    trans.frm_err  = vif.u1_o_FRM_Err;
                    trans.ovf_err  = vif.u1_o_OVF_Err;
                    trans.uart_id  = 1;
                    
                    trans.display ("MON U1");
                    
                end 
                2 : begin
                    @(posedge vif.u2_m_tvalid);       //uart2_rx fifo not_empty
                    trans.rx_data  = vif.u2_m_tdata;
                    trans.par_err  = vif.u2_o_PAR_Err;
                    trans.frm_err  = vif.u2_o_FRM_Err;
                    trans.ovf_err  = vif.u2_o_OVF_Err;
                    trans.uart_id  = 2;
                     
                     trans.display ("MON U2");
                end 
            endcase
            
            //places transaction reference into mailbox
            mon2scb.put(trans);
            
            
        end
    endtask
endclass