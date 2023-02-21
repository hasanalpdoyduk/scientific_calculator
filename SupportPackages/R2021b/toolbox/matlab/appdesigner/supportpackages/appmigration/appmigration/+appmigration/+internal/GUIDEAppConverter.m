classdef GUIDEAppConverter < handle
    %GUIDEAPPCONVERTER Converts an app built using GUIDE to an App Designer app.
    %   This class is responsible for migrating the GUIDE app and
    %   serializing the converted app as an MLAPP. It delegates the
    %   conversion work to specialized converter classes for the different
    %   aspects of the conversion:
    %       GUIDEFigFileConverter  - migrates the app's figure and children
    %       GUIDECodeFileConverter - migrates the app's code
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    properties
        FigFullFileName
        CodeFullFileName
        MLAPPFileName
    end
    
    methods
        function obj = GUIDEAppConverter(varargin)
            % Constructor.
            %   ARGUMENT 1: Fig file name to convert
            %   ARGUMENT 2 (Optional): MLAPP file name to save.
            % Note: file validation is performed for inputted file names.
            
            narginchk(1, 2);
            
            % Validate the inputted FIG file as a valid GUIDE App.
            [normalizedfullFileName, codeFullFileName] =  appdesigner.internal.application.validateGUIDEApp(varargin{1});
                        
            obj.FigFullFileName = normalizedfullFileName;
            obj.CodeFullFileName = codeFullFileName;
            
            % If nargin is 1, a destination mlapp filename was not
            % specified.  If nargin is 2 and the second input is not empty, 
            % a destination mlapp filename was given.
            if nargin == 1 || isempty(varargin{2})

                % Determine a unique MLAPP full file name for the migrated
                % app.
                obj.MLAPPFileName = generateUniqueMlappFullFileName(obj);
                
            else
                obj.MLAPPFileName  = varargin{2};
            end
            
            % Validate the destination MLAPP full file name.
            obj.MLAPPFileName = appdesigner.internal.application.getValidatedFile(obj.MLAPPFileName, '.mlapp');
            
        end
        
        function conversionResults = convert(obj)
            % CONVERT Performs the migration of the GUIDE app to an MLAPP
            %   App Designer app resulting in an MLAPP-file.
            %
            %   High Level Conversion Workflow:
            %       1. Parse GUIDE app's code file to get information about
            %           the callbacks it contains.
            %       2. Convert and configure the properties of the app's
            %           figure and the figure's children.
            %           This will result in a uifigure. This step will also
            %           return information about which callbacks are
            %           supported or not.  It will also return information
            %           about the singleton status of the app.
            %       3. Convert the GUIDE code based on the information from
            %           steps 1 and 2.
            %       4. Generate code from conversion issues for components
            %           or properties that can be configured
            %           programmatically in the startup fcn.
            %       5. Serialize the uifigure and new code format into a
            %           MLAPP file.
            %
            %   Inputs:
            %       obj - GUIDEAppConverter object
            %       varargin - There is an optional second argument.  If a
            %           second argument is specified, the argument is the
            %           destination mlapp full full name that will be written.
            % 
            %   Outputs:
            %       mlappFullFileName - Full file path to the MLAPP-file
            %       issues - Array of AppConversionIssues that were
            %           generated during the conversion.
            %       conversionResults - results of the conversion such as
            %           the mlapp filename, conversion issues, number of
            %           code lines analyzes, numbers of components
            %           migrated, and number of callback/utility functions
            %           mirated.
            
            import appmigration.internal.GUIDECodeParser;
            import appmigration.internal.GUIDEFigFileConverter;
            import appmigration.internal.GUIDECodeFileConverter;
            import appmigration.internal.AppConversionIssueCodeGenerator;
            import appmigration.internal.PreDefinedToolDefaultCallbackCodeGenerator;
                        
            % Check if folder is writable
            appdesigner.internal.application.validateFolderForWrite(obj.MLAPPFileName);
            
            guideCodeParser = GUIDECodeParser(obj.CodeFullFileName);
            codeFileFunctions = guideCodeParser.parseFunctions();
            
            figFileConverter = GUIDEFigFileConverter(...
                obj.FigFullFileName, codeFileFunctions);
            
            % Convert the component layout and properties.  Get information
            % about the singletonMode and defaultCallbacks of
            % predefinedTools
            [uifig, callbackSupport, componentIssues, singletonMode, preDefinedToolCallbackMigrationInfo] = figFileConverter.convert();
            uifigCleanup = onCleanup(@()delete(uifig));
                        
            codeFileConverter = GUIDECodeFileConverter(guideCodeParser, callbackSupport, preDefinedToolCallbackMigrationInfo);
            
            % Convert code structure
            [codeData, functionIssues, numMigratedFunctions] = codeFileConverter.convertSupportedFunctions();
            
            % Record the singleton status in the codeData struct
            codeData.SingletonMode = singletonMode;
	                 
            % Generate the code needed to convert default callbacks of
            % supported predefined tools.
            predefinedToolDefaultCallbackCodeGenerator = PreDefinedToolDefaultCallbackCodeGenerator(preDefinedToolCallbackMigrationInfo);
            predefinedToolDefaultCallbackCode = predefinedToolDefaultCallbackCodeGenerator.generateCode();
            
            % Update the codeData with code for default callbacks of
            % predefined tools.
            codeData.Callbacks = [codeData.Callbacks, predefinedToolDefaultCallbackCode];
            
            % Update the codeData with code for issues that are supported
            % in App Designer design time but can be programmatically added
            % to the app's startup fcn.
            appIssueCodeGenerator = AppConversionIssueCodeGenerator(obj.MLAPPFileName);
            [codeData, componentIssues] = appIssueCodeGenerator.updateCodeData(codeData, componentIssues);
            
            % Analyze GUIDE code for unsupported API
            codeIssues = codeFileConverter.analyzeCodeForUnsupportedAPICalls();
            
            % Serialize the data into an MLAPP file
            appUuid = serialize(obj, uifig, codeData, appIssueCodeGenerator);
            
            issues = [componentIssues, functionIssues, codeIssues];
            
            % Log app migration result
            data = struct();
            data.appUuid = appUuid;
            data.fileName = obj.MLAPPFileName;
            data.uiFigure = uifig;
            data.codeData = codeData;
            data.issues = issues;
            obj.logMigratedAppDetails(data);
            
            numLinesOfGUIDECode = length(strsplit(guideCodeParser.Code, '\n', 'CollapseDelimiters', false));
            numComponentsMigrated = obj.recursivelyGetNumComponents(uifig);
            
            conversionResults = struct(...
                'MLAPPFullFileName', obj.MLAPPFileName,...
                'Issues', issues,...
                'NumCodeLinesAnalyzed', numLinesOfGUIDECode,...
                'NumComponentsMigrated', numComponentsMigrated,...
                'NumFunctionsMigrated', numMigratedFunctions);
        end
    end
    
    methods (Access = private)
        
        function mlappFullFileName = generateUniqueMlappFullFileName(obj)
            % First, determine a proposed app name based on the fig file name.
            % Check if an app already exists with the proposed current
            % app name. If found, appends an incremented counter towards the end of the
            % current app name until a unique name is found
            
            [figFilePath, name] = fileparts(obj.FigFullFileName);
            convertedAppName = [name, '_App'];
            convertedMLappName = [convertedAppName, '.mlapp'];
            
            mlappFullFileName = fullfile(figFilePath, convertedMLappName);
            
            appNameCounter = 0;
            
            while exist(mlappFullFileName, 'file')
                appNameCounter = appNameCounter + 1;
                convertedMLappName = sprintf('%s_%d.mlapp', convertedAppName, appNameCounter);
                mlappFullFileName = fullfile(figFilePath, convertedMLappName);
            end
        end
        
        function appUuid = serialize(obj, uifig, codeData, appIssueCodeGenerator)
            
            import appdesigner.internal.serialization.MLAPPSerializer;
            
            % Create the serializer
            serializer = MLAPPSerializer(obj.MLAPPFileName, uifig);
            
            % Setting the code to throw an error when run explaining that
            % the app needs to be opened in App Designer and saved before
            % running from the command line. The is needed because code
            % generation for the app only occurs on the client.
            codeText = 'error(message(''AppMigration:AppMigration:OpenBeforeRun''));';
            
            % Set data on the Serializer
            serializer.MatlabCodeText = codeText;
            serializer.EditableSectionCode = codeData.EditableSectionCode;
            serializer.Callbacks = codeData.Callbacks;
            serializer.StartupCallback = codeData.StartupCallback;
            serializer.InputParameters = codeData.InputParameters;
            serializer.SingletonMode = codeData.SingletonMode;

            % Save the app data
            serializer.save();
            
            % Save the supporting component data to a separate MAT-file
            appIssueCodeGenerator.saveComponentData();
            
            % Return converted app's Uuid
            appMetadata = serializer.Metadata;
            appUuid = appMetadata.Uuid;
        end
        
        function num = recursivelyGetNumComponents(obj, comp)
            num = 1;
            
            if ~isprop(comp, 'Children')
                % Component doesn't have children
                return;
            end
            
            children = allchild(comp);
            if ~isempty(children)
                for i=1:length(children)
                    % allchild now returns two annotation panes when a
                    % container holds axes'.  We want to remove these
                    % annotation panes from the count of the components to
                    % migrate.
                    if ~isa(children(i),'matlab.graphics.shape.internal.AnnotationPane')
                        num = num + recursivelyGetNumComponents(obj, children(i));
                    end
                end
            end
        end
        
        function logMigratedAppDetails(~, data)
            try
                dataToLog = java.util.HashMap();
                % App Uuid
                dataToLog.put(java.lang.String('appUuid'), java.lang.String(data.appUuid));
                
                % Filename hash value
                md = java.security.MessageDigest.getInstance('sha1');
                fileNameBytes = java.lang.String(data.fileName).getBytes();
                hashValue = md.digest(fileNameBytes);
                dataToLog.put(java.lang.String('fileNameHash'), java.lang.String(sprintf('%2.2x', typecast(hashValue, 'uint8'))));
                
                % App's characteristics, such as: numberOfComponents,
                % numberOfCallbacks, numberOfLinesOfEditableCode
                componentList = findall(data.uiFigure, '-property', 'DesignTimeProperties');
                dataToLog.put(java.lang.String('numberOfComponents'), java.lang.String(num2str(numel(componentList))));
                
                % numberOfCallbacks
                numberOfCallbacks = 0;
                if ~isempty(data.codeData.Callbacks)
                    numberOfCallbacks = numel(data.codeData.Callbacks);
                end
                dataToLog.put(java.lang.String('numberOfCallbacks'), java.lang.String(num2str(numberOfCallbacks)));
                
                % Conversion issues data, like:
                % UnsupportedCallbackTypeEvalInBase:uicontrol:keyup="5"
                % UnsupportedPropertyWithNoWorkaround:axes:keypressed="15"
                if ~isempty(data.issues)
                    for ix = 1:numel(data.issues)
                        % There are different types of issues:
                        % 1)issue from unsupported component property or callback
                        % 2)issue from unsupported api, for example, ginput
                        % 3)issue from exception in migration tool
                        issue = data.issues(ix);
                        
                        if issue.Type == appmigration.internal.AppConversionIssueType.Error
                            % For exception from tool, whose type is 'Error',
                            % log 'Error' in the type, and exception idetifier
                            issueType = char(issue.Type);
                            issueName = issue.Value.identifier;
                        else
                            if ~isempty(issue.ComponentType)
                                % Issue in unsupported component property
                                % or callback, and so log ComponentType
                                issueType = issue.ComponentType;
                            else
                                % As to API issue, log 'API' in the type
                                issueType = char(issue.Type);
                            end
                            
                            % For unsupported component property or
                            % callback, this is the name of the property or
                            % callback; as to API issue, it's the api name.
                            issueName = issue.Name;
                            
                            % Make the issue name be generic instead of the
                            % specific callback name.
                            if isequal(issue.Identifier, appmigration.internal.AppConversionIssueFactory.Ids.UnrecommendedUsingCallbackProgrammatically)
                                issueName = 'Callback';
                            elseif isequal(issue.Identifier, appmigration.internal.AppConversionIssueFactory.Ids.UnsupportedCallbackOutputFcn)
                                issueName = 'OutputFcn';
                            end
                        end
                        
                        issueKey = [data.issues(ix).Identifier ':' issueType ':' issueName];
                        issueKey = java.lang.String(issueKey);
                        if dataToLog.containsKey(issueKey)
                            issueNumber = str2double(dataToLog.get(issueKey)) + 1;
                        else
                            issueNumber = 1;
                        end
                        dataToLog.put(issueKey, java.lang.String(num2str(issueNumber)));
                    end
                end
                
                dduxLog = com.mathworks.ddux.DDUXLog.getInstance();
                dduxLog.logUIEvent('MATLAB', ... % Product
                    'GUIDE to App Designer Migration Tool', ... % Scope
                    'GUIDEAppConverter', ... % elementId
                    dduxLog.elementTypeStringToEnum('DOCUMENT'), ... % elementType
                    dduxLog.eventTypeStringToEnum('OPENED'), ... % eventType
                    dataToLog ... % custom data to log
                    );
            catch me
                % no-op. Catch exception to avoid breaking migration
                % tool
            end
        end
    end
end