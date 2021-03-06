// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class irq_monitor extends uvm_monitor;

  protected virtual irq_if vif;

  uvm_analysis_port#(irq_seq_item) irq_port;

  `uvm_component_utils(irq_monitor)

  function new(string name, uvm_component parent=null);
    super.new(name, parent);
    irq_port = new("irq_port", this);
  endfunction : new

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual irq_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
    end
  endfunction: build_phase

  virtual task run_phase(uvm_phase phase);
    collect_irq();
  endtask : run_phase

  // We know that for Ibex, any given interrupt stimulus will be asserted until the core signals the
  // testbench that it has finished handling, and this stimulus will not change until the testbench
  // receives the signal, at which point it will drop.
  // Given this, as well as how the interrupt handshakes are designed, sending an irq_seq_item every
  // cycle is not useful at all.
  // In order to not send unnecessary sequence items, but to also send enough information that the
  // testbench can handle nested interrupt scenarios, the monitor will send out a sequence
  // item every time the interrupt lines change.
  virtual protected task collect_irq();
    irq_seq_item irq;
    bit[DATA_WIDTH-1:0] stored_irq_val = '0;
    bit[DATA_WIDTH-1:0] current_irq = '0;
    forever begin
      current_irq = {vif.irq_nm, vif.irq_fast, 4'b0, vif.irq_external, 3'b0,
                     vif.irq_timer, 3'b0, vif.irq_software, 3'b0};
      if (current_irq !== stored_irq_val) begin
        stored_irq_val = current_irq;
        irq = irq_seq_item::type_id::create("irq");
        irq.irq_software = vif.irq_software;
        irq.irq_timer = vif.irq_timer;
        irq.irq_external = vif.irq_external;
        irq.irq_fast = vif.irq_fast;
        irq.irq_nm = vif.irq_nm;
        irq_port.write(irq);
      end
      @(posedge vif.clock);
    end
  endtask : collect_irq

endclass : irq_monitor
