classdef UitableConverter < appmigration.internal.ComponentConverter
    %   UITABLECONVERTER Converts a uitable to equivalent App Designer
    %   component.
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, ~)
            
            % Create the appropriate App Designer Component
            componentCreationFunction = @uitable;
            issues = [];
        end
        
        function propertyValuePairs = getComponentCreationPropertyValuePairs(~, ~)
            propertyValuePairs = {};
        end
        
        function conversionFuncs = getCallbackConversionFunctions(~, ~)
            import appmigration.internal.CommonCallbackConversionUtil;
            
            conversionFuncs = {...
                {'ButtonDownFcn',           @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'CreateFcn',               @CommonCallbackConversionUtil.convertCreateFcn},...
                {'CellEditCallback',        @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'CellSelectionCallback',   @CommonCallbackConversionUtil.convertOneToOneCallback}...
                {'DeleteFcn',               @CommonCallbackConversionUtil.convertDeleteFcn},...
                {'KeyPressFcn',             @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'KeyReleaseFcn',           @CommonCallbackConversionUtil.convertOneToOneCallback},...
                };
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            import appmigration.internal.CommonPropertyConversionUtil;
            import appmigration.internal.UitableConverter;
            import appmigration.internal.AppConversionIssueFactory;
            
            conversionFuncs = {...
                {'BackgroundColor'      , @UitableConverter.convertBackgroundColor},...
                {'BusyAction'           , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'ColumnEditable'       , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'ColumnFormat'         , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot({}, AppConversionIssueFactory.Ids.UnsupportedPropertyTableColumnFormat)},...
                {'ColumnName'           , @UitableConverter.convertColumnName},...
                {'ColumnWidth'          , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'ContextMenu'          , @CommonPropertyConversionUtil.convertContextMenu},...
                {'Data'                 , @UitableConverter.convertData},...
                {'Enable'               , @CommonPropertyConversionUtil.convertEnable},...
                {'FontAngle'            , @CommonPropertyConversionUtil.convertFontAngle},...
                {'FontName'             , @CommonPropertyConversionUtil.convertFontName},...
                {'FontSize'             , @CommonPropertyConversionUtil.convertFontSize},...
                {'FontWeight'           , @CommonPropertyConversionUtil.convertFontWeight},...
                {'ForegroundColor'      , @CommonPropertyConversionUtil.convertForegroundColor},...
                {'HandleVisibility'     , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Interruptible'        , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Position'             , @CommonPropertyConversionUtil.convertPosition},...
                {'RearrangeableColumns' , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot('off', AppConversionIssueFactory.Ids.UnsupportedPropertyWithNoWorkaround)},...
                {'RowName'              , @UitableConverter.convertRowName},...
                {'RowStriping'          , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Tag'                  , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'TooltipString'        , @CommonPropertyConversionUtil.convertTooltipString}...
                {'UserData'             , @CommonPropertyConversionUtil.convertUserData},...
                {'Visible'              , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                };
            
            % Properties Implicitly Converted
            %   FontUnits - set to 'pixels' by ComponentConverter.convert()
            %   because this needs to be done prior to doing any conversions.
            %   Parent - set by ComponentCovnerter.convert()
            %   Units - set to 'pixels' by ComponentConverter.convert()
            %       because this needs to be done prior to doing any
            %       conversions.
            
            
            % Properties NOT converted and NOT reported:
            %   Not Applicable/Dropped
            %       BeingDeleted - Read-only
            %       Children - Dropped
            %       Extent - Read-only
            %       InnerPosition - Same as position
            %       OuterPosition - Same as position
            %       Type - Read-only
            
            % Caveat Conversions
            %   ColumnFormat - Reported only if non-default{}, not design-time configurable
            %   Data - Reported only if non-default[], not design-time configurable
            %   RowName - Report irrespective of GUIDE value as it is not
            %             design-time configurable & does not show numbered
            %             rows at AD run-time although set to default
            %             numbered config in GUIDE
        end
    end
    
    methods (Static)
        function [pvp, issues] = convertColumnName(guideComponent, prop)
            [pvp, issues] = appmigration.internal.UitableConverter.convertColumnOrRowName(guideComponent, prop);
        end
        
        function [pvp, issues] = convertRowName(guideComponent, prop)
            [pvp, issues] = appmigration.internal.UitableConverter.convertColumnOrRowName(guideComponent, prop);
        end
        
        function [pvp, issues] = convertBackgroundColor(guideComponent, prop)
            
            import appmigration.internal.AppConversionIssueFactory;
            
            issues = [];
            pvp = [];
            
            % App Designer does not provide a way to configure background
            % color via the sheet or inspector report if set to anything
            % other than default in GUIDE
            type = guideComponent.Type;
            factoryValue = get(groot, ['factory', type, prop]);
            backgroundColor = guideComponent.(prop);
            if ~isequal(backgroundColor, factoryValue)
                issues = AppConversionIssueFactory.createPropertyIssue(...
                    AppConversionIssueFactory.Ids.UnsupportedPropertyTableBackgroundColor,...
                    guideComponent, prop);
            end
        end
        
        function [pvp, issues] = convertData(guideComponent, prop)
            
            import appmigration.internal.AppConversionIssueFactory;
            
            issues = [];
            pvp = [];
            
            % App Designer does not provide a way to configure data
            % via the sheet or inspector report if set to anything
            % other than default in GUIDE
            % In GUIDE, the default data is returned as 4x2 empty cell
            % array. Check if all cells are empty, if not, report as unsupported property with startup workaround
            data = guideComponent.(prop);
            
            if(iscell(data))
                % if data is cell array,check if all cells are empty
                % checkForEmptyData is returned as logical
                checkForEmptyData = cellfun(@isempty,data);
                
                % confirm if all elements of logical array are empty
                isAllDataEmpty = all(checkForEmptyData(:));
            else
                % if data is numeric/logical array, just check if array is empty
                isAllDataEmpty = isempty(data);
            end
            
            
            if ~isAllDataEmpty
                issues = AppConversionIssueFactory.createPropertyIssue(...
                    AppConversionIssueFactory.Ids.UnsupportedPropertyTableData,...
                    guideComponent, prop);
            end
        end
    end
    
    methods (Static, Access = private)
        function [pvp, issues] = convertColumnOrRowName(guideComponent, prop)
            
            import appmigration.internal.CommonPropertyConversionUtil;
            
            issues = [];
            
            columnOrRowName = guideComponent.(prop);
            
            if strcmp(columnOrRowName,'numbered')
                pvp = {prop, 'numbered'};
            else
                
                % Convert padded character matrix to cell array
                if CommonPropertyConversionUtil.isPaddedCharacterMatrix(columnOrRowName)
                    columnOrRowName = cellstr(columnOrRowName);
                end
                
                % Normalize empty values of different types and sizes to be the
                % same. Otherwise, strip newline and carriage returns.
                if isempty(columnOrRowName)
                    columnOrRowName = '';
                else
                    columnOrRowName = CommonPropertyConversionUtil.stripNewlineAndCarriageReturns(columnOrRowName);
                end
                
                pvp = {prop,columnOrRowName};
            end
        end
    end
end