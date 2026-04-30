clear; clc; close all;


severity = 'high';      % 'low', 'medium', or 'high'
N = 20;                % number of Monte Carlo runs
curtail_tol = 1e-3;

% -----------------------------
% PREALLOCATE
% -----------------------------
EENS_all = zeros(N,1);
LOLP_all = zeros(N,1);
failed_hours_all = zeros(N,1);

storm_start_all = NaN(N,1);
storm_end_all   = NaN(N,1);

all_curtail = cell(N,1);
all_success = cell(N,1);

% -----------------------------
% LOAD ALL RUNS
% -----------------------------
for k = 1:N
    yearly_file = sprintf('yearly_resilience_%s_mc%d.mat', severity, k);
    storm_file  = sprintf('storm_result_%s_mc%d.mat', severity, k);

    % Load yearly results
    A = load(yearly_file);

    EENS_all(k) = A.ENS_case;
    LOLP_all(k) = A.LOLP_case;
    failed_hours_all(k) = A.n_failed_hours;

    all_curtail{k} = A.total_curtail_hourly;
    all_success{k} = A.opf_success;

    % Load storm timing if available
    if isfile(storm_file)
        S = load(storm_file);
        if isfield(S, 'storm_start_hour')
            storm_start_all(k) = S.storm_start_hour;
        end
        if isfield(S, 'storm_end_hour')
            storm_end_all(k) = S.storm_end_hour;
        end
    end
end

% -----------------------------
% SUMMARY STATISTICS
% -----------------------------
mean_EENS = mean(EENS_all);
std_EENS  = std(EENS_all);
p5_EENS   = prctile(EENS_all, 5);
p95_EENS  = prctile(EENS_all, 95);

mean_LOLP = mean(LOLP_all);
std_LOLP  = std(LOLP_all);
p5_LOLP   = prctile(LOLP_all, 5);
p95_LOLP  = prctile(LOLP_all, 95);

fprintf('\n=== %s severity summary ===\n', upper(severity));
fprintf('Mean EENS   = %.4f MWh\n', mean_EENS);
fprintf('Std EENS    = %.4f MWh\n', std_EENS);
fprintf('5th %% EENS  = %.4f MWh\n', p5_EENS);
fprintf('95th %% EENS = %.4f MWh\n', p95_EENS);

fprintf('\nMean LOLP   = %.6f\n', mean_LOLP);
fprintf('Std LOLP    = %.6f\n', std_LOLP);
fprintf('5th %% LOLP  = %.6f\n', p5_LOLP);
fprintf('95th %% LOLP = %.6f\n', p95_LOLP);

% -----------------------------
% WORST CASE BY EENS
% -----------------------------
[worst_EENS, worst_idx] = max(EENS_all);
fprintf('\nWorst-case EENS run = mc%d\n', worst_idx);
fprintf('Worst-case EENS     = %.4f MWh\n', worst_EENS);
fprintf('Worst-case LOLP     = %.6f\n', LOLP_all(worst_idx));

worst_curtail = all_curtail{worst_idx};
worst_success = all_success{worst_idx};

storm_start = storm_start_all(worst_idx);
storm_end   = storm_end_all(worst_idx);

fprintf('Storm window: hour %d to %d\n', storm_start, storm_end);

% Save summary
save(sprintf('summary_%s_allruns.mat', severity), ...
    'EENS_all', 'LOLP_all', 'failed_hours_all', ...
    'mean_EENS', 'std_EENS', 'p5_EENS', 'p95_EENS', ...
    'mean_LOLP', 'std_LOLP', 'p5_LOLP', 'p95_LOLP', ...
    'worst_idx', 'worst_EENS', 'worst_curtail', 'worst_success', ...
    'storm_start_all', 'storm_end_all');

disp('Saved summary file.');