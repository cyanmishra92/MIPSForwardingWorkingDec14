# Branch/Jump Wrapper Plan

This project keeps `Design.v` intact and introduces a new top-level wrapper that layers the branch/jump datapath pieces shown in Figure 6 of the project spec.

## Goals
- Preserve the existing forwarding-focused datapath from `Design.v` unchanged.
- Create a new top-level module that instantiates the original datapath, plus the external logic for branch/jump handling and refreshed memories.
- Use the new instruction stream and data initializations required by the updated lab instructions.

## Wrapper Responsibilities
1. **Instruction Memory (updated contents)**
   - Replace the previous five-ALU-program image with the new instruction sequence from the updated lab handout.
   - Keep the original instruction memory module untouched; the wrapper supplies a replacement memory instance with the new contents and connects it to the datapath's IF stage signals (address from PC, data to IF/ID).

2. **Data Memory (updated contents)**
   - Initialize the first words with the revised values given in the new lab (separate from the earlier A00000AA pattern).
   - Disconnect the original memory initialization in `Design.v`; the wrapper owns the memory and feeds its read/write ports to the MEM stage ports.

3. **Branch/Jump Addressing**
   - Add the Figure 6 mux chain that selects the next PC among `pc+4`, branch target, jump target, and JR/return paths.
   - Include the shift-left-2 units for branch immediate and jump target assembly, plus the adder for `pc+4+imm<<2`.
   - Feed the mux select signals from the existing control outputs (`pcsrc`, `jal`, `wpcir`) already produced by the control unit inside `Design.v`.

4. **Branch Comparison**
   - Provide an equality comparator for `rs` vs `rt` values entering ID; connect its output to the `rsrtequ` input on the control unit so it can assert `pcsrc` correctly.
   - Ensure the comparator uses the forwarded ID-stage values (`da`, `db`) exposed by the datapath.

5. **Register Write-Back Adjustments**
   - Support `jal` by routing `pc+8` into register 31 through the wrapper’s muxing into the datapath’s writeback data/rd index ports, while keeping normal R/I-type writes unchanged.

6. **Stall/Flush Control**
   - Honor `wpcir` from the control unit to gate PC and IF/ID updates; the wrapper should use this as the enable on the PC register and the IF/ID pipeline register replacement.
   - On taken branch/jump, flush the following IF/ID contents as specified by Figure 6.

## Interface Sketch (no code yet)
- Wrapper top I/O: `input clk`, `input rst` (or synchronous reset), `output [31:0] pc`, optional probe signals for the testbench.
- Instantiate existing datapath core as `datapath u_core (...)` with its instruction/data ports connected to wrapper-managed memories and control helper signals.
- Provide new instruction memory module (e.g., `imem_branchjump`) and data memory module (`dmem_branchjump`) that mirror the old port lists but with new initial contents.

## Next Steps (pending approval)
- Add the wrapper Verilog file implementing the above connections.
- Populate the instruction/data memories per the updated program in Figure 6 and the new lab tables.
- Adjust the testbench (or create a new one) to drive the wrapper top instead of the old datapath module.
