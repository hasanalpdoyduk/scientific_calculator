classdef GUIDECodeFileConverter < handle
    %GUIDECODEFILECONVERTER Migrates a GUIDE app's code file to App Designer.
    %   This class is responsible for updating a GUIDE app's code to the
    %   format needed by App Designer and analyzing the code for
    %   unsupported API calls.
    
    %   Copyright 2017-2021 The MathWorks, Inc.
    
    properties (Access = private)
        GUIDECodeParser
        CallbackSupport
        MigrationInfo
    end
    
    properties (Constant, Access = private)
        MethodIndent = 4;
        FunctionIndent = 8;
        FunctionBodyIndent = 12;
        UnsupportedFunctions = struct(...
            ...%UnsupportedAPI actxcontrol/javacomponent - at top so that they are reported at the top of API issues in report
            'actxcontrol'      , appmigration.internal.AppConversionIssueFactory.Ids.UnsupportedAPIActivex,...
            'javacomponent'    , appmigration.internal.AppConversionIssueFactory.Ids.UnsupportedAPIJavacomponent,...
            ...%UnsupportedAPIWithNoWorkaround
            'clf'              , appmigration.internal.AppConversionIssueFactory.Ids.UnsupportedAPIClfReset,...
            'uistack'          , appmigration.internal.AppConversionIssueFactory.Ids.UnsupportedAPIWithNoWorkaround,...
            ...%UnsupportedAPI
            'uicontrol'        , appmigration.internal.AppConversionIssueFactory.Ids.UnsupportedAPIUicontrol,...
            ...%FindComponentAPI
            'findobj'          , appmigration.internal.AppConversionIssueFactory.Ids.FindComponentAPI,...
            'findall'          , appmigration.internal.AppConversionIssueFactory.Ids.FindComponentAPI,...
            'gcbo'             , appmigration.internal.AppConversionIssueFactory.Ids.FindComponentAPI,...
            ...%NarginAPI
            'nargin'           , appmigration.internal.AppConversionIssueFactory.Ids.NarginAPI,...
            'narginchk'        , appmigration.internal.AppConversionIssueFactory.Ids.NarginAPI...
            );
        
        UnsupportedProperties = struct(...
            'JavaFrame'        , appmigration.internal.AppConversionIssueFactory.Ids.UnsupportedAPIJavaframe...
            );
    end
    
    methods
        function obj = GUIDECodeFileConverter(guideCodeParser, callbackSupport, migrationInfo)
            %GUIDECODEFILECONVERTER Construct an instance of this class
            %
            %   Inputs:
            %       GUIDECodeParser - Instance of GUIDECodeParser
            %       callbackSupport - struct with the following fields:
            %           Supported - 1xn cell array of callback
            %               names that should be migrated.
            %           Unsupported - 1xn cell array of callback
            %               names that should not be migrated.
            
            obj.GUIDECodeParser = guideCodeParser;
            obj.CallbackSupport = callbackSupport;
            obj.MigrationInfo = migrationInfo;
        end
        
        function [codeData, issues, numMigratedFunctions] = convertSupportedFunctions(obj)
            % CONVERTSUPPORTEDFUNCTIONS - Migrates the GUIDE callbacks and
            %   helper functions to App Designer's code format. Also
            %   applies small stransformations to app code.
            %
            %   Outputs:
            %       codeData - struct that holds information about the
            %           app's code. Has the following fields:
            %               Callbacks - struct array of callback info
            %               StartupCallback - struct with info about
            %                   startup callback (GUIDE app's OpeningFcn)
            %               EditableSectionCode - code for the editable
            %                   section (GUIDE app's helper functions)
            %
            %       issues - Array of AppConversionIssues that were
            %           generated during the code conversion.
            %
            %       numMigratedFunctions - number of callback and helper
            %           functions that were migrated.
            
            issues = [];
            numMigratedFunctions = 0;
            
            codeData = struct(...
                'Callbacks', struct('Name', {}, 'Code', {}),...
                'StartupCallback', struct([]),...
                'InputParameters', '',...
                'EditableSectionCode', []);
            
            codeFileFunctions = obj.GUIDECodeParser.parseFunctions();
            
            guiStateNames = obj.GUIDECodeParser.parseGUIStateFunctionNames();
            openingFcnName = guiStateNames.OpeningFcn;
            outputFcnName = guiStateNames.OutputFcn;
            layoutFcnName = guiStateNames.LayoutFcn;
            
            allFunctionNames = fieldnames(codeFileFunctions);
            
            supportedCallbackNames = unique(obj.CallbackSupport.Supported);
            unsupportedCallbackNames = unique(obj.CallbackSupport.Unsupported);
            
            if ~isempty(outputFcnName)
                unsupportedCallbackNames = [unsupportedCallbackNames outputFcnName];
                issues = [issues obj.convertOutputFcn(outputFcnName, codeFileFunctions)];
            end
            
            if ~isempty(layoutFcnName)
                unsupportedCallbackNames = [unsupportedCallbackNames layoutFcnName];
            end
            
            helperFunctionNames = setdiff(allFunctionNames,...
                [{openingFcnName}, supportedCallbackNames, unsupportedCallbackNames]);
            
            % -------------- Migrate OpeningFcn -----------------------
            if isfield(codeFileFunctions, openingFcnName)
                openingFcnCode = codeFileFunctions.(openingFcnName).Code;
                
                codeData.StartupCallback = obj.convertOpeningFcn(...
                    openingFcnName, openingFcnCode, helperFunctionNames, codeFileFunctions);
                
                codeData.InputParameters = 'varargin';
                
                numMigratedFunctions = numMigratedFunctions + 1;
            end
            
            % -------------- Construct Uitool Helper Function --------------
            % When there are at least 2 interactive uitools that are migrated, we
            % generate code for a private function called
            % resetInteractions.  This function ensures that the
            % interactive tools are selected only on a one-at-a-time basis.
            
            % Determine the number of interactive tools that are being
            % migrated.
            interactiveToolIndex = contains({obj.MigrationInfo.toolInfo.toolId},...
                {'Exploration.DataCursor','Exploration.Pan', 'Exploration.Rotate', 'Exploration.ZoomIn', 'Exploration.ZoomOut'});
            numberOfInteractiveTools = nnz(interactiveToolIndex);
            
            % If the number of interactive tools is 2 or more, define the
            % helper function
            if numberOfInteractiveTools > 1
                helperFunctionNames = [helperFunctionNames; 'resetInteractions'];
                
                codeFileFunctions = obj.generateFunctionForResetIneractions(codeFileFunctions);
            end
            
            % -------------- Migrate Supported Functions --------------
            % Add OutputFcn and LayoutFcn to unsupported callbacks
            % TODO: create issue when outputFcn has user written code
            
            % Pass the names of helper functions so that 'app' can be
            % inserted as the first argument to any invocations.
            codeData.Callbacks = obj.convertSupportedCallbacks(...
                supportedCallbackNames, codeFileFunctions, helperFunctionNames);
            
            % -------------- Migrate Helper Functions------------------
            % Convert helper functions as editable code
            [codeData.EditableSectionCode, numHelperFunctionsMigrated] = obj.convertHelperFunctions(...
                helperFunctionNames, codeFileFunctions);
            
            numMigratedFunctions = numMigratedFunctions +...
                length(supportedCallbackNames) + numHelperFunctionsMigrated;
        end
        
        function codeFileFunctions = generateFunctionForResetIneractions(obj, codeFileFunctions)
            % GENERATEFUNCTIONFORRESETINTERACTIONS - Generate the code for
            % the interactive tool helper function.
            
            % Determine the tags of the interactive tools being migrated.
            % The 'fliplr' function helps ensure that the order of the tags
            % matches the component browser order.
            InteractiveToolIndex = contains({obj.MigrationInfo.toolInfo.toolId},...
                {'Exploration.DataCursor','Exploration.Pan', 'Exploration.Rotate', 'Exploration.ZoomIn', 'Exploration.ZoomOut'});
            tagsOfInteractiveTools = fliplr({obj.MigrationInfo.toolInfo(InteractiveToolIndex).Tag});
            
            % Prepare the tags for code generation by appending 'app.' and
            % joining them.  The result should be similar to:
            % 'app.toggletool1, app.toggletool2, app.toggletool3'
            toolsWithAppAppended = append('app.',tagsOfInteractiveTools);
            combinedToolString = strjoin(toolsWithAppAppended,', ');
            
            % Define the helper function parameters
            codeFileFunctions.resetInteractions.Name = 'resetInteractions';
            codeFileFunctions.resetInteractions.Inputs = {'event'};
            codeFileFunctions.resetInteractions.Outputs = {};
            codeFileFunctions.resetInteractions.Code = {...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line1'));...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line2'));...
                ' ';...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line3'));...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line4'));...
                ['interactiveTools = [', combinedToolString , '];'];...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line5'));...
                ' ';...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line6'));...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line7'));...
                ' ';...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line8'));...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line9', obj.MigrationInfo.figureInfo.Tag));...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line10', obj.MigrationInfo.figureInfo.Tag));...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line11', obj.MigrationInfo.figureInfo.Tag));...
                getString(message('appmigration:codegeneration:InteractionHelperFunction_line12', obj.MigrationInfo.figureInfo.Tag));};
            
        end
        
        function issues = analyzeCodeForUnsupportedAPICalls(obj)
            % ANALYZECODEFORUNSUPPORTEDAPICALLs Analyzes the GUIDE code and
            % generates an AppConversionIssue for each unsupported API call
            % it finds.
            %
            %   Outputs:
            %       issues - Array of AppConversionIssues of each dectected
            %           unsupported API call
            import appmigration.internal.AppConversionIssueFactory;
            issues = [];
            
            % Find all usages of unsupported functions, unsupported
            % properties, and callbacks being called programmatically.
            % Create an issue for each detected unsupported API
            funcAPIInfo = obj.GUIDECodeParser.parseCodeForFunctionUsage(fieldnames(obj.UnsupportedFunctions));
            propAPIInfo = obj.GUIDECodeParser.parseCodeForPropertyUsage(fieldnames(obj.UnsupportedProperties));
            callbackAPIInfo = obj.GUIDECodeParser.parseCodeForFunctionUsage(...
                [obj.CallbackSupport.Unsupported, obj.CallbackSupport.Supported]);
            
            % Remove the first found instance of nargin because this refers
            % to the nargin check in the GUIDE init code and not the user's
            % code.
            narginIndices = strcmp('nargin', {funcAPIInfo.Name});
            if ~isempty(narginIndices)
                narginAPIInfo = funcAPIInfo(narginIndices);
                
                if length(narginAPIInfo.Lines) > 1
                    funcAPIInfo(narginIndices).Lines(1) = [];
                else
                    funcAPIInfo(narginIndices) = [];
                end
            end
            
            % Search unsupported property API usage first so that JavaFrame
            % usage bubbles to the top of the API issues
            for i=1:length(propAPIInfo)
                apiIssue = AppConversionIssueFactory.createAPIIssue(...
                    obj.UnsupportedProperties.(propAPIInfo(i).Name), propAPIInfo(i).Name, propAPIInfo(i).Lines);
                
                issues = [issues, apiIssue]; %#ok<AGROW>
            end
            
            for i=1:length(funcAPIInfo)
                apiIssue = AppConversionIssueFactory.createAPIIssue(...
                    obj.UnsupportedFunctions.(funcAPIInfo(i).Name), funcAPIInfo(i).Name, funcAPIInfo(i).Lines);
                
                issues = [issues, apiIssue]; %#ok<AGROW>
            end
            
            for i=1:length(callbackAPIInfo)
                apiIssue = AppConversionIssueFactory.createAPIIssue(...
                    'UnrecommendedUsingCallbackProgrammatically', callbackAPIInfo(i).Name, callbackAPIInfo(i).Lines);
                
                issues = [issues, apiIssue]; %#ok<AGROW>
            end
        end
    end
    
    methods (Access = private)
        function startupCallback = convertOpeningFcn(obj, openingFcnName, openingFcnCode, helperFunctionNames, codeFileFunctions)
            
            % Indent code, add 'app' to helper function calls, and add
            % mimicGUIDECallbackArgs call
            openingFcnCode = appmigration.internal.CodeConverterUtil.convertHelperFunctionInvocations(openingFcnCode, helperFunctionNames);
            openingFcnInputs = codeFileFunctions.(openingFcnName).Inputs;
            openingFcnCode = appmigration.internal.CodeConverterUtil.addGUIDEConversionCallForOpeningFcn(openingFcnCode, openingFcnInputs);
            openingFcnCode = obj.addEnsureOnScreenCodeToOpeningFcn(openingFcnCode);
            openingFcnCode = obj.indentCode(openingFcnCode, obj.FunctionBodyIndent);
            
            startupCallback = struct(...
                'Name', openingFcnName,...
                'Code', {openingFcnCode});
        end
        
        function issue = convertOutputFcn(~, outputFcnName, codeFileFunctions)
            
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.AppConversionIssue;
            import appmigration.internal.AppConversionIssueType;
            
            issue = [];
            
            if isfield(codeFileFunctions, outputFcnName)
                code = codeFileFunctions.(outputFcnName).Code;
                
                code = CommonCallbackConversionUtil.removeCommentsAndWhitespace(code);
                defaultCode = {'varargout{1}=handles.output;'};
                
                if isequal(code, defaultCode) || isempty(code)
                    % Do nothing, the user has default code and so we don't
                    % need to report an issue about OutputFcn not supported.
                else
                    issueType = AppConversionIssueType.Callback;
                    issueIdentifier = AppConversionIssueFactory.Ids.UnsupportedCallbackOutputFcn;
                    
                    % Use the app's name as the tag which is typically the
                    % name preceeding _OutputFcn of the output fcn's name.
                    % If the user manually changed the name of the
                    % OutputFcn, we will just use the name they provide.
                    issueComponentTag = strsplit(outputFcnName, '_');
                    issueComponentTag = issueComponentTag{1};
                    
                    issueComponentType = '';
                    issueName = outputFcnName;
                    issueValue = '';
                    
                    issue = AppConversionIssue(....
                        issueType,...
                        issueIdentifier,...
                        issueComponentTag,...
                        issueComponentType,...
                        issueName,...
                        issueValue);
                end
            end
        end
        
        function callbacks = convertSupportedCallbacks(obj, supportedCallbackNames, codeFileFunctions, helperFunctionNames)
            
            numCallbacks = length(supportedCallbackNames);
            emptyCellArray = cell(numCallbacks, 0);
            callbacks = struct('Name', emptyCellArray, 'Code', emptyCellArray);
            
            for i=1:length(supportedCallbackNames)
                callbackName = supportedCallbackNames{i};
                callbackCode = codeFileFunctions.(callbackName).Code;
                
                % Add 'app' to the beginning of all helper function
                % invocations inside the function body
                callbackCode = appmigration.internal.CodeConverterUtil.convertHelperFunctionInvocations(callbackCode, helperFunctionNames);
                
                % Add the call to mimicGUIDECallbackArguments, making sure
                % that the outputs of that function are assigned to the
                % same variables defined in the callback's inputs in the
                % GUIDE code file.
                callbackInputs = codeFileFunctions.(callbackName).Inputs;
                callbackCode = appmigration.internal.CodeConverterUtil.addGUIDEConversionCallForCallbacks(callbackCode, callbackInputs);
                
                % Indent code and replace handles. with app.
                callbackCode = obj.indentCode(callbackCode, obj.FunctionBodyIndent);
                
                callbacks(i).Name = callbackName;
                callbacks(i).Code = callbackCode;
            end
        end
        
        function [editableSectionCode, numMigrated] = convertHelperFunctions(obj, helperFunctionNames, codeFileFunctions)
            
            editableSectionCode = [];
            numMigrated = 0;
            
            if isempty(helperFunctionNames)
                % No helper functions to convert, return early
                return;
            end
            
            % Helper functions found in the GUIDE app's code file will be
            % converted as private methods of the app.
            editableSectionHeader = obj.indentCode({''; 'methods (Access = private)'}, obj.MethodIndent);
            editableSectionFooter = obj.indentCode({'end'; ''}, obj.MethodIndent);
            
            % Create the editable section body by looping over each helper
            % function and creating a function for each.
            editableSectionBody = {};
            for i=1:length(helperFunctionNames)
                functionInfo = codeFileFunctions.(helperFunctionNames{i});
                functionName = functionInfo.Name;
                functionCode = functionInfo.Code;
                
                % Don't want to convert empty helper functions and so
                % continue to the next function if the code is empty.
                if isempty(functionCode)
                    continue;
                end
                
                functionCode = obj.indentCode(functionCode, obj.FunctionBodyIndent);
                
                % Create function input string
                inputs = functionInfo.Inputs;
                if isempty(inputs)
                    inputs = 'app';
                else
                    inputs = sprintf('app, %s', strjoin(inputs, ', '));
                end
                
                % Create function output string
                outputs = functionInfo.Outputs;
                if length(outputs) > 1
                    outputs = sprintf('[%s] = ', strjoin(outputs, ', '));
                elseif length(outputs) == 1
                    outputs = sprintf('%s = ', outputs{1});
                else
                    outputs = '';
                end
                
                % Create the function signature
                functionSignature = {sprintf('function %s%s(%s)',...
                    outputs, functionName, inputs)};
                functionSignature = obj.indentCode(functionSignature, obj.FunctionIndent);
                
                % Create the function end
                functionEnd = obj.indentCode({'end'; ''}, obj.FunctionIndent);
                
                % Add 'app' to the beginning of all helper function
                % invocations inside the function body
                functionCode = appmigration.internal.CodeConverterUtil.convertHelperFunctionInvocations(functionCode, helperFunctionNames);
                
                % Combine all parts of the function together with
                % previously created functions.
                editableSectionBody = [...
                    editableSectionBody;...
                    functionSignature;...
                    functionCode;...
                    functionEnd]; %#ok<AGROW>
                
                numMigrated = numMigrated + 1;
            end
            
            if ~isempty(editableSectionBody)
                % Create the editable section
                editableSectionCode = [...
                    editableSectionHeader;...
                    editableSectionBody;...
                    editableSectionFooter];
            end
        end
        
        function openingFcnCode = addEnsureOnScreenCodeToOpeningFcn(obj, openingFcnCode)
            % add code to invoke movegui from openningFcn in the migrated
            % GUIDE app to ensure that the migrated apps are entirely on
            % screen at run-time
            ensureOnScreenComment = ['% ' getString(message('appmigration:codegeneration:EnsureOnScreenComment'))];
            ensureOnScreenCode = getString(message('appmigration:codegeneration:EnsureOnScreenCode', ['app.' obj.MigrationInfo.figureInfo.Tag]));
            openingFcnCode = [{ensureOnScreenComment; ensureOnScreenCode; ''}; openingFcnCode];
        end
    end
    
    methods (Static, Access = private)
        function code = indentCode(code, amount)
            code = strcat({blanks(amount)}, code);
        end
        
        function code = commentOutCode(code)
            code = strcat({'% '}, code);
        end
    end
end