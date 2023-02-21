classdef ActivexConverter < appmigration.internal.ComponentConverter
    %ACTIVEXCONVERTER Converter for an ActiveX control component
    
    %   Copyright 2017-2018 The MathWorks, Inc.
    
    methods
        function [newComponent, callbackSupport, issues] = convert(~, guideComponent, ~, ~, ~)
            % Override super convert method as activex controls are unique
            % and don't follow the general format of the other components.
            
            import appmigration.internal.AppConversionIssueFactory;
            
            % Activex control objects build on top of a uicontrol text
            % object. The actual control object is stored as as appdata
            % under 'Control' on the uicontrol object.
            
            % Get the control object 
            control = getappdata(guideComponent, 'Control');
            
            tag = guideComponent.Tag;

            % Generate list of callback names and list them as unsupported
            % so that the callback code doesn't get migrated.
            callbacks = control.Callbacks;
            numCallbacks = length(callbacks);
            unsupportedCallbacks = cell(0, numCallbacks);
            for i=1:length(callbacks)
                % GUIDE expects the callback name to be
                % <componentTag>_<callbackName>
                unsupportedCallbacks{i} = [tag, '_', callbacks{i}];
            end
            
            % Add the callback names to the list of unsupported callbacks
            callbackSupport = struct(...
                'Supported', {{}},...
                'Unsupported', {unsupportedCallbacks});
            
            % Activex is unsupported so return empty for newComponent and
            % report issue
            newComponent = [];
            
            issues = AppConversionIssueFactory.createComponentIssue(...
                AppConversionIssueFactory.Ids.UnsupportedComponentActivex, guideComponent.Tag, 'actxcontrol');
        end
    end
end