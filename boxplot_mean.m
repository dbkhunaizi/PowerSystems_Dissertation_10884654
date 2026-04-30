%% Manual Boxplots for Annual EENS and LOLP without Statistics Toolbox
% Includes:
% - EENS and LOLP panels
% - Baseline dashed lines
% - Mean shown as x marker
% - Median shown as horizontal line
% - Whiskers = 5th to 95th percentile
% - Individual Monte Carlo realisations overlaid

clear; clc; close all;

%% 1) Settings
severity_names = {'Low', 'Medium', 'High'};
severity_files = {'low', 'medium', 'high'};
Nmc = 20;

curtail_tol = 1e-3;
T = 8760;

% Baseline values from your baseline case
baseline_EENS = 5887.32;     % MWh
baseline_LOLP = 0.005365;   % probability

%% 2) Preallocate
annual_EENS = NaN(Nmc, numel(severity_names));
annual_LOLP = NaN(Nmc, numel(severity_names));

%% 3) Load annual EENS and LOLP values
for s = 1:numel(severity_names)

    for mc = 1:Nmc

        result_file = sprintf('yearly_resilience_%s_mc%d.mat', severity_files{s}, mc);

        if ~isfile(result_file)
            warning('File not found: %s', result_file);
            continue;
        end

        load(result_file, 'total_curtail_hourly');

        curtail = total_curtail_hourly(:);
        curtail(curtail < curtail_tol) = 0;

        % Annual EENS/ENS for this Monte Carlo run
        annual_EENS(mc, s) = sum(curtail);   % MWh

        % Annual LOLP for this Monte Carlo run
        annual_LOLP(mc, s) = sum(curtail > 0) / T;

    end
end

%% 4) Manual percentile function without Statistics Toolbox
percentile_manual = @(x,p) interp1( ...
    linspace(0,100,numel(sort(x))), ...
    sort(x), ...
    p, ...
    'linear', ...
    'extrap');

%% 5) Print statistics
fprintf('\n===== Annual EENS and LOLP Statistics =====\n');

for s = 1:numel(severity_names)

    data_EENS = annual_EENS(:, s);
    data_EENS = data_EENS(~isnan(data_EENS));

    data_LOLP = annual_LOLP(:, s);
    data_LOLP = data_LOLP(~isnan(data_LOLP));

    fprintf('\n%s Severity:\n', severity_names{s});

    fprintf('Mean EENS = %.1f MWh\n', mean(data_EENS));
    fprintf('EENS std = %.1f MWh\n', std(data_EENS));
    fprintf('EENS 5th percentile = %.1f MWh\n', percentile_manual(data_EENS, 5));
    fprintf('EENS 95th percentile = %.1f MWh\n', percentile_manual(data_EENS, 95));

    fprintf('Mean LOLP = %.6f\n', mean(data_LOLP));
    fprintf('LOLP std = %.6f\n', std(data_LOLP));
    fprintf('LOLP 5th percentile = %.6f\n', percentile_manual(data_LOLP, 5));
    fprintf('LOLP 95th percentile = %.6f\n', percentile_manual(data_LOLP, 95));

end

%% 6) Create stacked figure
figure;

%% -------------------------------
% Panel A: Annual EENS
%% -------------------------------
subplot(2,1,1);
hold on;

manual_boxplot_with_mean(annual_EENS, severity_names, percentile_manual);

% Baseline EENS line
yline(baseline_EENS, '--', 'Baseline', ...
    'LabelHorizontalAlignment', 'left', ...
    'LabelVerticalAlignment', 'bottom', ...
    'LineWidth', 1.2);

ylabel('Annual EENS (MWh)');
title('(a) Distribution of Annual EENS Across Monte Carlo Realisations');
grid on;
xlim([0.5, numel(severity_names)+0.5]);

hold off;

%% -------------------------------
% Panel B: Annual LOLP
%% -------------------------------
subplot(2,1,2);
hold on;

manual_boxplot_with_mean(annual_LOLP, severity_names, percentile_manual);

% Baseline LOLP line
yline(baseline_LOLP, '--', 'Baseline', ...
    'LabelHorizontalAlignment', 'left', ...
    'LabelVerticalAlignment', 'bottom', ...
    'LineWidth', 1.2);

xlabel('Windstorm Severity');
ylabel('Annual LOLP');
title('(b) Distribution of Annual LOLP Across Monte Carlo Realisations');
grid on;
xlim([0.5, numel(severity_names)+0.5]);

hold off;

%% 7) Optional: improve figure size
set(gcf, 'Position', [100 100 850 700]);

%% ============================================================
% Local function: manual boxplot
% Box = 25th to 75th percentile
% Median = horizontal line
% Whiskers = 5th to 95th percentile
% Mean = x marker
% Dots = individual Monte Carlo realisations
%% ============================================================
function manual_boxplot_with_mean(data_matrix, severity_names, percentile_manual)

    nCases = numel(severity_names);
    box_width = 0.35;

    for s = 1:nCases

        data = data_matrix(:, s);
        data = data(~isnan(data));

        q1  = percentile_manual(data, 25);
        med = percentile_manual(data, 50);
        q3  = percentile_manual(data, 75);
        p5  = percentile_manual(data, 5);
        p95 = percentile_manual(data, 95);
        mu  = mean(data);

        x = s;

        % Whisker line: 5th to 95th percentile
        plot([x x], [p5 p95], 'k-', 'LineWidth', 1.2);

        % Whisker caps
        plot([x-box_width/3 x+box_width/3], [p5 p5], 'k-', 'LineWidth', 1.2);
        plot([x-box_width/3 x+box_width/3], [p95 p95], 'k-', 'LineWidth', 1.2);

        % Box: interquartile range
        rectangle('Position', [x-box_width/2, q1, box_width, q3-q1], ...
            'EdgeColor', 'k', ...
            'LineWidth', 1.2);

        % Median line
        plot([x-box_width/2 x+box_width/2], [med med], 'k-', 'LineWidth', 1.6);

        % Mean marker
        plot(x, mu, 'kx', 'MarkerSize', 9, 'LineWidth', 1.8);

        % Individual Monte Carlo points
        rng(10 + s); % fixed jitter for reproducibility
        jitter = (rand(size(data)) - 0.5) * 0.12;

        scatter(x + jitter, data, 28, 'filled', ...
            'MarkerFaceAlpha', 0.45);

    end

    set(gca, 'XTick', 1:nCases, 'XTickLabel', severity_names);

end