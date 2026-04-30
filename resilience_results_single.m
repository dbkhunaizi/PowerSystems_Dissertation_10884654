% Run the resilience of each iteration and calculate summary metrics
clear; clc;
define_constants;

storm_file = 'storm_result_high_mc20.mat';   % change this for each case
save_file  = 'yearly_resilience_high_mc20.mat';

load(storm_file, 'A_total_branch');
load('build_baseline_8760.mat', 'A_gen');
mpc_base = loadcase('case24_ieee_rts');

T = size(A_total_branch, 2);
voll = 10000;
curtail_tol = 1e-3;

total_curtail_hourly   = zeros(T,1);
disconnected_curtail   = zeros(T,1);
opf_success            = false(T,1);
n_branch_out_hourly    = zeros(T,1);
n_gen_out_hourly       = zeros(T,1);
failed_hours_case      = [];

for h = 1:T
    branch_availability_h = A_total_branch(:,h);
    gen_availability_h    = A_gen(:,h);

    n_branch_out_hourly(h) = sum(~logical(branch_availability_h));
    n_gen_out_hourly(h)    = sum(~logical(gen_availability_h));

    try
        warning('off','all');
        out = run_mlc_opf_hour(mpc_base, branch_availability_h, gen_availability_h, voll);
        warning('on','all');

        opf_success(h) = logical(out.success);

        if out.success
            total_curtail_hourly(h) = out.total_curtail;
            disconnected_curtail(h) = out.disconnected_curtail;

            if out.total_curtail > curtail_tol
                fprintf('Hour %d: total curtailed load = %.4f MW\n', h, out.total_curtail);
            end

        else
            failed_hours_case = [failed_hours_case; h];

            if isfield(out, 'disconnected_curtail') && ~isnan(out.disconnected_curtail)
                total_curtail_hourly(h) = out.disconnected_curtail;
                disconnected_curtail(h) = out.disconnected_curtail;

                fprintf('Hour %d: OPF unresolved | disconnected-load fallback = %.4f MW\n', ...
                    h, total_curtail_hourly(h));
            else
                total_curtail_hourly(h) = NaN;
                disconnected_curtail(h) = NaN;

                fprintf('Hour %d: OPF unresolved | curtailment unknown\n', h);
            end
        end

    catch ME
        warning('on','all');
        opf_success(h) = false;
        failed_hours_case = [failed_hours_case; h];

        total_curtail_hourly(h) = NaN;
        disconnected_curtail(h) = NaN;

        fprintf('Hour %d: Error - %s\n', h, ME.message);
    end
end

% ---------------------------------------------------------
% Summary metrics
% ---------------------------------------------------------
real_curtail = total_curtail_hourly;
real_curtail(real_curtail < curtail_tol) = 0;

ENS_case = sum(real_curtail, 'omitnan');              % MWh over 1-hour steps
hours_with_curtail = sum(real_curtail > 0, 'omitnan');
LOLP_case = hours_with_curtail / T;

n_failed_hours = sum(~opf_success);
max_hourly_curtail = max(real_curtail, [], 'omitnan');
total_branch_outage_hours = sum(n_branch_out_hourly);
mean_branches_out_per_hour = mean(n_branch_out_hourly);

if any(~opf_success)
    mean_branches_out_failed_hours = mean(n_branch_out_hourly(~opf_success));
    max_branches_out_failed_hours  = max(n_branch_out_hourly(~opf_success));
else
    mean_branches_out_failed_hours = 0;
    max_branches_out_failed_hours  = 0;
end

fprintf('\nTotal curtailed energy across the year (ENS) = %.4f MWh\n', ENS_case);
fprintf('Number of failed hours = %d\n', n_failed_hours);
fprintf('Hours with curtailment = %d\n', hours_with_curtail);
fprintf('LOLP = %.6f\n', LOLP_case);
fprintf('Maximum hourly curtailment = %.4f MW\n', max_hourly_curtail);

save(save_file, ...
    'total_curtail_hourly', 'disconnected_curtail', 'opf_success', ...
    'ENS_case', 'LOLP_case', 'hours_with_curtail', 'n_failed_hours', ...
    'max_hourly_curtail', 'failed_hours_case', ...
    'n_branch_out_hourly', 'n_gen_out_hourly', ...
    'total_branch_outage_hours', 'mean_branches_out_per_hour', ...
    'mean_branches_out_failed_hours', 'max_branches_out_failed_hours', ...
    'voll', 'curtail_tol', 'T');

disp(['Saved: ' save_file]);