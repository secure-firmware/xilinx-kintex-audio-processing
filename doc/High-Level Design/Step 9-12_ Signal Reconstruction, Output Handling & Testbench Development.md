### **Steps 9-12: Signal Reconstruction, Output Handling & Testbench Development**

Steps 9 to 12 involve the final stages of signal reconstruction, normalization, output handling, and the design of a testbench to validate the phase vocoder system.

---

### **Step 9: Signal Normalization**

Once the output signal is reconstructed using the overlap-add method, normalization ensures that the final audio signal doesn't exceed the allowable range, avoiding clipping.

#### **High-Level Requirements**:
1. **Find Maximum Amplitude**: Identify the maximum amplitude in the reconstructed signal.
2. **Normalize Output**: Scale the signal such that the maximum amplitude is within a safe range (e.g., -1 to 1 for 16-bit audio).

#### **Module 9: Signal Normalization (Verilog)**

```verilog
module signal_normalization (
    input clk,
    input rst,
    input signed [15:0] audio_in,  // Reconstructed audio
    input valid_in,
    output reg signed [15:0] audio_out,  // Normalized audio
    output reg valid_out
);

    reg signed [15:0] max_amplitude;  // Maximum amplitude of the signal
    reg signed [31:0] normalized_value;  // Temporary variable for scaled value

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            max_amplitude <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Find the maximum amplitude of the signal
            if (audio_in > max_amplitude) begin
                max_amplitude <= audio_in;
            end
            valid_out <= 1;
        end
    end

    always @(posedge clk) begin
        if (max_amplitude != 0) begin
            // Normalize the signal to ensure it's within [-1, 1]
            normalized_value <= (audio_in <<< 15) / max_amplitude;
            audio_out <= normalized_value[15:0];  // Truncate to 16 bits
        end
    end
endmodule
```

---

### **Explanation**:
- **Maximum Amplitude**: The module first calculates the maximum amplitude encountered in the signal.
- **Normalization**: It then scales the signal so that the maximum value becomes the maximum allowable amplitude, preventing clipping.
- **Output**: The final normalized audio is provided for writing to an output file or further processing.

---

### **Step 10: Output Handling (File Writing)**

After normalization, the final audio data needs to be written to an output file for storage or playback.

#### **High-Level Requirements**:
1. **Buffer Management**: Manage output audio data in memory.
2. **File Interface**: Interface with file-writing systems (such as SD card, memory storage).

#### **Module 10: Output Audio Buffer (Verilog)**

```verilog
module output_buffer (
    input clk,
    input rst,
    input signed [15:0] audio_in,  // Normalized audio
    input valid_in,
    output reg signed [15:0] audio_out,  // Output audio
    output reg write_enable        // Signal to enable writing to storage
);

    reg [15:0] audio_memory[0:16383];  // Audio output buffer
    reg [13:0] write_index;  // Memory write index

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            write_index <= 0;
            write_enable <= 0;
        end else if (valid_in) begin
            // Store the normalized audio in the output buffer
            audio_memory[write_index] <= audio_in;
            write_index <= write_index + 1;
            write_enable <= 1;  // Signal to indicate the buffer is ready to write
        end else begin
            write_enable <= 0;
        end
    end

    // Assign the output audio signal
    assign audio_out = audio_memory[write_index];

endmodule
```

---

### **Explanation**:
- **Output Buffer**: Stores the final audio data in memory for later writing to a file (e.g., using an SD card interface or external storage).
- **Write Enable**: Signals when the buffer is full and ready for writing.
- **Memory Write**: Writes audio samples to memory sequentially.

---

### **Step 11: Testbench Development**

To ensure that the Verilog design operates correctly, we create a testbench that simulates the full system, providing inputs and verifying the outputs.

#### **High-Level Requirements**:
1. **Stimulus Generation**: Generate test input signals (e.g., sample audio data).
2. **Monitor & Check Outputs**: Verify the system outputs are correct.
3. **Clock & Reset Simulation**: Simulate clock cycles and reset conditions.

#### **Module 11: Testbench (Verilog)**

```verilog
module testbench;

    reg clk;
    reg rst;
    reg signed [15:0] audio_in;  // Simulated audio input
    wire signed [15:0] audio_out;  // Normalized audio output
    wire write_enable;

    // Instantiate the complete phase vocoder system
    phase_vocoder_top uut (
        .clk(clk),
        .rst(rst),
        .audio_in(audio_in),
        .audio_out(audio_out),
        .write_enable(write_enable)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period, 100MHz clock
    end

    // Test procedure
    initial begin
        // Apply reset
        rst = 1;
        #10 rst = 0;

        // Simulate input audio
        audio_in = 16'h1FFF;  // Sample input (modify with real test data)
        #10 audio_in = 16'h0FFF;
        #10 audio_in = 16'h0AAA;

        // Continue feeding data
        #1000;

        // Finish simulation
        $finish;
    end

    // Monitor the outputs
    always @(posedge clk) begin
        if (write_enable) begin
            $display("Audio Output: %d", audio_out);
        end
    end

endmodule
```

---

### **Explanation**:
- **Clock & Reset**: The testbench generates a clock signal and handles reset conditions to initialize the phase vocoder system.
- **Test Inputs**: The `audio_in` signal is driven with test values to simulate audio input, which can be replaced with real audio data.
- **Output Monitoring**: The testbench monitors the `audio_out` and prints the values to the console for verification.
- **Write Enable**: This signal is used to indicate when data is ready for writing, which could be monitored for correctness.

---

### **Step 12: Test Coverage & Validation**

In this step, we ensure that the testbench covers all possible cases and edge scenarios, and validates that the system performs as expected.

#### **High-Level Requirements**:
1. **Test Cases**: Develop test cases for normal operation, edge conditions (e.g., silence, maximum amplitude), and stress tests.
2. **Coverage Analysis**: Ensure that all critical paths and corner cases are covered.

#### **Module 12: Test Case Development**

To thoroughly test the system, we should create additional test cases to handle various scenarios, such as:
- **Silence**: Test the system with an input of all zeros to verify that it handles silence correctly.
- **Clipping**: Use inputs that could result in clipping and ensure that the normalization step prevents this.
- **Real Audio Data**: Load actual audio waveforms into the testbench and verify the output using comparison scripts or tools.

---

### **Summary of Steps 9-12**:
1. **Step 9**: Signal normalization is performed to ensure the audio does not exceed allowable amplitude ranges.
2. **Step 10**: The normalized output is buffered and prepared for writing to an audio file or playback system.
3. **Step 11**: A testbench is developed to simulate the full system, with clock generation, reset handling, and output verification.
4. **Step 12**: Further test cases are defined to ensure complete coverage of edge cases and stress testing.
