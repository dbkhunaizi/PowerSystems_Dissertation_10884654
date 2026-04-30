clear; clc; close all;

severity = 'medium';
load(sprintf('summary_%s_allruns.mat', severity));

% -----------------------------
% Histograms
% -----------------------------
figure;
histogram(EENS_all, 'Normalization', 'probability');
xlabel('EENS (MWh)');
ylabel('Proportion of Runs');
title(sprintf('%s Severity: Distribution of EENS', upper(severity)));
grid on;

figure;
histogram(LOLP_all, 'Normalization', 'probability');
xlabel('LOLP');
ylabel('Proportion of Runs');
title(sprintf('%s Severity: Distribution of LOLP', upper(severity)));
grid on;

% -----------------------------
% Scatter plots of all runs
% -----------------------------
figure;
plot(1:length(EENS_all), sort(EENS_all), 'o-', 'LineWidth', 1.2);
xlabel('Ordered Run Index');
ylabel('EENS (MWh)');
title(sprintf('%s Severity: Ordered EENS Values', upper(severity)));
grid on;

figure;
plot(1:length(LOLP_all), sort(LOLP_all), 'o-', 'LineWidth', 1.2);
xlabel('Ordered Run Index');
ylabel('LOLP');
title(sprintf('%s Severity: Ordered LOLP Values', upper(severity)));
grid on;

% -----------------------------
% Summary statistics
% -----------------------------
EENS_sorted = sort(EENS_all);
LOLP_sorted = sort(LOLP_all);

n = length(EENS_sorted);

q1_EENS = EENS_sorted(max(1, round(0.25*n)));
med_EENS = EENS_sorted(max(1, round(0.50*n)));
q3_EENS = EENS_sorted(max(1, round(0.75*n)));

q1_LOLP = LOLP_sorted(max(1, round(0.25*n)));
med_LOLP = LOLP_sorted(max(1, round(0.50*n)));
q3_LOLP = LOLP_sorted(max(1, round(0.75*n)));

fprintf('\n--- %s severity quartile summary ---\n', upper(severity));
fprintf('EENS: Q1 = %.4f, Median = %.4f, Q3 = %.4f\n', q1_EENS, med_EENS, q3_EENS);
fprintf('LOLP: Q1 = %.6f, Median = %.6f, Q3 = %.6f\n', q1_LOLP, med_LOLP, q3_LOLP);