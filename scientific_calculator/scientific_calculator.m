classdef Alp_Doyduk_EE101_TermProject1 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        GridLayout          matlab.ui.container.GridLayout
        Button_exponential  matlab.ui.control.Button
        Button_x3           matlab.ui.control.Button
        Button_x2           matlab.ui.control.Button
        Button_tan          matlab.ui.control.Button
        Button_cos          matlab.ui.control.Button
        Button_sin          matlab.ui.control.Button
        Button_tan_deg      matlab.ui.control.Button
        Button_cos_deg      matlab.ui.control.Button
        Button_sin_deg      matlab.ui.control.Button
        Button_factorial    matlab.ui.control.Button
        historyScreen       matlab.ui.control.EditField
        Button_right_par    matlab.ui.control.Button
        Button_root         matlab.ui.control.Button
        Button_percent      matlab.ui.control.Button
        Button_left_par     matlab.ui.control.Button
        Button_e            matlab.ui.control.Button
        Button_pi           matlab.ui.control.Button
        Button_C            matlab.ui.control.Button
        Button_AC           matlab.ui.control.Button
        Button_1            matlab.ui.control.Button
        Button_5            matlab.ui.control.Button
        Button_6            matlab.ui.control.Button
        Button_4            matlab.ui.control.Button
        Button_dot          matlab.ui.control.Button
        Button_0            matlab.ui.control.Button
        Button_9            matlab.ui.control.Button
        Button_8            matlab.ui.control.Button
        Button_3            matlab.ui.control.Button
        Button_2            matlab.ui.control.Button
        Button_7            matlab.ui.control.Button
        Button_subtract     matlab.ui.control.Button
        Button_multiply     matlab.ui.control.Button
        Button_divide       matlab.ui.control.Button
        Button_sum          matlab.ui.control.Button
        Button_equal        matlab.ui.control.Button
        Screen              matlab.ui.control.EditField
    end

    
    properties (Access = private)

    end
    
    methods (Access = private)
        
        function WriteOnScreen_number (app, event)
            app.Screen.Value = [app.Screen.Value, event.Source.Text];
            
        end
        
        
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: Button_0, Button_1, Button_2, Button_3, 
        % Button_4, Button_5, Button_6, Button_7, Button_8, Button_9
        function numberButton_Pressed(app, event)
            WriteOnScreen_number (app, event)
        end

        % Button pushed function: Button_equal
        function equalButton_Pressed(app, event)
            try
                app.historyScreen.Value = app.Screen.Value;
                app.Screen.Value = string(eval(app.Screen.Value));
            catch
                app.Screen.Value = "Error"
            end
        end

        % Button pushed function: Button_cos, Button_cos_deg, 
        % Button_divide, Button_dot, Button_exponential, Button_left_par, 
        % Button_multiply, Button_percent, Button_right_par, Button_root, 
        % Button_sin, Button_sin_deg, Button_subtract, Button_sum, 
        % Button_tan, Button_tan_deg, Button_x2, Button_x3
        function basicOperationButton_Pressed(app, event)
            app.Screen.Value = [app.Screen.Value, event.Source.Tag];
        end

        % Button pushed function: Button_AC
        function ACButton_Pressed(app, event)
           app.Screen.Value = ""
        end

        % Button pushed function: Button_e, Button_pi
        function pieButton_Pressed(app, event)
           app.Screen.Value = [app.Screen.Value, num2str(event.Source.Tag)];
        end

        % Button pushed function: Button_C
        function CButton_Pushed(app, event)
            app.Screen.Value = app.Screen.Value(1:end-1)
        end

        % Button pushed function: Button_factorial
        function factorialButton_Pushed(app, event)
            app.historyScreen.Value = app.Screen.Value;
            x = str2num(app.Screen.Value);
            fact = 1;
            for index = (1:x)
                fact = fact * index;
            end
            app.Screen.Value = num2str(fact)

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 551 516];
            app.UIFigure.Name = 'MATLAB App';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x', 50, 50, 50, 38, 38, 80, 80, 80, 1};
            app.GridLayout.RowHeight = {1, 32, 70, '1x', '1x', '1x', '1x', '1x', '1x', 1};
            app.GridLayout.ColumnSpacing = 7;
            app.GridLayout.BackgroundColor = [0.9294 0.8706 0.7922];

            % Create Screen
            app.Screen = uieditfield(app.GridLayout, 'text');
            app.Screen.HorizontalAlignment = 'right';
            app.Screen.FontSize = 32;
            app.Screen.Placeholder = '0';
            app.Screen.Layout.Row = 3;
            app.Screen.Layout.Column = [2 9];

            % Create Button_equal
            app.Button_equal = uibutton(app.GridLayout, 'push');
            app.Button_equal.ButtonPushedFcn = createCallbackFcn(app, @equalButton_Pressed, true);
            app.Button_equal.Tag = '=';
            app.Button_equal.BackgroundColor = [0.8549 0.7216 0.5451];
            app.Button_equal.FontSize = 32;
            app.Button_equal.Layout.Row = [8 9];
            app.Button_equal.Layout.Column = 9;
            app.Button_equal.Text = '=';

            % Create Button_sum
            app.Button_sum = uibutton(app.GridLayout, 'push');
            app.Button_sum.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_sum.Tag = '+';
            app.Button_sum.VerticalAlignment = 'top';
            app.Button_sum.BackgroundColor = [0.8549 0.7216 0.5451];
            app.Button_sum.FontSize = 32;
            app.Button_sum.Layout.Row = 7;
            app.Button_sum.Layout.Column = 9;
            app.Button_sum.Text = '+';

            % Create Button_divide
            app.Button_divide = uibutton(app.GridLayout, 'push');
            app.Button_divide.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_divide.Tag = '/';
            app.Button_divide.VerticalAlignment = 'top';
            app.Button_divide.BackgroundColor = [0.8549 0.7216 0.5451];
            app.Button_divide.FontSize = 32;
            app.Button_divide.Layout.Row = 4;
            app.Button_divide.Layout.Column = 9;
            app.Button_divide.Text = '÷';

            % Create Button_multiply
            app.Button_multiply = uibutton(app.GridLayout, 'push');
            app.Button_multiply.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_multiply.Tag = '*';
            app.Button_multiply.VerticalAlignment = 'top';
            app.Button_multiply.BackgroundColor = [0.8549 0.7216 0.5451];
            app.Button_multiply.FontSize = 32;
            app.Button_multiply.Layout.Row = 5;
            app.Button_multiply.Layout.Column = 9;
            app.Button_multiply.Text = '×';

            % Create Button_subtract
            app.Button_subtract = uibutton(app.GridLayout, 'push');
            app.Button_subtract.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_subtract.Tag = '-';
            app.Button_subtract.VerticalAlignment = 'top';
            app.Button_subtract.BackgroundColor = [0.8549 0.7216 0.5451];
            app.Button_subtract.FontSize = 32;
            app.Button_subtract.Layout.Row = 6;
            app.Button_subtract.Layout.Column = 9;
            app.Button_subtract.Text = '−';

            % Create Button_7
            app.Button_7 = uibutton(app.GridLayout, 'push');
            app.Button_7.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_7.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_7.FontSize = 32;
            app.Button_7.FontColor = [0.9804 0.9647 0.949];
            app.Button_7.Layout.Row = 6;
            app.Button_7.Layout.Column = [5 6];
            app.Button_7.Text = '7';

            % Create Button_2
            app.Button_2 = uibutton(app.GridLayout, 'push');
            app.Button_2.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_2.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_2.FontSize = 32;
            app.Button_2.FontColor = [0.9804 0.9647 0.949];
            app.Button_2.Layout.Row = 8;
            app.Button_2.Layout.Column = 7;
            app.Button_2.Text = '2';

            % Create Button_3
            app.Button_3 = uibutton(app.GridLayout, 'push');
            app.Button_3.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_3.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_3.FontSize = 32;
            app.Button_3.FontColor = [0.9804 0.9647 0.949];
            app.Button_3.Layout.Row = 8;
            app.Button_3.Layout.Column = 8;
            app.Button_3.Text = '3';

            % Create Button_8
            app.Button_8 = uibutton(app.GridLayout, 'push');
            app.Button_8.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_8.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_8.FontSize = 32;
            app.Button_8.FontColor = [0.9804 0.9647 0.949];
            app.Button_8.Layout.Row = 6;
            app.Button_8.Layout.Column = 7;
            app.Button_8.Text = '8';

            % Create Button_9
            app.Button_9 = uibutton(app.GridLayout, 'push');
            app.Button_9.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_9.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_9.FontSize = 32;
            app.Button_9.FontColor = [0.9804 0.9647 0.949];
            app.Button_9.Layout.Row = 6;
            app.Button_9.Layout.Column = 8;
            app.Button_9.Text = '9';

            % Create Button_0
            app.Button_0 = uibutton(app.GridLayout, 'push');
            app.Button_0.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_0.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_0.FontSize = 32;
            app.Button_0.FontColor = [0.9804 0.9647 0.949];
            app.Button_0.Layout.Row = 9;
            app.Button_0.Layout.Column = [5 7];
            app.Button_0.Text = '0';

            % Create Button_dot
            app.Button_dot = uibutton(app.GridLayout, 'push');
            app.Button_dot.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_dot.Tag = '.';
            app.Button_dot.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_dot.FontSize = 32;
            app.Button_dot.FontColor = [0.9804 0.9647 0.949];
            app.Button_dot.Layout.Row = 9;
            app.Button_dot.Layout.Column = 8;
            app.Button_dot.Text = '.';

            % Create Button_4
            app.Button_4 = uibutton(app.GridLayout, 'push');
            app.Button_4.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_4.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_4.FontSize = 32;
            app.Button_4.FontColor = [0.9804 0.9647 0.949];
            app.Button_4.Layout.Row = 7;
            app.Button_4.Layout.Column = [5 6];
            app.Button_4.Text = '4';

            % Create Button_6
            app.Button_6 = uibutton(app.GridLayout, 'push');
            app.Button_6.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_6.VerticalAlignment = 'top';
            app.Button_6.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_6.FontSize = 32;
            app.Button_6.FontColor = [0.9804 0.9647 0.949];
            app.Button_6.Layout.Row = 7;
            app.Button_6.Layout.Column = 8;
            app.Button_6.Text = '6';

            % Create Button_5
            app.Button_5 = uibutton(app.GridLayout, 'push');
            app.Button_5.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_5.VerticalAlignment = 'top';
            app.Button_5.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_5.FontSize = 32;
            app.Button_5.FontColor = [0.9804 0.9647 0.949];
            app.Button_5.Layout.Row = 7;
            app.Button_5.Layout.Column = 7;
            app.Button_5.Text = '5';

            % Create Button_1
            app.Button_1 = uibutton(app.GridLayout, 'push');
            app.Button_1.ButtonPushedFcn = createCallbackFcn(app, @numberButton_Pressed, true);
            app.Button_1.BackgroundColor = [0.7176 0.7922 0.8588];
            app.Button_1.FontSize = 32;
            app.Button_1.FontColor = [0.9804 0.9647 0.949];
            app.Button_1.Layout.Row = 8;
            app.Button_1.Layout.Column = [5 6];
            app.Button_1.Text = '1';

            % Create Button_AC
            app.Button_AC = uibutton(app.GridLayout, 'push');
            app.Button_AC.ButtonPushedFcn = createCallbackFcn(app, @ACButton_Pressed, true);
            app.Button_AC.BackgroundColor = [0.7412 0.8235 0.7137];
            app.Button_AC.FontSize = 32;
            app.Button_AC.FontColor = [0.8196 0.1882 0.2627];
            app.Button_AC.Layout.Row = 4;
            app.Button_AC.Layout.Column = [5 7];
            app.Button_AC.Text = 'AC';

            % Create Button_C
            app.Button_C = uibutton(app.GridLayout, 'push');
            app.Button_C.ButtonPushedFcn = createCallbackFcn(app, @CButton_Pushed, true);
            app.Button_C.BackgroundColor = [0.7412 0.8235 0.7137];
            app.Button_C.FontSize = 32;
            app.Button_C.Layout.Row = 4;
            app.Button_C.Layout.Column = 8;
            app.Button_C.Text = 'C';

            % Create Button_pi
            app.Button_pi = uibutton(app.GridLayout, 'push');
            app.Button_pi.ButtonPushedFcn = createCallbackFcn(app, @pieButton_Pressed, true);
            app.Button_pi.Tag = 'pi';
            app.Button_pi.BackgroundColor = [0.6353 0.698 0.6235];
            app.Button_pi.FontSize = 32;
            app.Button_pi.Layout.Row = 5;
            app.Button_pi.Layout.Column = 4;
            app.Button_pi.Text = 'π';

            % Create Button_e
            app.Button_e = uibutton(app.GridLayout, 'push');
            app.Button_e.ButtonPushedFcn = createCallbackFcn(app, @pieButton_Pressed, true);
            app.Button_e.Tag = 'exp(1)';
            app.Button_e.BackgroundColor = [0.6353 0.698 0.6235];
            app.Button_e.FontSize = 32;
            app.Button_e.Layout.Row = 4;
            app.Button_e.Layout.Column = 4;
            app.Button_e.Text = 'e';

            % Create Button_left_par
            app.Button_left_par = uibutton(app.GridLayout, 'push');
            app.Button_left_par.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_left_par.Tag = '(';
            app.Button_left_par.VerticalAlignment = 'top';
            app.Button_left_par.BackgroundColor = [0.7412 0.8235 0.7137];
            app.Button_left_par.FontSize = 32;
            app.Button_left_par.Layout.Row = 5;
            app.Button_left_par.Layout.Column = 5;
            app.Button_left_par.Text = '(';

            % Create Button_percent
            app.Button_percent = uibutton(app.GridLayout, 'push');
            app.Button_percent.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_percent.Tag = '/100';
            app.Button_percent.VerticalAlignment = 'top';
            app.Button_percent.BackgroundColor = [0.7412 0.8235 0.7137];
            app.Button_percent.FontSize = 32;
            app.Button_percent.Layout.Row = 5;
            app.Button_percent.Layout.Column = 8;
            app.Button_percent.Text = '%';

            % Create Button_root
            app.Button_root = uibutton(app.GridLayout, 'push');
            app.Button_root.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_root.Tag = '^(1/2)';
            app.Button_root.VerticalAlignment = 'top';
            app.Button_root.BackgroundColor = [0.7412 0.8235 0.7137];
            app.Button_root.FontSize = 32;
            app.Button_root.Layout.Row = 5;
            app.Button_root.Layout.Column = 7;
            app.Button_root.Text = '√';

            % Create Button_right_par
            app.Button_right_par = uibutton(app.GridLayout, 'push');
            app.Button_right_par.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_right_par.Tag = ')';
            app.Button_right_par.BackgroundColor = [0.7412 0.8235 0.7137];
            app.Button_right_par.FontSize = 32;
            app.Button_right_par.Layout.Row = 5;
            app.Button_right_par.Layout.Column = 6;
            app.Button_right_par.Text = ')';

            % Create historyScreen
            app.historyScreen = uieditfield(app.GridLayout, 'text');
            app.historyScreen.HorizontalAlignment = 'right';
            app.historyScreen.FontSize = 20;
            app.historyScreen.Placeholder = 'ans';
            app.historyScreen.Layout.Row = 2;
            app.historyScreen.Layout.Column = [2 9];

            % Create Button_factorial
            app.Button_factorial = uibutton(app.GridLayout, 'push');
            app.Button_factorial.ButtonPushedFcn = createCallbackFcn(app, @factorialButton_Pushed, true);
            app.Button_factorial.BackgroundColor = [0.6353 0.698 0.6235];
            app.Button_factorial.FontSize = 32;
            app.Button_factorial.Layout.Row = 6;
            app.Button_factorial.Layout.Column = 4;
            app.Button_factorial.Text = 'x!';

            % Create Button_sin_deg
            app.Button_sin_deg = uibutton(app.GridLayout, 'push');
            app.Button_sin_deg.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_sin_deg.Tag = 'sind(';
            app.Button_sin_deg.BackgroundColor = [0.4745 0.5294 0.4667];
            app.Button_sin_deg.FontSize = 26;
            app.Button_sin_deg.FontColor = [1 0.9843 0.9686];
            app.Button_sin_deg.Layout.Row = 4;
            app.Button_sin_deg.Layout.Column = [2 3];
            app.Button_sin_deg.Text = 'sin(deg)';

            % Create Button_cos_deg
            app.Button_cos_deg = uibutton(app.GridLayout, 'push');
            app.Button_cos_deg.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_cos_deg.Tag = 'cosd(';
            app.Button_cos_deg.BackgroundColor = [0.4745 0.5294 0.4667];
            app.Button_cos_deg.FontSize = 26;
            app.Button_cos_deg.FontColor = [1 0.9843 0.9686];
            app.Button_cos_deg.Layout.Row = 5;
            app.Button_cos_deg.Layout.Column = [2 3];
            app.Button_cos_deg.Text = 'cos(deg)';

            % Create Button_tan_deg
            app.Button_tan_deg = uibutton(app.GridLayout, 'push');
            app.Button_tan_deg.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_tan_deg.Tag = 'tand(';
            app.Button_tan_deg.BackgroundColor = [0.4745 0.5294 0.4667];
            app.Button_tan_deg.FontSize = 26;
            app.Button_tan_deg.FontColor = [1 0.9843 0.9686];
            app.Button_tan_deg.Layout.Row = 6;
            app.Button_tan_deg.Layout.Column = [2 3];
            app.Button_tan_deg.Text = 'tan(deg)';

            % Create Button_sin
            app.Button_sin = uibutton(app.GridLayout, 'push');
            app.Button_sin.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_sin.Tag = 'sin(';
            app.Button_sin.BackgroundColor = [0.4745 0.5294 0.4667];
            app.Button_sin.FontSize = 26;
            app.Button_sin.FontColor = [1 0.9843 0.9686];
            app.Button_sin.Layout.Row = 7;
            app.Button_sin.Layout.Column = [2 3];
            app.Button_sin.Text = 'sin(rad)';

            % Create Button_cos
            app.Button_cos = uibutton(app.GridLayout, 'push');
            app.Button_cos.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_cos.Tag = 'cos(';
            app.Button_cos.BackgroundColor = [0.4745 0.5294 0.4667];
            app.Button_cos.FontSize = 26;
            app.Button_cos.FontColor = [1 0.9843 0.9686];
            app.Button_cos.Layout.Row = 8;
            app.Button_cos.Layout.Column = [2 3];
            app.Button_cos.Text = 'cos(rad)';

            % Create Button_tan
            app.Button_tan = uibutton(app.GridLayout, 'push');
            app.Button_tan.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_tan.Tag = 'tan(';
            app.Button_tan.BackgroundColor = [0.4745 0.5294 0.4667];
            app.Button_tan.FontSize = 26;
            app.Button_tan.FontColor = [1 0.9843 0.9686];
            app.Button_tan.Layout.Row = 9;
            app.Button_tan.Layout.Column = [2 3];
            app.Button_tan.Text = 'tan(rad)';

            % Create Button_x2
            app.Button_x2 = uibutton(app.GridLayout, 'push');
            app.Button_x2.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_x2.Tag = '^2';
            app.Button_x2.BackgroundColor = [0.6353 0.698 0.6235];
            app.Button_x2.FontSize = 32;
            app.Button_x2.Layout.Row = 8;
            app.Button_x2.Layout.Column = 4;
            app.Button_x2.Text = 'x²';

            % Create Button_x3
            app.Button_x3 = uibutton(app.GridLayout, 'push');
            app.Button_x3.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_x3.Tag = '^3';
            app.Button_x3.BackgroundColor = [0.6353 0.698 0.6235];
            app.Button_x3.FontSize = 32;
            app.Button_x3.Layout.Row = 9;
            app.Button_x3.Layout.Column = 4;
            app.Button_x3.Text = 'x³';

            % Create Button_exponential
            app.Button_exponential = uibutton(app.GridLayout, 'push');
            app.Button_exponential.ButtonPushedFcn = createCallbackFcn(app, @basicOperationButton_Pressed, true);
            app.Button_exponential.Tag = '^';
            app.Button_exponential.BackgroundColor = [0.6353 0.698 0.6235];
            app.Button_exponential.FontSize = 32;
            app.Button_exponential.Layout.Row = 7;
            app.Button_exponential.Layout.Column = 4;
            app.Button_exponential.Text = 'xʸ';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = Alp_Doyduk_EE101_TermProject1

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
