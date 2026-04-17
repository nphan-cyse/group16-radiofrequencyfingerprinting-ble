% Generated with MATLAB(R) 25.2 (R2025b) and Bluetooth Toolbox 25.2 (R2025b).
% Generating Bluetooth Low Energy waveforms

clear; clc;

%% Global BLE settings
% Modify if wanted
symbolRate = 1000000;     % Data rate
channelIndex = 37;        % Channel setting
mode = 'LE1M';            % Symbols per sample, 'LE2M' would give 2M symbols/sample
numDevices = 5;           % Number of devices to generate waveforms for
capturesPerDevice = 10000; % Number of waveform files to be generated

% Keep these the same
sps = 8;                  % Symbols per second
Fs = sps * symbolRate;    % Sampling rate
payloadBits = 1000;
accessAddress = [0 1 1 0 1 0 1 1 0 1 1 1 1 1 0 1 1 0 0 1 0 0 0 1 0 1 1 1 0 0 0 1]';
pulseLength = 1;
modIndex = 0.5;
whitenStatus = 'On';

%% Impairment "base" per device
deviceCfg(1) = struct('Label',"Device1",'SNR',22,'FreqOffset',-15, ...
    'DC',0.08+0.18j,'IQAmp',7.0,'IQPhase',pi/6);

deviceCfg(2) = struct('Label',"Device2",'SNR',20,'FreqOffset',-5, ...
    'DC',0.12+0.22j,'IQAmp',8.0,'IQPhase',pi/5);

deviceCfg(3) = struct('Label',"Device3",'SNR',18,'FreqOffset',10, ...
    'DC',0.10+0.20j,'IQAmp',9.0,'IQPhase',0.70);

deviceCfg(4) = struct('Label',"Device4",'SNR',16,'FreqOffset',25, ...
    'DC',0.06+0.25j,'IQAmp',10.0,'IQPhase',0.85);

deviceCfg(5) = struct('Label',"Device5",'SNR',14,'FreqOffset',40, ...
    'DC',0.14+0.16j,'IQAmp',11.0,'IQPhase',1.00);

rng(7);

%% Generate the dataset
for dev = 1:numDevices;

    folderName = char(deviceCfg(dev).Label);
    if ~exist(folderName,'dir')
        mkdir(folderName);
    end

    fprintf("\nGenerating captures for %s\n", folderName);

    for k = 1:capturesPerDevice

        % Random payload bits so captures are not identical
        in = randi([0, 1], payloadBits, 1);

        % Generate BLE waveform
        waveform = bleWaveformGenerator(in, ...
            'Mode', mode, ...
            'SamplesPerSymbol', sps, ...
            'ChannelIndex', channelIndex, ...
            'AccessAddress', accessAddress, ...
            'DFPacketType', 'Disabled', ...
            'WhitenStatus', whitenStatus, ...
            'PulseLength', pulseLength, ...
            'ModulationIndex', modIndex);

        % Small wiggles around device-specific impairments
        SNR_dB = deviceCfg(dev).SNR + 1.0*randn;
        freqOffsetHz = deviceCfg(dev).FreqOffset + 3.0*randn;
        dcOffset = deviceCfg(dev).DC + (0.01*randn + 1j*0.01*randn);
        iqAmp_dB = deviceCfg(dev).IQAmp + 0.2*randn;
        iqPhase_rad = deviceCfg(dev).IQPhase + 0.03*randn;

        % Apply the impairments
        rx = applyIQImbalanceLocal(waveform, iqAmp_dB, iqPhase_rad);
        rx = rx + dcOffset;
        rx = applyFrequencyOffsetLocal(rx, freqOffsetHz, Fs);
        rx = awgn(rx, SNR_dB, 'measured');

        % Store metadata and waveform
        waveStruct = struct;
        waveStruct.waveform = rx;
        waveStruct.deviceLabel = deviceCfg(dev).Label;
        waveStruct.captureIndex = k;
        waveStruct.SNR_dB = SNR_dB;
        waveStruct.FrequencyOffset_Hz = freqOffsetHz;
        waveStruct.DCOffset = dcOffset;
        waveStruct.IQAmpImbalance_dB = iqAmp_dB;
        waveStruct.IQPhaseImbalance_rad = iqPhase_rad;
        waveStruct.SamplesPerSymbol = sps;
        waveStruct.ChannelIndex = channelIndex;
        waveStruct.Mode = mode;
        waveStruct.PulseLength = pulseLength;
        waveStruct.ModulationIndex = modIndex;
        waveStruct.SampleRate = Fs;

        fileName = sprintf('device%d_%02d.mat', dev, k);
        save(fullfile(folderName, fileName), 'waveStruct');

        fprintf('Saved %s | SNR %.2f dB | CFO %.2f Hz | DC %.3f%+.3fi | IQAmp %.2f dB | IQPhase %.3f rad\n', ...
            fileName, SNR_dB, freqOffsetHz, real(dcOffset), imag(dcOffset), iqAmp_dB, iqPhase_rad);
    end
end

%% Helper functions
% Applies CFO to each sample
function y = applyFrequencyOffsetLocal(x, freqOffsetHz, Fs)
    n = (0:length(x)-1).';
    y = x .* exp(1j*2*pi*freqOffsetHz*n/Fs);
end

% Applies IQ imbalance
% Splits the IQ waveform into I and Q then slightly changes them unequally,
% then adds them back together
function y = applyIQImbalanceLocal(x, ampImb_dB, phImb_rad)
    g = 10^(ampImb_dB/20);

    I = real(x);
    Q = imag(x);

    I2 = g * I;
    Q2 = Q*cos(phImb_rad) + I*sin(phImb_rad);

    y = complex(I2, Q2);
end