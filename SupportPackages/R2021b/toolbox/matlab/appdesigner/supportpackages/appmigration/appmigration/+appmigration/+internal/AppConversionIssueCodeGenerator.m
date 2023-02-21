classdef AppConversionIssueCodeGenerator < handle
    %APPCONVERSIONISSUECODEGENERATOR Generates code from conversion issues
    %   Some components and component properties are not yet supported in
    %   the App Designer design environment but are supported
    %   programmatically in uifigure. Issues are created for these
    %   components during the migration and then this class is responsible
    %   for taking those issues and generating code and adding it to the
    %   app's StartupFcn.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (Access = private)
        AppFullFileName
        
        % Structure that contains complex component property values that
        % can't be generated into a simple line code (example: data for
        % uitable). This stuct with nested structs for each component
        % and the data they are saving.
        %   DataToSave
        %       <component tag>:
        %           <component property name>: <component property value>
        %
        %   Example:
        %       table1
        %           Data: [mxn] data matrix
        %           UserData: <whatever data user specified>
        DataToSave
    end
    
    properties (Constant, Access = private)
        TabSpace = 4;
    end
    
    methods
        function obj = AppConversionIssueCodeGenerator(appFullFileName)
            %APPCONVERSIONISSUECODEGENERATOR Geherates code from conversion
            %issues
            %
            %   Inputs:
            %       appFullFileName: full file path to the migrated app
            %           (.mlapp file)
            
            obj.AppFullFileName = appFullFileName;
        end
        
        function [codeData, remainingIssues] = updateCodeData(obj, codeData, issues)
            %UPDATECODEDATA Updates the codeData structure needed for app
            %serialization with code for programmatically creating
            %components or component properties that are only supported
            %programmatically.
            %
            %   Inputs:
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
            %   Outputs:
            %       codeData - updated codeData struct with the new code
            %           for programmatically creating/configuring
            %           components
            %
            %       remainingIssues - Array of AppConversionIssues that
            %           were not used to generate code.
            
            %  Update components that require runtime configuration.  The following
            % will generate code for the editable section that will look like the following.
            %
            %function addRuntimeConfigurations(app)
            %
            %    % Load data for component configuration
            %    componentData = load('Test_App_14.mat');
            %
            %    % Set component properties that require runtime configuration
            %    app.figure1.PointerShapeCData = componentData.figure1.PointerShapeCData;
            %    app.figure1.PointerShapeHotSpot = [15 32];
            %    app.figure1.UserData = componentData.figure1.UserData;
            %    app.axes1.Colormap = componentData.axes1.Colormap;
            %    app.pushbutton1.ButtonPushedFcn = 'disp test';
            %    app.pushbutton1.DeleteFcn = createCallbackFcn(app, @pushbutton1_DeleteFcn, true);
            %    app.pushbutton1.UserData = componentData.pushbutton1.UserData;
            %    app.uitable1.BackgroundColor = [0.9412 0.9412 0.9412;1 1 0];
            %    app.uitable1.ColumnFormat = {'numeric' 'char'};
            %    app.uitable1.Data = componentData.uitable1.Data;
            %    app.listbox1.scroll(app.listbox1.Items{5});
            %    app.pushbutton2.ButtonPushedFcn = @(~,~)disp('hello world');
            %    app.pushbutton2.DeleteFcn = @(~,~)disp('in delete of pushbutton2');
            %end
            
            % Generate the code for all issues
            [issueCode, dataToSave, remainingIssues] = obj.generateCodeFromIssues(issues);
            
            obj.DataToSave = dataToSave;
            
            if ~isempty(issueCode)
                issueCode = [...
                    {getString(message('appmigration:codegeneration:SetComponentPropertiesComment'))};...
                    issueCode];
            end
            
            % addRuntimeConfiguration function block
            configFuncCode = obj.buildAddRuntimeConfigurationFunctionCode(issueCode);
            configFuncCode = obj.indentCode(configFuncCode, 2*obj.TabSpace);
            
            if isempty(configFuncCode)
                % There is no code to add to the EditableSection or
                % StartupFcn and so terminate early
                return;
            end
            
            % Add code to EditableSectionCode
            if isempty(codeData.EditableSectionCode)
                codeData.EditableSectionCode = [...
                    obj.indentCode({''}, obj.TabSpace);
                    obj.indentCode({'methods (Access = private)'}, obj.TabSpace);
                    configFuncCode;...
                    obj.indentCode({'end'}, obj.TabSpace);
                    ];
            else
                % TODO: this assumes that the EditableSectionCode has a
                % methods end on the second to last line.
                codeData.EditableSectionCode = [...
                    codeData.EditableSectionCode(1:end-2);... % This is all of the migrated helper functions
                    configFuncCode;
                    codeData.EditableSectionCode(end-1:end)]; % This is the method 'end' and remaining code
            end
            
            % The following will add call to addRuntimeConfiguration
            % to StartupFcn if there is code to add
            
            if ~isempty(codeData.StartupCallback) && ~isempty(configFuncCode)
                codeData.StartupCallback.Code = [...
                    obj.getCodeToAddToStartupFcn();...
                    codeData.StartupCallback.Code];
            end
        end
        
        function saveComponentData(obj)
            % SAVECOMPONENTDATA saves any component property data that is
            % necessary for the generated code. It save the data to a MAT
            % file with the same name and location as the MLAPP file.
            
            if ~isempty(obj.DataToSave)
                [fullPath, appName] = fileparts(obj.AppFullFileName);
                fullFileName = fullfile(fullPath, [appName '.mat']);
                
                dataToSave = obj.DataToSave;
                save(fullFileName, '-struct', 'dataToSave');
            end
        end
    end
    
    methods (Access = private)
        function [code, dataToSave, remainingIssues] = generateCodeFromIssues(obj, issues)
            
            import appmigration.internal.AppConversionIssueUtil;
            
            code = [];
            dataToSave = [];
            remainingIssues = [];
            
            for i=1:length(issues)
                issue = issues(i);
                switch issue.Identifier
                    case {...
                            'UnsupportedPropertyAxesColormap',...
                            'UnsupportedPropertyFigurePointerShapeCData',...
                            'UnsupportedPropertyTableData',...
                            'UnsupportedPropertyUserData'}
                        [codeSnippet, data] = AppConversionIssueUtil.generateCodeForComplexValue(issue);
                        dataToSave = obj.mergeStructs(dataToSave, data);
                        
                    case 'UnsupportedPropertyFigurePointerShapeHotSpot'
                        codeSnippet = AppConversionIssueUtil.generateCodeForFigurePointerShapeHotSpot(issue);
                    case 'UnsupportedPropertyTableBackgroundColor'
                        codeSnippet = AppConversionIssueUtil.generateForTableBackgroundColor(issue);
                    case 'UnsupportedPropertyTableColumnFormat'
                        codeSnippet = AppConversionIssueUtil.generateCodeForTableColumnFormat(issue);
                    case 'UnsupportedPropertyListboxTop'
                        codeSnippet = AppConversionIssueUtil.generateCodeForUicontrolListboxTop(issue);
                    case 'UnsupportedCallbackTypeCustom'
                        codeSnippet = AppConversionIssueUtil.generateCodeForCustomCallback(issue);
                    case 'UnsupportedCallbackTypeEvalInBase'
                        codeSnippet = AppConversionIssueUtil.generateCodeForEvalInBaseCallback(issue);
                    case {...
                            'UnsupportedCallbackDeleteFcn',...
                            'UnsupportedCallbackWithProgrammaticWorkaround'}
                        codeSnippet = AppConversionIssueUtil.generateCodeForCallback(issue);
                    otherwise
                        codeSnippet = [];
                        remainingIssues = [remainingIssues issue]; %#ok<AGROW>
                end
                
                if ~isempty(codeSnippet)
                    code = [code; codeSnippet]; %#ok<AGROW>
                end
            end
        end
        
        function code = buildAddRuntimeConfigurationFunctionCode(obj, code)
            
            if ~isempty(obj.DataToSave)
                [~, appName] = fileparts(obj.AppFullFileName);
                code = [...
                    {getString(message('appmigration:codegeneration:LoadComponentDataComment'))};...
                    {sprintf('componentData = load(''%s.mat'');', appName)};...
                    {''};...
                    code];
            end
            
            if ~isempty(code)
                code = [...
                    {getString(message('appmigration:codegeneration:UpdateComponentsComment'))};...
                    {'function addRuntimeConfigurations(app)'};...
                    obj.indentCode({''}, obj.TabSpace);...
                    obj.indentCode(code, obj.TabSpace);...
                    {'end'}...
                    ];
            end
        end
        
        function code = getCodeToAddToStartupFcn(obj)
            
            code = obj.indentCode([...
                {getString(message('appmigration:codegeneration:AddedConfigurationByMigrationToolComment'))};...
                {'addRuntimeConfigurations(app);'};...
                {''};...
                ], 3*obj.TabSpace);
        end
    end
    
    methods (Static, Access = private)
        
        function s1 = mergeStructs(s1, s2)
            % MERGESTRUCTS - merges struct s2 into s1. It s2 will overwrite
            % any fields that are the same as in s1.
            
            if isempty(s1)
                s1 = s2;
                return;
            end
            
            if isempty(s2)
                return;
            end
            
            names = fieldnames(s2);
            for i=1:length(names)
                name = names{i};
                
                if isfield(s1, name) && isstruct(s1.(name)) && isstruct(s2.(name))
                    % Recursive merge children structs
                    s1.(name) = appmigration.internal.AppConversionIssueCodeGenerator.mergeStructs(s1.(name), s2.(name));
                else
                    % Both values are not struct and so add/replace s2 on
                    % s1
                    s1.(name) = s2.(name);
                end
            end
        end
        
        function code = indentCode(code, amount)
            % INDENTCODE - indents code by specified amount
            %
            % Inputs:
            %   code - 1xn cell array of lines of code.
            %   amount - number of blank spaces to indent code by.
            %
            % Outputs:
            %   code - 1xn cell array of lines of code.
            
            if isempty(code)
                return;
            end
            code = appmigration.internal.CodeConverterUtil.indentCode(code, amount);
        end
    end
end