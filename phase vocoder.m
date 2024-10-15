% Load audio signal
[audioIn, fs] = audioread('input_audio.wav');
audioIn = audioIn(:, 1);  % If stereo, take only one channel

% Noise estimation (assuming first 0.5 seconds is noise)
noiseSegment = audioIn(1:round(0.5 * fs));  % First 0.5 seconds assumed as noise
noiseSpectrum = mean(abs(fft(noiseSegment, 1024)));  % Estimate the noise spectrum

% Parameters for STFT
windowSize = 1024;        % Window size for STFT
hopSize = 256;            % Hop size for overlap
nFFT = windowSize;        % FFT size
timeStretchFactor = 1.5;  % Time stretch factor (e.g., 1.5 = 50% slower)

% Create a Hanning window
window = hanning(windowSize);

% Short-Time Fourier Transform (STFT)
numFrames = floor((length(audioIn) - windowSize) / hopSize) + 1;
stft = zeros(nFFT, numFrames);  % Initialize STFT matrix

for i = 1:numFrames
    frameStart = (i-1) * hopSize + 1;
    frameEnd = frameStart + windowSize - 1;
    frame = audioIn(frameStart:frameEnd) .* window;
    
    % Perform FFT on the frame
    fftFrame = fft(frame, nFFT);
    
    % Noise reduction: subtract noise spectrum from the current frame's magnitude
    mag = abs(fftFrame);
    phase = angle(fftFrame);
    magDenoised = max(mag - noiseSpectrum', 0);  % Subtract noise and ensure non-negative magnitude
    
    % Reconstruct the STFT frame after noise reduction
    stft(:, i) = magDenoised .* exp(1j * phase);
end

% Time-stretch by modifying the time axis
newNumFrames = round(numFrames * timeStretchFactor);
stretchedSTFT = zeros(nFFT, newNumFrames);
phase = angle(stft(:, 1));  % Initialize phase

for i = 2:newNumFrames
    % Interpolate magnitude and phase
    index = i / timeStretchFactor;
    lower = floor(index);
    upper = ceil(index);
    interpFactor = index - lower;
    
    if lower > 0 && upper <= numFrames
        % Interpolate magnitude
        mag = (1 - interpFactor) * abs(stft(:, lower)) + interpFactor * abs(stft(:, upper));
        
        % Adjust phase progression
        deltaPhase = angle(stft(:, upper)) - angle(stft(:, lower));
        deltaPhase = mod(deltaPhase + pi, 2 * pi) - pi;  % Phase unwrapping
        phase = phase + deltaPhase;  % Add to current phase
        
        % Create the stretched STFT frame
        stretchedSTFT(:, i) = mag .* exp(1j * phase);
    end
end

% Inverse FFT and overlap-add to reconstruct time-domain signal
outputAudio = zeros((newNumFrames - 1) * hopSize + windowSize, 1);

for i = 1:newNumFrames
    frame = real(ifft(stretchedSTFT(:, i), nFFT));
    frameStart = (i-1) * hopSize + 1;
    frameEnd = frameStart + windowSize - 1;
    outputAudio(frameStart:frameEnd) = outputAudio(frameStart:frameEnd) + frame .* window;
end

% Normalize the output to avoid clipping
outputAudio = outputAudio / max(abs(outputAudio) + eps);

% Save the output audio
audiowrite('output_audio_stretched_denoised.wav', outputAudio, fs);

% Optional: Play the output audio
sound(outputAudio, fs);
