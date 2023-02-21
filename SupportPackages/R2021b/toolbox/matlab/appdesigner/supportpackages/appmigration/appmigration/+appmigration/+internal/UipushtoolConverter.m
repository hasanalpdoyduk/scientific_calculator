classdef UipushtoolConverter < appmigration.internal.ComponentConverter
    % UIPUSHTOOLCONVERTER Converter for uipushtool
    
    % Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, ~)
            % GETCOMPONENTCREATIONFUNCTION - Override superclass method.
            
            componentCreationFunction = @uipushtool;
            issues = [];
        end
        
        function conversionFuncs = getCallbackConversionFunctions(~, guideComponent)
            % GETCALLBACKCONVERSIONFUNCTIONS - Override superclass method.

            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.UipushtoolConverter;
            
            conversionFuncs = {...
                {'ButtonDownFcn'  , @CommonCallbackConversionUtil.convertUnsupportedCallback},...
                {'CreateFcn'      , @CommonCallbackConversionUtil.convertCreateFcn},...
                {'DeleteFcn'      , @CommonCallbackConversionUtil.convertDeleteFcn},...
                };
            
            toolid = getappdata(guideComponent, 'toolid');
            clickedCallback = guideComponent.ClickedCallback;
            
            % The pre-defined save callback is not supported in App
            % Designer.  In this situation, generate a Migration Report
            % Issue for the ClickedCallback.  Else, convert the
            % ClickedCallback as usual.
            if ~isempty(toolid) && strcmp(toolid,'Standard.SaveFigure') && strcmp(clickedCallback, '%default') 
                
                conversionFuncs = [conversionFuncs, {...
                    {'ClickedCallback', @UipushtoolConverter.convertDefaultSaveToolCallback},...
                    }];
            else
                conversionFuncs = [conversionFuncs, {...
                    {'ClickedCallback', @CommonCallbackConversionUtil.convertOneToOneCallback},...
                    }];
            end
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            % GETPROPERTYCONVERSIONFUNCTIONS - Override superclass method.

            import appmigration.internal.CommonPropertyConversionUtil;
            
            conversionFuncs = {...
                {'BusyAction'         , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'CData'              , @CommonPropertyConversionUtil.convertCData},...
                {'Enable'             , @CommonPropertyConversionUtil.convertEnable},...
                {'HandleVisibility'   , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Interruptible'      , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Separator'          , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Tag'                , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Tooltip'            , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'UserData'           , @CommonPropertyConversionUtil.convertUserData},...
                {'Visible'            , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                };
        end
    end
    
    methods (Static)
        function [pvp, issues] = convertDefaultSaveToolCallback(guideComponent, prop, ~, ~, ~)
            % CONVERTDEFAULTSAVETOOLCALLBACK - The Default ClickedCallback
            % ('%default') for the save push tool in GUIDE is not supported
            % in App Designer.  Generate a Migration Issue if the app
            % utilizes this default callback.
            
            import appmigration.internal.AppConversionIssueFactory;
            
            pvp = [];
            issues = AppConversionIssueFactory.createCallbackIssue(...
                AppConversionIssueFactory.Ids.UnsupportedCallbackPredefinedSaveTool, guideComponent, prop);
        end
    end
    
end