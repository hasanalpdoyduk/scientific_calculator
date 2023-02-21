classdef (Sealed, Abstract) CommonCallbackConversionUtil
    %COMMONCALLBACKCONVERSIONUTIL Common callback conversion functions
    %   Utility of common callback conversion functions that are shared
    %   amongst the various ComponentConverters.
    %
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods (Static)
        
        function [pvp, issues] = convertOneToOneCallback(guideComponent, prop, callbackType, callbackName, callbackCode)
            % Convert one-to-one callbacks that are directly supported in App
            % Designer without any issues.
            
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.GUIDECallbackType;
            
            if callbackType == GUIDECallbackType.Standard
                issues = [];
                pvp = {prop, callbackName};
            else
                [pvp, issues] = CommonCallbackConversionUtil.convertNonStandardCallback(...
                    guideComponent, prop, callbackType, callbackName, callbackCode);
            end
        end
        
        function [pvp, issues] = convertNonStandardCallback(guideComponent, prop, callbackType, callbackName, callbackCode)
            % Converts callbacks that are not of type
            % GUIDECallbackType.Standard
            
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.GUIDECallbackType;
            
            pvp = [];
            issues = [];
            
            switch callbackType
                case GUIDECallbackType.StandardWithAdditionalArgs
                    % Callbacks is of the form:
                    % @(hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject), 1, pi, 'abc')
                    % or
                    % MyGUI('pushbutton1_Callback',gcbo,[],guidata(gcbo), 1, pi, 'abc')
                    
                    issues = [issues, AppConversionIssueFactory.createCallbackIssue(...
                        AppConversionIssueFactory.Ids.UnsupportedCallbackTypeAdditionalArgs, guideComponent, prop)];
                case GUIDECallbackType.Custom
                    % Callbacks is of the form:
                    % @(src,event)disp('Hello World')
                    
                    issues = [issues, AppConversionIssueFactory.createCallbackIssue(...
                        AppConversionIssueFactory.Ids.UnsupportedCallbackTypeCustom, guideComponent, prop)];
                case GUIDECallbackType.EvalInBase
                    % Callbacks is of the form:
                    % 'actxproxy(gcbo)'
                    % 'closereq'
                    
                    issues = [issues, AppConversionIssueFactory.createCallbackIssue(...
                        AppConversionIssueFactory.Ids.UnsupportedCallbackTypeEvalInBase, guideComponent, prop)];
                case GUIDECallbackType.Automatic
                    % Callback is of the form:
                    % '%automatic' or '%default'
                    % For all Callbacks of the form '%default' (except for the
                    % default save tool), we generate custom App Designer
                    % callback code during the migration process.  The
                    % callback is migrated as <Tag>_ClickedCallback.
                    
                    if isa(guideComponent,'matlab.ui.container.toolbar.PushTool') || isa(guideComponent,'matlab.ui.container.toolbar.ToggleTool')
                        toolid = getappdata(guideComponent).toolid;
                        
                        if ~strcmp(toolid,'Standard.SaveFigure')
                            pvp = {prop, [guideComponent.Tag,'_ClickedCallback']};
                        end
                    end
                    
                case GUIDECallbackType.CellArray
                    % Do nothing
                    % It is not possible to set the callback to be
                    % a cell array in GUIDE's design environment.
                    % However, it can be done in the OpeningFcn and
                    % then accidentally serialized into the fig
                    % file.
            end
        end
        
        function [pvp, issues] = convertUnsupportedCallback(guideComponent, prop, callbackType, callbackName, callbackCode)
            
            import appmigration.internal.AppConversionIssueFactory;
            
            pvp = [];
            
            issues = AppConversionIssueFactory.createCallbackIssue(...
                AppConversionIssueFactory.Ids.UnsupportedCallbackWithNoWorkaround, guideComponent, prop);
        end
        
        function [pvp, issues] = convertCallbackForUnsupportedComponent(guideComponent, prop, callbackType, callbackName, callbackCode) %#ok<INUSD>
            
            % No conversion is performed for unsupported component
            % callbacks and so return empty pvp. Issue is reported at the
            % component level and so we don't need to report an issue for
            % the callback.
            pvp = [];
            issues = [];
        end
        
        function [pvp, issues] = convertCallbackWithProgrammaticWorkaround(guideComponent, prop, callbackType, callbackName, callbackCode)
            
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.GUIDECallbackType;
            
            if callbackType == GUIDECallbackType.Standard
                
                % Set the value empty because it will be set
                % programmatically but we still need the conversion to
                % recognize it as valid.
                pvp = {prop, ''};
                
                issues = AppConversionIssueFactory.createCallbackIssue(...
                    AppConversionIssueFactory.Ids.UnsupportedCallbackWithProgrammaticWorkaround, guideComponent, prop);
                
                % Set the issue value to be that of the callback name
                % instead of the GUIDE component's full value;
                issues.Value = callbackName;
            else
                [pvp, issues] = CommonCallbackConversionUtil.convertNonStandardCallback(...
                    guideComponent, prop, callbackType, callbackName, callbackCode);
            end
            
        end
        
        function [pvp, issues] = convertCreateFcn(guideComponent, prop, callbackType, callbackName, callbackCode) %#ok<INUSD>
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.GUIDECallbackType;
            
            pvp = [];
            % CreateFcn is not yet supported for components. However, a
            % potential workaround is to use the add the code to the
            % app's StartupFcn.
            issues = AppConversionIssueFactory.createCallbackIssue(...
                AppConversionIssueFactory.Ids.UnsupportedCallbackCreateFcn, guideComponent, prop);
        end
        
        function [pvp, issues] = convertDeleteFcn(guideComponent, prop, callbackType, callbackName, callbackCode)
            [pvp, issues] = appmigration.internal.CommonCallbackConversionUtil.convertCallbackWithProgrammaticWorkaround(...
                guideComponent, prop, callbackType, callbackName, callbackCode);
        end
        
        function [pvp, issues] = convertSizeChangedFcn(guideComponent, prop, callbackType, callbackName, callbackCode)
            
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.CommonCallbackConversionUtil;
            import appmigration.internal.GUIDECallbackType;
            
            if callbackType == GUIDECallbackType.Standard
                pvp = {prop, callbackName};
                
                % SizeChangeFcn is supported but App Designer only supports
                % pixel units. Need to warn the user to carefully consider the
                % callback code to make sure it will work with pixel units.
                issues = AppConversionIssueFactory.createCallbackIssue(...
                    AppConversionIssueFactory.Ids.PixelSupportOnlyForSizeChangedFcn, guideComponent, prop);
            else
                [pvp, issues] = CommonCallbackConversionUtil.convertNonStandardCallback(...
                    guideComponent, prop, callbackType, callbackName, callbackCode);
            end
        end
        
        function callbackCode = removeCommentsAndWhitespace(callbackCode)
            % Removes all comments and whitespace from callbackCode (nx1
            % cell array). This makes it easier for the callback converters
            % to verify if the code in the callback is the default code.
            
            % Remove comment lines
            callbackCode = callbackCode(cellfun(@(line)~startsWith(strtrim(line),'%'), callbackCode));
            % Trim whitespace
            callbackCode = strtrim(callbackCode);
            % Remove empty lines (do after trimming whitespace)
            callbackCode = callbackCode(~cellfun(@isempty, callbackCode));
            % Remove interior whitespace
            callbackCode = strrep(callbackCode, ' ', '');
        end
    end
end