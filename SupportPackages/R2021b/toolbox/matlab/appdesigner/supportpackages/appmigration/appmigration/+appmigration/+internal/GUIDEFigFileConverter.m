classdef GUIDEFigFileConverter < handle
    %GUIDEFIGFILECONVERTER Migrates a GUIDE app's FIG-file to a uifigure.
    %   This class is responsible for converting a GUIDE app's figure and
    %   children components into equivalent App Designer components and
    %   configure their properties.
    
    %   Copyright 2017 - 2020 The MathWorks, Inc.
    
    properties
        FigFullFileName
        CodeFileFunctions
    end
    
    properties (Access = private)
        % Struct of component code names based on GUIDE tag
        CodeNames
        GUIDEFigure;
        StartingDirectory
    end
    
    methods
        function obj = GUIDEFigFileConverter(figFullFileName, codeFileFunctions)
            %GUIDEFIGFILECONVERTER Construct an instance of this class
            %
            %   Inputs:
            %       figFullFileName - full file name to GUIDE fig-file
            %       codeFileFunctions - Struct output of call to
            %           GUIDECodeParser.parseFunctions().
            
            obj.FigFullFileName = figFullFileName;
            obj.CodeFileFunctions = codeFileFunctions;
        end
        
        function [uifig, callbacks, issues, singletonMode, preDefinedToolCallbackMigrationInfo] = convert(obj)
            % CONVERT - Traverses the GUIDE app's figure and converts all
            %   of the app's components into compatible App Designer
            %   components. It also configures each component's properties
            %   to match as closely as possible the GUIDE component's
            %   properties.
            %
            %   Outputs:
            %       uifig - app figure and children converted to a uifigure
            %       callbackSupport - struct with the following fields:
            %           SupportedCallbacks - 1xn cell array of callback
            %               names that should be migrated.
            %           UnsupportedCallbacks - 1xn cell array of callback
            %               names that should not be migrated.
            %       issues - 1xn array of AppConversionIssues that were
            %           generated during the conversion.
            %       singletonMode - char indicating singleton status.  
            %            '' if the app is not singleton.
            %            'FOCUS' if the app is singleton
            %       preDefinedToolCallbackMigrationInfo - struct containing fields toolInfo,
            %       and figureInfo.  toolInfo is a struct that contains info
            %       on default tools: toolId and Tag.  figureInfo is a
            %       struct that contains info on the figure: Tag and
            %       WindowStyle.
            
            figFilePath = fileparts(obj.FigFullFileName);
            
            % Create a cleanup object that will delete the GUIDE figure
            % that gets loaded and restore users current directory when
            % this function goes out of scope.
            cleanup = onCleanup(@obj.cleanupFigureAndDirectory);
            
            % CD to location of GUIDE fig file so that loading doesn't
            % drool load errors to command window
            obj.StartingDirectory = pwd;
            cd(figFilePath);
            
            % Load GUIDE fig file
            obj.GUIDEFigure = hgload(obj.FigFullFileName, struct('Visible','off'));
            
            % check if fig file created using GUIDE
            % before recursively converting components
            options = getappdata(obj.GUIDEFigure,'GUIDEOptions');
            isGUIDEApp = isempty(options);
            
            if isGUIDEApp
                error(message('appmigration:appmigration:NotGuideCreatedApp'));
            end
            
            % Singleton status in GUIDE is 0 or 1.  Singleton status in App
            % Designer is '' or 'FOCUS'.  Make the conversion here.
            if options.singleton
                singletonMode = 'FOCUS';
            else
                singletonMode = '';
            end
            
            % Remove standard figure MenuBar and ToolBar if any. These are
            % not yet supported by uifigure.
            obj.removeFigureMenuBar(obj.GUIDEFigure);
            obj.removeFigureToolBar(obj.GUIDEFigure);
            obj.removeAnnotationPane(obj.GUIDEFigure);
            
            % Suppress slider fixed height warning before converting
            % components
            prevWarningState = warning('off', 'MATLAB:ui:Slider:fixedHeight');
            warningCleanup = onCleanup(@()warning(prevWarningState));
            
            % Move context menus to the bottom of the figure children list
            % so that they get migrated first because other components
            % might have a context menu assigned.
            obj.reorderChildrenByType(obj.GUIDEFigure, 'uicontextmenu', 'bottom');
            
            % Convert all of the components
            [uifig, callbacks, issues] = recursivelyConvertComponents(...
                obj, obj.GUIDEFigure, groot);
            
            % Make sure the callbacks are uniquely represented
            callbacks.Supported = unique(callbacks.Supported,'stable');
            callbacks.Unsupported = unique(callbacks.Unsupported,'stable');
            
            % Convert context menu for the figure as it doesn't get
            % converted in recursivelyConvertComponents because the figure
            % is converted before all its children, including context menus
            pvp = appmigration.internal.CommonPropertyConversionUtil.convertContextMenu(obj.GUIDEFigure, 'ContextMenu');
            if ~isempty(pvp)
                set(uifig, pvp{:});
            end
            
            % Move context menus to the top of the figure children list so
            % that they appear at the bottom of the App Designer figure
            % hierarch
            obj.reorderChildrenByType(uifig, 'uicontextmenu', 'top');
            
            % If there are any menus present in the fig-file, we want to
            % make sure they are arranged to the bottom of the fig children list
            % in order to make sure they are listed at top of AppDesigner figure hierarchy
            obj.reorderChildrenByType(uifig, 'uimenu', 'bottom');

            % Obtain information from the GUIDE Figure that is needed to
            % generate code for the predefined tools with default
            % callbacks.
            preDefinedToolCallbackMigrationInfo = obj.getInfoForDefaultToolCallbackMigration();
        end
        
        function preDefinedToolCallbackMigrationInfo = getInfoForDefaultToolCallbackMigration(obj)
            % GETINFOFORDEFAULTTOOLCALLBACKS - Get the information needed
            % to generate code for the predefined tools with default
            % callbacks.  These tools have ClickedCallbacks equal to
            % '%default'.  The information is then used in
            % PreDefinedToolDefaultCallbackCodeGenerator to generate the
            % code.
            
            preDefinedToolCallbackMigrationInfo = struct(...
                'toolInfo', struct('toolId', {}, 'Tag',{}),...
                'figureInfo', struct('WindowStyle', obj.GUIDEFigure.WindowStyle, 'Tag', obj.GUIDEFigure.Tag));
            
            % Find tools with default callbacks.
            toolList = findall(obj.GUIDEFigure, {'Type', 'uipushtool', '-OR', 'Type', 'uitoggletool'}, '-AND','ClickedCallback', '%default');
            
            % For each tool, if the tool is not a save tool (default
            % callback is not supported for the save tool), record
            % information about the toolid and Tag.
            for i = 1:length(toolList)
                
                tool = toolList(i);
                toolid = getappdata(tool).toolid;
                
                if ~isempty(toolid)&& ~strcmp(toolid,'Standard.SaveFigure')
                    preDefinedToolCallbackMigrationInfo.toolInfo(end+1).toolId = toolid;
                    preDefinedToolCallbackMigrationInfo.toolInfo(end).Tag = tool.Tag;
                end
            end
        end
        
        function codeName = getUniqueCodeName(obj, guideComponent)
            % Returns a unique code name based on the tag of the GUIDE
            % component
            
            tag = guideComponent.Tag;
            
            % Use the tag value as the code name. Removing all characters
            % in tag that are not alphabetic, numeric, or underscore.
            codeName =  regexprep(tag, '\W', '');
            
            % Remove all non-ASCII characters
            nonASCII = arrayfun(@(char)double(char) >= 128, codeName);
            codeName(nonASCII) = [];
            
            % After stripping out invalid characters, if the codeName is
            % empty, set the code name to be the same as the type.
            if isempty(codeName)
                codeName = [guideComponent.Type, '1'];
            end
            
            % After stripping out invalid characters, if the codeName
            % starts with a number, prefix the code name with the
            % components type.
            if regexp(codeName(1), '\d')
                codeName = [guideComponent.Type codeName];
            end
            
            % It is possible to have duplicate tag names or a function name
            % that is the same as the tag. Create a unique code name if the
            % tag has already been used.
            codeNameWithoutCount = codeName;
            counter = 1;
            while isfield(obj.CodeNames, codeName) || ...
                    isfield(obj.CodeFileFunctions, codeName)
                codeName = sprintf('%s_%d', codeNameWithoutCount, counter);
                counter = counter + 1;
            end
            
            % Cache the code name in a struct
            obj.CodeNames.(codeName) = guideComponent.Type;
        end
    end
    
    methods (Access=private)
        function [component, callbacks, issues] = recursivelyConvertComponents(obj, guideComponent, parent)
            import appmigration.internal.ComponentConverterFactory;
            
            % Create the converter
            converter = ComponentConverterFactory.createComponentConverter(guideComponent);
            
            % Get a unique code name
            codeName = obj.getUniqueCodeName(guideComponent);
            
            % Update the tag to be the same as the unique code name.
            % Typically the tag name is the same as the unique code name
            % but need to ensure that the tag is unique for the instances
            % that we generate code using the component's tag.
            guideComponent.Tag = codeName;
            
            % Convert the component and collect any conversion issues
            [component, callbacks, issues] = converter.convert(guideComponent, parent, obj.CodeFileFunctions, codeName);
            
            % Because contextmenus are objects and not primitive data
            % types, we can't simply get the GUIDE components context menu
            % and convert it to a new context menu in the component
            % converters. Instead, all of the context menus are converted
            % first here and a dynamic property is added with the new
            % context menu to the original GUIDE context menu so that we
            % can find it aassign it to the PVP in the component converter.
            if ~isempty(component) && strcmp(component.Type, 'uicontextmenu')
                addprop(guideComponent, 'MigratedContextMenu');
                guideComponent.MigratedContextMenu = component;
            end
            
            % Recursively convert children components (except for axes)
            children = allchild(guideComponent);
            if ~isempty(children) && ~strcmp(guideComponent.Type, 'axes')
                if numel(children) > 0
                    % Loop over children in reverse order so that
                    % components are added in same order as GUIDE
                    for index = numel(children):-1:1
                        [~, childCallbacks, childIssues] = recursivelyConvertComponents(...
                            obj, children(index), component);
                        
                        callbacks.Supported = [callbacks.Supported childCallbacks.Supported];
                        callbacks.Unsupported = [callbacks.Unsupported childCallbacks.Unsupported];
                        issues = [issues childIssues]; %#ok<AGROW>
                    end
                end
            end
        end
        
        function cleanupFigureAndDirectory(obj)
            
            % First delete the GUIDE figure and then cd back to the
            % starting directory. Must do it in that order to avoid
            % drooling error messages in command window if the figure has
            % components with DeleteFcns.
            
            if ~isempty(obj.GUIDEFigure)
                delete(obj.GUIDEFigure);
            end
            
            if ~isempty(obj.StartingDirectory)
                cd(obj.StartingDirectory);
            end
        end
    end
    
    methods (Static)
        function removeFigureMenuBar(fig)
            % Removes the standard menubar from the figure if the GUIDE
            % author has configured them 'MenuBar' property to be 'figure'.
            % The standard menubar is not yet supported in uifigure.
            
            if isequal(fig.MenuBar, 'figure')
                
                % Find all top level uimenu with handle visibility off. This
                % is the first indicator that it is a standard menu and not
                menus = findall(fig, 'type', 'uimenu', '-AND', 'HandleVisibility', 'off', '-AND', 'Parent', fig);
                
                % Find all the menus that have a tag begining with
                % 'figMenu'. This means it is the standard figure menu and
                % not a menu created by the GUIDE author.
                idx = arrayfun(@(a)startsWith(a.Tag, 'figMenu'), menus);
                
                % Delete the menus
                delete(menus(idx));
            end
        end
        
        function removeFigureToolBar(fig)
            % Removes the standard toolbar from the figure if the GUIDE
            % author has configured them 'ToolBar' property to be 'figure'.
            % The standard toolbar is not yet supported in uifigure.
            
            % The figure has a standard toolbar if the ToolBar property is
            % set to 'figure' OR it is set to 'auto' and MenuBar is set to
            % 'figure'
            if isequal(fig.ToolBar, 'figure') || ...
                    (isequal(fig.ToolBar, 'auto') && isequal(fig.MenuBar, 'figure'))
                
                % Remove the standard toolbar
                toolbar = findall(fig, 'type', 'uitoolbar', '-AND', 'Tag', 'FigureToolBar');
                delete(toolbar);
            end
        end
        
        function removeAnnotationPane(fig)
            % Removes any annotation panes from the figure hierachy
            
            ap = findall(fig, 'type', 'annotationpane');
            delete(ap);
        end
        
        function reorderChildrenByType(parent, type, position)
            % Reorders the children of the specificed TYPE in the PARENT to
            % the specified POSITION. POSITION can be 'top' or 'bottom'.
            % Components that can't be reordered such as axes will not be
            % moved.
            
            allChildren = allchild(parent);
            moveableChildren = allChildren;
            
            % Axes and AnnotationPanes can not be moved relative to other
            % components and so filter them out of the list of moveable
            % children.
            moveableChildren(arrayfun(@(c)isa(c, 'matlab.graphics.axis.Axes'), moveableChildren)) = [];
            moveableChildren(arrayfun(@(c)isa(c, 'matlab.graphics.shape.internal.AnnotationPane'), moveableChildren)) = [];
            
            childrenToMove = ishghandle(moveableChildren, type);
            
            if any(childrenToMove)
                
                % Reorder the moveable children
                switch position
                    case 'top'
                        moveableChildren = [moveableChildren(childrenToMove); moveableChildren(~childrenToMove)];
                    case 'bottom'
                        moveableChildren = [moveableChildren(~childrenToMove); moveableChildren(childrenToMove)];
                end
                
                % Reform the complete children list by only moving the
                % moveable children
                allChildren(ismember(allChildren, moveableChildren)) = moveableChildren;
                parent.Children = allChildren;
            end
        end
    end
end