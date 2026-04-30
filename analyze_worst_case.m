clear; clc; close all;

severity = 'low';
load(sprintf('event_summary_%s.mat', severity));   % NOT summary_medium_allruns.mat

curtail_tol = 1e-3;
Pd_total = 2850;

% Use EVENT-worst variables only
curtail = worst_curtail;
curtail(curtail < curtail_tol) = 0;

storm_start = storm_start_all(worst_event_idx);
storm_end   = storm_end_all(worst_event_idx);

performance = 1 - (curtail / Pd_total);
performance(performance < 0) = 0;

pad_before = 12;
pad_after  = 24;

t1 = max(1, storm_start - pad_before);
t2 = min(length(performance), storm_end + pad_after);

t_plot = t1:t2;
perf_plot = performance(t_plot);

phi = mean(performance(max(1,storm_start-3):storm_start-1), 'omitnan');

event_hours = storm_start:storm_end;
[min_perf, idx_min] = min(performance(event_hours));
min_hour = event_hours(idx_min);

drop_local = find(performance(event_hours) < phi - 1e-6, 1, 'first');
if ~isempty(drop_local)
    drop_hour = event_hours(drop_local);
else
    drop_hour = NaN;
end

recover_idx = find(performance(min_hour:end) >= phi - 1e-6, 1, 'first');
if ~isempty(recover_idx)
    recover_hour = min_hour + recover_idx - 1;
else
    recover_hour = NaN;
end

figure;
hold on; box on;

patch([storm_start storm_end storm_end storm_start], ...
      [0 0 1.05 1.05], ...
      [0.90 0.90 0.90], ...
      'EdgeColor', 'none', 'FaceAlpha', 0.35);

plot(t_plot, perf_plot, 'b-', 'LineWidth', 2.2);
yline(phi, '--k', 'LineWidth', 1.0);
xline(storm_start, '--k', 'LineWidth', 1.0);
xline(storm_end, '--k', 'LineWidth', 1.0);
plot(min_hour, min_perf, 'ro', 'MarkerSize', 7, 'LineWidth', 1.5);

xlabel('Hour of Year');
ylabel('Performance, P(t)');
title(sprintf('Worst EVENT Resilience Curve for Low-Severity Storm (mc%d)', worst_event_idx));

xlim([t1 t2]);
ylim([0 1.05]);
yticks(0:0.1:1.0);
grid on;

text(t1 + 4, 1.015, 'Pre-disturbance', 'FontSize', 9);
text((storm_start + storm_end)/2, 1.015, 'Storm window', ...
    'HorizontalAlignment', 'center', 'FontSize', 9);

if ~isnan(drop_hour)
    text((drop_hour + min_hour)/2, 0.72, 'Degradation', ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end

text(min_hour, min_perf - 0.08, ...
    sprintf('Minimum performance = %.3f', min_perf), ...
    'HorizontalAlignment', 'center', 'FontSize', 9);

if ~isnan(recover_hour)
    text((min_hour + recover_hour)/2, min_perf + 0.08, 'Recovery', ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end

hold off;

fprintf('Using worst EVENT run = mc%d\n', worst_event_idx);
fprintf('Worst Event ENS = %.4f MWh\n', worst_event_ENS);
fprintf('Annual EENS in same run = %.4f MWh\n', worst_year_EENS);