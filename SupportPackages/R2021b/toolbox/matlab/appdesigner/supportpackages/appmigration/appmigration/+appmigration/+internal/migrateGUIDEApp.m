function migrateGUIDEApp(varargin)
% MIGRATEGUIDEAPP - Migrate a GUIDE App to App Designer

% This function is intentionally undocumented.
% Its behavior may change, or it may be removed, in a future release.

% Copyright 2020 The MathWorks, Inc.

narginchk(0, 3)

if nargin == 0
    % If there were no input arguments, launch the GUIDEAppMaintenanceOptions
    % app such that there is no specified FIG file and the app opens to the
    % 'migrate' tab.
    guide.internal.launchGUIDEAppMaintenanceOptions([], 'migrate');
    return
end

validatedMLAPPFullFileName = [];

if nargin >= 2 && ~strcmp(varargin{2}, '-open')
    % If there were at least two input arguments and the second argument
    % is not '-opened', the second input argument is the file to which to
    % save the migrated app.
    
    % Validate the user-specfied file name using an expected extension of
    % '.mlapp'.
    fileExtension = '.mlapp';
    inputtedMLAPPFileName = varargin{2};
    validatedMLAPPFullFileName = appdesigner.internal.application.getValidatedFile(inputtedMLAPPFileName, fileExtension);
    
    % Note: GUIDEAppConverter will validate the folder for writability.    
end

% Migrate the GUIDE app
inputtedFigFile = varargin{1};
converter = appmigration.internal.GUIDEAppConverter(inputtedFigFile, validatedMLAPPFullFileName);
conversionResults = converter.convert();

% Generate the report
reportGenerator = appmigration.internal.AppConversionReportGenerator(converter.FigFullFileName, conversionResults);
reportGenerator.generateHTMLReport();

% Open the MLAPP if the last input argument was '-open'.
if ischar(varargin{end}) && strcmp(varargin{end}, '-open')
    mlappFile = conversionResults.MLAPPFullFileName;
    
    % Open the app in App Designer
    appdesigner(mlappFile)
end

end