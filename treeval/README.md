# Treeval Accelerator

This collection of modules is an acclerator of the computation of optimal expected reward via backpropagation through a tree of representing a hypothesis about the world and future. In addition, there is a controller to wrap the acclerator such that it is accessible to software via AXI and thus able to be integrated into general computing systems.

## Source Code Layout

The following is a high-level overview of the repository:

* __treeval.sv__ => Implementation of accelerator.
* __axi_fifo_dummy.sv__ => Implementation of mockup of AXI IP without full integration.
* __treeval_controller.sv__ => Implementation of controller that wraps accelerator and AXI (top).
* __treeval_tb.sv__ => Standalone testbench for accelerator.
* __axi_fifo_dummy.sv__ => Standalone testbench for AXI dummy.
* __treeval_controller.sv__ => Testbench for controller.

## Prerequisites

* [Vivado](https://www.xilinx.com/products/design-tools/vivado.html) for simulation and builds is recommended.

## Documentation and Analysis

See [this paper](https://github.com/joshkimmel16/reinforce-accelerator/blob/master/CS_259__Final_Project_Report.pdf) for more robust documentation of the hardware and its performance.

## Authors

* **Josh Kimmel**
* **Hannah Nguyen**