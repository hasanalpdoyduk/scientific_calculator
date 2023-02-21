classdef (Sealed, Abstract) CommonPropertyConversionUtil
    %COMMONPROPERTYCONVERSIONUTIL Common property conversion functions
    %   Utility of common property conversion functions that are shared
    %   amongst the various ComponentConverters.
    %
    %   Copyright 2017-2020 The MathWorks, Inc.
    
    methods (Static)
        
        function [pvp, issues] = convertOneToOneProperty(guideComponent, prop)
            issues = [];
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertOneToOneProperty(guideComponent, prop);
        end
        
        function [pvp, issues] = convertOneToOnePropertyIfNotFactoryValue(guideComponent, prop)
            % Performs a one to one property conversion if the value of
            % that property does not equal the factory setting for it. For
            % example, if a uicontrol's BackgroundColor is set to [1 0 0],
            % that value will be migrated over because the factory value is
            % [.94 .94 .94]
            %
            % This method should not be implemented in
            % BasePropertyConversionUtil.  Converting a property only if it
            % differs from the factory value only makes sense during app
            % migration.  If used at runtime, it can result in property
            % sets not being converted and thus ignored.
            
            pvp = [];
            issues = [];
            
            type = guideComponent.Type;
            factoryValue = get(groot, ['factory', type, prop]);
            value = guideComponent.(prop);
            
            if ~isequal(value, factoryValue)
                value = guideComponent.(prop);
                pvp = {prop, value};
            end
        end
        
        function [pvp, issues] = convertBackgroundColor(guideComponent, prop)
            import appmigration.internal.CommonPropertyConversionUtil;
            
            [pvp, issues] = CommonPropertyConversionUtil.convertOneToOnePropertyIfNotFactoryValue(...
                guideComponent, prop);
        end
        
        function [pvp, issues] = convertContextMenu(guideComponent, ~)
            issues = [];
            pvp = [];
            
            % Because contextmenus are objects and not primitive data
            % types, we can't simply get the GUIDE components context menu
            % and convert it to a new context menu. Instead, all of the
            % context menus are converted first (in
            % GUIDEFigFileConverter)and a dynamic property is added with
            % the new context menu to the original GUIDE context menu so
            % that we can find it here and assign it to the PVP.
            if ~isempty(guideComponent.ContextMenu) && isprop(guideComponent.ContextMenu, 'MigratedContextMenu')
                pvp = {'ContextMenu', guideComponent.ContextMenu.MigratedContextMenu};
            end
        end
        
        function [pvp, issues] = convertPosition(guideComponent, prop)
            issues = [];
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertPosition(guideComponent, prop);
        end
        
        function [pvp, issues] = convertTitle(guideComponent, prop)
            
            % Common across: uibuttongroup, uipanel
            
            import matlab.ui.internal.componentconversion.BasePropertyConversionUtil;
            
            issues = [];
            
            title = guideComponent.(prop);
            
            % Convert padded character matrix to cell array
            if BasePropertyConversionUtil.isPaddedCharacterMatrix(title)
                title = cellstr(title);
            end
            
            % Normalize empty values of different types and sizes to be the
            % same. Otherwise, strip newline and carriage returns.
            if isempty(title)
                title = '';
            else
                title = BasePropertyConversionUtil.stripNewlineAndCarriageReturns(title);
            end
            
            % App Designer only accepts characters for title
            % GUIDE, on the other hand, at design-time, supports
            % entering a column cell array as Title eg: {A;B;C}
            % but at run time, only displays the first entry of the cell array
            % Modify the PVP to send only the first entry of cell
            % App Designer display only first entry at both design and
            % run-time
            
            % If cell, set the first entry as title
            if(iscell(title))
                title = title{1};
            end
            
            pvp = {'Title', title};
            
        end
        
        function [pvp, issues] = convertTitlePosition(guideComponent, prop)
            % Common across: uipanel, uibuttongroup
            
            issues = [];
            
            titlePosition = guideComponent.(prop);
            
            % GUIDE allows TitlePosition to be configured to 'lefttop''centertop'
            % 'righttop' 'leftbottom','centerbottom' and 'rightbottom'
            % In AppDesigner, TitlePosition can only be configured to 'lefttop'
            % 'centertop' 'righttop'.
            % Therefore, GUIDE 'leftbottom','centerbottom' and'rightbottom' will
            % be mapped to their respective 'top' counterparts
            switch(titlePosition)
                case {'lefttop','leftbottom'}
                    pvp = {prop,'lefttop'};
                case {'centertop','centerbottom'}
                    pvp = {prop,'centertop'};
                case {'righttop','rightbottom'}
                    pvp = {prop,'righttop'};
            end
        end
        
        function [pvp, issues] = convertEnable(guideComponent, prop)
            % Common across: uicontrol, uitable, uimenu
            issues = [];
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertEnable(guideComponent, prop);
        end
        
        function [pvp, issues] = convertFontAngle(guideComponent, prop)
            % Common across: uicontrol, uibuttongroup, uipanel, uitable
            issues = [];
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertFontAngle(guideComponent, prop);
        end
        
        function [pvp, issues] = convertFontName(guideComponent, prop)
            import appmigration.internal.CommonPropertyConversionUtil;
            [pvp, issues] = CommonPropertyConversionUtil.convertOneToOnePropertyIfNotFactoryValue(...
                guideComponent, prop);
            
            % replace any carriage returns/newline characters present in font
            % for example, font can be set as:
            % comp.FontName = ['Arial' newline 'Black'];
            % here newline creates a newline character which needs to be
            % stripped
            if(~isempty(pvp))
                pvp{2} = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.stripNewlineAndCarriageReturns(pvp{2});
            end
        end
        
        function [pvp, issues] = convertFontSize(guideComponent, prop)
            % Common across: uicontrol, uibuttongroup, uipanel, uitable
            issues = [];
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertFontSize(guideComponent, prop);
        end
        
        function [pvp, issues] = convertFontWeight(guideComponent, prop)
            % Common across: uicontrol, uibuttongroup, uipanel, uitable
            issues = [];
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertFontWeight(guideComponent, prop);
        end
        
        function [pvp, issues] = convertBorderType(guideComponent, prop)
            % Common across: uipanel, uibuttongroup
            issues = [];
            
            borderType = guideComponent.(prop);
            
            % In AppDesigner, BorderType can only be configured to 'line'or 'none'.
            % GUIDE lets you configure'etchedin', 'etchedout','beveldin' & 'beveledout'
            % The following BorderTypes will be mapped to 'line':
            % 'etchedin', 'etchedout','beveldin','beveledout','line'
            switch(borderType)
                case {'line','etchedin','etchedout','beveledin','beveledout'}
                    pvp = {prop,'line'};
                otherwise
                    pvp = {prop,'none'};
            end
        end
        
        function [pvp, issues] = convertForegroundColor(guideComponent, prop)
            % Common across: uicontrol, uibuttongroup, uipanel, uitable,
            % uimenu
            import appmigration.internal.CommonPropertyConversionUtil;
            [pvp, issues] = CommonPropertyConversionUtil.convertOneToOnePropertyIfNotFactoryValue(...
                guideComponent, prop);
        end
        
        function [pvp, issues] = convertUserData(guideComponent, prop)
            % Common across: uicontrol and uitable
            
            import appmigration.internal.AppConversionIssueFactory;
            
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertUserData(guideComponent, prop);
            issues = [];
            
            % UserData is not configurable in App Designer design time
            % for all components. Only report an issue if it is not empty.
            if ~isempty(guideComponent.UserData)
                issues = AppConversionIssueFactory.createPropertyIssue(...
                    AppConversionIssueFactory.Ids.UnsupportedPropertyUserData,...
                    guideComponent, prop);
            end
        end
        
        function [pvp, issues] = convertTooltipString(guideComponent, prop)
            % Common across all components
            issues = [];
            pvp = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.convertTooltipString(guideComponent, prop);
        end
        
        function [pvp, issues] = convertCData(guideComponent, prop)
            % CONVERTCDATA - Converts the CData property
            % Common across: uipushtool, uitoggletool, pushbutton
            % uicontrol, and togglebutton uicontrol.
            
            import appmigration.internal.AppConversionIssueFactory;
            
            pvp = [];
            issues = [];
            cdata = guideComponent.CData;
            
            % For clarity, return immediately if CData is empty
            if isempty(cdata)
                return;
            end
            
            % CData is converted for PushTool, ToggleTool, pushbutton
            % uicontrol, and togglebutton uicontrol.  CData is a property
            % issue for checkbox and radiobutton uicontrols.
            isCDataConvertable = ((isprop(guideComponent,'Style') || isfield(guideComponent,'Style')) && contains(guideComponent.Style, {'pushbutton','togglebutton'})) || ...
                contains(guideComponent.Type, {'uitoggletool','uipushtool'});
            isPropertyIssue = (isprop(guideComponent,'Style') || isfield(guideComponent,'Style')) && contains(guideComponent.Style, {'checkbox', 'radiobutton'});
            
            if isCDataConvertable
                % For pushbuttons, togglebuttons, pushtools, and toggletools,
                % save the CData as an image file and set the image path on the
                % new component.
                
                % The image will be saved in the same directory as
                % the GUIDE Fig-file.
                imgName = sprintf('%s_image.png', guideComponent.Tag);
                
                % CData with NaN values are transparent on the
                % legacy uicontrol. Need to save image with NaN's
                % as transparent.
                [m, n, ~] = size(cdata);
                alpha = ones(m,n);
                alpha(isnan(cdata(:,:,1))) = 0;
                
                % Write the image file
                imwrite(cdata, imgName, 'Alpha', alpha);
                pvp = {'Icon', imgName};
                
                % The uicontrols pushbutton and togglebutton have
                % IconAlignment to set.  PushTool and ToggleTool do not
                % have IconAlignment.
                if ((isprop(guideComponent,'Style') || isfield(guideComponent,'Style')) && contains(guideComponent.Style, {'pushbutton','togglebutton'}))
                    pvp = [pvp, 'IconAlignment', 'center'];
                end
                
            elseif isPropertyIssue
                % GUIDE users would uses the cdata property on radiobutton
                % and checkbox to display 2D images. This is no
                % longer supported. Report an issue.
                
                issues = AppConversionIssueFactory.createPropertyIssue(...
                    AppConversionIssueFactory.Ids.UnsupportedPropertyCData,...
                    guideComponent, prop);
            end
        end
    end
    
    methods (Static)
        function str = stripNewlineAndCarriageReturns(str)
            str = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.stripNewlineAndCarriageReturns(str);
        end
        
        function isPadded = isPaddedCharacterMatrix(str)
            isPadded = matlab.ui.internal.componentconversion.BasePropertyConversionUtil.isPaddedCharacterMatrix(str);
        end
        
        function func = reportUnsupportedPropertyIfValueIs(value, issueId)
            % Returns a conversion function that when executed, will return
            % an issue with identifier set to ISSUEID if the GUIDE
            % components property value is equal to VALUE.
            
            % Return a conversion function that closes over value and
            % issueId
            func = @conversionFunction;
            
            % Creating a closure over value and issueId so that they
            % persist when the conversion function is executed.
            function [pvp, issues] = conversionFunction(guideComponent, prop)
                pvp = [];
                issues = [];
                
                if isequal(guideComponent.(prop), value)
                    issues = appmigration.internal.AppConversionIssueFactory.createPropertyIssue(...
                        issueId,...
                        guideComponent, prop);
                end
            end
        end
        
        function func = reportUnsupportedPropertyIfValueIsNot(value, issueId)
            % Returns a conversion function that when executed, will return
            % an issue with identifier set to ISSUEID if the GUIDE
            % components property value is NOT equal to VALUE.
            
            % Return a conversion function that closes over value and
            % issueId
            func = @conversionFunction;
            
            % Creating a closure over value and issueId so that they
            % persist when the conversion function is executed.
            function [pvp, issues] = conversionFunction(guideComponent, prop)
                pvp = [];
                issues = [];
                
                if ~isequal(guideComponent.(prop), value)
                    issues = appmigration.internal.AppConversionIssueFactory.createPropertyIssue(...
                        issueId,...
                        guideComponent, prop);
                end
            end
        end
    end
end