classdef (Sealed, Abstract) AppConversionIssueFactory
    %APPCONVERSIONISSUEFACTORY Creates AppConversionIssues
    %   This class is responsible for creating an AppConversionIssue of the
    %   correct type.
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    properties (Constant)
        % Issue Ids used when reporting issues
        Ids = struct(...
            ...% Issues that are reported
            'FindComponentAPI'                              , 'FindComponentAPI',...
            'InvalidParentUicontrolRadioButton'             , 'InvalidParentUicontrolRadioButton',...
            'NarginAPI'                                     , 'NarginAPI',...
            'PixelSupportOnlyForSizeChangedFcn'             , 'PixelSupportOnlyForSizeChangedFcn',...
            'UnrecommendedUsingCallbackProgrammatically'    , 'UnrecommendedUsingCallbackProgrammatically',...
            'UnsupportedAPIUicontrol'                       , 'UnsupportedAPIUicontrol',...
            'UnsupportedAPIWithNoWorkaround'                , 'UnsupportedAPIWithNoWorkaround',...
            'UnsupportedCallbackWithNoWorkaround'           , 'UnsupportedCallbackWithNoWorkaround',...
            'UnsupportedCallbackCreateFcn'                  , 'UnsupportedCallbackCreateFcn',...
            'UnsupportedCallbackOutputFcn'                  , 'UnsupportedCallbackOutputFcn',...
            'UnsupportedComponentActivex'                   , 'UnsupportedComponentActivex',...
            'UnsupportedCallbackPredefinedSaveTool'         , 'UnsupportedCallbackPredefinedSaveTool',...
            'UnsupportedComponentWithNoWorkaround'          , 'UnsupportedComponentWithNoWorkaround',...
            'UnsupportedPropertyWithNoWorkaround'           , 'UnsupportedPropertyWithNoWorkaround',...
            'UnsupportedAPIActivex'                         , 'UnsupportedAPIActivex',...
            'UnsupportedAPIJavacomponent'                   , 'UnsupportedAPIJavacomponent',...
            'UnsupportedAPIClfReset'                        , 'UnsupportedAPIClfReset',...
            'UnsupportedAPIJavaframe'                       , 'UnsupportedAPIJavaframe',...
            'UnsupportedCallbackTypeAdditionalArgs'         , 'UnsupportedCallbackTypeAdditionalArgs',...
            'UnsupportedCallbackUicontrolInButtonGroup'     , 'UnsupportedCallbackUicontrolInButtonGroup',...
            ...% Issues that are handled by AppConversionIssueCodeGenerator
            'UnsupportedCallbackTypeCustom'                 , 'UnsupportedCallbackTypeCustom',...
            'UnsupportedCallbackTypeEvalInBase'             , 'UnsupportedCallbackTypeEvalInBase',...
            'UnsupportedCallbackWithProgrammaticWorkaround' , 'UnsupportedCallbackWithProgrammaticWorkaround',...
            'UnsupportedPropertyAxesColormap'               , 'UnsupportedPropertyAxesColormap',...
            'UnsupportedPropertyCData'                      , 'UnsupportedPropertyCData',...
            'UnsupportedPropertyFigurePointerShapeCData'    , 'UnsupportedPropertyFigurePointerShapeCData',...
            'UnsupportedPropertyFigurePointerShapeHotSpot'  , 'UnsupportedPropertyFigurePointerShapeHotSpot',...
            'UnsupportedPropertyListboxTop'                 , 'UnsupportedPropertyListboxTop',...
            'UnsupportedPropertyTableBackgroundColor'       , 'UnsupportedPropertyTableBackgroundColor',...
            'UnsupportedPropertyTableColumnFormat'          , 'UnsupportedPropertyTableColumnFormat',...
            'UnsupportedPropertyTableData'                  , 'UnsupportedPropertyTableData',...
            'UnsupportedPropertyTableRowName'               , 'UnsupportedPropertyTableRowName',...
            'UnsupportedPropertyUserData'                   , 'UnsupportedPropertyUserData',...
            ...% Tool Errors
            'ErrorComponentConverterApplyPropertyValuePairs','ErrorComponentConverterApplyPropertyValuePairs',...
            'ErrorComponentConverterConvert'                , 'ErrorComponentConverterConvert',...
            'ErrorComponentConverterConvertCallbacks'       , 'ErrorComponentConverterConvertCallbacks',...
            'ErrorComponentConverterConvertProperties'      , 'ErrorComponentConverterConvertProperties'...
            );
    end
    
    methods (Static)
        
        function issue = createAPIIssue(identifier, name, lines)
            % CREATEAPIISSUE Creates an AppConversionIssue of type
            % AppConversionType.API
            %
            %   Inputs:
            %       identifier - string uniquely identifiying the issue of
            %           the form: 'UnsupportedAPIWithNoWorkaround'
            %       name - the API function name
            %       lines - line number array of where the API was detected
            %           (e.g. [10 23 50]);
            %
            %   Outputs:
            %       issue - Concrete AppConversionIssue with type set to
            %           AppConversionIssueType.API and other properties
            %           configured for an API issue.
            
            import appmigration.internal.AppConversionIssue;
            import appmigration.internal.AppConversionIssueType;
            
            issueType = AppConversionIssueType.API;
            issueIdentifier = identifier;
            issueComponentTag = '';
            issueComponentType = '';
            issueName = name;
            issueValue = lines;
            
            issue = AppConversionIssue(....
                issueType,...
                issueIdentifier,...
                issueComponentTag,...
                issueComponentType,...
                issueName,...
                issueValue);
        end
        
        function issue = createComponentIssue(identifier, tag, type)
            % CREATECOMPONENTISSUE Creates an AppConversionIssue of type
            % AppConversionType.Component
            %
            %   Inputs:
            %       identifier - string uniquely identifiying the issue of
            %           the form: 'UnsupportedComponentActivex'
            %       tag - the component's tag value
            %       type - the component's type value
            %
            %   Outputs:
            %       issue - Concrete AppConversionIssue with type set to
            %           AppConversionIssueType.Component and other
            %           properties configured for a component issue.
            
            import appmigration.internal.AppConversionIssue;
            import appmigration.internal.AppConversionIssueType;
            
            issueType = AppConversionIssueType.Component;
            issueIdentifier = identifier;
            issueComponentTag = tag;
            issueComponentType = type;
            issueName = type;
            issueValue = '';
            
            issue = AppConversionIssue(....
                issueType,...
                issueIdentifier,...
                issueComponentTag,...
                issueComponentType,...
                issueName,...
                issueValue);
        end
        
        function issue = createCallbackIssue(identifier, guideComponent, propName)
            % CREATECALLBACKISSUE Creates an AppConversionIssue of type
            % AppConversionType.Callback
            %
            %   Inputs:
            %       identifier - string uniquely identifiying the issue of
            %           the form: 'UnsupportedCallbackButtonDownFcn'
            %       guideComponent - GUIDE component with the callback
            %           conversion issue
            %       propName - the callback property name being
            %           converted that had an issue
            %
            %   Outputs:
            %       issue - Concrete AppConversionIssue with type set to
            %           AppConversionIssueType.Callback and other
            %           properties configured for a callback issue
            
            import appmigration.internal.AppConversionIssue;
            import appmigration.internal.AppConversionIssueType;
            
            callbackValue = guideComponent.(propName);
            % Convert to a string if it is a function handle
            if ~ischar(callbackValue)
                callbackValue = func2str(callbackValue);
            end
            
            issueType = AppConversionIssueType.Callback;
            issueIdentifier = identifier;
            issueComponentTag = guideComponent.Tag;
            issueComponentType = guideComponent.Type;
            issueName = propName;
            issueValue = callbackValue;
            
            issue = AppConversionIssue(....
                issueType,...
                issueIdentifier,...
                issueComponentTag,...
                issueComponentType,...
                issueName,...
                issueValue);
        end
        
        function issue = createPropertyIssue(identifier, guideComponent, prop)
            % CREATEPROPERTYISSUE Creates an AppConversionIssue of type
            % AppConversionType.Property
            %
            %   Inputs:
            %       identifier - string uniquely identifiying the issue of
            %           the form: 'UnsupportedPropertyBusyAction'
            %       guideComponent - GUIDE component with the property
            %           conversion issue
            %       prop - the property being converted that had an issue
            %
            %   Outputs:
            %       issue - Concrete AppConversionIssue with type set to
            %           AppConversionIssueType.Property and other
            %           properties configured for a property issue
            
            import appmigration.internal.AppConversionIssue;
            import appmigration.internal.AppConversionIssueType;
            
            issueType = AppConversionIssueType.Property;
            issueIdentifier = identifier;
            issueComponentTag = guideComponent.Tag;
            issueComponentType = guideComponent.Type;
            issueName = prop;
            issueValue = guideComponent.(prop);
            
            issue = AppConversionIssue(....
                issueType,...
                issueIdentifier,...
                issueComponentTag,...
                issueComponentType,...
                issueName,...
                issueValue);
        end
        
        function issue = createErrorIssue(identifier, exception)
            % CREATEERRORISSUE Creates an AppConversionIssue of type
            % AppConversionType.Error
            %
            %   Inputs:
            %       identifier - string uniquely identifiying the issue
            %       exception - MException object
            %
            %   Outputs:
            %       issue - Concrete AppConversionIssue with type set to
            %           AppConversionIssueType.Error and other
            %           properties configured for a error issue
            
            import appmigration.internal.AppConversionIssue;
            import appmigration.internal.AppConversionIssueType;
            
            issueType = AppConversionIssueType.Error;
            issueIdentifier = identifier;
            issueComponentTag = '';
            issueComponentType = '';
            issueName = '';
            issueValue = exception;
            
            issue = AppConversionIssue(....
                issueType,...
                issueIdentifier,...
                issueComponentTag,...
                issueComponentType,...
                issueName,...
                issueValue);
        end
    end
end