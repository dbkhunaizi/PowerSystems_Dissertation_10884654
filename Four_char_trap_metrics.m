% Evaulate worst case scenario from each severity
clear; clc;

severity = 'low';   % change as needed
Pd_total = 2850;       % MW
curtail_tol = 1e-3;

load(sprintf('event_summary_%s.mat', severity));

% Use worst EVENT run, not worst annual EENS run
curtail = all_curtail{worst_event_idx};
curtail(curtail < curtail_tol) = 0;

storm_start = storm_start_all(worst_event_idx);
storm_end   = storm_end_all(worst_event_idx);

annual_EENS = Annual_EENS_all(worst_event_idx);
annual_LOLP = LOLP_all(worst_event_idx);

performance = 1 - (curtail / Pd_total);
performance(performance < 0) = 0;

event_hours = storm_start:storm_end;

% Event ENS
event_ENS = sum(curtail(event_hours), 'omitnan');

% Peak curtailment during event
peak_curtail = max(curtail(event_hours));

% Pre-disturbance performance (use 3 hours before event if available)
pre_hours = max(1, storm_start-3):storm_start-1;
if isempty(pre_hours)
    phi = 1.0;
else
    phi = mean(performance(pre_hours), 'omitnan');
end

% Minimum performance during event
[min_perf, idx_min] = min(performance(event_hours));
min_hour = event_hours(idx_min);

% First drop below phi within event window
drop_local = find(performance(event_hours) < phi - 1e-6, 1, 'first');
if ~isempty(drop_local)
    drop_hour = event_hours(drop_local);
    Lambda = min_hour - drop_hour;
else
    drop_hour = NaN;
    Lambda = NaN;
end

% First recovery back to phi after minimum
recover_idx = find(performance(min_hour:end) >= phi - 1e-6, 1, 'first');
if ~isempty(recover_idx)
    recover_hour = min_hour + recover_idx - 1;
    Pi = recover_hour - min_hour;
else
    recover_hour = NaN;
    Pi = NaN;
end

% Area of performance loss over storm event only
E = sum(1 - performance(event_hours), 'omitnan');

fprintf('\n=== Worst-event resilience characteristics ===\n');
fprintf('Worst event run index        = mc%d\n', worst_event_idx);
fprintf('Annual EENS in same run      = %.4f MWh\n', annual_EENS);
fprintf('Annual LOLP in same run      = %.6f\n', annual_LOLP);
fprintf('Event ENS                    = %.4f MWh\n', event_ENS);
fprintf('Peak curtailment             = %.4f MW\n', peak_curtail);
fprintf('Pre-disturbance performance  = %.4f\n', phi);
fprintf('Minimum performance          = %.4f\n', min_perf);
fprintf('Degradation time Lambda      = %.2f h\n', Lambda);
fprintf('Recovery time Pi             = %.2f h\n', Pi);
fprintf('Area of performance loss E   = %.4f\n', E);

save(sprintf('worstevent_metrics_%s_mc%d.mat', severity, worst_event_idx), ...
    'event_ENS', 'peak_curtail', 'phi', 'min_perf', 'Lambda', 'Pi', 'E', ...
    'storm_start', 'storm_end', 'worst_event_idx', 'annual_EENS', 'annual_LOLP');