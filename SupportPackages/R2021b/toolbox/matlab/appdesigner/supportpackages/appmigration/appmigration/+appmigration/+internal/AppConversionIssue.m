classdef AppConversionIssue < handle
    %APPCONVERSIONISSUE represents an issue discovered during the
    %app migration.
    
    %   Copyright 2017-2018 The MathWorks, Inc.
    
    properties
        Type
        Identifier
        ComponentTag
        ComponentType
        Name
        Value
    end
    
    methods
        function obj = AppConversionIssue(type, identifier, componentTag, componentType, name, value)
            %APPCONVERSIONISSUE Creates a conversion issue
            %   Inputs:
            %       type - AppConversionIssueTypeEnum (Component | Property
            %           | Callback | API | Error)
            %       identifier - string uniquely identifiying the issue of
            %           the form: UnsupportedPropertyCData
            %       componentTag - GUIDE component tag (empty '' for API &
            %           Error type issues)
            %       componentType - GUIDE component type (empty '' for API &
            %           Error type issues)
            %       name - Name associated with the issue. Different for
            %           each type:
            %               Component - same as componentType
            %               Callback - the callback's property name (e.g.
            %                   'SelectionChangedFcn')
            %               Property - the property name (e.g.
            %                   'BusyAction')
            %               API - the name of the API function (e.g.
            %                   'ginput')
            %               Error - empty str ('')
            %       value - Value associated with the issue
            %               Component - empty str ('')
            %               Callback - string of the callback's property
            %                   value
            %               Property - the property's value
            %               API - line number array (e.g. [10 23 50]);
            %               Error - MException object
            
            obj.Type = type;
            obj.Identifier = identifier;
            obj.ComponentTag = componentTag;
            obj.ComponentType = componentType;
            obj.Name = name;
            obj.Value = value;
        end
    end
end