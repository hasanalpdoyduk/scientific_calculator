classdef UnsupportedComponentConverter < appmigration.internal.ComponentConverter
    %UNSUPPORTEDCOMPONENTCONVERTER Converter for unsupported components
    
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods
        function [componentCreationFunction, issues] = getComponentCreationFunction(~, guideComponent)
            % GETCOMPONENTCREATIONFunction - Override superclass method.
            % Returns empty componentCreationFunction to signify it is not
            % supported and reports an issue
            
            import appmigration.internal.AppConversionIssueFactory;
            
            componentCreationFunction = [];
            
            % Don't report an issue because we this is a component like an
            % annotation pane or uicontainer that somehow got inserted into
            % the GUIDE app but isn't something the user is a aware of.
            issues = [];
        end
    end
end