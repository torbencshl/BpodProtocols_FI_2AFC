function NosePoke()
% Learning to Nose Poke side ports

global BpodSystem
global TaskParameters

%% Task parameters
TaskParameters = BpodSystem.ProtocolSettings;
if isempty(fieldnames(TaskParameters))
    %general
    TaskParameters.GUI.Ports_LMR = '123';
    TaskParameters.GUI.FI = 1; % (s)
    TaskParameters.GUI.VI = false;
    TaskParameters.GUIMeta.VI.Style = 'checkbox';
    TaskParameters.GUI.ChoiceDeadline = 10;
    TaskParameters.GUIPanels.General = {'Ports_LMR','FI','VI','ChoiceDeadline'};
    %"stimulus"
    TaskParameters.GUI.PlayStimulus = 1;
    TaskParameters.GUIMeta.PlayStimulus.Style = 'popupmenu';
    TaskParameters.GUIMeta.PlayStimulus.String = {'No stim.','Click stim.','Freq. stim.'};
    TaskParameters.GUI.MinSampleTime = 0.05;
    TaskParameters.GUI.MaxSampleTime = 0.5;
    TaskParameters.GUI.AutoIncrSample = true;
    TaskParameters.GUIMeta.AutoIncrSample.Style = 'checkbox';
    TaskParameters.GUI.MinSampleIncr = 0.01;
    TaskParameters.GUI.MinSampleDecr = 0.005;
    TaskParameters.GUI.EarlyWithdrawalTimeOut = 1;
    TaskParameters.GUI.EarlyWithdrawalNoise = true;
    TaskParameters.GUIMeta.EarlyWithdrawalNoise.Style='checkbox';
    TaskParameters.GUI.SampleTime = TaskParameters.GUI.MinSampleTime;
    TaskParameters.GUIMeta.SampleTime.Style = 'text';
    TaskParameters.GUIPanels.Sampling = {'PlayStimulus','MinSampleTime','MaxSampleTime','AutoIncrSample','MinSampleIncr','MinSampleDecr','EarlyWithdrawalTimeOut','EarlyWithdrawalNoise','SampleTime'};
    %Reward
    TaskParameters.GUI.rewardAmount = 30;
    TaskParameters.GUI.Deplete = true;
    TaskParameters.GUIMeta.Deplete.Style = 'checkbox';
    TaskParameters.GUI.DepleteRate = 0.8;
    TaskParameters.GUI.Jackpot = true;
    TaskParameters.GUIMeta.Jackpot.Style = 'checkbox';
    TaskParameters.GUI.JackpotMin = 1;
    TaskParameters.GUI.JackpotTime = 1;
    TaskParameters.GUIMeta.JackpotTime.Style = 'text';
        TaskParameters.GUIPanels.Reward = {'rewardAmount','Deplete','DepleteRate','Jackpot','JackpotMin','JackpotTime'};
    TaskParameters.GUI = orderfields(TaskParameters.GUI);
end
BpodParameterGUI('init', TaskParameters);

%% Initializing data (trial type) vectors and first values
BpodSystem.Data.Custom.ChoiceLeft = NaN;
BpodSystem.Data.Custom.SampleTime(1) = TaskParameters.GUI.MinSampleTime;
BpodSystem.Data.Custom.EarlyWithdrawal(1) = false;
BpodSystem.Data.Custom.Jackpot(1) = false;
BpodSystem.Data.Custom.RewardMagnitude = [TaskParameters.GUI.rewardAmount,TaskParameters.GUI.rewardAmount];
BpodSystem.Data.Custom = orderfields(BpodSystem.Data.Custom);
%server data
[~,BpodSystem.Data.Custom.Rig] = system('hostname');
[~,BpodSystem.Data.Custom.Subject] = fileparts(fileparts(fileparts(fileparts(BpodSystem.DataPath))));
BpodSystem.Data.Custom.PsychtoolboxStartup=false;
BpodSystem.Data.Custom.MaxSampleTime = 1; %only relevant for max stimulus length
[BpodSystem.Data.Custom.RightClickTrain,BpodSystem.Data.Custom.LeftClickTrain] = getClickStimulus(BpodSystem.Data.Custom.MaxSampleTime);
BpodSystem.Data.Custom.FreqStimulus = getFreqStimulus(BpodSystem.Data.Custom.MaxSampleTime);

BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler';

%% Configuring PulsePal
%% Configuring PulsePal
load PulsePalParamStimulus.mat
load PulsePalParamFeedback.mat
BpodSystem.Data.Custom.PulsePalParamStimulus=PulsePalParamStimulus;
BpodSystem.Data.Custom.PulsePalParamFeedback=PulsePalParamFeedback;
clear PulsePalParamFeedback PulsePalParamStimulus
if ~BpodSystem.EmulatorMode
    ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamStimulus);
    SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain, ones(1,length(BpodSystem.Data.Custom.RightClickTrain))*5);
    SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain))*5); 
    if TaskParameters.GUI.PlayStimulus == 3
        InitiatePsychtoolbox();
        PsychToolboxSoundServer('Load', 1, BpodSystem.Data.Custom.FreqStimulus);
    end
end


%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
NosePoke_PlotSideOutcome(BpodSystem.GUIHandles.SideOutcomePlot,'init');
% BpodNotebook('init');

%% Main loop
RunSession = true;
iTrial = 1;

while RunSession
    TaskParameters = BpodParameterGUI('sync', TaskParameters);
    InitiatePsychtoolbox();
    
    sma = stateMatrix(iTrial);
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        SaveBpodSessionData;
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
    
    updateCustomDataFields(iTrial)
    iTrial = iTrial + 1;
    NosePoke_PlotSideOutcome(BpodSystem.GUIHandles.SideOutcomePlot,'update',iTrial);
end
end

function sma = stateMatrix(iTrial)
global BpodSystem
global TaskParameters
%% Define ports
LeftPort = floor(mod(TaskParameters.GUI.Ports_LMR/100,10));
CenterPort = floor(mod(TaskParameters.GUI.Ports_LMR/10,10));
RightPort = mod(TaskParameters.GUI.Ports_LMR,10);
LeftPortOut = strcat('Port',num2str(LeftPort),'Out');
CenterPortOut = strcat('Port',num2str(CenterPort),'Out');
RightPortOut = strcat('Port',num2str(RightPort),'Out');
LeftPortIn = strcat('Port',num2str(LeftPort),'In');
CenterPortIn = strcat('Port',num2str(CenterPort),'In');
RightPortIn = strcat('Port',num2str(RightPort),'In');

LeftValve = 2^(LeftPort-1);
RightValve = 2^(RightPort-1);

LeftValveTime  = GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,1), LeftPort);
RightValveTime  = GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,2), RightPort);

JackpotFactor = max(2,10 - sum(BpodSystem.Data.Custom.Jackpot));
LeftValveTimeJackpot  = JackpotFactor*GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,1), LeftPort);
RightValveTimeJackpot  = JackpotFactor*GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,2), RightPort);

if TaskParameters.GUI.PlayStimulus == 1 %no
    StimStartOutput = {};
    StimStart2Output = {};
    StimStopOutput = {};
elseif TaskParameters.GUI.PlayStimulus == 2 %click
    StimStartOutput = {'BNCState',1};
    StimStart2Output = {'BNCState',1};
    StimStopOutput = {'BNCState',0};
elseif TaskParameters.GUI.PlayStimulus == 3 %freq
    StimStartOutput = {'SoftCode',21};
    StimStopOutput = {'SoftCode',22};
    StimStart2Output = {};
end

if TaskParameters.GUI.EarlyWithdrawalNoise;
    PunishSoundAction=11;
else
    PunishSoundAction=0;
end

sma = NewStateMatrix();
sma = AddState(sma, 'Name', 'state_0',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'wait_Cin'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'wait_Cin',...
    'Timer', 0,...
    'StateChangeConditions', {CenterPortIn, 'Cin'},...
    'OutputActions', {strcat('PWM',num2str(CenterPort)),255});
sma = AddState(sma, 'Name', 'Cin',...
    'Timer', TaskParameters.GUI.SampleTime,...
    'StateChangeConditions', {CenterPortOut, 'EarlyWithdrawal','Tup','stillSampling'},...
    'OutputActions', StimStartOutput);
