classdef UicontrolConverter < appmigration.internal.ComponentConverter
    %UICONTROLCONVERTER Converts a uicontrol to equivalent App Designer
    %   component.
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, guideComponent)
            
            import appmigration.internal.AppConversionIssueFactory;
            
            issues = [];
            
            % Create the appropriate App Designer Component
            switch guideComponent.Style
                case 'frame'
                    % Frame was deprecated in 2006a.
                    componentCreationFunction = [];
                    issueType = guideComponent.Style;
                    issues = AppConversionIssueFactory.createComponentIssue(...
                        AppConversionIssueFactory.Ids.UnsupportedComponentWithNoWorkaround, guideComponent.Tag, issueType);
                case 'radiobutton'
                    parent = guideComponent.Parent;
                    if strcmp(parent.Type, 'uibuttongroup')
                        componentCreationFunction = @uiradiobutton;
                    else
                        % App Designer doesn't support radiobuttons not
                        % parented to a button group.
                        componentCreationFunction = [];
                        issueType = guideComponent.Style;
                        issues = AppConversionIssueFactory.createComponentIssue(...
                            AppConversionIssueFactory.Ids.InvalidParentUicontrolRadioButton, guideComponent.Tag, issueType);
                    end
                otherwise
                    try
                        componentCreationFunction = ...
                            matlab.ui.internal.componentconversion.UicontrolConversionUtils.getComponentCreationFunction(guideComponent);
                    catch ME
                        error('appmigration:appmigration:UnsupportedUicontrolStyle', ME.message);
                    end
            end
        end
        
        function propertyValuePairs = getComponentCreationPropertyValuePairs(~, guideComponent)
            style = guideComponent.Style;
            switch (style)
                case 'frame'
                    % Frames are not converted, so this function should
                    % still return nothing for them.  The default behavior,
                    % defined by the uicontrol redirect, would be to return
                    % some values for frames.
                    propertyValuePairs = {};
                otherwise
                    propertyValuePairs = matlab.ui.internal.componentconversion.UicontrolConversionUtils.getComponentCreationPropertyValuePairs(guideComponent);
            end
        end
        
        function conversionFuncs = getCallbackConversionFunctions(~, ~)
            import appmigration.internal.UicontrolConverter;
            import appmigration.internal.CommonCallbackConversionUtil;
            
            conversionFuncs = {...
                {'ButtonDownFcn', @CommonCallbackConversionUtil.convertUnsupportedCallback},...
                {'Callback'     , @UicontrolConverter.convertCallback},...
                {'CreateFcn'    , @UicontrolConverter.convertCreateFcn},...
                {'DeleteFcn'    , @CommonCallbackConversionUtil.convertDeleteFcn},...
                {'KeyPressFcn'  , @CommonCallbackConversionUtil.convertUnsupportedCallback},...
                {'KeyReleaseFcn', @CommonCallbackConversionUtil.convertUnsupportedCallback},...
                };
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            import appmigration.internal.UicontrolConverter;
            import appmigration.internal.CommonPropertyConversionUtil;
            
            conversionFuncs = {...
                {'BackgroundColor'    , @UicontrolConverter.convertBackgroundColor},...
                {'BusyAction'         , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'CData'              , @CommonPropertyConversionUtil.convertCData},...
                {'ContextMenu'        , @CommonPropertyConversionUtil.convertContextMenu},...
                {'Enable'             , @CommonPropertyConversionUtil.convertEnable},...
                {'FontAngle'          , @CommonPropertyConversionUtil.convertFontAngle},...
                {'FontName'           , @CommonPropertyConversionUtil.convertFontName},...
                {'FontSize'           , @CommonPropertyConversionUtil.convertFontSize},...
                {'FontWeight'         , @CommonPropertyConversionUtil.convertFontWeight},...
                {'ForegroundColor'    , @UicontrolConverter.convertForegroundColor},...
                {'HandleVisibility'   , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'HorizontalAlignment', @UicontrolConverter.convertHorizontalAlignment},...
                {'Interruptible'      , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'ListboxTop'         , @UicontrolConverter.convertListboxTop},...
                {'Max'                , @UicontrolConverter.convertMaxAndMin},....
                {'Position'           , @UicontrolConverter.convertPosition},...
                {'SliderStep'         , @UicontrolConverter.convertSliderStep},...
                {'String'             , @UicontrolConverter.convertString}...
                {'Tag'                , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'TooltipString'      , @CommonPropertyConversionUtil.convertTooltipString},...
                {'UserData'           , @CommonPropertyConversionUtil.convertUserData},...
                {'Visible'            , @CommonPropertyConversionUtil.convertOneToOneProperty},...
                {'Value'              , @UicontrolConverter.convertValue}...
                };
            
            % Properties Implicitly Converted
            %   FontUnits - set to 'pixels' by ComponentConverter.convert()
            %       because this needs to be done prior to doing any
            %       conversions.
            %   Min - converted with Max
            %   Parent - set by ComponentCovnerter.convert()
            %   Style - Each style is created into a separate App Designer
            %       component.
            %   Units - set to 'pixels' by ComponentConverter.convert()
            %       because this needs to be done prior to doing any
            %       conversions.
            
            % Properties NOT converted and NOT reported:
            %   Dropped (HG cruft) - Not Reported
            %     Children (all sytles)
            %     Clipping (all sytles)
            %     HitTest (all styles)
            %     Selected (all styles)
            %     SelectionHighlight (all styles)
            %   Not applicable - Not Reported
            %     BeingDeleted (all styles) - read-only
            %     InnerPosition (all styles) - same as position
            %     ListboxTop (all but ListBox)
            %     OuterPosition (all styles) - same as position
            %     SliderStep (all but Slider)
            %     Type (all styles) - read-only
        end
    end
    
    methods (Static)
        function [pvp, issues] = convertCallback(guideComponent, prop, callbackType, callbackName, callbackCode)
            
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.GUIDECallbackType;
            
            pvp = [];
            issues = [];
            
            switch guideComponent.Style
                case {'checkbox', 'edit', 'listbox', 'popupmenu', 'slider'}
                    pvp = {'ValueChangedFcn', callbackName};
                case {'pushbutton'}
                    pvp = {'ButtonPushedFcn', callbackName};
                case {'radiobutton'}
                    % Radiobuttons in App Designer no longer have a
                    % callback as they rely on the SelectionChangeFcn of
                    % its parent buttongroup. Report an issue to the user.
                    issues = AppConversionIssueFactory.createCallbackIssue(...
                        AppConversionIssueFactory.Ids.UnsupportedCallbackUicontrolInButtonGroup,...
                        guideComponent, prop);
                case {'text'}
                    % Do noting as static text don't have callbacks
                case {'togglebutton'}
                    parent = guideComponent.Parent;
                    if strcmp(parent.Type, 'uibuttongroup')
                        % Togglebuttons in App Designer no longer have a
                        % callback as they rely on the SelectionChangeFcn
                        % of its parent buttongroup. Report an issue to the
                        % user.
                        issues = AppConversionIssueFactory.createCallbackIssue(...
                            AppConversionIssueFactory.Ids.UnsupportedCallbackUicontrolInButtonGroup,...
                            guideComponent, prop);
                    else
                        pvp = {'ValueChangedFcn', callbackName};
                    end
            end
            
            if callbackType ~= GUIDECallbackType.Standard
                % Callback is non-standard and so it can not be migrated
                % directly.
                
                % If pvp is empty then we report the issue generated in the
                % switch yard above. If it is not empty then we need to
                % report a non-standard callback issue.
                if ~isempty(pvp)
                    newCallbackName = pvp{1};
                    
                    [pvp, issues] = CommonCallbackConversionUtil.convertNonStandardCallback(...
                        guideComponent, prop, callbackType, callbackName, callbackCode);
                    
                    if ~isempty(issues) && any(strcmp(issues.Identifier,...
                            {AppConversionIssueFactory.Ids.UnsupportedCallbackTypeCustom,...
                            AppConversionIssueFactory.Ids.UnsupportedCallbackTypeEvalInBase}))
                        
                        % Replace the issue 'Name' value to be that of the new
                        % property name for the callback. This is needed to
                        % autognerate correct StartupFcn code (g2104259).
                        issues.Name = newCallbackName;
                    end
                end
            end
        end
        
        function [pvp, issues] = convertCreateFcn(guideComponent, prop, callbackType, callbackName, callbackCode)
            
            import appmigration.internal.UicontrolConverter;
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.GUIDECallbackType;
            
            if callbackType == GUIDECallbackType.Standard
                
                pvp = [];
                issues = [];
                style = guideComponent.Style;
                
                callbackCode = CommonCallbackConversionUtil.removeCommentsAndWhitespace(callbackCode);
                defaultCode = UicontrolConverter.getCreateFcnDefaultCode(style);
                
                if isequal(callbackCode, defaultCode) || isempty(callbackCode)
                    % Do nothing, the user has default code and so we don't
                    % need to report an issue about CreateFcn not supported.
                else
                    % CreateFcn is not yet supported for components.
                    [pvp, issues] = CommonCallbackConversionUtil.convertCreateFcn(guideComponent, prop, callbackType, callbackName, callbackCode);
                end
            else
                % CreateFcn is not yet supported for components.
                [pvp, issues] = CommonCallbackConversionUtil.convertCreateFcn(guideComponent, prop, callbackType, callbackName, callbackCode);
            end
        end
        
        function [pvp, issues] = convertBackgroundColor(guideComponent, prop)
            import appmigration.internal.CommonPropertyConversionUtil;
            % Use the CommonPropertyConversionUtil to convert here as
            % converting one-to-one is not always correct.
            pvp = [];
            issues = [];
            
            switch guideComponent.Style
                case {'edit', 'listbox', 'popupmenu', 'pushbutton', 'text', 'togglebutton'}
                    [pvp, issues] = ...
                        CommonPropertyConversionUtil.convertBackgroundColor(guideComponent, prop);
                otherwise
                    % Do nothing, not applicable for the other styles
            end
        end
        
        function [pvp, issues] = convertForegroundColor(guideComponent, prop)
            import appmigration.internal.CommonPropertyConversionUtil;
            % Use the CommonPropertyConversionUtil to convert here as
            % converting one-to-one is not always correct.
            [pvp, issues] = CommonPropertyConversionUtil.convertForegroundColor(guideComponent, prop);
            
            if ~isempty(pvp)
                % Replace 'ForegroundColor' with 'FontColor' as that is
                % the new API.
                pvp{1} = 'FontColor';
            end
        end
        
        function [pvp, issues] = convertHorizontalAlignment(guideComponent, prop)
            issues = [];
            pvp = matlab.ui.internal.componentconversion.UicontrolConversionUtils.convertHorizontalAlignment(guideComponent, prop);
        end
        
        function [pvp, issues] = convertListboxTop(guideComponent, prop)
            
            import appmigration.internal.AppConversionIssueFactory;
            
            pvp = [];
            issues = [];
            
            switch guideComponent.Style
                case 'listbox'
                    % ListboxTop has been removed. However, a potential
                    % workaround is to use the new uilistbox scroll method
                    % in the app's startupFcn. Only report the issue if the
                    % ListboxTop is not 1 (scrolled to top).
                    if ~isequal(guideComponent.ListboxTop, 1)
                        issues = AppConversionIssueFactory.createPropertyIssue(...
                            AppConversionIssueFactory.Ids.UnsupportedPropertyListboxTop,...
                            guideComponent, prop);
                    end
                otherwise
                    % Do nothing, not applicable for the other styles
            end
        end
        
        function [pvp, issues] = convertMaxAndMin(guideComponent, prop)
            issues = [];
            pvp = matlab.ui.internal.componentconversion.UicontrolConversionUtils.convertMaxAndMin(guideComponent, prop);
        end
        
        function [pvp, issues] = convertPosition(guideComponent, prop)
            issues = [];
            pvp = matlab.ui.internal.componentconversion.UicontrolConversionUtils.convertPosition(guideComponent, prop);
        end
        
        function [pvp, issues] = convertSliderStep(guideComponent, prop)
            import appmigration.internal.AppConversionIssueFactory;
            
            pvp = [];
            issues = [];
            
            switch guideComponent.Style
                case 'slider'
                    factorySliderStep = get(groot, 'factoryuicontrolsliderstep');
                    
                    % SliderStep has been removed with the new slider.
                    % There are no workarounds. Only report the issue if
                    % the slider step is set something different than the
                    % GUIDE default value (factory setting).
                    if ~isequal(guideComponent.SliderStep, factorySliderStep)
                        issues = AppConversionIssueFactory.createPropertyIssue(...
                            AppConversionIssueFactory.Ids.UnsupportedPropertyWithNoWorkaround,...
                            guideComponent, prop);
                    end
                otherwise
                    % Do nothing, not applicable for the other styles
            end
        end
        
        function [pvp, issues] = convertString(guideComponent, prop)
            issues = [];
            pvp = matlab.ui.internal.componentconversion.UicontrolConversionUtils.convertString(guideComponent, prop);
        end
        
        function [pvp, issues] = convertValue(guideComponent, prop)
            issues = [];
            pvp = matlab.ui.internal.componentconversion.UicontrolConversionUtils.convertValue(guideComponent, prop);
        end
    end
    
    methods (Static, Access = private)
        function defaultCode = getCreateFcnDefaultCode(style)
            switch style
                case {'slider'}
                    defaultCode = {...
                        'ifisequal(get(hObject,''BackgroundColor''),get(0,''defaultUicontrolBackgroundColor''))';...
                        'set(hObject,''BackgroundColor'',[.9.9.9]);';...
                        'end'};
                case {'edit', 'listbox', 'popupmenu'}
                    defaultCode = {...
                        'ifispc&&isequal(get(hObject,''BackgroundColor''),get(0,''defaultUicontrolBackgroundColor''))';...
                        'set(hObject,''BackgroundColor'',''white'');';...
                        'end'};
                otherwise
                    % The other styles have no code by default
                    defaultCode = {};
            end
        end
    end
end
