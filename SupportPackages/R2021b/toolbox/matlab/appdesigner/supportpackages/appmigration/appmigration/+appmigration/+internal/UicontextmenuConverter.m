classdef UicontextmenuConverter < appmigration.internal.ComponentConverter
    %UICONTEXTMENUCONVERTER Converter for uicontextmenu.
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, ~)
            componentCreationFunction = @uicontextmenu;
            issues = [];
        end
        
        function propertyValuePairs = getComponentCreationPropertyValuePairs(~, ~)
            propertyValuePairs = {};
        end
        
        function conversionFuncs = getCallbackConversionFunctions(~, ~)
            import appmigration.internal.CommonCallbackConversionUtil;
            
            conversionFuncs = {...
                {'ButtonDownFcn'         , @CommonCallbackConversionUtil.convertUnsupportedCallback},...
                {'ContextMenuOpeningFcn' , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'CreateFcn'             , @CommonCallbackConversionUtil.convertCreateFcn},...
                {'DeleteFcn'             , @CommonCallbackConversionUtil.convertDeleteFcn},...
            };
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            import appmigration.internal.CommonPropertyConversionUtil;
            
            conversionFuncs = {...
                {'BusyAction'         , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'HandleVisibility'   , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Interruptible'      , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Tag'                , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'UserData'           , @CommonPropertyConversionUtil.convertUserData},...
                };
            % Properties Implicitly Converted
            %   Parent - set by ComponentCovnerter.convert()
            
            % Properties NOT converted and NOT reported:
            %   Not Applicable/Dropped
            %       BeingDeleted - Read-only
            %       Children - Read-only
            %       Clipping - Dropped
            %       Type - Read-only
            %       ContextMenu
            
        end
    end
end