if TaskParameters.GUI.Jackpot
sma = AddState(sma, 'Name', 'stillSampling',...
    'Timer', TaskParameters.GUI.JackpotTime-TaskParameters.GUI.SampleTime,...
    'StateChangeConditions', {CenterPortOut, 'stop_stim','Tup','stillSamplingJackpot'},...
    'OutputActions', StimStart2Output);
sma = AddState(sma, 'Name', 'stillSamplingJackpot',...
    'Timer', TaskParameters.GUI.ChoiceDeadline-TaskParameters.GUI.JackpotTime-TaskParameters.GUI.SampleTime,...
    'StateChangeConditions', {CenterPortOut, 'stop_stim_jackpot','Tup','ITI'},...
    'OutputActions', StimStart2Output);
sma = AddState(sma, 'Name', 'stop_stim_jackpot',...
    'Timer',0.001,...
    'StateChangeConditions', {'Tup','wait_SinJackpot'},...
    'OutputActions',StimStopOutput);
else
    sma = AddState(sma, 'Name', 'stillSampling',...
    'Timer', TaskParameters.GUI.ChoiceDeadline,...
    'StateChangeConditions', {CenterPortOut, 'stop_stim','Tup','stop_stim'},...
    'OutputActions', StimStart2Output);
end
sma = AddState(sma, 'Name', 'stop_stim',...
    'Timer',0.001,...
    'StateChangeConditions', {'Tup','wait_Sin'},...
    'OutputActions',StimStopOutput);
sma = AddState(sma, 'Name', 'wait_Sin',...
    'Timer',TaskParameters.GUI.ChoiceDeadline,...
    'StateChangeConditions', {LeftPortIn,'water_L',RightPortIn,'water_R','Tup','ITI'},...
    'OutputActions',{strcat('PWM',num2str(LeftPort)),255,strcat('PWM',num2str(RightPort)),255});
sma = AddState(sma, 'Name', 'water_L',...
    'Timer', LeftValveTime,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'ValveState', LeftValve});
sma = AddState(sma, 'Name', 'water_R',...
    'Timer', RightValveTime,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'ValveState', RightValve});
sma = AddState(sma, 'Name', 'wait_SinJackpot',...
    'Timer',TaskParameters.GUI.ChoiceDeadline,...
    'StateChangeConditions', {LeftPortIn,'water_LJackpot',RightPortIn,'water_RJackpot','Tup','ITI'},...
    'OutputActions',{strcat('PWM',num2str(LeftPort)),255,strcat('PWM',num2str(RightPort)),255});
sma = AddState(sma, 'Name', 'water_LJackpot',...
    'Timer', LeftValveTimeJackpot,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'ValveState', LeftValve});
sma = AddState(sma, 'Name', 'water_RJackpot',...
    'Timer', RightValveTimeJackpot,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'ValveState', RightValve});
sma = AddState(sma, 'Name', 'EarlyWithdrawal',...
    'Timer', TaskParameters.GUI.EarlyWithdrawalTimeOut,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'SoftCode',PunishSoundAction});
if TaskParameters.GUI.VI
    sma = AddState(sma, 'Name', 'ITI',...
        'Timer',exprnd(TaskParameters.GUI.FI),...
        'StateChangeConditions',{'Tup','exit'},...
        'OutputActions',{});
else
    sma = AddState(sma, 'Name', 'ITI',...
        'Timer',TaskParameters.GUI.FI,...
        'StateChangeConditions',{'Tup','exit'},...
        'OutputActions',{});
end

end

function updateCustomDataFields(iTrial)
global BpodSystem
global TaskParameters

%% OutcomeRecord
statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial}(BpodSystem.Data.RawData.OriginalStateData{iTrial});
BpodSystem.Data.Custom.ST(iTrial) = NaN;
if any(strcmp('Cin',statesThisTrial))
    if any(strcmp('stillSampling',statesThisTrial))
        if any(strcmp('stillSamplingJackpot',statesThisTrial))
            BpodSystem.Data.Custom.ST(iTrial) = BpodSystem.Data.RawEvents.Trial{iTrial}.States.stillSamplingJackpot(1,2) - BpodSystem.Data.RawEvents.Trial{iTrial}.States.Cin(1,1);
        else
            BpodSystem.Data.Custom.ST(iTrial) = BpodSystem.Data.RawEvents.Trial{iTrial}.States.stillSampling(1,2) - BpodSystem.Data.RawEvents.Trial{iTrial}.States.Cin(1,1);
        end
    else
            BpodSystem.Data.Custom.ST(iTrial) = diff(BpodSystem.Data.RawEvents.Trial{iTrial}.States.Cin);
    end
