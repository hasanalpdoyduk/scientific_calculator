classdef GUIDECallbackType
    %GUIDECALLBACKTYPE Creates GUIDECallbackType enum
    %   Enumeration of the different types of GUIDE callback values
    
    %   Copyright 2018 The MathWorks, Inc.
    
    enumeration
        % Ex: @(hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject)) 
        % Ex (Legacy): MyGUI('pushbutton1_Callback',gcbo,[],guidata(gcbo))
        Standard 

        % Ex: (hObject,eventdata)MyGUI('pushbutton1_Callback',hObject,eventdata,guidata(hObject), 1, pi, 'abc')
        % Ex (Legacy): MyGUI('pushbutton1_Callback',gcbo,[],guidata(gcbo), 1, pi, 'abc')
        StandardWithAdditionalArgs
        
        % Ex: @(src,event)disp('Hello World')
        Custom
        
        % Ex: actxproxy(gcbo)
        EvalInBase
        
        % Ex: %automatic or %default
        Automatic
        
        % Ex: {@myfunc, 1, pi, 'abc'} - You can't actually specify a callback like this during design time in GUIDE
        CellArray
    end
end