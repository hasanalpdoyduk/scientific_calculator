classdef GUIDECodeParser < handle
    %GUIDECODEPARSER Parses a GUIDE app's code.
    %   Service class responsible for extracting the functions/callbacks in
    %   a GUIDE app's code file, parsing the callback string in of a
    %   component to determine the associated callback name, and analyzing
    %   the GUIDE code for API calls.
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    properties (SetAccess = private)
        CodeFullFileName
        Code
    end
    
    properties (Access = private)
        CodeFileFunctionsCache = [];
        CodeMTree
    end
    
    methods
        function obj = GUIDECodeParser(codeFullFileName)
            %GUIDECODEPARSER Construct an instance of this class
            %
            %   Inputs:
            %       codeFullFileName - filename to the MATLAB code file of
            %           a GUIDE GUI
            
            obj.CodeFullFileName = codeFullFileName;
            obj.Code = fileread(codeFullFileName);
            
            % Use MTREE to parse the code. Not including comments in tree
            % so that trailing comments will be ignored when getting
            % extracting the code. GUIDE adds comments above the function
            % and we want to ignore them and not include them with the
            % previous function body.
            obj.CodeMTree = mtree(obj.Code);
        end
        
        function codeFileFunctions = parseFunctions(obj)
            % PARSEFUNCTIONS Parses a GUIDE app's code file and extracts
            %   the functions.
            %
            %   Outputs:
            %       codeFileFunctions - Struct where each fieldname is the
            %           name of a function contained in the code file and
            %           its value is another struct with the following
            %           fields:
            %               Name - name of the function
            %               Code - mx1 cell array of the functions body
            %                   code
            %               Inputs - 1xn cell array of parameter names for
            %                   the function
            %               Outputs = 1xn cell array of output names for
            %               the function
            
            if ~isempty(obj.CodeFileFunctionsCache)
                % Return the cached version
                codeFileFunctions = obj.CodeFileFunctionsCache;
                return;
            end
            
            codeFileFunctions = [];
            
            % Find all the function nodes
            funcNodes = mtfind(obj.CodeMTree, 'Kind', 'FUNCTION');
            funcNodesIndices = indices(funcNodes);
            
            % Skip the main function. We only care about the subfunctions
            % which are the callbacks or helper functions to the GUIDE app
            funcNodesIndices = funcNodesIndices(2:end);
            
            for i = 1:length(funcNodesIndices)
                funcNode = select(funcNodes, funcNodesIndices(i));
                funcName = tree2str(funcNode.Fname);
                
                % If the node is a member of a previous node, it is a
                % nested function.
                if ismember(funcNode, subtree(select(funcNodes, funcNodesIndices(1:i-1))))
                    % Function is a nested function. We don't want to
                    % extract out nested functions and so continue;
                    continue;
                end
                
                % Get the full, raw function code (includes function
                % definition line)
                code = obj.Code(lefttreepos(funcNode):righttreepos(funcNode));
                
                % MATLAB functions can have an optional 'end' stament.
                % We need to remove this 'end' because App Designer code
                % code generation for callbacks automatically includes the
                % 'end'. It is not easy with MTREE to determine if the
                % function has a dedicated 'end' statment. If the function
                % ends with 'end' attempt to remove that 'end' and see if
                % the function code is still valid (doesn't have a parse
                % error because of 'end' mismatch')
                if ~isempty(regexp(code, '\<end$', 'once'))
                    
                    % Remove the end and see if MTREE errors, if so then
                    % the end statement doesn't belong to the function and
                    % so shouldn't be removed.
                    newCode = code(1:end-3);
                    tree = mtree(newCode);
                    
                    if tree.count == 1 && strcmp(tree.kind(), 'ERR')
                        % mtree error and so only want to remove the 'end'
                        % statement if the function contains nested
                        % functions (which require there to be an 'end').
                        funcTree = subtree(select(funcNodes, funcNodesIndices(i)));
                        nestedFuncNodes = mtfind(funcTree, 'Kind', 'FUNCTION');
                        if length(indices(nestedFuncNodes)) > 1
                            % Function has subfunctions and so an 'end'
                            % statement was required for the function. We
                            % can remove the 'end' because App Designer
                            % code generation creates the closing 'end'.
                            code = newCode;
                        end
                        
                    else
                        % No error and so update code to be the new code
                        % without the 'end'.
                        code = newCode;
                    end
                end
                
                % Strip and split the code into a cell array
                code = strip(code);
                code = split(code, newline);
                
                % Strip again on the right. If the code file has CR/LF
                % endings, splitting will split on the LF and then strip
                % will remove the extra CR.
                code = strip(code, 'right');
                
                % Determine the number of lines the function signature
                % spans (due to any '...') and remove them. We don't want
                % to include the function signature; just the body.
                sigLineIdx = 1;
                while sigLineIdx <= length(code) && contains(code(sigLineIdx), '...')
                    sigLineIdx = sigLineIdx + 1;
                end
                code = code(sigLineIdx+1:end);
                
                codeFileFunctions.(funcName) = struct(...
                    'Name', funcName,...
                    'Code', {code},...
                    'Inputs', {obj.extractListItems(funcNode.Ins)},...
                    'Outputs', {obj.extractListItems(funcNode.Outs)});
            end
            
            if isempty(codeFileFunctions)
                % Return empty struct if no functions were extracted from
                % the code file
                codeFileFunctions = struct([]);
            end
            
            % Cache the results because we only need to analyze the file
            % once.
            obj.CodeFileFunctionsCache = codeFileFunctions;
        end
        
        function apiInfo = parseCodeForFunctionUsage(obj, functionList)
            % PARSECODEFORFUNCTIONUSAGE - Analyzes the GUIDE code for the
            %   specified function calls.
            %
            %   Inputs:
            %       functionList - 1xn cell array of function names to
            %           search for usage in the code.
            %
            %   Outputs:
            %       apiInfo - 1xn struct array with fields:
            %           Name   - function name found
            %           Lines  - 1xn double array of line numbers
            
            apiInfo = struct('Name', {}, 'Lines', {});
            
            % Find all the usages of each function in the list
            for i=1:length(functionList)
                functionName = functionList{i};
                
                % We treat clf differently because clf is allowed if there
                % is no 'reset' input.
                if strcmp(functionName,'clf')
                    
                    % Finds clf reset usage in functional form, including the following:
                    % >> clf('reset')
                    % >> clf("reset")
                    % >> clf(figure, 'reset')
                    % >> clf(figure, "reset")
                    % >> output = clf('reset');
                    % >> output = clf("reset");
                    % >> output = clf(figure,'reset');
                    % >> output = clf(figure, "reset");
                    clfResetFunctionCalls  = mtfind(obj.CodeMTree, 'Kind', 'CALL', 'Left.Fun', functionName, 'Right.List.Any.String', {'''reset''';'"reset"'});
                    
                    % Finds clf usage in command form, including the
                    % following:
                    % >> clf reset;
                    clfResetCommandCalls = mtfind(obj.CodeMTree, 'Kind', 'DCALL', 'Left.Fun', functionName, 'Right.List.Any.String', 'reset');
                    
                    % Combines the lines numbers of the clf reset calls
                    % into a unique, sorted list.
                    lines = unique([lineno(clfResetFunctionCalls); lineno(clfResetCommandCalls)], 'sorted');
                else 
                    
                    calls = mtfind(obj.CodeMTree, 'Kind', 'CALL', 'Left.Fun', functionName);
                    lines = lineno(calls);
                end
                
                if ~isempty(lines)
                        apiInfo = [apiInfo, struct('Name', functionName,...
                            'Lines', {lines'})];
                end
            end
        end
        
        function apiInfo = parseCodeForPropertyUsage(obj, propList)
            % PARSECODEFORFUNCTIONUSAGE - Analyzes the GUIDE code for the
            %   specified function calls.
            %
            %   Inputs:
            %       propList - 1xn cell array of properties to
            %           search for usage in the code.
            %
            %   Outputs:
            %       apiInfo - 1xn struct array with fields:
            %           Name   - function name found
            %           Lines  - 1xn double array of line numbers
            
            apiInfo = struct('Name', {}, 'Lines', {});
            
            % Find all the usages of each property in the list
            for i=1:length(propList)
                propName = propList{i};
                
                % Find all "get" usages of a property.
                % Ex: get(fig, 'JavaFrame')
                getCalls = mtfind(obj.CodeMTree, 'Kind', 'CALL', 'Left.Fun', 'get', 'Right.List.Any.String', ['''' propList{i} '''']);
                
                % Find all "set" usages of a property.
                % Ex: set(slider1, 'SliderStep', ...)
                setCalls = mtfind(obj.CodeMTree, 'Kind', 'CALL', 'Left.Fun', 'set', 'Right.List.Any.String', ['''' propList{i} '''']);
                
                % Find all "dot" usages of a property.
                % Ex: jFrame = fig.JavaFrame
                dotCalls = mtfind(obj.CodeMTree, 'Kind', 'FIELD', 'String', propList{i});
                
                getLines = lineno(getCalls);
                setLines = lineno(setCalls);
                dotLines = lineno(dotCalls);
                
                lines = sort([getLines; setLines; dotLines]);
                
                if ~isempty(lines)
                    apiInfo = [apiInfo, struct('Name', propName,...
                        'Lines', {lines'})];
                end
            end
        end
        
        function guiStateNames = parseGUIStateFunctionNames(obj)
            % PARSEGUISTATEFUNCTIONNAMES - Analyzes the GUIDE code for the
            %   name of the OpeningFcn, OutputFcn, and LayoutFcn functions
            %   which are defined in the gui_State struct at the beginning
            %   of each GUIDE app code file.
            %
            %   Outputs:
            %       guiStateNames - struct array with fields:
            %           OpeningFcn - name of app's OpeningFcn (char array)
            %           OutputFcn  - name of app's OutputFcn (char array)
            %           LayoutFcn  - name of app's LayoutFcn (char array)
            
            guiStateNames = struct(...
                'OpeningFcn', obj.parseGUIStateFunctionName('OpeningFcn'),...
                'OutputFcn' , obj.parseGUIStateFunctionName('OutputFcn'),...
                'LayoutFcn' , obj.parseGUIStateFunctionName('LayoutFcn'));
        end
    end
    
    methods (Static)
        function callbackInfo = parseCallbackValue(callbackValue)
            % PARSECALLBACKVALUE Parses a GUIDE components callback value
            %
            %   Inputs:
            %       callbackValue - a GUIDE component's callback value. Can
            %           be a string, anynomous function, or cell array.
            %           Standard GUIDE callbacks are of the form:
            %
            % @(hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject))
            %
            %   Outputs:
            %       callbackInfo - A struct with the following fields:
            %           FunctionName - name of the function executed by the
            %               callback
            %           FunctionArgs - the arguments of the function
            %               executed by the callback
            %           AnonymousArgs - the arguments of the anonymous
            %               function that wraps the function call. This
            %               will be empty if the function call is not
            %               wrapped by an anonymous function.
            %           Type - The type of the callback. Possible values:
            %               'Standard' - Ex: @(hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject))
            %                          - Ex (Legacy): MyGUI('pushbutton1_Callback',gcbo,[],guidata(gcbo))
            %               'StandardWithAdditionalArgs' - Ex: (hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject), 1, pi, 'abc')
            %                          - Ex (Legacy): MyGUI('pushbutton1_Callback',gcbo,[],guidata(gcbo), 1, pi, 'abc')
            %               'Custom' - Ex: @(src,event)disp('Hello World')
            %               'EvalInBase' - Ex: actxproxy(gcbo)
            %               'Automatic' - Ex: %automatic or %default
            %               'CellArray' - Ex: {@myfunc, 1, pi, 'abc'} - You can't actually specify a callback like this during design time in GUIDE
            
            import appmigration.internal.GUIDECodeParser;
            import appmigration.internal.GUIDECallbackType;
            
            callbackInfo = struct(...
                'FunctionName', '',...
                'FunctionArgs', {{}},...
                'AnonymousArgs', {{}});
            
            if iscell(callbackValue)
                % Callback is a cell array
                callbackInfo.FunctionName = func2str(callbackValue{1});
                callbackInfo.FunctionArgs = callbackValue(2:end);
                callbackInfo.Type = GUIDECallbackType.CellArray;
                return;
            end
            
            % Convert to a string if the callback value is a function
            % handle
            if isa(callbackValue, 'function_handle')
                callbackValue = func2str(callbackValue);
            end
            
            if startsWith(callbackValue, '%')
                % Callback str is %automatic or %default which GUIDE uses
                % to automatically generate the callback when the user
                % specifies to do so. Return with the type as 'Automatic'
                callbackInfo.Type = GUIDECallbackType.Automatic;
                return;
            end
            
            T = mtree(callbackValue);
            
            % The first "Arg" node of the mtree should either be an
            % anonymous function (ANON) or a regular function call (CALL)
            % for a valid GUIDE callback string
            node = T.root.Arg;
            
            if iskind(node, 'ANON')
                % The callback string begins with an anonymous function and
                % so extract the arguments and traverse the tree to the
                % Right which should be the body of the anonymous function
                callbackInfo.AnonymousArgs = GUIDECodeParser.extractListItems(node.Left);
                node = node.Right; % This should be a CALL node for a valid callback
            end
            
            if iskind(node, 'CALL')
                % Extract the function name and arguments from the callback
                % string
                callbackInfo.FunctionName = node.Left.string;
                callbackInfo.FunctionArgs = GUIDECodeParser.extractListItems(node.Right);
            end
            
            % Identify the type of GUIDE callback
            callbackInfo.Type = GUIDECodeParser.identifyCallbackType(...
                callbackInfo.AnonymousArgs, callbackInfo.FunctionArgs);
            
        end
    end
    
    methods (Access = private)
        function name = parseGUIStateFunctionName(obj, stateFunction)
            % Parses the code to get the name of the opening, output, or
            % layout functions for the app.
            %   stateFunction - either 'OpeningFcn', 'OutputFcn', or
            %   'LayoutFcn'
            
            name = '';
            
            % Looking for: 'gui_OpeningFcn', @AppName_OpeningFcn, ...
            expression = ['''gui_', stateFunction, '''\s*,\s*@(\w*)\s*,'];
            [tokens, ~] = regexp(obj.Code, expression, 'tokens', 'match');
            
            if ~isempty(tokens)
                name = tokens{1}{1};
            end
        end
    end
    
    methods (Static, Access = private)
        function type = identifyCallbackType(anonymousArgs, functionArgs)
            % Identifies the type of callback:
            %   'Standard' - Ex: @(hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject))
            %              - Ex (Legacy): MyGUI('pushbutton1_Callback',gcbo,[],guidata(gcbo))
            %   'StandardWithAdditionalArgs' - Ex: (hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject), 1, pi, 'abc')
            %                                - Ex (Legacy): MyGUI('pushbutton1_Callback',gcbo,[],guidata(gcbo), 1, pi, 'abc')
            %   'Custom' - Ex: @(src,event)disp('Hello World')
            %   'EvalInBase' - Ex: actxproxy(gcbo)
            
            import appmigration.internal.GUIDECallbackType;
            
            numFunctionArgs = length(functionArgs);
            
            if isempty(anonymousArgs)
                % Not an anonymous function so either Legacy,
                % Legacy Standard, legacy StandardWithAdditionalArgs or EvalInBase type
                
                if numFunctionArgs >= 4
                    if isequal(functionArgs(2:4), {'gcbo', '[]', 'guidata(gcbo)'})
                        if numFunctionArgs > 4
                            type = GUIDECallbackType.StandardWithAdditionalArgs;
                        else
                            type = GUIDECallbackType.Standard;
                        end
                    else
                        type = GUIDECallbackType.EvalInBase;
                    end
                else
                    type = GUIDECallbackType.EvalInBase;
                end
                
            else
                % Either Standard, StandardWithAdditionalArgs or Custom
                
                % For a standard callback, functionsArgs(2:4) should be:
                % {'hObject', 'eventdata', 'guidata(hObject)'}
                normalCallbackArgs = {anonymousArgs{1}, anonymousArgs{2}, sprintf('guidata(%s)', anonymousArgs{1})};
                
                % For a standard selectionChangedFcn, functionsArgs(2:4) should be:
                % {'get(hObject,''SelectedObject'')', 'eventdata', 'guidata(get(hObject,''SelectedObject''))'}
                selectionChangedCallbackArgs = {sprintf('get(%s,''SelectedObject'')',anonymousArgs{1}), anonymousArgs{2}, sprintf('guidata(get(%s,''SelectedObject''))',anonymousArgs{1})};
                
                if numFunctionArgs >= 4
                    if isequal(functionArgs(2:4), normalCallbackArgs) ||...
                            isequal(functionArgs(2:4), selectionChangedCallbackArgs)
                        
                        if numFunctionArgs > 4
                            type = GUIDECallbackType.StandardWithAdditionalArgs;
                        else
                            type = GUIDECallbackType.Standard;
                        end
                    else
                        type = GUIDECallbackType.Custom;
                    end
                else
                    type = GUIDECallbackType.Custom;
                end
            end
        end
        
        function items = extractListItems(tree)
            % Gets the lists of items in function signatures
            current = tree;
            items = {};
            while(~isempty(current))
                itemStr = tree2str(current);
                
                if startsWith(itemStr, '''') && endsWith(itemStr, '''')
                    % item is a char array, just trim whitespace
                    items{end+1} =  strtrim(itemStr);%#ok<*AGROW>
                else
                    % Remove all whitespace and append to items list
                    items{end+1} =  itemStr(~isspace(itemStr));%#ok<*AGROW>
                end
                
                current = current.Next;
            end
        end
    end
end