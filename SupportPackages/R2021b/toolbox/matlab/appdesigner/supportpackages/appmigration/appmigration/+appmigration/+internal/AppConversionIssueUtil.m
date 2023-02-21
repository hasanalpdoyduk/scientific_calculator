classdef (Sealed, Abstract) AppConversionIssueUtil
    %APPCONVERSIONISSUECODEUTIL Util of functions that take an
    %AppConversionIssue and generate code to configure programmatically
    %
    %   Copyright 2020 The MathWorks, Inc.
    
    methods (Static)
        function [filtered, remaining] = filterByIdentifier(issues, identifier)
            % FILTERBYIDENTIFIER - filters the issues by a specified
            % identiier
            %
            %   Inputs:
            %       issues - 1xn array of AppConversionIssues
            %       identifier - an ApppConversionIssueFactory.Ids id
            %
            %   Outputs:
            %       filtered - 1xn array of AppConversionIssues with the id
            %           specified by identifier
            %       remaining - 1xn array of AppConversionIssues that do
            %           not match the specified identifier
            
            if isempty(issues)
                filtered = [];
                remaining = [];
                return;
            end
            
            indices = strcmp({issues.Identifier}, identifier);
            
            filtered = issues(indices);
            remaining = issues(~indices);
        end
        
        function [filtered, remaining] = filterByComponentTag(issues, tag)
            % FILTERBYCOMPONENTTAG - filters the issues by a specified
            % component tag.
            %
            %   Inputs:
            %       issues - 1xn array of AppConversionIssues
            %       tag - a component tag value
            %
            %   Outputs:
            %       filtered - 1xn array of AppConversionIssues with the
            %           ComponentTag that matches tag
            %
            %       remaining - 1xn array of AppConversionIssues that do
            %           not have a ComponentTag that matches tag.
            
            if isempty(issues)
                filtered = [];
                remaining = [];
                return;
            end
            
            indices = strcmp({issues.ComponentTag}, tag);
            
            filtered = issues(indices);
            remaining = issues(~indices);
        end
        
        function [code, dataToSave] = generateCodeForComplexValue(issue)
            % Generates code for a component property value that is too
            % complex to represent in a single line. The complex data is
            % saved into a MAT file that will be loaded prior to the call
            % this this code.
            %   Ex: app.figure1.CData = componentData.figure1.CData;
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            cdata = issue.Value;
            
            dataToSave = struct(codeName, struct(prop, cdata));
            
            code = {sprintf('app.%s.%s = componentData.%s.%s;',...
                codeName, prop, codeName, prop)};
        end
        
        function code = generateCodeForStringValue(issue)
            % Generates code for a component property value that is a
            % string.
            %   Ex: app.uitoolbar1.Tag = 'uitoolbar1';
            %   Exp app.pushtool1.ClickedCallback = 'disp(''hello world'')'
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            value = issue.Value;
            
            % Escape single quotes
            value = strrep(value, '''', '''''');
            
            code = {sprintf('app.%s.%s = ''%s'';',...
                codeName, prop, value)};
        end
        
        function code = generateCodeForOnOffEnum(issue)
            % Generates code for a component property value that is an
            % on/off enum.
            %   Ex: app.uipushtool1.Interruptible = 'off';
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            onOffStr = char(issue.Value);
            
            code = {sprintf('app.%s.%s = ''%s'';',...
                codeName, prop, onOffStr)};
        end
        
        function code = generateCodeForFigurePointerShapeHotSpot(issue)
            % Generates code that will set a figure PointerShapeHotSpot
            % property for the App Designer component converted from GUIDE.
            %   Ex: app.figure1.PointerShapeHotSpot = [0 1];
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            pointerShapeHotSpot = issue.Value;
            
            code = {sprintf('app.%s.%s = [%d %d];',...
                codeName, prop, pointerShapeHotSpot)};
        end
        
        function code = generateForTableBackgroundColor(issue)
            % Generates code that will set a uitables BackgroundColor
            % property for the App Designer component converted from GUIDE.
            %   Ex: app.uitable1.BackgroundColor = [1 1 1 ;0.85 0.85 1];
            
            % BackgroundColor is a mx3 RBG triplet matrix
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            backgroundColor = issue.Value;
            
            rgbValues = sprintf('%.4g %.4g %.4g;', backgroundColor');
            % Strip off the ending ';'
            rgbValues(end) = '';
            
            code = {sprintf('app.%s.%s = [%s];',...
                codeName, prop, rgbValues)};
        end
        
        function code = generateCodeForTableColumnFormat(issue)
            % Generates code that will set a uitables ColumnFormat property
            % for the App Designer component converted from GUIDE.
            % Ex: app.uitable1.ColumnFormat = {[] 'numeric' 'char' 'logical' {'a' 'b' 'cdef'} 'long'};
            
            % ColumnFormat is a cell array of elements being equal to one
            % of the following:
            %   'char'
            %   'logical'
            %   'numeric'
            %   A 1-by-n cell array of character vectors, such as {'one' 'two' 'three'}
            %   A format name accepted by the format function, such as: 'short' or 'long'
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            columnFormat = issue.Value;
            
            % Loop over each item and format the code based on its type
            cellCode = cell(size(columnFormat));
            for i=1:length(columnFormat)
                element = columnFormat{i};
                if isempty(element)
                    cellCode{i} = '[]';
                elseif ischar(element)
                    cellCode{i} = sprintf('''%s''', element);
                else
                    % element is a cell array of character vectors
                    cellStr = cellfun(@(c)sprintf('''%s''', c), element, 'UniformOutput', false);
                    cellStr = strjoin(cellStr, ' ');
                    cellCode{i} = sprintf('{%s}', cellStr);
                end
            end
            cellCode = strjoin(cellCode, ' ');
            cellCode = sprintf('{%s}', cellCode);
            
            code = {sprintf('app.%s.%s = %s;',...
                codeName, prop, cellCode)};
        end
        
        function code = generateCodeForUicontrolListboxTop(issue)
            % Generates code that will use the uilistbox scroll method
            % for the App Designer component converted from GUIDE.
            %   Ex: app.listbox1.scroll(app.listbox1.Items{7});
            
            codeName = issue.ComponentTag;
            listboxTop = issue.Value;
            
            code = {sprintf('app.%s.scroll(app.%s.Items{%d});',...
                codeName, codeName, listboxTop)};
        end
        
        function code = generateCodeForCustomCallback(issue)
            % Generates code to set the callback for the new App Designer
            % component converted from the GUIDE component.
            %   Ex: app.pushbutton1.ButtonPushedFcn = @(src,event)disp('hello world');
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            callbackValue = issue.Value;
            
            % callbackValue is a str for an anynomous function. Don't need to
            % escape single quotes.
            
            code = {sprintf('app.%s.%s = %s;',...
                codeName, prop, callbackValue)};
        end
        
        function code = generateCodeForEvalInBaseCallback(issue)
            % Generates code to set the callback for the new App Designer
            % component converted from the GUIDE component.
            %   Ex: app.pushbutton1.ButtonPushedFcn = 'disp(''hello world'');'
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            callbackValue = issue.Value;
            
            % Escape single quotes. So that string value
            %   disp('hello world')
            % comes out as
            %   app.tag.property = 'disp(''hello world'')';
            callbackValue = strrep(callbackValue, '''', '''''');
            
            code = {sprintf('app.%s.%s = ''%s'';',...
                codeName, prop, callbackValue)};
        end
        
        function code = generateCodeForCallback(issue)
            % Generates code to wire up a callback to use App Designer's
            % createCallbackFcn
            %   Ex: app.uipushtool1.ClickedCallback = createCallbackFcn(app, @uipushtool1_ClickedCallback, true);
            
            codeName = issue.ComponentTag;
            prop = issue.Name;
            callbackName = issue.Value;
            
            code = {sprintf('app.%s.%s = createCallbackFcn(app, @%s, true);',...
                codeName, prop, callbackName)};
        end
    end
end