end

if any(strncmp('water_L',statesThisTrial,7))
    BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 1;
elseif any(strncmp('water_R',statesThisTrial,7))
    BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 0;
elseif any(strcmp('EarlyWithdrawal',statesThisTrial))
    BpodSystem.Data.Custom.EarlyWithdrawal(iTrial) = true;
end
if any(strcmp('water_LJackpot',statesThisTrial)) || any(strcmp('water_RJackpot',statesThisTrial))
    BpodSystem.Data.Custom.Jackpot(iTrial) = true;
end


%% initialize next trial values
BpodSystem.Data.Custom.ChoiceLeft(iTrial+1) = NaN;
BpodSystem.Data.Custom.EarlyWithdrawal(iTrial+1) = false;
BpodSystem.Data.Custom.Jackpot(iTrial+1) = false;

%stimuli
if ~BpodSystem.EmulatorMode
    if TaskParameters.GUI.PlayStimulus == 2
        [BpodSystem.Data.Custom.RightClickTrain,BpodSystem.Data.Custom.LeftClickTrain] = getClickStimulus(BpodSystem.Data.Custom.MaxSampleTime);
        SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain, ones(1,length(BpodSystem.Data.Custom.RightClickTrain))*5);
        SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain))*5);
    elseif TaskParameters.GUI.PlayStimulus == 3
        InitiatePsychtoolbox();
        BpodSystem.Data.Custom.FreqStimulus = getFreqStimulus(BpodSystem.Data.Custom.MaxSampleTime);
        PsychToolboxSoundServer('Load', 1, BpodSystem.Data.Custom.FreqStimulus);
    end
end

%jackpot time
if  TaskParameters.GUI.Jackpot
    if sum(~isnan(BpodSystem.Data.Custom.ChoiceLeft(1:iTrial)))>10
        TaskParameters.GUI.JackpotTime = max(TaskParameters.GUI.JackpotMin,quantile(BpodSystem.Data.Custom.ST,0.95));
    else
        TaskParameters.GUI.JackpotTime = TaskParameters.GUI.JackpotMin;
    end
end

%reward depletion
if BpodSystem.Data.Custom.ChoiceLeft(iTrial) == 1 && TaskParameters.GUI.Deplete
    BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,1) = BpodSystem.Data.Custom.RewardMagnitude(iTrial,1)*TaskParameters.GUI.DepleteRate;
    BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,2) = TaskParameters.GUI.rewardAmount;
elseif BpodSystem.Data.Custom.ChoiceLeft(iTrial) == 0 && TaskParameters.GUI.Deplete
    BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,2) = BpodSystem.Data.Custom.RewardMagnitude(iTrial,2)*TaskParameters.GUI.DepleteRate;
    BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,1) = TaskParameters.GUI.rewardAmount;
elseif isnan(BpodSystem.Data.Custom.ChoiceLeft(iTrial)) && TaskParameters.GUI.Deplete
    BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,:) = BpodSystem.Data.Custom.RewardMagnitude(iTrial,:);
else
    BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,:) = [TaskParameters.GUI.rewardAmount,TaskParameters.GUI.rewardAmount];
end

