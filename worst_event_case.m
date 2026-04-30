clear; clc;

severity = 'low';      % change to 'medium' or 'high'
Nmc = 20;
curtail_tol = 1e-3;

Event_ENS_all   = nan(Nmc,1);
storm_start_all = nan(Nmc,1);
storm_end_all   = nan(Nmc,1);

for k = 1:Nmc
    yearly_file = sprintf('yearly_resilience_%s_mc%d.mat', severity, k);
    storm_file  = sprintf('storm_result_%s_mc%d.mat', severity, k);

    if ~isfile(yearly_file) || ~isfile(storm_file)
        warning('Missing file for mc%d', k);
        continue;
    end

    % Load hourly curtailment
    S1 = load(yearly_file, 'total_curtail_hourly');
    curtail = S1.total_curtail_hourly;
    curtail(curtail < curtail_tol) = 0;

    % Load storm window
    S2 = load(storm_file, 'storm_start_hour', 'storm_end_hour');

    storm_start = S2.storm_start_hour;
    storm_end   = S2.storm_end_hour;

    storm_start_all(k) = storm_start;
    storm_end_all(k)   = storm_end;

    % Event ENS over storm window only
    event_hours = storm_start:storm_end;
    Event_ENS_all(k) = sum(curtail(event_hours), 'omitnan');
end

% Find worst event by highest Event ENS
[worst_event_ENS, worst_idx] = max(Event_ENS_all);

fprintf('Severity class           = %s\n', upper(severity));
fprintf('Worst event run          = mc%d\n', worst_idx);
fprintf('Worst Event ENS          = %.4f MWh\n', worst_event_ENS);
fprintf('Storm window             = %d to %d\n', ...
    storm_start_all(worst_idx), storm_end_all(worst_idx));