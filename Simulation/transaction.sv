/*
------------------------------------------------------------
Transaction (UART Packet)
------------------------------------------------------------
Purpose:
    Represents a single UART data transfer.

Fields:
    • tx_data → transmitted byte
    • rx_data → received byte
    • Error flags (parity, framing, overflow)
    • uart_id → source identifier

Notes:
    • Used across generator, driver, monitor, scoreboard
------------------------------------------------------------
*/

class transaction;
    
    // DUT DATA (to drive, observe pin-level signasl)
    rand bit [7:0] tx_data;         //Data to transmit out via tx pin {gen and drv}    
    bit      [7:0] rx_data;         //Data packet formed from sampling the rx pin {mon}
    bit            par_err;         //Flag indicating mismatched parity    
    bit            frm_err;         //Flag indicating a frame error         
    bit            ovf_err;         //Flag indicating overflow error     
    
    int uart_id; // which uart {agent genator} generated it    
    
    
    //-- Debugging function {display date elements of transaction packet} 
    function void display(string tag);
        $display("[%s] TX=%h, RX=%h, PAR_ERR=%b, FRM_ERR=%b, OVF_ERR=%b",
                 tag, tx_data, rx_data, par_err, frm_err, ovf_err);
    endfunction
    
endclass