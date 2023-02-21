classdef (Sealed, Abstract) CodeConverterUtil < handle
    % CODECONVERTERUTILS - Collection of functions for converting GUIDE
    %   code to App Designer code.

    % Copyright 2019 - 2020 The MathWorks, Inc.

    methods (Static)
        function code = convertHelperFunctionInvocations(code, helperFunctionNames)
            % CONVERTHELPRFUNCTIONSINVOCATIONS - Updates invocations of
            %   helper functions to contain app as first argument and to
            %   remove "handles" as parameters. Also adds "app." to
            %   function handle usage of helper functions.
            %
            % Inputs:
            %   code - nx1 cell array of lines of code.
            %   helperFunctionNames = nx1 cell array of the names of the
            %       app's helper functions.
            %
            % Outputs:
            %   code - nx1 cell array of lines of code with helper function
            %       invocations updated.

            % Join the code into a single string so we can use mtree over
            % the entire code and not per line.
            code = strjoin(code, '\n');

            for idx = 1:length(helperFunctionNames)
                helperFunctionName = helperFunctionNames{idx};
                code = appmigration.internal.CodeConverterUtil.convertHelperFunctionHandleSet(code, helperFunctionName);
                code = appmigration.internal.CodeConverterUtil.convertHelperFunctionCall(code, helperFunctionName);
            end

            code = strsplit(code, '\n', 'CollapseDelimiters', false)';
        end

        function code = addGUIDEConversionCallForCallbacks(code, guideInputs)
            codeToInsert = appmigration.internal.CodeConverterUtil.getMimicGUIDEArgsCallAndComments(guideInputs, 'app, event');

            code = [codeToInsert; code];
        end

        function openingFcnCode = addGUIDEConversionCallForOpeningFcn(openingFcnCode, guideInputs)
            codeToInsert = appmigration.internal.CodeConverterUtil.getMimicGUIDEArgsCallAndComments(guideInputs, 'app');
            openingFcnCode = [codeToInsert; openingFcnCode];
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

            code = strcat({blanks(amount)}, code);
        end
    end

    methods (Static, Access = private)
        function commentsAndCall = getMimicGUIDEArgsCallAndComments(guideInputs, appDesignerInputs)
            argumentsCall = sprintf('[%s, %s, %s] = convertToGUIDECallbackArguments(%s); %%#ok<ASGLU>', guideInputs{1:3}, appDesignerInputs);
            commentsAndCall = {...
                '% Create GUIDE-style callback args - Added by Migration Tool';...
                argumentsCall;...
                ''... % Include a newline to separate this code visually
                };
        end
        
        function code = convertHelperFunctionHandleSet(functionCode, helperFunctionName)
            % Adds "app." to handle usage of helper functions.
            % Example: handles.figure1.ButtonDownFcn = {@myfunc, x, y}
            
            exp = sprintf('@%s\\>', helperFunctionName);
            newStr = sprintf('@app.%s', helperFunctionName);
            code = regexprep(functionCode, exp, newStr);
        end

        function code = convertHelperFunctionCall(functionCode, helperFunctionName)
            codeTree = mtree(functionCode);

            % Find the function call nodes that match the name of our helper
            % function.
            funcNodes = mtfind(codeTree, 'Kind', 'CALL', 'Left.Fun', helperFunctionName);

            if isempty(funcNodes)
                code = functionCode;
                return;
            end

            % Find the nodes that are 'top level', i.e. are not nested within
            % another of the helper function call nodes.
            topLevelNodes = appmigration.internal.CodeConverterUtil.findTopLevelNodes(funcNodes);
            topLevelNodesIndices = indices(topLevelNodes);

            % A cell array containing the converted function calls
            convertedCalls = {};
            % A cell array containing the pieces of the original code that we need
            % to keep around to reassemble the correct final string.  This will
            % include all code except for the original helper function call code.
            originalCodeToKeep = {};

            % The start location to pull out code from the original string up to a
            % function call.
            startIndex = 1;

            % Loop over the top level nodes.
            for i = 1:length(topLevelNodesIndices)
                funcNode = select(codeTree, topLevelNodesIndices(i));
                % Get the indices of the start and end of the function call from
                % the original string
                funcCodeStartIndex = lefttreepos(funcNode);
                funcCodeEndIndex = righttreepos(funcNode);

                % Find the nodes that are the parameters passed to the function
                argNodes = list(funcNode.Right);

                % Add any code from the current start up to the start of the
                % function node we are looking at to the cell array, to be
                % reassembled later
                originalCodeToKeep = [originalCodeToKeep {functionCode(startIndex:funcCodeStartIndex - 1)}];

                % If there are no arguments, do a simple regexp replace.  This
                % handles calls like 'foo()' as well as 'foo'.
                if isempty(argNodes)
                    prefixCode = functionCode(funcCodeStartIndex:funcCodeEndIndex);
                    convertedCall = regexprep(prefixCode, [helperFunctionName '\s*(\(\))?'], [helperFunctionName, '(app)'], 'once');
                else
                    % There are arguments, so pull out the code representing the
                    % arguments.
                    argNodesIndices = indices(argNodes);
                    argCodeStartIndex = lefttreepos(select(argNodes, argNodesIndices(1)));
                    argCodeEndIndex = righttreepos(select(argNodes, argNodesIndices(end)));

                    argCode = functionCode(argCodeStartIndex:argCodeEndIndex);

                    % Convert the arguments so any nested functions here are
                    % processed appropriately; this recursively processes the
                    % arguments to ensure any nested calls are handled.
                    convertedCall = appmigration.internal.CodeConverterUtil.convertHelperFunctionCall(argCode, helperFunctionName);

                    % Extract the function call code and anything occurring after
                    % the last argument
                    prefixCode = functionCode(funcCodeStartIndex:argCodeStartIndex - 1);
                    suffixCode = functionCode(argCodeEndIndex + 1:funcCodeEndIndex);

                    % Add 'app' as the first argument.  Make sure to handle
                    % any line continuations (...) and comments afterward
                    prefixCode = regexprep(prefixCode, [helperFunctionName '(\s*(\.\.\..*)\s*)*\('], [helperFunctionName, '$1(app, '], 'once');
                    % Insert the correctly converted arguments and terminate the
                    % code correctly.
                    convertedCall = [prefixCode convertedCall suffixCode];
                end

                % Add this converted function call to the new code to be
                % reassembled.
                convertedCalls = [convertedCalls {convertedCall}];

                % Advance the starting index to the end of this function.
                % Including the extra +1 here is needed - without it
                % sometimes functions have an extra ')' included at the end
                startIndex = funcCodeEndIndex + 1;
            end

            % Add anything after the last function call into the pieces
            originalCodeToKeep = [originalCodeToKeep functionCode(startIndex:end)];

            % Reassemble the code.
            code = '';
            for idx = 1:length(convertedCalls)
                code = [code originalCodeToKeep{idx} convertedCalls{idx}];
            end

            % If there's anything after the last function call, add it to the end.
            if length(originalCodeToKeep) > length(convertedCalls)
                code = [code originalCodeToKeep{end}];
            end
        end

        function topLevelNodes = findTopLevelNodes(candidateNodes)
            % Given a set of nodes, find those that aren't contained in the
            % subtrees of any of the other nodes.  Each node that is
            % returned is not contained in the subtree of any other node
            % that is returned.
            curSize = count(candidateNodes);
            prevSize = 0;
            nodeIndices = indices(candidateNodes);

            % Operate on every pair of nodes until the size of the set of
            % nodes does not change.
            while curSize ~= prevSize
                prevSize = curSize;

                indicesToRemove = [];

                for i = 1:length(nodeIndices)
                    for j = 1:length(nodeIndices)
                        % Look at each pair of nodes.  If one is contained in the
                        % subtree of the other, then mark it for removal.
                        node1 = select(candidateNodes, nodeIndices(i));
                        node2 = select(candidateNodes, nodeIndices(j));

                        if node1 == node2
                            continue;
                        end

                        % AND is overloaded for MTREE to do a set intersection.
                        if and(subtree(node1), node2) == node2
                            indicesToRemove = [indicesToRemove j];
                        elseif and(subtree(node2), node1) == node1
                            indicesToRemove = [indicesToRemove i];
                        end
                    end
                end

                % Find the unique values that are to be removed, and remove them
                % from the node indices.
                indicesToRemove = unique(indicesToRemove);
                % Vectorize
                logicalArr = ones(1, length(nodeIndices), 'logical');
                logicalArr(indicesToRemove) = false;

                nodeIndices = nodeIndices(logicalArr);
                curSize = length(nodeIndices);
            end

            topLevelNodes = [];

            % Retrieve the top level nodes from the original set of nodes.
            for idx = 1:length(nodeIndices)
                node = select(candidateNodes, nodeIndices(idx));
                if isempty(topLevelNodes)
                    topLevelNodes = node;
                else
                    % Add 'node' to the top level nodes.  The '|' operator
                    % is overloaded to perform a set union for MTREE
                    % objects.
                    topLevelNodes = topLevelNodes | node;
                end
            end
        end
    end
end