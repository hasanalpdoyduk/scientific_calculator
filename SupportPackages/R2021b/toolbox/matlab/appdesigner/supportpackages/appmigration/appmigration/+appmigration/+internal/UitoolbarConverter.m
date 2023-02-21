classdef UitoolbarConverter < appmigration.internal.ComponentConverter
    % UITOOLBARCONVERTER Converter for uitoolbar
    
    % Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, ~)
            % GETCOMPONENTCREATIONFUNCTION - Override superclass method.
            
            componentCreationFunction = @uitoolbar;
            issues = [];
        end
        
        function conversionFuncs = getCallbackConversionFunctions(~, ~)
            % GETCALLBACKCONVERSIONFUNCTIONS - Override superclass method.

            import appmigration.internal.CommonCallbackConversionUtil;
            
            conversionFuncs = {...
                {'ButtonDownFcn', @CommonCallbackConversionUtil.convertUnsupportedCallback},...
                {'CreateFcn'    , @CommonCallbackConversionUtil.convertCreateFcn},...
                {'DeleteFcn'    , @CommonCallbackConversionUtil.convertDeleteFcn},...
                };
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            % GETPROPERTYCONVERSIONFUNCTIONS - Override superclass method.

            import appmigration.internal.CommonPropertyConversionUtil;
            
            conversionFuncs = {...
                {'BusyAction'         , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'HandleVisibility'   , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Interruptible'      , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Tag'                , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'UserData'           , @CommonPropertyConversionUtil.convertUserData},...
                {'Visible'            , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                };
        end
    end
end