classdef (Abstract) ComponentConverter < handle
    %COMPONENTCONVERTER Abstract base class for all component converters.
    %   This class is responsible for providing the template for performing
    %   a component conversion. It specifies a concrete convert method
    %   which follows the template design pattern and uses information
    %   specified by subclasses to perform the correct conversion for each
    %   component type. It also provides common, static methods that
    %   subclasses may uses.
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [newComponent, callbackSupport, issues] = convert(obj, guideComponent, newParent, codeFileFunctions, codeName)
            % CONVERT Employs the template design pattern to perform the
            %   conversion for the GUIDE component. It outputs a component
            %   that is compatible with App Designer.
            %   
            %   Inputs:
            %       guideComponent - GUIDE component to be converted
            %       newParent - parent for the new component. Specify [] if
            %           no parent.
            %       codeFileFunctions - Struct output of call to
            %           GUIDECodeParser.parseFunctions(). Needed to convert
            %           the component's callbacks and identify which
            %           callbacks are supported.
            %       codeName - code name to assign to the component
            %
            %   Outputs:
            %       component - the converted component
            %       callbackSupport - struct with the following fields:
            %           SupportedCallbacks - 1xn cell array of callback
            %               names that should be migrated.
            %           UnsupportedCallbacks - 1xn cell array of callback
            %               names that should not be migrated.
            %       issues - 1xn array of AppConversionIssues that were
            %           generated during the conversion.
            
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.AppConversionIssueType;
            
            newComponent = [];
            callbackSupport = struct('Supported', {{}}, 'Unsupported', {{}});
            issues = [];
                        
            try
                % Get the creation function and pvp pairs for creating the
                % new component
                [componentCreationFunction, creationIssues] = obj.getComponentCreationFunction(guideComponent);
                componentCreationPVP = obj.getComponentCreationPropertyValuePairs(guideComponent);
                
                % Need to attempt to convert callbacks for supported and
                % unsupported components so that we can build a list of
                % supported and unsupported callbacks exist in the code.
                % This list is needed to identify which functions in the
                % code are helper functions (not a supported or unsupported
                % callback).
                [callbackPVP, callbackSupport, callbackIssues] = convertCallbacks(...
                    obj, guideComponent, codeFileFunctions);
                
                % Combine issues
                issues = [issues creationIssues callbackIssues];
                
                if isempty(componentCreationFunction) || isempty(newParent)
                    % Component or its parent is unsupported. Don't proceed
                    % with component creation and property sets.
                    return;
                end
                                
                % Add parent property. It needs to be added to the end of
                % the component creation pvp to handle scenarios where the
                % first input is a style like 'state' for a uibutton
                componentCreationPVP = [componentCreationPVP {'Parent', newParent}];
                
                % Create the component using the component creation
                % function
                newComponent = componentCreationFunction(componentCreationPVP{:});
                
                obj.setSerializable(newComponent);
                obj.setCodeName(newComponent, codeName);
                               
                % Execute the property conversions functions specified by
                % concrete classes. This will result in the property value
                % pairs (pvp) to set on the new component.
                [propertyPVP, propertyIssues] = convertProperties(obj, guideComponent);
                
                % Combine all pvp
                pvp = [callbackPVP, propertyPVP];
                
                % Perform setting the PVP on the new component
                propertySetIssues = applyPropertyValuePairs(obj, newComponent, pvp);
                
                % Combine all issues
                issues = [issues, propertyIssues, propertySetIssues];
                
            catch exception
                % Issue occured with the conversion tool.
                issue = AppConversionIssueFactory.createErrorIssue(...
                    AppConversionIssueFactory.Ids.ErrorComponentConverterConvert, exception);
                
                issues = [issues issue];
            end
        end

        function [componentCreationFunction, issues] = getComponentCreationFunction(obj, guideComponent) %#ok<INUSD>
            % GETCOMPONENTCREATIONFUNCTION Returns a handle to a function
            %   to create the new component that the GUIDE component is
            %   being converted to. Subclasses for App Designer supported
            %   components should override this; otherwise, default value
            %   is [].
            %
            %   Inputs:
            %       guideComponent - the GUIDE component to be converted.
            %
            %   Outputs:
            %       componentCreationFunction - name of function to use to 
            %           create the new App Designer component.
            %       issues - 1xn AppConversionIssues array for the issues
            %           discovered during the conversion. It can be [] if
            %           there were no issues.
            
            componentCreationFunction = [];
            issues = [];
        end
        
        function propertyValuePairs = getComponentCreationPropertyValuePairs(obj, guideComponent) %#ok<INUSD>
            % GETCOMPONENTCREATIONPROPERTYVALUEPAIRS Returns a 1xn cell
            %   array of property value pairs that should be used when
            %   instantiated the component class returned from
            %   getComponentClassNameToCreate. Subclass for App Designer
            %   supported component converters should override this;
            %   otherwise, the default value is {};
            %
            %   Inputs:
            %       guideComponent - the GUIDE component to be converted.
            %
            %   Outputs:
            %       propertyValuePairs - property value pairs to be used
            %           when creating the new component.
            
            propertyValuePairs = {};
        end
        
        function conversionFuncs = getCallbackConversionFunctions(obj, guideComponent) %#ok<INUSD>
            % GETCALLBACKCONVERSIONFUNCTIONS Returns a 1xn cell array of
            %   cell arrays containing the callback property name of the
            %   GUIDE component to be converted and a handle to a function
            %   that will perform the conversion for the specified callback.
            %
            %   All subclasses need to override this. Unsupported component
            %   converters also need to override this to provide details
            %   about what callbacks the component might have specified in
            %   code. This is needed to identify which GUIDE code functions
            %   not to migrate over when converting the code. Unsupported
            %   component converters can use a function handle to
            %   ComponentConverter.convertUnsupportedCallback
            %
            %   Inputs:
            %       guideComponent - the GUIDE component to be converted.
            %
            %   Outputs:
            %       conversionFuncs - a 1xn cell array. For example:
            %           { {'ButtonDownFcn', @convertButtonDownFcn},...
            %             {'CreateFcn'    , @convertCreateFcn},...
            %             {'DeleteFcn'    , @convertDeleteFcn}...
            %           }
            %
            %       Each conversion function must honor the following
            %       signature:
            %
            % [pvp, issues] = conversionFuncName(guideComponent, propName, callbackType, callbackName, callbackCode)
            %
            %   Where:
            %
            %       pvp - 1xn property value pair cell array with the
            %           converted callback property name(s) and value(s).
            %           It can be {} if no conversion was performed.
            %       issues - 1xn AppConversionIssues array for the issues
            %           discovered during the conversion. It can be [] if
            %           there were no issues.
            %       guideComponent - GUIDE component being converted
            %       propName - the property name of the GUIDE component
            %           callback being converted.
            %       callbackType - a GUIDECallbackType - the type of
            %           GUIDE callback it is. 
            %       callbackName - the actual callback name extracted from
            %           the callback property string.
            %       callbackCode - nx1 cell array with each cell element
            %           being a line of code contained in the callback.
            %
            %   Note:
            %       The conversion functions will be executed in the order
            %       specified by the conversionFuncs cell array.
            
            conversionFuncs = {};
        end
        
        function conversionFuncs = getPropertyConversionFunctions(~)
            % GETPROPERTYCONVERSIONFUNCTIONS Returns a 1xn cell array of
            %   cell arrays containing the property name of the GUIDE
            %   component to be converted and a handle to a function that
            %   will perform the conversion for the specified property.
            %   Subclasses for App Designer supported components should 
            %   override this. Unsupported component properties will
            %   not be converted and so this method will not be used.
            %
            %   Outputs:
            %       conversionFuncs - a 1xn cell array. For example:
            %           { {'Prop1', @convertProp1},...
            %             {'Prop2', @convertProp2},...
            %             {'PropN', @convertPropN}...
            %           }
            %
            %       Each conversion function must honor the following
            %       signature:
            %
            % [pvp, issues] = conversionFuncName(guideComponent, propName)
            %
            %   Where:
            %
            %       pvp - 1xn property value pair cell array with the
            %           converted property name(s) and value(s). It can
            %           be {} if no conversion was performed.
            %       issues - 1xn AppConversionIssues array for the issues
            %           discovered during the conversion. It can be []
            %           if there were no issues.
            %       guideComponent - GUIDE component being converted
            %       propName - the property name of the GUIDE component
            %           being converted.
            %
            %   Note:
            %       The conversion functions will be executed in the order
            %       specified by the conversionFuncs cell array.
            
            conversionFuncs = {};
        end
    end
    
    methods (Access = protected)
        
        function [pvp, callbackSupport, issues] = convertCallbacks(obj, guideComponent, codeFileFunctions)
            import appmigration.internal.GUIDECallbackType;
            import appmigration.internal.GUIDECodeParser;
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.AppConversionIssueType;
            
            pvp = [];
            callbackSupport = struct('Supported', {{}}, 'Unsupported', {{}});
            issues = [];
            
            callbackConversionFunctions = obj.getCallbackConversionFunctions(guideComponent);
            
            % Loop over each callback and perform the conversion
            for i=1:length(callbackConversionFunctions)
                try
                    conversionInfo = callbackConversionFunctions{i};
                    propToConvert = conversionInfo{1};
                    conversionFunction = conversionInfo{2};
                    
                    callbackValue = guideComponent.(propToConvert);
                    if isempty(callbackValue)
                        % There is no callback so do nothing
                        continue;
                    end
                    
                    % Parse the callback value to determine its type and
                    % name
                    callbackInfo = GUIDECodeParser.parseCallbackValue(callbackValue);
                    
                    callbackType = callbackInfo.Type;
                    callbackName = '';
                    callbackCode = '';
                    
                    % If the callback is the standard or standard with
                    % additional input arguments type of GUIDE callback, we
                    % need to extract the callback name and code for the
                    % conversion. We don't execute the conversion function
                    % if the code is empty or only contains comments.
                    if callbackType == GUIDECallbackType.Standard || ...
                       callbackType == GUIDECallbackType.StandardWithAdditionalArgs
                        
                        callbackName = strrep(callbackInfo.FunctionArgs{1},'''','');
                        
                        if isfield(codeFileFunctions, callbackName)
                            % The callback exists in the GUIDE code file.
                            
                            % Get the callback code
                            callbackCode = codeFileFunctions.(callbackName).Code;
                            
                            % Strip out the comments to see if the code
                            % only contains comments
                            noCommentLines = cellfun(@(line)~startsWith(strtrim(line),'%'), callbackCode);
                            callbackCodeNoComments = callbackCode(noCommentLines);
                            
                            if isempty(callbackCodeNoComments)
                                % Callback code only contains comments
                                % so don't convert it
                                callbackSupport.Unsupported{end+1} = callbackName;
                                continue;
                            end
                        else
                            % Do nothing as there is no callback code
                            % associated with the callback;
                            continue;
                        end
                        
                    end
                    
                    % Execute conversion function
                    [compPVP, compIssues] = conversionFunction(guideComponent, propToConvert, callbackType, callbackName, callbackCode);
                    
                    if ~isempty(callbackName)
                        if isempty(compPVP)
                            % No conversion was performed and so add the
                            % callback names to the unsupported list so
                            % that we don't copy over its code.
                            callbackSupport.Unsupported{end+1} = callbackName;
                        else
                            % Conversion was performed. Add the callback
                            % name to the supported list so that we copy
                            % over the callback code.
                            callbackSupport.Supported{end+1} = callbackName;
                        end
                    end
                    
                    pvp = [pvp compPVP]; %#ok<AGROW>
                    issues = [issues compIssues]; %#ok<AGROW>
                    
                catch exception
                    % Issue occured with the conversion tool.
                    issue = AppConversionIssueFactory.createErrorIssue(...
                        AppConversionIssueFactory.Ids.ErrorComponentConverterConvertCallbacks, exception);
                    
                    issues = [issues issue]; %#ok<AGROW>
                end
            end
        end
        
        function [pvp, issues] = convertProperties(obj, guideComponent)
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.AppConversionIssueType;
            
            % Need to set the guide component to pixel units before
            % converting the properties as all of the conversions assume
            % pixel units.
            obj.forceUnitsToPixels(guideComponent);
                        
            pvp = [];
            issues = [];
            propConversionFunctions = obj.getPropertyConversionFunctions();
            
            % Loop over each property and perform the conversion
            for i=1:length(propConversionFunctions)
                conversionInfo = propConversionFunctions{i};
                propToConvert = conversionInfo{1};
                conversionFunction = conversionInfo{2};
                
                try
                    [compPvp, compIssues] = conversionFunction(guideComponent, propToConvert);
                catch exception
                    compPvp = [];
                    
                    compIssues = AppConversionIssueFactory.createErrorIssue(...
                        AppConversionIssueFactory.Ids.ErrorComponentConverterConvertProperties, exception);
                end
                
                pvp = [pvp compPvp]; %#ok<AGROW>
                issues = [issues compIssues];   %#ok<AGROW>
            end
        end
        
        function issues = applyPropertyValuePairs(~, newComponent, pvp)
            import appmigration.internal.AppConversionIssueFactory;
            import appmigration.internal.AppConversionIssueType;
            
            issues = [];
            try
                % For performance benefits, try setting all of
                % the property value pairs at once.
                set(newComponent, pvp{:});
            catch
                % If the batch set fails, do individual sets to
                % minimize the amount of properties not configured.
                for i=1:2:length(pvp)
                    individualPVP = pvp(i:i+1);
                    try
                        set(newComponent, individualPVP{:});
                    catch exception
                        
                        issue = AppConversionIssueFactory.createErrorIssue(...
                                AppConversionIssueFactory.Ids.ErrorComponentConverterApplyPropertyValuePairs,...
                                exception);
                        
                        issues = [issues issue]; %#ok<AGROW>
                    end
                end
            end
        end
    end
    
    methods (Static, Access = private)
                
        function setSerializable(component)
            
            % In order for the component to be serialized properly
            % it must have a 'Serializable' property set to true.  This
            % is really only needed if the component is parented to an
            % hg component but settng it regardless of the initial parent
            % in case this component is ever  reparented to an hg container
            if ~isprop(component, 'Serializable')
                addprop(component, 'Serializable');
                component.Serializable = 'on';
            end
        end
        
        function setCodeName(component, codeName)
            
            if ~isprop(component, 'DesignTimeProperties')
                addprop(component, 'DesignTimeProperties');
                
                component.DesignTimeProperties = struct(...
                    'CodeName', codeName,...
                    'GroupId', '',...
                    'ComponentCode', {{}});
            end
            component.DesignTimeProperties.CodeName = codeName;
        end
        
        function forceUnitsToPixels(guideComponent)
            if isprop(guideComponent, 'Units')
                guideComponent.Units = 'pixels';
            end
            
            if isprop(guideComponent, 'FontUnits')
                guideComponent.FontUnits = 'pixels';
            end
        end
    end
    
end

