function void = stream_shimmer_to_lsl(comPort) 

 %PLOTANDWRITEEMGEXAMPLE - Plotting ecg signal and write to file
    %    INPUT: comPort  - String value defining the COM port number for Shimmer
    %   
    %    INPUT: captureDuration  - Numerical value defining the capture duration
    %    OUTPUT: shimmer  - Object of the ShimmerHandleClass
    %
    % Example or Shimmer3
    addpath('C:/Users/Admin/Documents/MATLAB/Shimmer-MATLAB-ID-master/Resources/');
    fs = 204.8;                                                                % sample rate in [Hz] 
    DELAY_PERIOD = 0.2; 
     streaming = 0;

    PPGChannelNum = 13;
    comPort = '12';
    shimmer = ShimmerHandleClass(comPort);
    SensorMacros = SetEnabledSensorsMacrosClass;     
    shimmer.disconnect;                                                % disconnect from shimmer
    global outlet
    connection_ready = 0; 

function setup_LSL_Stream()
    try
        shimmer.disconnect;
    end

     if (shimmer.connect)
            shimmer.setsamplingrate(fs);                                           % Select sampling rate
            PPGChannel = ['INT A' num2str(PPGChannelNum)];        
            shimmer.setinternalboard('GSR');                                       % Select internal expansion board; select 'EMG' to enable SENSOR_EXG1
            shimmer.disableallsensors;                                             % Disable other sensors
            shimmer.setenabledsensors(SensorMacros.GSR,1, PPGChannel,1 );                         % Enable GSR, enable PPG Channel, disable other sensors
            shimmer.setinternalexppower(1);                                        % set internal expansion power
            disp('shimmer connection ready');
        end
           
        %% LSL
        %% instantiate the library
        disp('Loading LSL library...');
        lib = lsl_loadlib();
        
        %% create new stream
        disp('Creating a new stream info for Shimmer...');
        info = lsl_streaminfo(lib,'Shimmer', 'Physio', 3, fs, 'cf_double64','GSR+');
        chns = info.desc().append_child('channels');
        ch = chns.append_child('channel');
        ch.append_child_value('label','timestamp');
        ch.append_child_value('unit','ms');

        ch = chns.append_child('channel');
        ch.append_child_value('label','PPG');
        ch.append_child_value('unit','microvolts');


        ch = chns.append_child('channel');
        ch.append_child_value('label','EDA');
        ch.append_child_value('unit','komhs');

        
        info.desc().append_child_value('manufacturer','ShimmerSensing');
        setup = info.desc().append_child('setup');
        setup.append_child_value('location',dd.Value);

        % make a new stream outlet
        disp('Opening an outlet...');
        outlet = lsl_outlet(info);

        connection_ready = 1;

    end % end setup LSL    
    %% UI

        fig = uifigure("Name", 'Shimmer Streamer');
        fig.Position = [100 100 400 200];
        fig.WindowStyle = 'alwaysontop';
        label = uilabel(fig);
        label.Text = "Press record to send Shimmer data to LabStreamingLayer.";
        label.Position = [20 150 350 60];
        label.WordWrap = "on";

        dd = uidropdown(fig,...
             'Position',[20 100 300 22],...
            'Items',{'fingers - medial phalange', 'fingers - distal phalange','fingers - proximal phalange','wrist', 'palm - thenar'},...
            'Value','fingers - medial phalange');
        dd.Position = [20 140 300 22];
%         dd.get.Value

        % Create a push button
        btnSetup = uibutton(fig,'push',...
           'Text', 'Setup LSL',... 
                          'Position',[20, 110, 100, 22],...
                       'ButtonPushedFcn', @(btn,event) setup_LSL_Stream()); 

        btnStream = uibutton(fig,'push',...
           'Text', 'Stream',... 
                          'Position',[20, 80, 100, 22],...
                       'ButtonPushedFcn', @(btn,event) startStreaming()); 
        
        
        btnStop = uibutton(fig,'push',...
           'Text', 'Stop',... 
                          'Position',[20, 50, 100, 22],...
                       'ButtonPushedFcn', @(btn,event) stopStreaming()); 

        t = uicontrol(fig,...
            'Style','text',...
            'String','Waiting...',...
            'ForegroundColor', 'r',...
            'Position',[20 15 50 20]);

%         function closeRequest(hObject)
% %       uialert(fig,report,'Error Message','Interpreter','html');
%         selection = uiconfirm('Close document?','Confirm Close',...
%                         'Icon','warning');
% 
%                       
%             switch selection
%                 case 'OK'
%                     try
%                         shimmer.stop;                                                      % stop data streaming                                                    
%                         shimmer.disconnect;                                                % disconnect from shimmer
%                     end
%                     delete(hObject);
%         
% 
%                 case 'No'
%                     return
%             end
%         end
% 
%         set(fig,'CloseRequestFcn',@closeRequest)

        
    function startStreaming()

        if(connection_ready)
       

        if(shimmer.start)
            streaming = 1;
            t.String = 'Streaming...';
            t.ForegroundColor = 'b';
        end % shimmer-start

%         streamData_lsl = [];

            while (streaming)  
               pause(DELAY_PERIOD); % Pause for this period of time on each iteration to allow data to arrive in the buffer
               [newData,signalNameArray,signalFormatArray,signalUnitArray] = shimmer.getdata('c');   % Read the latest data from shimmer data buffer, signalFormatArray defines the format of the data and signalUnitArray the unit
                if ~isempty(newData) % TRUE if new data has arrived
                        chIndex(1) = find(ismember(signalNameArray, 'Time Stamp'));   % get signal indices
                        chIndex(2) = find(ismember(signalNameArray, 'Internal ADC A13'));
                        chIndex(3) = find(ismember(signalNameArray, 'GSR'));
                        % send data into the outlet, sample by sample
                        fprintf('Now transmitting data, size %i...\n',size(newData,1));
                        t.String = 'Streaming...';
                        streamData = [newData(:, chIndex(1)), newData(:, chIndex(2)), newData(:, chIndex(3))]; 
                        streamData = streamData'; % transpose into the format expected by LSL
%                         disp(streamData);
                        outlet.push_chunk(streamData);                        
                end % data
            end % while-loop 
        end
    end

    function stopStreaming()
        streaming = 0;
        t.String = 'Stopped';
        t.ForegroundColor = 'r';
    end   


end % end streamtoLsl