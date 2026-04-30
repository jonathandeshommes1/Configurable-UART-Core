/*
------------------------------------------------------------
Scoreboard
------------------------------------------------------------
Purpose:
    Verifies correctness of full-duplex UART communication.

Method:
    • Stores expected TX data in per-UART queues
    • Receives actual RX data from monitor
    • Performs cross-UART comparison:
        UART1 RX ← UART2 TX
        UART2 RX ← UART1 TX

Key Feature:
    • Queue-based alignment handles FIFO + UART latency naturally
    • Preserves ordering of transmitted data (FIFO behavior) 
    • Enables synchronization of transmitted and received data

Error Handling:
    • Transactions with error flags are ignored

Output:
    • PASS / FAIL messages per transaction

Next steps:
    • Add functional coverage
    • Inject parity/frame errors
    • Verify FIFO full/empty conditions
------------------------------------------------------------
*/

class scoreboard;
    
    //mailbox to communicate with monitor
    mailbox mon2scb;
    
    // Expected queues
    bit [7:0] u1_tx_q[$];  // expected queue from UART1 TX
    bit [7:0] u2_tx_q[$];  // expected queue from UART2 TX -> compare against opposite RX
    
    function new (mailbox mon2scb);
        this.mon2scb = mon2scb;    
    endfunction

    // Called by driver to store expected TX data 
    function void write_expected(int uart_id, bit [7:0] data);
        if (uart_id == 1)
            u1_tx_q.push_back(data);
        else
            u2_tx_q.push_back(data);
    endfunction
      
task main();
    repeat(20)
    begin
        transaction trans; 
        mon2scb.get(trans);  // RX transaction

        // check error flags first (RX would deassert rx_dv)(no byte written to FIFO)
        if (trans.par_err || trans.frm_err || trans.ovf_err) begin
            $display("WARNING: Error flags detected UART%0d (ignored)", trans.uart_id);
            continue;
        end 
        

        // UART1 RX → compare with UART2 TX.  {UART1 RX ← UART2 TX}
        if (trans.uart_id == 1) begin
            if (u2_tx_q.size() == 0) begin
                $display("ERROR: No expected data for UART1 (queue empty)");
            end else begin
                bit [7:0] exp = u2_tx_q.pop_front();

                if (exp != trans.rx_data)
                    $display("MISMATCH U2->U1: EXP=%h ACT=%h", exp, trans.rx_data);
                else
                    $display("PASS U2->U1: EXP=%h ACT=%h", exp, trans.rx_data);
            end
        end

        // UART2 RX → compare with UART1 TX. {UART2 RX ← UART1 TX}
        else if (trans.uart_id == 2) begin
            if (u1_tx_q.size() == 0) begin
                $display("ERROR: No expected data for UART2 (queue empty)");
            end else begin
                bit [7:0] exp = u1_tx_q.pop_front();

                if (exp != trans.rx_data)
                    $display("MISMATCH U1->U2: EXP=%h ACT=%h", exp, trans.rx_data);
                else
                    $display("PASS U1->U2: EXP=%h ACT=%h", exp, trans.rx_data);
            end
        end

    end
endtask
endclass


