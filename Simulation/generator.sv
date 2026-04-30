/*
------------------------------------------------------------
Generator
------------------------------------------------------------
Purpose:
    Produces randomized UART transactions to drive DUTs using virtual interface

Behavior:
    • Creates new transaction each iteration
    • Randomizes TX data
    • Sends transaction to driver via mailbox

Notes:
    • Transactions are passed by reference (no copying)
------------------------------------------------------------
*/


class generator;
    mailbox gen2drv;
    transaction trans;
    
    int uart_id;
    
    function new (mailbox gen2drv, int uart_id);
        this.gen2drv = gen2drv;
        this.uart_id = uart_id;
    endfunction
    
    //Task that randomized/generated values {stimuli} to drive DUT
    task main();
        repeat(10)
        begin
            trans = new();
            trans.randomize();
            if (uart_id == 1) 
                trans.display("GEN U1");
            else if (uart_id == 2) 
                trans.display("GEN U2");

            gen2drv.put(trans);
        end 
    endtask
endclass