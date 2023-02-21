classdef PreDefinedToolDefaultCallbackCodeGenerator
    % PREDEFINEDTOOLDEFAULTCALLBACKCODEGENERATOR - This class is
    % responsible for generating App Designer Callback Code needed to
    % migrate default callbacks of predefined tools from GUIDE.  The
    % predefined tools include 'new', 'open', 'print', 'zoomin', etc.  The
    % default callbacks are identified by a ClickedCallback of '%default'.
    
    % Copyright 2020 The MathWorks, Inc.
    
    properties (Constant, Access = private)
        FunctionBodyIndent = 12;
        IfStatementIndent = 4;
    end
    
    properties(Access = private)
        % This property is a struct that contains info about the predefined tools with
        % default callbacks.
        predefinedToolDefaultCallbackInfo
        
        % This property is a struct that contains info about the GUIDE
        % Figure.
        guideFigureInfo
        
        % This property records the number of interactive tools being
        % migrated
        numberOfInteractiveTools
    end
    
    
    methods
        function obj = PreDefinedToolDefaultCallbackCodeGenerator(preDefinedToolCallbackMigrationInfo)
            
            % The tool information is defined in the toolInfo field of preDefinedToolCallbackMigrationInfo.
            % The figure information is defined in figureInfo field of preDefinedToolCallbackMigrationInfo.
            if ~isempty(preDefinedToolCallbackMigrationInfo.toolInfo)
                obj.predefinedToolDefaultCallbackInfo = preDefinedToolCallbackMigrationInfo.toolInfo;
                obj.guideFigureInfo =  preDefinedToolCallbackMigrationInfo.figureInfo;
                
                % Record the number of interactive tools being migrated.
                % If only one interactive tool is migrated, we do not call
                % the uitool helper function in the generated code.
                interactiveToolIndex = contains({obj.predefinedToolDefaultCallbackInfo.toolId},...
                    {'Exploration.DataCursor','Exploration.Pan', 'Exploration.Rotate', 'Exploration.ZoomIn', 'Exploration.ZoomOut'});
                obj.numberOfInteractiveTools = nnz(interactiveToolIndex);
                
            end
        end
        
        function codeDataForDefaultToolCallbacks = generateCode(obj)
            % GENERATECODE - predefined PushTool/ToggleTool
            % can have 'default' callbacks.  In this situation, the
            % ClickedCallback is '%default'.  If the tool is not a
            % SaveTool, we migrate these callbacks over by adding in custom
            % code to replicate the 'default' behavior of the callback.
            % The custom code is generated in this method.
            
            codeDataForDefaultToolCallbacks = struct('Name', {}, 'Code', {});
            
            % Loop through each default tool and get the callback code
            % needed for the tool.
            for index = 1:length(obj.predefinedToolDefaultCallbackInfo)
                
                codeDataForDefaultToolCallbacks(index).Name = [obj.predefinedToolDefaultCallbackInfo(index).Tag,'_ClickedCallback'];
                
                switch obj.predefinedToolDefaultCallbackInfo(index).toolId
                    case 'Standard.NewFigure'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getNewFigureCode();
                        
                    case 'Standard.FileOpen'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getOpenFigureCode();
                        
                    case 'Standard.PrintFigure'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getPrintFigureCode();
                        
                    case 'Annotation.InsertLegend'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getLegendCode(index);
                        
                    case 'Annotation.InsertColorbar'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getColorbarCode(index);
                        
                    case 'Exploration.DataCursor'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getDataCursorCode(index);
                        
                    case 'Exploration.Rotate'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getRotateCode(index);
                        
                    case 'Exploration.Pan'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getPanCode(index);
                        
                    case 'Exploration.ZoomOut'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getZoomOutCode(index);
                        
                    case 'Exploration.ZoomIn'
                        codeDataForDefaultToolCallbacks(index).Code = obj.getZoomInCode(index);
                        
                end
            end
            
            if ~isempty(codeDataForDefaultToolCallbacks)
                for i =1:length(codeDataForDefaultToolCallbacks)
                    codeDataForDefaultToolCallbacks(i).Code = obj.indentCodeCell(codeDataForDefaultToolCallbacks(i).Code, obj.FunctionBodyIndent);
                end
            end
        end
    end
    
    methods
        
        function code = getNewFigureCode(obj)
            %GETNEWFIGURECODE - Get the code for the default 'New' tool
            
            code =  {getString(message('appmigration:codegeneration:CreateFigureComment'));...
                getString(message('appmigration:codegeneration:CreateFigureCode', obj.guideFigureInfo.Tag))};
        end
        
        function code = getLegendCode(obj, index)
            %GETLEGENDCODE - Get the code for the default 'Legend' tool
            
            code = [obj.getCommonCallbackCode('legend','axes',index);...
                obj.getIfStatementCode(...
                getString(message('appmigration:codegeneration:LegendCode_Line1')),...
                getString(message('appmigration:codegeneration:LegendCode_Line2')))];
        end
        
        function code = getColorbarCode(obj, index)
            % GETCOLORBARCODE - Get the code for the default 'Colorbar'
            % tool
            
            code = [obj.getCommonCallbackCode('colorbar','axes',index);...
                obj.getIfStatementCode(...
                getString(message('appmigration:codegeneration:ColorbarCode_Line1')),...
                getString(message('appmigration:codegeneration:ColorbarCode_Line2')))];
        end
        
        function code = getRotateCode(obj, index)
            %GETROTATECODE - Get the code for the default 'Rotate' tool
            
            code = [obj.getInteractiveCode();...
                obj.getCommonCallbackCode('rotation','figure',index);...
                getString(message('appmigration:codegeneration:RotateCode', obj.guideFigureInfo.Tag))];
        end
        
        function code = getPanCode(obj, index)
            %GETPANCODE - Get the code for the default 'Pan' tool
            
            code = [obj.getInteractiveCode();...
                obj.getCommonCallbackCode('pan','figure',index);...
                getString(message('appmigration:codegeneration:PanCode',  obj.guideFigureInfo.Tag))];
        end
        
        function code = getDataCursorCode(obj, index)
            %GETDATACURSORCODE - Get the code for the default 'Data Cursor'
            %tool.
            
            code = [obj.getInteractiveCode();...
                obj.getCommonCallbackCode('data tips','figure',index);...
                getString(message('appmigration:codegeneration:DataCursorCode', obj.guideFigureInfo.Tag))];
        end
        
        function code = getZoomOutCode(obj, index)
            %GETZOOMOUTCODE - Get the code for the default 'Zoom Out' tool.
            
            code = [obj.getInteractiveCode();...
                obj.getCommonCallbackCode('zoom-out','figure',index);...
                getString(message('appmigration:codegeneration:ZoomCode_Line1', obj.guideFigureInfo.Tag))
                obj.getIfStatementCode(...
                getString(message('appmigration:codegeneration:ZoomoutCode_Line1')),...
                getString(message('appmigration:codegeneration:ZoomCode_Line2')),...
                getString(message('appmigration:codegeneration:ZoomCode_Line3')))];
        end
        
        function code = getZoomInCode(obj, index)
            %GETZOOMINCODE - Get the code for the default 'Zoom In' tool.
            
            code = [obj.getInteractiveCode();...
                obj.getCommonCallbackCode('zoom-in','figure',index);...
                getString(message('appmigration:codegeneration:ZoomCode_Line1', obj.guideFigureInfo.Tag));...
                obj.getIfStatementCode(...
                getString(message('appmigration:codegeneration:ZoominCode_Line2')),...
                getString(message('appmigration:codegeneration:ZoomCode_Line2')),...
                getString(message('appmigration:codegeneration:ZoomCode_Line3')))];
        end
        
        function code = getOpenFigureCode(~)
            %GETOPENFIGURECODE - Get the code for the default 'Open Figure'
            %tool.
            
            code = {getString(message('appmigration:codegeneration:OpenFigureComment'));...
                getString(message('appmigration:codegeneration:OpenFigureCode'))};
        end
        
        function code = getPrintFigureCode(obj)
            %GETPRINTFIGURECODE - Get the code for the default 'Print'
            %tool.
            
            code = {getString(message('appmigration:codegeneration:PrintComment1'));...
                getString(message('appmigration:codegeneration:PrintComment2'));...
                getString(message('appmigration:codegeneration:PrintComment3'));...
                getString(message('appmigration:codegeneration:PrintComment4'));...
                getString(message('appmigration:codegeneration:PrintComment5'));...
                '';...
                getString(message('appmigration:codegeneration:PrintComment6'));...
                getString(message('appmigration:codegeneration:PrintComment7'));...
                getString(message('appmigration:codegeneration:PrintCode1'));...
                getString(message('appmigration:codegeneration:PrintCode2'));...
                getString(message('appmigration:codegeneration:PrintCode3'));...
                getString(message('appmigration:codegeneration:PrintCode4'));...
                getString(message('appmigration:codegeneration:PrintCode5'));...
                getString(message('appmigration:codegeneration:PrintCode6'));...
                '';...
                getString(message('appmigration:codegeneration:PrintComment8'));...
                getString(message('appmigration:codegeneration:PrintComment9'));...
                getString(message('appmigration:codegeneration:PrintCode7'));...
                '';...
                getString(message('appmigration:codegeneration:PrintComment10'));...
                getString(message('appmigration:codegeneration:PrintCode8'));...
                '';...
                obj.indentCodeChar(getString(message('appmigration:codegeneration:PrintCode9', obj.guideFigureInfo.Tag)), obj.IfStatementIndent);...
                getString(message('appmigration:codegeneration:EndStatement'));};
        end
        
        function code = getInteractiveCode(obj)
            % GETINERACTIVECODE - Get the code (and associated comment)
            % that calls the uitool helper function, resetInteractions.
            
            % Only generate the code if more than one interactive tools is
            % being migrated.
            if obj.numberOfInteractiveTools > 1
                code={getString(message('appmigration:codegeneration:InteractiveToolLine1'));...
                    getString(message('appmigration:codegeneration:InteractiveToolLine2'));...
                    getString(message('appmigration:codegeneration:InteractiveToolLine3'));...
                    ' ';};
            else
                code = {''};
            end
        end
        
        function code = getCommonCallbackCode(obj, tool,parent, index)
            % GETCOMMONCALLBACKCODE - Get code that is common to many (but
            % not all) default tools.  The code returned is similar to the
            % following:
            
            % {'% Based on the tool''s State, toggle colobar'
            % '% for the current figure.'
            % 'state = app.ToggleTool1.State;'}
            
            code={getString(message('appmigration:codegeneration:ToolCommonComment1',tool));...
                getString(message('appmigration:codegeneration:ToolCommonComment2'));...
                getString(message('appmigration:codegeneration:StateAssignment', obj.predefinedToolDefaultCallbackInfo(index).Tag));};
            
        end
        
        function code = getIfStatementCode(varargin)
            % GETIFSTATEMENTCODE - Get code if-statement code.  Many
            % default callbacks use the following syntax for their code.
            % This utility method organizes the code given two or three
            % variable lines (the line within the if section and the line
            % within the else section)
            
            % if state
            %     colorbar(gca);
            % else
            %     colorbar(gca,''off'');
            % end
            obj = varargin{1};
            
            if nargin == 3
                code={getString(message('appmigration:codegeneration:IfStatement'));...
                    obj.indentCodeChar(varargin{2}, obj.IfStatementIndent);...
                    getString(message('appmigration:codegeneration:ElseStatement'));...
                    obj.indentCodeChar(varargin{3}, obj.IfStatementIndent);...
                    getString(message('appmigration:codegeneration:EndStatement'));};
            elseif nargin == 4
                code={getString(message('appmigration:codegeneration:IfStatement'));...
                    obj.indentCodeChar(varargin{2}, obj.IfStatementIndent);...
                    obj.indentCodeChar(varargin{3}, obj.IfStatementIndent);...
                    getString(message('appmigration:codegeneration:ElseStatement'));...
                    obj.indentCodeChar(varargin{4}, obj.IfStatementIndent);...
                    getString(message('appmigration:codegeneration:EndStatement'));};
            end
            
        end
        
        function code = indentCodeCell(~, code, amount)
            %indentCodeCell - indent the code by a set amount and return a
            %cell array of character vectors
            
            code = strcat({blanks(amount)}, code);
        end
        
        function code = indentCodeChar(~, code, amount)
            %indentCodeCell - indent the code by a set amount and return a
            %character vector.
            
            code = strcat({blanks(amount)}, code);
            code = code{1};
        end
    end
end