# **1️⃣ Cache Core Architecture — Eren**

This is one of the two major new hardware modules for Phase 6\.

### **Responsibilities**

* Implement a fully parameterizable cache module:  
  * Cache size  
  * Block size  
  * N‑way associativity  
* Implement tag array, valid bits, dirty bits, and data array.  
* Implement hit detection logic and block offset extraction.  
* Build separate instruction cache and data cache instances.  
* Expose a clean interface for CPU requests, hit/miss, read/write, and block replacement.

### **Inputs**

* Address  
* Read/Write enable  
* Write data  
* Cache parameters (size, block size, associativity)

### **Outputs**

* Hit/Miss  
* Read data  
* Dirty bit status  
* Selected way index  
* Signals to miss‑handling FSM

### **Why this is a full job**

This is the foundation of the entire phase.

Every other task depends on this module’s interface, so one person owning the architecture avoids mismatched assumptions.

# **2️⃣ Replacement, Write Policy, and Prefetch Logic — Kai**

This is the second major new module.

### **Responsibilities**

* Implement LRU and PLRU replacement policy structures.  
* Implement victim‑selection logic for N‑way sets.  
* Implement write‑back on hit (dirty‑bit update).  
* Implement write‑allocate on miss.  
* Implement next‑line prefetching logic:  
  * Trigger prefetch on hit or miss  
  * Select next sequential block  
  * Avoid interfering with normal cache access

### **Inputs**

* Accessed way  
* Valid bits  
* Dirty bits  
* Tag match results  
* Cache hit/miss  
* Block index and tag

### **Outputs**

* Victim way  
* Updated LRU/PLRU state  
* Dirty‑bit updates  
* Prefetch request signals

### **Why this is a full job**

This module determines *which* block gets evicted, *when* dirty blocks are written back, and *how* prefetching interacts with normal accesses.

It is logic‑heavy and completely independent of CPU integration.

# **3️⃣ Miss‑Handling FSM & Shared Main Memory — Orion**

This is the only sequential control logic added in Phase 6\.

### **Responsibilities**

* Implement the miss‑handling finite‑state machine:  
  * Detect miss  
  * Stall cache  
  * Issue 100‑cycle memory penalty  
  * Handle block fill  
  * Handle dirty‑block write‑back  
  * Handle prefetch requests  
* Implement shared main memory for both caches.  
* Provide ready/valid handshake signals to caches.  
* Ensure instruction and data caches can miss independently without interfering.

### **Inputs**

* Miss request  
* Dirty bit  
* Victim way  
* Prefetch request  
* Memory address  
* Write‑back data

### **Outputs**

* Memory busy/ready  
* Filled block data  
* Write‑back completion  
* Stall/continue signals to cache

### **Why this is a full job**

This FSM is the only part of the design that interacts with the 100‑cycle memory penalty and must coordinate block transfers.

It is fully independent of CPU wiring and can be developed in parallel.

# **4️⃣ RISCV\_TOP Integration & signals.yaml — Dawn**

This role owns the top‑level wiring for Phase 6\.

### **Responsibilities**

* Replace direct memory access with:  
  * Instruction cache  
  * Data cache  
* Add CPU stall logic for cache misses:  
  * Freeze PC  
  * Freeze IF/ID  
  * Freeze pipeline registers as needed  
* Ensure instruction fetch stalls correctly propagate.  
* Ensure data memory stalls do not break forwarding or hazard logic.  
* Integrate prefetch behavior without corrupting pipeline state.  
* Update signals.yaml:  
  * IF\_ID\_Instruction  
  * IF\_ID\_PC  
  * Instruction\_Cache  
  * Data\_Cache

### **Inputs**

* Cache hit/miss  
* Cache stall signals  
* Miss‑handling FSM ready/valid  
* Prefetch signals  
* Pipeline control signals from Phase 5

### **Outputs**

* PCWrite  
* IFID\_Write  
* Pipeline stall signals  
* Cache request signals  
* Updated signals.yaml

### **Why this is a full job**

This is the only task that touches the CPU pipeline.

It is the glue that makes the caches actually work with the existing 5‑stage design.

