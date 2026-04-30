// ------------------------------------------------------------
// Test Program
// ------------------------------------------------------------
// Purpose:
//  -- Top-level testbench program used to verify the DUT
//  -- Instantiates the environment and connects it to the DUT
//  -- Separates verification logic from RTL design (clean testbench structure)
//
// Key Concepts:
//  -- Uses a program block instead of a module for testbench execution
//  -- Receives the interface from the top-level module
//  -- Passes the virtual interface into the environment
//  -- Ensures structured simulation flow and avoids race conditions with DUT

// Operation:
//  -- Accepts a physical interface instance {intff} from the top module
//  -- Creates an environment object
//  -- Passes the interface into the environment constructor
//  -- Calls {test_run()} to start all verification components

// Flow:
//  Top Module → Interface → Test Program → Environment → TB Components
// ------------------------------------------------------------


`include "environment.sv"
program test(itf intff);
    //Handle to the environment
     environment env;
    
    //only ran once at start of simulation
    initial begin      
        // Initialize with passed intf reference 
        env = new(intff);
        
        // Start generator, driver, monitor, scoreboard
        env.test_run();    
    end;
endprogram