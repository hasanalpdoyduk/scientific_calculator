classdef AppConversionReportGenerator < handle
    %APPCONVERSIONREPORTGENERATOR Creates a report for the GUIDE to App
    %Designer conversion
    
    %   Copyright 2017-2021 The MathWorks, Inc.
    
    properties (Access = private)
        MLAPPName
        GUIDEAppName
        FigFullFileName
        CodeFullFileName
        MLAPPFullFileName
        Issues
        NumCodeLinesAnalyzed
        NumComponentsMigrated
        NumFunctionsMigrated
    end
    
    properties (Constant, Access = private)
        ReportTemplateFileName = 'conversionReportTemplate.html';
        ReportIssuesSectionTemplateFileName = 'conversionReportIssuesSectionTemplate.html'; 
        ReportFileNameSuffix = '_report.html';
        TableRowWith3ColumnsTemplate = [
            '<tr>'...
              '<td>%s</td>'...
              '<td>%s</td>'...
              '<td rowspan="%d">'...
                '<div>%s</div>',...
                '<div class="detailsWorkaround">'...
                  '<span class="detailsWorkaroundHeader">%s</span>',...
                  '<span class="detailsWorkaroundText">%s</span>',...
                '</div>',...
            '</tr>'...
            ];
        TableRowWith2ColumnsTemplate = [
            '<tr>'...
              '<td>%s</td>'...
              '<td>%s</td>'...
            '</tr>'...
            ];
    end
    
    properties (Access = private)
        % Struct with mapping of issue identifiers to the message catalog
        % id for the associated message. This struct is created by decoding
        % AppConversionIssuesMessageCatlogMap.json
        %
        % AppConversionIssuesMessageCatlogMap.json contains two top level
        % elements: IssuesWithNoWorkaround and Issues.
        %
        %   IssuesWithNoWorkaround is an array of issue identifiers that
        %   are considered unsupported with no workaround.
        %
        %   Issues is a hash map (struct when it gets
        %   decoded) of issue identifier reported by the migration tool to
        %   another hash map (struct) with information needed to form the
        %   actual message in the report". The inner hash map has the
        %   following fields:
        %       "DetailsMessId" - message catalog id for the "details"
        %           portion of the message
        %       "WorkaroundMessageId" - message catalog id for the
        %           "workaround" portion of the message.
        %       "WorkaroundMessageHole" - either null, "OpeningFcn" which
        %           means that the workaround message has a hole that needs
        %           to be filled with the name of the opening fcn of the
        %           app, or "HoleArray" which means the 
        %           WorkaroundMessageHoleData contains an array of holes
        %           needed for the message catalog.
        %      "WorkaroundMessageHoleData" - data for the specified
        %           WorkaroundMessageHole
        AppConversionIssuesMessageCatalogMap
    end
    
    methods
        function obj = AppConversionReportGenerator(guideAppFullFileName, conversionResults)
            %APPCONVERSIONREPORTGENERATOR Creates a report for the GUIDE to
            %App Designer
            %   
            %   Inputs:
            %       guideAppFullFileName: full file path to the GUIDE app
            %           (.fig file)
            %       conversionResults: struct containing results of the
            %           conversion such as the MLAPP full file name and the
            %           conversion issues.
            
            [path, name] = fileparts(guideAppFullFileName);

            obj.GUIDEAppName = name;
            obj.FigFullFileName = fullfile(path, [name '.fig']);
            obj.CodeFullFileName = fullfile(path, [name '.m']);
            obj.MLAPPFullFileName = conversionResults.MLAPPFullFileName;
            [~, obj.MLAPPName] = fileparts(obj.MLAPPFullFileName);
            obj.Issues = conversionResults.Issues;
            obj.NumCodeLinesAnalyzed = conversionResults.NumCodeLinesAnalyzed;
            obj.NumComponentsMigrated = conversionResults.NumComponentsMigrated;
            obj.NumFunctionsMigrated = conversionResults.NumFunctionsMigrated;
            
            % Get the conversion issue message catalog map struct by
            % reading the data from a json file.
            jsonPath = fileparts(mfilename('fullpath'));
            jsonStr = fileread(fullfile(jsonPath, 'AppConversionIssuesMessageCatalogMap.json'));
            obj.AppConversionIssuesMessageCatalogMap = jsondecode(jsonStr);
        end
        
        function reportFullFilename = generateHTMLReport(obj)
            %GENERATEHTMLREPORT - Creates the conversion report
            %   Outputs:
            %       reportFullFileName: full file path to the generated
            %           HTML report file.
            
            import appmigration.internal.AppConversionIssueType;
            
            issues = obj.Issues;
            
            if ~isempty(issues)
                % Remove errors with the migration tool as these are not
                % reported to the user.
                issues([issues.Type] == appmigration.internal.AppConversionIssueType.Error) = [];

                % Sort by component, callback, property, API
                compIdices = ([issues.Type] == appmigration.internal.AppConversionIssueType.Component);
                callbackIdices = ([issues.Type] == appmigration.internal.AppConversionIssueType.Callback);
                propertyIdices = ([issues.Type] == appmigration.internal.AppConversionIssueType.Property);
                apiIdices = ([issues.Type] == appmigration.internal.AppConversionIssueType.API);
                issues = [issues(compIdices) issues(callbackIdices) issues(propertyIdices) issues(apiIdices)];
                
                % Further sort the issues by bubbling up the unsupported issues
                % with no workarounds to the top
                idx = arrayfun(@obj.isUnsupportedWithNoWorkaround, issues);
                unsupportedIssues = issues(idx);
                partiallySupportedIssues = issues(~idx);
                
                issues = [unsupportedIssues, partiallySupportedIssues];
            end

            % Create the issues table if there are issues
            if isempty(issues)
                summaryHeader = getString(message('appmigration:report:readyForValidationHeader'));
                issuesSectionHTML = '';
            else
                summaryHeader = getString(message('appmigration:report:actionRequiredHeader'));
                issuesSectionHTML = createIssuesSectionHTML(obj, issues);
            end
            
            % Read the report template
            templateStr = getHTMLTemplateStr(obj, obj.ReportTemplateFileName);
            
            % Fill in the template holes
            templateStr = replaceTemplateHoles(obj, templateStr, struct(...
                ...% Title & Results section
                'reportTitle'                   , getString(message('appmigration:report:reportTitle', obj.GUIDEAppName)),...
                'reportTitleHeader'             , getString(message('appmigration:report:reportTitle', getString(message('appmigration:report:wrapWithCodeTag', obj.GUIDEAppName)))),...
                'summaryHeader'                 , summaryHeader,...
                'resultsHeader'                 , getString(message('appmigration:report:resultsHeader')),...
                'generatedAppText'              , getString(message('appmigration:report:generatedAppText', [obj.MLAPPName '.mlapp'])),...
                'analyzedCodeText'              , getString(message('appmigration:report:analyzedCodeText', obj.NumCodeLinesAnalyzed, [obj.GUIDEAppName '.m'])),...
                'migratedComponentsText'        , getString(message('appmigration:report:migratedComponentsText', obj.NumComponentsMigrated)),...
                'copiedCodeText'                , getString(message('appmigration:report:copiedCodeText', obj.NumFunctionsMigrated)),...
                ...% Issues section
                'issuesSectionHTML'             , issuesSectionHTML,...
                ...% Validate your app section
                'validateHeader'                , getString(message('appmigration:report:validateHeader')),...
                'validateDescriptionText'       , getString(message('appmigration:report:validateDescriptionText')),...
                'verifyLayoutHeader'            , getString(message('appmigration:report:verifyLayoutHeader')),...
                'verifyLayoutText1'             , getString(message('appmigration:report:verifyLayoutText1')),...
                'verifyLayoutText2'             , getString(message('appmigration:report:verifyLayoutText2')),...
                'verifyCallbacksHeader'         , getString(message('appmigration:report:verifyCallbacksHeader')),...
                'verifyCallbacksText1'          , getString(message('appmigration:report:verifyCallbacksText1')),...
                'verifyCallbacksText2'          , getString(message('appmigration:report:verifyCallbacksText2')),...
                'validateFooterText'            , getString(message('appmigration:report:validateFooterText'))...
                ));
            
            % Assert that all of the wholes have been filled in (i.e. don't
            % find ${.*} anywhere in the template.
            noHoles = isempty(regexp(templateStr, '\$\{.*\}', 'once'));
            assert(noHoles);
            
            % Write the report to an HTML file
            [mlappFilePath, mlappFileName, ~] = fileparts(obj.MLAPPFullFileName);
            reportFullFilename = fullfile(mlappFilePath, [mlappFileName, obj.ReportFileNameSuffix]);
            fid = fopen(reportFullFilename,'w+');
            fileCleanup = onCleanup(@()fclose(fid));
            fprintf(fid, '%s', templateStr);
        end
    end
    
    methods (Access = private)        
        
        function tableStr = createIssuesSectionHTML(obj, issues)
            % Generates the html for the issues section from the array of
            % issues.
            
            % Get the list of unique issues by keying off the "identifier"
            % property. We need to combine the issues with the same
            % "identifier" into the same row
            identifiers = {issues.Identifier};
            uniqueIdentifiers = unique(identifiers, 'stable');
            
            % Initialize the table body cell array
            issueTableBody = [];
            
            % Loop over and create the rows of the table
            for i=1:length(uniqueIdentifiers)
                identifier = uniqueIdentifiers{i};
                
                idx = strcmp(identifiers, identifier);
                issuesWithSameId = issues(idx);
                
                names = {issuesWithSameId.Name};
                uniqueNames = unique(names, 'stable');
                numRows = length(uniqueNames);
                for j=1:length(uniqueNames)
                    
                    % The first row should contain 3 columns and any
                    % more rows for this identifier should have 2
                    % columns with the second column spanning the 3rd.
                    if numRows == 1 || j == 1
                        doSpan = false; % Indicates that the row should have all 3 columns
                    else
                        doSpan = true; % Indicates that second colum should span to the 3rd
                    end
                    name = uniqueNames{j};
                    idxName = strcmp(names, name);
                    issuesWithSameIdAndName = issuesWithSameId(idxName);
                    issueTableBody = [issueTableBody; createIssuesHTMLTableRow(obj, issuesWithSameIdAndName, identifier, numRows, doSpan)]; %#ok<AGROW>
                end
            end

            % Combine into single string
            issueTableBody = strjoin(issueTableBody, newline);
            
            % Get the table template string
            tableTemplateStr = getHTMLTemplateStr(obj, obj.ReportIssuesSectionTemplateFileName);
            
            % Get the identifierColumnHeader
            identifierColumnHeader = obj.getIdentifierColumnHeader(issues);
            
            % Fill in the template holes
            tableStr = replaceTemplateHoles(obj, tableTemplateStr, struct(...
                'issuesHeader'             , getString(message('appmigration:report:issuesHeader')),...
                'identifierColumnHeader'   , identifierColumnHeader,...
                'functionalityColumnHeader', getString(message('appmigration:report:functionalityHeader')),...
                'detailsColumnHeader'      , getString(message('appmigration:report:detailsWithWorkaroundsHeader')),...
                'tableBody'                , issueTableBody));
        end
        
        function tableRow = createIssuesHTMLTableRow(obj, issues, msgIdentifierSuffix, numRows, doSpan)
            % Generates the html for a single row of the issues table
            
            if isempty(issues)
                tableRow = {};
            else
                % Get the map of how the message, workaround, and
                % workaround code will be obtained/created based on the
                % issue identifier.
                issuesMap = obj.AppConversionIssuesMessageCatalogMap.Issues;
                issueMapData = issuesMap.(msgIdentifierSuffix);
                name = sprintf('<code>%s</code>', issues(1).Name);
                
                % Extract the data that makes up the tag column
                % (line numbers for API issues and component tag for all
                % other issues).
                apiIdx = ([issues.Type] == appmigration.internal.AppConversionIssueType.API);
                apiLines = [issues(apiIdx).Value];
                tags = {issues(~apiIdx).ComponentTag};

                % Format the tag column
                tagStr = formatTagColumn(obj, tags, apiLines);
                
                if doSpan
                    tableRow = {sprintf(obj.TableRowWith2ColumnsTemplate,...
                        name, tagStr)};
                else
                    detailsMsg = getString(message(sprintf('appmigration:issues:%s', issueMapData.DetailsMessageId)));
                    
                    if isequal(issueMapData.WorkaroundMessageHoleId, 'OpeningFcn')
                        % The workaround message references the app's opening
                        % fcn and so need to fill in that hole with the name of
                        % the GUIDE app's opening fcn.
                        workaroundMsg = getString(message(sprintf('appmigration:issues:%s',...
                            issueMapData.WorkaroundMessageId), sprintf('%s_OpeningFcn', obj.GUIDEAppName)));
                    elseif isequal(issueMapData.WorkaroundMessageHoleId, 'HoleArray')
                        workaroundMsg = getString(message(sprintf('appmigration:issues:%s',...
                            issueMapData.WorkaroundMessageId), issueMapData.WorkaroundMessageHoleData{:}));
                    else
                        workaroundMsg = getString(message(sprintf('appmigration:issues:%s', issueMapData.WorkaroundMessageId)));
                    end
                    
                    workaroundHeader = getString(message('appmigration:report:workaroundHeader'));
                    
                    % Fill in the template holes
                    tableRow = {sprintf(obj.TableRowWith3ColumnsTemplate,...
                        name, tagStr, numRows, detailsMsg, workaroundHeader, workaroundMsg)};
                end
            end
        end
        
        function tagStr = formatTagColumn(obj, tags, apiLines)
            % Formats the strings in the tags or column of the
            % issue tables. Adds "Show more" hyperlink if there are more
            % than three tags.
            
            % Sort the tags alpabetically (case insensitive)
            [~, idx] = sort(lower(tags));
            tags = tags(idx);
            tags = cellfun(@(tag)sprintf('<code>%s</code>',...
                tag), tags, 'UniformOutput', false);
            
            % Sort the line numbers in ascending order
            apiLines = sort(apiLines);
            
            % Add the hyperlink to the line numbers
            formatedLines = arrayfun(@(line)sprintf('<a href="matlab:opentoline(''%s'', %d)">line %d</a>',...
                obj.CodeFullFileName, line, line), apiLines, 'UniformOutput', false);
            
            % Combine the tags and line numbers together with tags first
            tags = [tags formatedLines];
            
            for i=1:length(tags)
                if any(i==[1 2 3])
                    % Always want to display the first three tags and so
                    % don't add the 'hidden' class;
                    class = '';
                else
                    % Want to initially hide all but the first three tags
                    class = 'hidden';
                end
                tags{i} = sprintf('<div class="%s">%s</div>', class, tags{i});
            end
            
            % Add the "Show more" and "Show less" hyperlinks with the "Show
            % Less" being hidden by default.
            if length(tags) > 3
                tags{end + 1} = sprintf('<div class="showMore"><a href="#" onclick="toggleShowMore(this); return false;">%s</a></div>',...
                    getString(message('appmigration:report:showMore', length(tags)-3)));
                tags{end + 1} = sprintf('<div class="showMore hidden"><a href="#" onclick="toggleShowMore(this); return false;">%s</a></div>',...
                    getString(message('appmigration:report:showLess')));
            end
            
            % Combine together to form a single string
            tagStr = strjoin(tags, newline);
        end
        
        function template = replaceTemplateHoles(~, template, holesStruct)
            % Fills in the holes specified in the template string. The
            % holes are of the form "${holeName}". holesStruct contains
            % field names that are the same as the "holeName" and the value
            % is what should replace the hole.
            
            holes = fieldnames(holesStruct);
            
            for i=1:length(holes)
                hole = holes{i};
                template = strrep(template, ['${' hole '}'], holesStruct.(hole));
            end
        end
        
        function isUnsupported = isUnsupportedWithNoWorkaround(obj, issue)
            % Returns true if the issue is considered unsupported with no
            % workaround.
            
            unsupportedIssues = obj.AppConversionIssuesMessageCatalogMap.IssuesWithNoWorkaround;
            isUnsupported = ismember(issue.Identifier, unsupportedIssues);
        end
        
        function str = getHTMLTemplateStr(~, filename)
            path = fileparts(mfilename('fullpath'));
            str = fileread(fullfile(path, filename));
        end
    end
    
    methods (Static)
        function identifierHeader = getIdentifierColumnHeader(issues)
            % Returns the header for the identifier/tag column of the
            % unsupported and paritally supported issues tables
            
            % Get all of the issues of type API (these are the issues that
            % will display a line number in the tag column. All other
            % issues will display the GUIDE tag instead.
            apiIndices = ([issues.Type] == appmigration.internal.AppConversionIssueType.API);
            apiIndices = find(apiIndices);
            
            if isempty(apiIndices)
                % There are no API issues and so header should be just
                % "GUIDE Tag"
                identifierHeader = getString(message('appmigration:report:identifierHeaderTagOnly'));
            else
                if length(issues) == length(apiIndices)
                    % There are only API issues and so header should be
                    % "GUIDE Line #"
                    identifierHeader = getString(message('appmigration:report:identifierHeaderLineOnly'));
                else
                    % There are API and other issues and so header should
                    % be "GUIDE Tag / Line #;
                    identifierHeader = getString(message('appmigration:report:identifierHeaderTagAndLine'));
                end
            end
        end
    end
end