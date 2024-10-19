### **Steps 1-4: High-Level Design & Initial STFT Setup**

The first few steps in our Verilog implementation for the phase vocoder focus on preparing the input signal, segmenting it into frames, and performing the Short-Time Fourier Transform (STFT).

---

### **Step 1: Input Audio Handling**

The input audio signal is processed into frames to prepare for the STFT.

#### **High-Level Requirements**:
1. **Load Audio Data**: The audio data must be segmented into frames for processing.
2. **Buffer Audio Data**: Store the audio data in memory so it can be processed frame by frame.

#### **Module 1: Audio Input Buffer (Verilog)**

This module reads the audio input signal into a buffer for further processing.

```verilog
module audio_input_buffer (
    input clk,
    input rst,
    input signed [15:0] audio_in,  // 16-bit audio input
    input valid_in,
    output reg [15:0] audio_frame_out,  // Output the current audio frame
    output reg valid_out
);

    // Frame buffer (assuming 1024 samples per frame)
    reg [15:0] frame_buffer[0:1023];
    reg [9:0] buffer_index;  // Track the position within the frame buffer

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buffer_index <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Store input audio in buffer
            frame_buffer[buffer_index] <= audio_in;
            buffer_index <= buffer_index + 1;

            // Output frame when buffer is full
            if (buffer_index == 1023) begin
                audio_frame_out <= audio_in;  // Output the current frame
                valid_out <= 1;
                buffer_index <= 0;  // Reset buffer index
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule
```

---

### **Explanation**:
- **Input Buffering**: The module buffers the input audio into 1024-sample frames, ready to be processed by the STFT module.
- **Frame Output**: Once a frame is complete, it outputs the frame for further processing.
- **Synchronization**: Valid signals are used to indicate when the module is ready with a new frame.

---

### **Step 2: Apply Hanning Window**

Before performing the STFT, each frame is multiplied by a Hanning window to reduce spectral leakage.

#### **High-Level Requirements**:
1. **Hanning Window Multiplication**: Multiply each audio frame by a Hanning window of the same length to taper the edges.

#### **Module 2: Hanning Window (Verilog)**

```verilog
module hanning_window (
    input clk,
    input rst,
    input signed [15:0] audio_frame_in,
    input valid_in,
    output reg signed [15:0] windowed_frame_out,
    output reg valid_out
);

    // Pre-calculated Hanning window values for 1024 points (stored in ROM)
    reg [15:0] hanning_values[0:1023];
    initial $readmemh("hanning_coeffs.hex", hanning_values);  // Load values from file

    reg [9:0] index;  // Index for window values

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            index <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Apply Hanning window to the audio frame
            windowed_frame_out <= (audio_frame_in * hanning_values[index]) >>> 15;  // Scale down result
            index <= index + 1;

            if (index == 1023) begin
                index <= 0;
            end
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule
```

---

### **Explanation**:
- **Windowing**: The module multiplies each frame of the input signal by a pre-calculated Hanning window to smooth the edges of the frame.
- **Scaling**: The multiplication result is shifted right to maintain the proper scaling of the signal.
- **Window Values**: The Hanning window coefficients are stored in a ROM (read-only memory), which is loaded from a file during initialization.

---

### **Step 3: FFT Calculation (STFT)**

The Fast Fourier Transform (FFT) is applied to each windowed frame to convert the signal to the frequency domain.

#### **High-Level Requirements**:
1. **FFT Computation**: Apply a 1024-point FFT to the windowed frame.
2. **Store Results**: Store the FFT result (magnitude and phase) for each frame.

#### **Module 3: FFT Processing (Verilog)**

```verilog
module fft_1024 (
    input clk,
    input rst,
    input signed [15:0] windowed_frame_in,
    input valid_in,
    output reg signed [15:0] real_out,  // Real part of FFT result
    output reg signed [15:0] imag_out,  // Imaginary part of FFT result
    output reg valid_out
);

    // Instantiate FFT core (assume using Xilinx FFT IP core)
    // Parameters for 1024-point FFT
    wire signed [15:0] fft_real;
    wire signed [15:0] fft_imag;
    wire fft_valid_out;

    xilinx_fft_core fft_core_inst (
        .clk(clk),
        .rst(rst),
        .s_axis_data_tdata(windowed_frame_in),
        .m_axis_data_tdata({fft_real, fft_imag}),
        .m_axis_data_tvalid(fft_valid_out)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            real_out <= 0;
            imag_out <= 0;
            valid_out <= 0;
        end else if (fft_valid_out) begin
            real_out <= fft_real;
            imag_out <= fft_imag;
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule
```

---

### **Explanation**:
- **FFT Core**: The module uses an external FFT core (e.g., Xilinx's FFT IP core) to compute the 1024-point FFT of the windowed frame.
- **Real and Imaginary Parts**: The real and imaginary parts of the FFT output are captured for further processing.
- **Synchronization**: The FFT module outputs valid signals when the result is ready.

---

### **Step 4: Magnitude and Phase Calculation**

Once the FFT is performed, we calculate the magnitude and phase of the frequency components.

#### **High-Level Requirements**:
1. **Magnitude Calculation**: Compute the magnitude of the frequency components from the real and imaginary parts of the FFT result.
2. **Phase Calculation**: Calculate the phase from the real and imaginary parts.

#### **Module 4: Magnitude and Phase Calculator (Verilog)**

```verilog
module mag_phase_calc (
    input clk,
    input rst,
    input signed [15:0] real_in,  // Real part from FFT
    input signed [15:0] imag_in,  // Imaginary part from FFT
    input valid_in,
    output reg signed [15:0] mag_out,  // Magnitude of the frequency component
    output reg signed [15:0] phase_out,  // Phase of the frequency component
    output reg valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mag_out <= 0;
            phase_out <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Calculate magnitude: sqrt(real^2 + imag^2)
            mag_out <= sqrt(real_in * real_in + imag_in * imag_in);  // Magnitude calculation
            // Calculate phase: atan2(imag, real)
            phase_out <= atan2(imag_in, real_in);  // Phase calculation (CORDIC-based)

            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule
```

---

### **Explanation**:
- **Magnitude**: The magnitude is calculated using the formula `sqrt(real^2 + imag^2)`.
- **Phase**: The phase is calculated using the `atan2(imag, real)` function, which can be implemented using a CORDIC algorithm.
- **Output**: The module outputs the magnitude and phase for each frequency bin of the FFT.

---

### **Summary of Steps 1-4**:
1. **Step 1**: The audio signal is buffered into frames for processing.
2. **Step 2**: Each frame is multiplied by a Hanning window to reduce spectral leakage.
3. **Step 3**: The windowed frames are transformed into the frequency domain using a 1024-point FFT.
4. **Step 4**: The magnitude and phase of each frequency component are calculated from the FFT result.
