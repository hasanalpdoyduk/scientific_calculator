classdef UimenuConverter < appmigration.internal.ComponentConverter
    %   UIMENUCONVERTER Converts a uimenu to equivalent App Designer
    %   component.
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, guideComponent)
            
            % Create the appropriate App Designer Component
            componentCreationFunction = @uimenu;
            issues = [];
        end
        
        function propertyValuePairs = getComponentCreationPropertyValuePairs(~, guideComponent)
            propertyValuePairs = {};
        end
        
        function conversionFuncs = getCallbackConversionFunctions(~, ~)
            import appmigration.internal.CommonCallbackConversionUtil;
            
            conversionFuncs = {...
                {'ButtonDownFcn'    , @CommonCallbackConversionUtil.convertUnsupportedCallback}...
                {'CreateFcn'        , @CommonCallbackConversionUtil.convertCreateFcn},...
                {'DeleteFcn'        , @CommonCallbackConversionUtil.convertDeleteFcn},...
                {'MenuSelectedFcn'  , @CommonCallbackConversionUtil.convertOneToOneCallback}...
                };
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            import appmigration.internal.CommonPropertyConversionUtil;
            
            conversionFuncs = {...
                {'Accelerator'        , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'BusyAction'         , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Checked'            , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Enable'             , @CommonPropertyConversionUtil.convertEnable},...
                {'ForegroundColor'    , @CommonPropertyConversionUtil.convertForegroundColor},...
                {'HandleVisibility'   , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Interruptible'      , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Separator'          , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Tag'                , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Text'               , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'UserData'           , @CommonPropertyConversionUtil.convertUserData},...
                {'Visible'            , @CommonPropertyConversionUtil.convertOneToOneProperty}...
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
            %       Label - Dropped
            %       BeingDeleted - Read-only
            %       Children - Dropped
            %       Type - Read-only
            %       UIContextMenu - Non-functional and unassignable in App
            %       Designer design view
        end
    end
end