%increase sample time
if TaskParameters.GUI.AutoIncrSample
    History = 50;
    Crit = 0.8;
    if iTrial<5
        ConsiderTrials = iTrial;
    else
        ConsiderTrials = max(1,iTrial-History):1:iTrial;
    end
    ConsiderTrials = ConsiderTrials(~isnan(BpodSystem.Data.Custom.ChoiceLeft(ConsiderTrials))|BpodSystem.Data.Custom.EarlyWithdrawal(ConsiderTrials));
    if sum(~BpodSystem.Data.Custom.EarlyWithdrawal(ConsiderTrials))/length(ConsiderTrials) > Crit
        if ~BpodSystem.Data.Custom.EarlyWithdrawal(iTrial)
            BpodSystem.Data.Custom.SampleTime(iTrial+1) = min(TaskParameters.GUI.MaxSampleTime,max(TaskParameters.GUI.MinSampleTime,BpodSystem.Data.Custom.SampleTime(iTrial) + TaskParameters.GUI.MinSampleIncr));
        else
             BpodSystem.Data.Custom.SampleTime(iTrial+1) =  min(TaskParameters.GUI.MaxSampleTime,max(TaskParameters.GUI.MinSampleTime,BpodSystem.Data.Custom.SampleTime(iTrial)));
        end
    elseif sum(~BpodSystem.Data.Custom.EarlyWithdrawal(ConsiderTrials))/length(ConsiderTrials) < Crit/2
        if BpodSystem.Data.Custom.EarlyWithdrawal(iTrial)
            BpodSystem.Data.Custom.SampleTime(iTrial+1) = max(TaskParameters.GUI.MinSampleTime,min(TaskParameters.GUI.MaxSampleTime,BpodSystem.Data.Custom.SampleTime(iTrial) - TaskParameters.GUI.MinSampleDecr));
        else
            BpodSystem.Data.Custom.SampleTime(iTrial+1) =   min(TaskParameters.GUI.MaxSampleTime,max(TaskParameters.GUI.MinSampleTime,BpodSystem.Data.Custom.SampleTime(iTrial)));
        end
    else
        BpodSystem.Data.Custom.SampleTime(iTrial+1) =  BpodSystem.Data.Custom.SampleTime(iTrial);
    end
else
    BpodSystem.Data.Custom.SampleTime(iTrial+1) = TaskParameters.GUI.MinSampleTime;
end
% if BpodSystem.Data.Custom.Jackpot(iTrial)
%     BpodSystem.Data.Custom.SampleTime(iTrial+1) = BpodSystem.Data.Custom.SampleTime(iTrial+1)+0.05*TaskParameters.GUI.JackpotTime;
% end
TaskParameters.GUI.SampleTime = BpodSystem.Data.Custom.SampleTime(iTrial+1);

%send bpod status to server
try
script = 'receivebpodstatus.php';
%create a common "outcome" vector
outcome = BpodSystem.Data.Custom.ChoiceLeft(1:iTrial); %1=left, 0=right
outcome(BpodSystem.Data.Custom.EarlyWithdrawal(1:iTrial))=3; %early withdrawal=3
outcome(BpodSystem.Data.Custom.Jackpot(1:iTrial))=4;%jackpot=4
SendTrialStatusToServer(script,BpodSystem.Data.Custom.Rig,outcome,BpodSystem.Data.Custom.Subject,BpodSystem.CurrentProtocolName);
catch
end

end

function [RightClickTrain,LeftClickTrain]=getClickStimulus(time)
rr = rand(1,1)*0.6+0.2;
l = ceil(rr*100);
r=100-l;
RightClickTrain=GeneratePoissonClickTrain(r,time);
LeftClickTrain=GeneratePoissonClickTrain(l,time);
end

function Sound = getFreqStimulus(time)
StimulusSettings=struct();
            StimulusSettings.SamplingRate = 192000; % Sound card sampling rate;
            StimulusSettings.ramp = 0.003;
            StimulusSettings.nFreq = 18; % Number of different frequencies to sample from
            StimulusSettings.ToneOverlap = 0.6667;
            StimulusSettings.ToneDuration = 0.03;
            StimulusSettings.Noevidence=0;
            StimulusSettings.minFreq = 5000 ;
            StimulusSettings.maxFreq = 40000 ;
            StimulusSettings.UseMiddleOctave=0;
            StimulusSettings.Volume=50;
            StimulusSettings.nTones = floor((time-StimulusSettings.ToneDuration*StimulusSettings.ToneOverlap)/(StimulusSettings.ToneDuration*(1-StimulusSettings.ToneOverlap))); %number of tones
            newFracHigh = rand(1,1);
            [Sound, ~, ~] = GenerateToneCloudDual(newFracHigh, StimulusSettings);
end