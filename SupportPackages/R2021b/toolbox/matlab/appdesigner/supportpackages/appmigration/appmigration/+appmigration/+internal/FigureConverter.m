classdef FigureConverter < appmigration.internal.ComponentConverter
    %FIGURECONVERTER Converts a figure to a uifigure
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, ~)
            componentCreationFunction = @uifigure;
            issues = [];
        end
        
        function propertyValuePairs = getComponentCreationPropertyValuePairs(~, ~)
            propertyValuePairs = {'Visible', 'off'};
        end
        
        function conversionFuncs = getCallbackConversionFunctions(~, ~)
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.FigureConverter;
            
            conversionFuncs = {...
                {'ButtonDownFcn'        , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'CloseRequestFcn'      , @FigureConverter.convertCloseRequestFcn},...
                {'CreateFcn'            , @CommonCallbackConversionUtil.convertCreateFcn},...
                {'DeleteFcn'            , @CommonCallbackConversionUtil.convertDeleteFcn},...
                {'KeyPressFcn'          , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'KeyReleaseFcn'        , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'SizeChangedFcn'       , @CommonCallbackConversionUtil.convertSizeChangedFcn},...
                {'WindowButtonDownFcn'  , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'WindowButtonMotionFcn', @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'WindowButtonUpFcn'    , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'WindowKeyPressFcn'    , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'WindowKeyReleaseFcn'  , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                {'WindowScrollWheelFcn' , @CommonCallbackConversionUtil.convertOneToOneCallback},...
                };
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            import appmigration.internal.CommonPropertyConversionUtil;
            import appmigration.internal.FigureConverter;
            import appmigration.internal.AppConversionIssueFactory;
            
            conversionFuncs = {...
                {'BusyAction'         , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Color'              , @FigureConverter.convertColor},...
                {'Colormap'           , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'ContextMenu'        , @CommonPropertyConversionUtil.convertContextMenu},...
                {'GraphicsSmoothing'  , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot('on', AppConversionIssueFactory.Ids.UnsupportedPropertyWithNoWorkaround)},...
                {'HandleVisibility'   , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'IntegerHandle'      , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Interruptible'      , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'MenuBar'            , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot('none', AppConversionIssueFactory.Ids.UnsupportedPropertyWithNoWorkaround)},...
                {'Name'               , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'NextPlot'           , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot('add', AppConversionIssueFactory.Ids.UnsupportedPropertyWithNoWorkaround)},....
                {'NumberTitle'        , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Pointer'            , @CommonPropertyConversionUtil.convertOneToOneProperty},....
                {'PointerShapeCData'  , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot(ones(16,16), AppConversionIssueFactory.Ids.UnsupportedPropertyFigurePointerShapeCData)},....
                {'PointerShapeHotSpot', CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot([1 1], AppConversionIssueFactory.Ids.UnsupportedPropertyFigurePointerShapeHotSpot)},....
                {'Position'           , @CommonPropertyConversionUtil.convertPosition},...
                {'Renderer'           , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIsNot('opengl', AppConversionIssueFactory.Ids.UnsupportedPropertyWithNoWorkaround)},...
                {'Resize'             , @CommonPropertyConversionUtil.convertOneToOneProperty}...
                {'Tag'                , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'ToolBar'            , CommonPropertyConversionUtil.reportUnsupportedPropertyIfValueIs('figure', AppConversionIssueFactory.Ids.UnsupportedPropertyWithNoWorkaround)},...
                {'UserData'           , @CommonPropertyConversionUtil.convertUserData},...
                {'WindowStyle'        , @FigureConverter.convertWindowStyle},...
                };
            
            % Properties NOT converted and NOT reported:
            %   Not Applicable
            %       Alphamap - not settable in GUIDE
            %       BeingDeleted - Read-only
            %       Clipping - has no effect on figures
            %       InnperPosition - same as position
            %       Number - Read-only
            %       OuterPosition - Read-only
            %       RenderMode - Manually set by MATLAB when change Render
            %   Unsupported with no workaround
            %       DocControls
            %       FileName
            %       InvertHardcopy
            %       PaperOrientation
            %       PaperPositionMode
            %       PaperSize
            %       PaperType
            %       PaperUnits
            
        end
    end
    
    methods (Static)
        function [pvp, issues] = convertCloseRequestFcn(guideComponent, prop, callbackType, callbackName, callbackCode)
            
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.GUIDECallbackType;
            
            pvp = [];
            issues = [];
            
            if isequal(guideComponent.(prop), 'closereq')
                % Do nothing, this is default close request for
                % figure.
            elseif callbackType == GUIDECallbackType.Standard
                callbackCode = CommonCallbackConversionUtil.removeCommentsAndWhitespace(callbackCode);
                
                if isequal(callbackCode, {'delete(hObject);'})
                    % Do nothing, the user has default code and so we don't
                    % need to convert this callback.
                else
                    % Callback has user code and so convert the callback.
                    pvp = {'CloseRequestFcn', callbackName};
                end
            else
                [pvp, issues] = CommonCallbackConversionUtil.convertNonStandardCallback(...
                    guideComponent, prop, callbackType, callbackName, callbackCode);
            end
        end
        
        function [pvp, issues] = convertWindowStyle(guideComponent, prop)
            % CONVERTWINDOWSTYLE - WindowStyle of 'docked' is not supported
            % in App Designer.  If the GUIDE app has a WindowStyle of
            % 'docked', report a migration issue; else, migrate as usual.
            
            issues = [];
            pvp = [];
            
            if strcmp(guideComponent.(prop),'docked')
                issues = appmigration.internal.AppConversionIssueFactory.createPropertyIssue(...
                        'UnsupportedPropertyWithNoWorkaround',...
                        guideComponent, prop);
            else
                pvp = {'WindowStyle',guideComponent.(prop)};
            end
            
        end
        function [pvp, issues] = convertColor(guideComponent, prop)
            issues = [];
            pvp = [];
            
            % Fetch GUIDE Application options
            guiOptions = getappdata(guideComponent,'GUIDEOptions');
            
            % In GUIDE you can set an option to change the figure's
            % background color to be the same as the default uicontrol's
            % background color when loading and running the app.
            if isfield(guiOptions, 'syscolorfig') && guiOptions.syscolorfig
                % User has opted to use same background color as the
                % default value for uicontrol.
                colorValue = get(groot,'DefaultUicontrolBackgroundColor');
            else
                % User has opted to use the actual figure background color
                colorValue = guideComponent.(prop);
            end
            
            % Only convert the figure's background color if it is different
            % than the factory value. If it is the factory value, we want
            % to use App Designer's default color instead by not setting
            % the property.
            colorFactoryValue = get(groot, ['factory', guideComponent.Type, prop]);
            if ~isequal(colorValue, colorFactoryValue)
                pvp = {prop, colorValue};
            end
        end
    end
end