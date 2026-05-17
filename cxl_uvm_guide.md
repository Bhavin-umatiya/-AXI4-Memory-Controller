# A UVM-Verified Advanced AXI4 Memory Controller

This guide breaks down the theory and step-by-step implementation plan for your high-performance memory controller project. As discussed, while a full CXL (Compute Express Link) protocol stack is incredibly complex and requires PCIe Gen5 knowledge, the industry standard stepping stone is building an **AXI4-Coherent Memory Controller** and verifying it heavily with **UVM (Universal Verification Methodology)**. 

This project will make you highly competitive for top VLSI verification roles at companies like Qualcomm, AMD, and NVIDIA.

---

## The Big Picture (Theory)

### Why AXI4?
**AXI (Advanced eXtensible Interface)** is part of ARM's AMBA architecture. It is the de facto standard for high-performance, high-frequency, low-latency communication inside modern SoCs (System on Chips). Unlike older protocols, AXI separates address/control and data phases, allows unaligned data transfers, and supports burst transactions.

AXI4 consists of 5 independent channels:
1. **Write Address (AW):** Master sends the address and control information for a write.
2. **Write Data (W):** Master sends the actual data.
3. **Write Response (B):** Slave responds with the status of the write (Success, Error).
4. **Read Address (AR):** Master sends the address and control information for a read.
5. **Read Data (R):** Slave sends the data and read status back to the master.

All channels use a strict **VALID / READY** handshake mechanism. The sender asserts `VALID` when data is ready, and the receiver asserts `READY` when it can accept it. A transfer only occurs when both are high at a clock edge.

### Why UVM?
**UVM (Universal Verification Methodology)** is a standardized framework based on SystemVerilog used to verify complex digital designs. 
Why not just write a simple testbench? Because in real chips, bugs happen in crazy corner cases (e.g., sending a read burst right after a write burst while the FIFO is almost full and resetting the system). UVM allows us to:
- **Constrain Randomize:** Automatically generate millions of unique, valid (or intentionally invalid) scenarios.
- **Coverage:** Mathematically prove we hit every possible state and transition.
- **Scoreboarding:** Automatically predict what the hardware *should* do and compare it to what it *actual* did.

---

## Phase 1: The RTL Design (SystemVerilog)

In this phase, we act as the **Design Engineer**. We will write synthesizeable SystemVerilog for an AXI4 Slave that connects to an internal SRAM (Static Random Access Memory) array.

### Step-by-Step Implementation

1. **Setup Vivado Project:**
   - Open Vivado and create a new RTL project.
   - Select your target board/FPGA (even if we are just simulating, it's good practice).
   - Create a new SystemVerilog file: `axi4_slave.sv`.

2. **Define the Interface:**
   - Define all the input and output ports for the 5 AXI channels. 
   - Define parameters for `ADDR_WIDTH` (e.g., 12 bits) and `DATA_WIDTH` (e.g., 32 or 64 bits).

3. **Implement the SRAM Array:**
   - Create a 2D packed array in SystemVerilog to act as your memory.
   - Example: `logic [DATA_WIDTH-1:0] mem_array [0:(1<<ADDR_WIDTH)-1];`

4. **Write Address & Data FSM (Finite State Machine):**
   - Create an FSM to handle incoming Write transactions.
   - **IDLE:** Wait for `AWVALID`. When it arrives, assert `AWREADY` and capture the starting address and burst length (`AWLEN`).
   - **WRITE:** Wait for `WVALID`. When it arrives, assert `WREADY`, write the data into the `mem_array`, and increment the internal address pointer. Keep doing this until the `WLAST` signal is high (indicating the end of the burst).
   - **RESPONSE:** Assert `BVALID` with an `OKAY` response to tell the master the write finished successfully. Wait for `BREADY`.

5. **Read Address & Data FSM:**
   - Create an FSM to handle incoming Read transactions.
   - **IDLE:** Wait for `ARVALID`. Assert `ARREADY`, capture the address and burst length.
   - **READ:** Read from `mem_array`, assert `RVALID`, and send the data. If the master asserts `RREADY`, move to the next address. When sending the final piece of data in the burst, assert `RLAST`.

> [!TIP]
> Keep your read and write data paths independent. AXI4 supports simultaneous reads and writes (Full-Duplex)!

---

## Phase 2: The UVM Verification

In this phase, we act as the **Verification Engineer**. We will build an object-oriented, reusable testbench to try and break our RTL.

### The UVM Architecture (Theory)
A UVM testbench is built like Russian nesting dolls using OOP (Object-Oriented Programming) classes:
- **Sequence Item:** The fundamental data packet. In our case, this is an AXI Transaction (Address, Data, Read/Write type, Burst Length).
- **Sequencer:** Generates a stream of Sequence Items.
- **Driver:** Takes Sequence Items and translates them into physical 1s and 0s on the AXI pins (wiggling `VALID` and `READY`).
- **Monitor:** Passively watches the AXI pins. When it sees a valid transaction, it converts the 1s and 0s back into a Sequence Item and broadcasts it.
- **Agent:** Groups the Sequencer, Driver, and Monitor together.
- **Scoreboard:** Subscribes to the Monitor. It has a "Reference Model" (a perfect software version of the memory). It compares the RTL's read data with its own perfect data to catch data-corruption bugs.
- **Environment (Env):** Groups the Agent and Scoreboard.
- **Test:** The top-level class that configures the environment and starts specific sequences (e.g., `burst_read_write_test`, `fifo_full_test`).

### Step-by-Step Implementation

1. **Define the Sequence Item (`axi_item.sv`):**
   - Create a class extending `uvm_sequence_item`.
   - Add random variables (`rand bit [31:0] addr;`, `rand bit [31:0] data;`, `rand bit [7:0] len;`).
   - Add **Constraints**: e.g., ensure `addr` is aligned, ensure `len` doesn't exceed memory bounds.

2. **Build the Agent Components:**
   - **Driver (`axi_driver.sv`):** Write a state machine inside the `run_phase` that mimics an AXI Master. It needs to drive `AWVALID`, `WVALID`, etc., based on the item received from the sequencer.
   - **Monitor (`axi_monitor.sv`):** Write parallel threads (using `fork/join`) that constantly monitor the 5 AXI channels for successful handshakes (`VALID & READY`).

3. **Build the Scoreboard (`axi_scoreboard.sv`):**
   - Create an associative array (`int ref_mem [int]`) to act as the gold-standard memory.
   - When the monitor broadcasts a Write transaction, update `ref_mem`.
   - When the monitor broadcasts a Read transaction, compare the RTL's read data against `ref_mem`. If they don't match, trigger a `uvm_error`.

4. **Write the Top-Level and Interface:**
   - Create an SV `interface` to bundle the wires between the testbench and your RTL.
   - Create a `top.sv` module that instantiates your RTL module, the interface, and calls `run_test()`.

5. **Write Sequences and Run Tests:**
   - Write a base sequence that randomizes 1000 transactions.
   - Run the simulation in Vivado (or Questasim/VCS if you have access). Look at the log output and waveform to ensure the AXI handshakes are perfectly aligned.

---

### Next Steps
We can now start writing the SystemVerilog code for the **Phase 1 RTL Design**, specifically the AXI4 Interface and Memory Array.
