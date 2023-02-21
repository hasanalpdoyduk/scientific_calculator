classdef (Sealed, Abstract) ComponentConverterFactory
    %COMPONENTCONVERTERFACTORY Creates component converters
    %   This class is responsible for creating a ComponentConverter based
    %   on the GUIDE component's type. There is a converter for each
    %   component that GUIDE supports.
    
    %   Copyright 2017-2019 The MathWorks, Inc.

    methods (Static)
        function converter = createComponentConverter(guideComponent)
            % CREATECOMPONENTCONVERTER Creates the ComponentConverter based
            %   on the GUIDE components type.
            %
            %   Inputs:
            %       guideComponent - guide component to convert
            %
            %   Outputs:
            %       converter - Concrete ComponentConverter
            
            import appmigration.internal.*
            
            switch guideComponent.Type
                case 'axes'
                    converter = AxesConverter;
                case 'figure'
                    converter = FigureConverter;
                case 'uibuttongroup'
                    converter = UibuttongroupConverter;
                case 'uicontextmenu'
                    converter = UicontextmenuConverter;
                case 'uicontrol'
                    % An actxcontrol is hacked on top of a uicontrol text
                    % object. We can identify the actxcontrol by verifying
                    % that a 'Control' appdata object exists on the
                    % uicontrol.
                    activexControl = getappdata(guideComponent, 'Control');
                    
                    if isempty(activexControl)
                        % Real uicontrol
                        converter = UicontrolConverter;
                    else
                        % Activex component
                        converter = ActivexConverter;
                    end
                case 'uimenu'
                    converter = UimenuConverter;
                case 'uipanel'
                    converter = UipanelConverter;
                case 'uipushtool'
                    converter = UipushtoolConverter;
                case 'uitable'
                    converter = UitableConverter;
                case 'uitoggletool'
                    converter = UitoggletoolConverter;
                case 'uitoolbar'
                    converter = UitoolbarConverter;
                otherwise
                    converter = UnsupportedComponentConverter;
            end
        end 
    end
end