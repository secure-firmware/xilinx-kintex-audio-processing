### **Steps 11-13: Noise Reduction in Verilog**

These steps focus on implementing the noise reduction functionality, where we subtract the estimated noise spectrum from the signal's magnitude spectrum to enhance the quality of the processed audio. 

---

### **Step 11: Noise Spectrum Subtraction**

We will subtract the noise spectrum from the magnitude spectrum of each STFT frame to reduce noise.

#### **High-Level Requirements**:
1. **Estimate Noise Spectrum**: The noise spectrum should be pre-estimated from the noise portion of the signal.
2. **Magnitude Subtraction**: For each frame, subtract the noise spectrum from the magnitude spectrum.
3. **Ensure Non-Negativity**: Ensure the resulting magnitude spectrum remains non-negative after subtraction.

#### **Module 4: Noise Reduction (Verilog)**

```verilog
module noise_reduction (
    input clk,
    input rst,
    input signed [15:0] mag_in,   // Input magnitude of current frame
    input signed [15:0] noise_spectrum,  // Estimated noise spectrum
    input valid_in,
    output reg signed [15:0] mag_out,  // Output magnitude after noise reduction
    output reg valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mag_out <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Subtract noise spectrum from the input magnitude
            if (mag_in > noise_spectrum)
                mag_out <= mag_in - noise_spectrum;
            else
                mag_out <= 0;  // Ensure non-negative magnitude

            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
endmodule
```

---

### **Explanation**:
1. **Magnitude Subtraction**: The noise-reduction module subtracts the estimated noise spectrum from the magnitude of each STFT frame.
2. **Non-Negativity**: If the resulting magnitude is negative, it is set to zero to ensure non-negative magnitudes.
3. **Output**: The module outputs the cleaned magnitude spectrum for further processing.

---

### **Step 12: Phase Preservation**

In the noise reduction process, the phase of the signal is preserved, as noise typically affects only the magnitude spectrum.

#### **High-Level Requirements**:
1. **Preserve Phase**: The phase values of the original signal should be maintained.
2. **Magnitude Modification Only**: Only modify the magnitude, leaving the phase unchanged.

Since phase is not modified in the noise reduction process, no additional module is required for this step beyond ensuring that the phase is passed through unmodified from the STFT stage to subsequent processing.

---

### **Step 13: Combine Magnitude and Phase for STFT Reconstruction**

Once noise reduction is performed, we need to combine the denoised magnitude and the original phase to reconstruct the modified STFT frames.

#### **High-Level Requirements**:
1. **Combine Denoised Magnitude and Original Phase**: The final STFT frame should be reconstructed by multiplying the denoised magnitude and the exponential of the phase.
2. **Complex Representation**: Each STFT frame should be represented as a complex number (`magnitude * exp(j*phase)`).

#### **Module 5: STFT Frame Reconstruction (Verilog)**

```verilog
module stft_reconstruction (
    input clk,
    input rst,
    input signed [15:0] mag_in,   // Denoised magnitude
    input signed [15:0] phase_in, // Original phase
    input valid_in,
    output reg signed [15:0] real_out,  // Real part of the STFT frame
    output reg signed [15:0] imag_out,  // Imaginary part of the STFT frame
    output reg valid_out
);

    wire signed [15:0] cos_phase;
    wire signed [15:0] sin_phase;

    // Use CORDIC algorithm or lookup table to calculate sine and cosine of the phase
    cordic_sin_cos cordic_inst (
        .clk(clk),
        .rst(rst),
        .theta(phase_in),
        .cos_out(cos_phase),
        .sin_out(sin_phase)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            real_out <= 0;
            imag_out <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Reconstruct the real and imaginary parts using denoised magnitude and original phase
            real_out <= (mag_in * cos_phase) >>> 15;
            imag_out <= (mag_in * sin_phase) >>> 15;

            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

endmodule
```

---

### **Explanation**:
1. **CORDIC Algorithm**: We use a CORDIC-based approach (or a lookup table) to compute the sine and cosine of the phase angle.
2. **Real and Imaginary Parts**: The real part is computed as `magnitude * cos(phase)` and the imaginary part as `magnitude * sin(phase)`.
3. **Output**: The reconstructed STFT frame is output as complex values (real and imaginary parts), ready for further processing, such as inverse FFT.

---

### **Summary of Steps 11-13**:
1. **Step 11**: Noise reduction is performed by subtracting the estimated noise spectrum from the magnitude spectrum, ensuring that the resulting magnitudes are non-negative.
2. **Step 12**: The phase is preserved during noise reduction, with no additional modifications.
3. **Step 13**: The denoised magnitude is combined with the original phase to reconstruct the STFT frame in the complex form (real and imaginary components).

---

### **Next Steps**:
Would you like to proceed with testing the noise reduction module, or move forward with the integration of inverse FFT and overlap-add operations?
