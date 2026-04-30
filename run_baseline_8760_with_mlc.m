% run_baseline_8760_with_mlc.m
% Yearly baseline AC OPF using island-aware hourly MLC OPF

clear; clc;
define_constants;

load('build_baseline_8760.mat', 'A_branch', 'A_gen');
mpc_base = loadcase('case24_ieee_rts');

T  = size(A_branch, 2);
nl = size(mpc_base.branch, 1);
ng = size(mpc_base.gen, 1);

if size(A_branch,1) ~= nl
    error('A_branch row count does not match number of branches in mpc.');
end

if size(A_gen,1) ~= ng
    error('A_gen row count does not match number of generators in mpc.');
end

voll = 10000;
curtail_tol = 1e-3;

% ---------------------------------------------------------
% Preallocate outputs
% ---------------------------------------------------------
opf_success           = false(T,1);
total_curtail_hourly  = zeros(T,1);
disconnected_curtail  = zeros(T,1);
n_branch_out_hourly   = zeros(T,1);
n_gen_out_hourly      = zeros(T,1);

% optional storage
failed_hours_baseline = [];

% ---------------------------------------------------------
% Hourly loop
% ---------------------------------------------------------
for h = 1:T
    if mod(h,500) == 0 || h == 1 || h == T
        fprintf('Running baseline MLC OPF hour %d of %d...\n', h, T);
    end

    branch_availability_h = A_branch(:,h);
    gen_availability_h    = A_gen(:,h);

    n_branch_out_hourly(h) = sum(~logical(branch_availability_h));
    n_gen_out_hourly(h)    = sum(~logical(gen_availability_h));

    out = run_mlc_opf_hour(mpc_base, branch_availability_h, gen_availability_h, voll);

    opf_success(h) = logical(out.success);

    if out.success
        total_curtail_hourly(h) = out.total_curtail;
        disconnected_curtail(h) = out.disconnected_curtail;

        if out.total_curtail > curtail_tol
            fprintf('Hour %d: total curtailed load = %.4f MW\n', h, out.total_curtail);
        end
    else
        % at least count disconnected curtailment if present
        if ~isnan(out.disconnected_curtail)
            total_curtail_hourly(h) = out.disconnected_curtail;
            disconnected_curtail(h) = out.disconnected_curtail;
        else
            total_curtail_hourly(h) = 0;
            disconnected_curtail(h) = 0;
        end

        failed_hours_baseline = [failed_hours_baseline; h];
        fprintf('Hour %d: OPF unresolved | assigned curtailment = %.4f MW\n', ...
            h, total_curtail_hourly(h));
    end
end

% ---------------------------------------------------------
% Summary metrics
% ---------------------------------------------------------
hours_successful = sum(opf_success);
hours_failed     = T - hours_successful;
success_rate     = hours_successful / T;

hours_curtailed = sum(total_curtail_hourly > curtail_tol);
LOLP_baseline   = hours_curtailed / T;

ENS_MWh        = sum(total_curtail_hourly);
max_curtail_MW = max(total_curtail_hourly);

mean_curtail_ifany = mean(total_curtail_hourly(total_curtail_hourly > curtail_tol));
if isempty(mean_curtail_ifany) || isnan(mean_curtail_ifany)
    mean_curtail_ifany = 0;
end

% branch outage metrics
total_branch_outage_hours = sum(n_branch_out_hourly);
mean_branches_out_per_hour = mean(n_branch_out_hourly);

if any(~opf_success)
    mean_branches_out_failed_hours = mean(n_branch_out_hourly(~opf_success));
    max_branches_out_failed_hours  = max(n_branch_out_hourly(~opf_success));
else
    mean_branches_out_failed_hours = 0;
    max_branches_out_failed_hours  = 0;
end

fprintf('\n============================================\n');
fprintf('BASELINE 8760-HOUR MLC OPF SUMMARY\n');
fprintf('============================================\n');
fprintf('Successful OPF hours                 = %d\n', hours_successful);
fprintf('Failed OPF hours                     = %d\n', hours_failed);
fprintf('OPF success rate                     = %.4f\n', success_rate);
fprintf('Hours with load curtailment          = %d\n', hours_curtailed);
fprintf('Baseline LOLP                        = %.6f\n', LOLP_baseline);
fprintf('Total ENS (MWh)                      = %.4f\n', ENS_MWh);
fprintf('Maximum hourly curtailment (MW)      = %.4f\n', max_curtail_MW);
fprintf('Mean curtailment if disrupted (MW)   = %.4f\n', mean_curtail_ifany);
fprintf('Total branch outage-hours            = %d\n', total_branch_outage_hours);
fprintf('Mean branches out per hour           = %.4f\n', mean_branches_out_per_hour);
fprintf('Mean branches out in failed hours    = %.4f\n', mean_branches_out_failed_hours);
fprintf('Max branches out in failed hours     = %d\n', max_branches_out_failed_hours);

fprintf('\nBaseline failed hours:\n');
disp(failed_hours_baseline(:)');

% ---------------------------------------------------------
% Save results
% ---------------------------------------------------------
save('baseline_mlc_results_8760.mat', ...
    'opf_success', 'total_curtail_hourly', 'disconnected_curtail', ...
    'n_branch_out_hourly', 'n_gen_out_hourly', ...
    'hours_successful', 'hours_failed', 'success_rate', ...
    'hours_curtailed', 'LOLP_baseline', 'ENS_MWh', ...
    'max_curtail_MW', 'mean_curtail_ifany', ...
    'total_branch_outage_hours', 'mean_branches_out_per_hour', ...
    'mean_branches_out_failed_hours', 'max_branches_out_failed_hours', ...
    'failed_hours_baseline', 'voll', 'curtail_tol', 'T');

disp('Saved: baseline_mlc_results_8760.mat');

% ---------------------------------------------------------
% Quick plots
% ---------------------------------------------------------
figure;
plot(total_curtail_hourly);
xlabel('Hour');
ylabel('Curtailed load (MW)');
title('Baseline hourly curtailed load');
grid on;

figure;
plot(double(opf_success));
xlabel('Hour');
ylabel('OPF success (1 = yes, 0 = no)');
title('Baseline hourly OPF success');
grid on;