%% Overlaid Annual ENS vs Worst Event ENS for Low, Medium and High Severity
clear; clc; close all;

%% 1) Define worst-case files for each severity
severity_names = {'Low', 'Medium', 'High'};

resilience_files = {
    'yearly_resilience_low_mc10.mat'
    'yearly_resilience_medium_mc2.mat'
    'yearly_resilience_high_mc16.mat'
};

storm_files = {
    'storm_result_low_mc10.mat'
    'storm_result_medium_mc2.mat'
    'storm_result_high_mc16.mat'
};

%% 2) Preallocate results
nCases = numel(severity_names);

annual_ENS = zeros(nCases,1);
event_ENS  = zeros(nCases,1);
event_share = zeros(nCases,1);

curtail_tol = 1e-3;

%% 3) Loop through each severity
for i = 1:nCases

    load(resilience_files{i}, 'total_curtail_hourly');
    load(storm_files{i}, 'storm_start_hour', 'storm_end_hour');

    curtail = total_curtail_hourly(:);
    curtail(curtail < curtail_tol) = 0;

    % Annual ENS for the simulated year
    annual_ENS(i) = sum(curtail);   % MWh

    % Worst storm-event ENS
    storm_hours = storm_start_hour:storm_end_hour;
    event_ENS(i) = sum(curtail(storm_hours));   % MWh

    if annual_ENS(i) > 0
        event_share(i) = (event_ENS(i) / annual_ENS(i)) * 100;
    else
        event_share(i) = 0;
    end
end

%% 4) Print results
fprintf('\n===== Annual ENS vs Worst Event ENS =====\n');

for i = 1:nCases
    fprintf('\n%s Severity:\n', severity_names{i});
    fprintf('Annual ENS = %.2f MWh\n', annual_ENS(i));
    fprintf('Worst Event ENS = %.2f MWh\n', event_ENS(i));
    fprintf('Event share of annual ENS = %.2f %%\n', event_share(i));
end

%% 5) Overlaid bar chart
x = 1:nCases;

figure;
hold on;

% Large background bars: annual ENS
bar(x, annual_ENS, 0.65, ...
    'FaceColor', [0.2 0.45 0.9], ...
    'EdgeColor', 'none');

% Smaller front bars: worst-event ENS
bar(x, event_ENS, 0.35, ...
    'FaceColor', [0.95 0.45 0.1], ...
    'EdgeColor', 'none');

set(gca, 'XTick', x, 'XTickLabel', severity_names);
xlabel('Windstorm Severity');
ylabel('Energy Not Supplied (MWh)');
title('Annual ENS and Worst-Event ENS by Windstorm Severity');
legend({'Annual ENS', 'Worst-Event ENS'}, 'Location', 'northwest');
grid on;

%% 6) Add percentage labels above orange bars
for i = 1:nCases
    text(x(i), event_ENS(i), sprintf('%.1f%%', event_share(i)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'FontSize', 9);
end

hold off;