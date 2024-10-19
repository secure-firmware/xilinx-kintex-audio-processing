### **Steps 5-8: Noise Reduction, Phase Vocoder Operations & Time Stretching**

Steps 5 to 8 handle noise reduction, the phase vocoder’s time-stretch operation, and interpolation between frames. These steps refine the signal's spectral components and reconstruct the output in the frequency domain.

---

### **Step 5: Noise Reduction**

After the FFT and magnitude/phase calculations, we apply noise reduction by subtracting an estimated noise spectrum from the current frame.

#### **High-Level Requirements**:
1. **Noise Spectrum Estimation**: Estimate the noise spectrum from the initial part of the audio.
2. **Noise Subtraction**: Subtract the noise spectrum from each frame's magnitude.

#### **Module 5: Noise Reduction (Verilog)**

```verilog
module noise_reduction (
    input clk,
    input rst,
    input signed [15:0] mag_in,      // Magnitude from FFT
    input valid_in,
    input signed [15:0] noise_est,   // Estimated noise spectrum
    output reg signed [15:0] mag_out,  // Noise-reduced magnitude
    output reg valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mag_out <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Subtract noise estimate from magnitude
            if (mag_in > noise_est) begin
                mag_out <= mag_in - noise_est;  // Ensure non-negative magnitude
            end else begin
                mag_out <= 0;
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
- **Noise Estimation**: The module subtracts an estimated noise spectrum from the current frame's magnitude.
- **Non-Negative Magnitude**: Ensures that the magnitude does not become negative after noise subtraction by clipping it to zero if necessary.
- **Input/Output**: The `noise_est` signal is provided externally and can be calculated based on the average noise from the initial audio segment.

---

### **Step 6: Phase Vocoder (Time Stretching)**

In this step, the phase vocoder operates to stretch the time of the signal by interpolating magnitude and phase values between frames.

#### **High-Level Requirements**:
1. **Time-Stretching Factor**: Interpolate frames based on a time-stretching factor (e.g., 1.5 for 50% slower).
2. **Phase Continuity**: Maintain smooth phase transitions to avoid discontinuities in the output.

#### **Module 6: Time-Stretching Interpolation (Verilog)**

```verilog
module time_stretch (
    input clk,
    input rst,
    input signed [15:0] mag_lower,  // Magnitude from lower frame
    input signed [15:0] mag_upper,  // Magnitude from upper frame
    input signed [15:0] phase_lower,  // Phase from lower frame
    input signed [15:0] phase_upper,  // Phase from upper frame
    input [9:0] interp_factor,  // Interpolation factor (fixed-point representation)
    input valid_in,
    output reg signed [15:0] mag_interp,  // Interpolated magnitude
    output reg signed [15:0] phase_interp,  // Interpolated phase
    output reg valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mag_interp <= 0;
            phase_interp <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Interpolate magnitude between frames
            mag_interp <= ((mag_lower * (1024 - interp_factor)) + (mag_upper * interp_factor)) >>> 10;
            
            // Interpolate phase
            phase_interp <= ((phase_lower * (1024 - interp_factor)) + (phase_upper * interp_factor)) >>> 10;
            
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule
```

---

### **Explanation**:
- **Magnitude & Phase Interpolation**: This module interpolates the magnitude and phase between two consecutive frames based on the time-stretching factor.
- **Phase Continuity**: It ensures that phase transitions between frames are smooth to avoid artifacts such as phase jumps.
- **Interpolation Factor**: The `interp_factor` is provided as a fixed-point value (scaled by 1024), where 0 means no interpolation and 1024 means complete interpolation to the next frame.

---

### **Step 7: Inverse FFT**

After the time-stretching interpolation, we perform the inverse FFT (IFFT) to convert the frequency-domain signal back into the time domain for each frame.

#### **High-Level Requirements**:
1. **Inverse FFT Calculation**: Perform a 1024-point IFFT on the interpolated magnitude and phase data.
2. **Complex to Real Conversion**: Convert the complex IFFT result into a real-valued time-domain signal.

#### **Module 7: Inverse FFT (Verilog)**

```verilog
module ifft_1024 (
    input clk,
    input rst,
    input signed [15:0] mag_in,    // Interpolated magnitude
    input signed [15:0] phase_in,  // Interpolated phase
    input valid_in,
    output reg signed [15:0] time_signal_out,  // Time-domain signal
    output reg valid_out
);

    // Convert magnitude and phase back to complex form
    wire signed [15:0] real_part = mag_in * cos(phase_in);
    wire signed [15:0] imag_part = mag_in * sin(phase_in);

    // Instantiate IFFT core (e.g., Xilinx IP core)
    wire signed [15:0] ifft_real;
    wire signed [15:0] ifft_imag;
    wire ifft_valid_out;

    xilinx_ifft_core ifft_core_inst (
        .clk(clk),
        .rst(rst),
        .s_axis_data_tdata({real_part, imag_part}),
        .m_axis_data_tdata({ifft_real, ifft_imag}),
        .m_axis_data_tvalid(ifft_valid_out)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            time_signal_out <= 0;
            valid_out <= 0;
        end else if (ifft_valid_out) begin
            time_signal_out <= ifft_real;  // We only take the real part of the IFFT result
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule
```

---

### **Explanation**:
- **Inverse FFT**: The IFFT is applied to convert the interpolated magnitude and phase data back into the time domain.
- **Complex to Real**: The IFFT results in complex numbers, but only the real part is used as the time-domain signal.

---

### **Step 8: Overlap-Add Reconstruction**

The final time-domain signal is reconstructed by overlapping and adding the IFFT results from each frame.

#### **High-Level Requirements**:
1. **Overlap-Add**: Add successive time-domain frames, accounting for overlap (based on the hop size).
2. **Output Buffering**: Store the final output audio in a buffer for saving or playback.

#### **Module 8: Overlap-Add (Verilog)**

```verilog
module overlap_add (
    input clk,
    input rst,
    input signed [15:0] frame_in,  // Time-domain frame from IFFT
    input [9:0] hop_size,         // Hop size (256 in this case)
    input valid_in,
    output reg signed [15:0] audio_out,  // Reconstructed audio output
    output reg valid_out
);

    // Output audio buffer
    reg signed [15:0] audio_buffer[0:16383];  // Adjust size as needed
    reg [13:0] write_index;  // Index for writing to the output buffer

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            write_index <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Overlap-add the frame into the output buffer
            audio_buffer[write_index] <= audio_buffer[write_index] + frame_in;
            write_index <= write_index + hop_size;  // Increment by hop size for overlap
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

    // Output the reconstructed audio
    always @(posedge clk) begin
        audio_out <= audio_buffer[write_index];
    end
endmodule
```

---

### **Explanation**:
- **Overlap-Add**: This module accumulates overlapping frames by adding them to the appropriate positions in the output buffer.
- **Hop Size**: The hop size determines how much each frame is shifted in the output buffer to create the overlap effect.
- **Output Buffer**: The reconstructed audio is stored in a buffer, which can later be written to an output file or played back.

---

### **Summary of Steps 5-8**:
1. **Step 5**: Noise is reduced by subtracting a pre-estimated noise spectrum from the magnitude of each frame.
2. **Step 6**: The phase vocoder interpolates magnitude and phase values between frames to stretch the signal.
3. **Step 7**: The

 inverse FFT converts the stretched frequency-domain signal back to the time domain.
4. **Step 8**: The overlap-add method is used to reconstruct the final time-domain signal from overlapping frames.
