% Purpose: Base Case Results when System is intact

clear; clc;
define_constants;

mpc0 = loadcase('case24_ieee_rts');
results0 = runopf(mpc0);

opf_converged = results0.success;

total_demand_MW = sum(results0.bus(:, PD));
total_generation_MW = sum(results0.gen(:, PG));
total_losses_MW = total_generation_MW - total_demand_MW;

min_voltage_pu = min(results0.bus(:, VM));
max_voltage_pu = max(results0.bus(:, VM));

PF_from = abs(results0.branch(:, PF));
PF_to   = abs(results0.branch(:, PT));
branch_flow = max(PF_from, PF_to);

rateA = results0.branch(:, RATE_A);
branch_loading_percent = NaN(size(branch_flow));
idx = rateA > 0;
branch_loading_percent(idx) = 100 * branch_flow(idx) ./ rateA(idx);

max_branch_loading_percent = max(branch_loading_percent, [], 'omitnan');

base_case_curtailment_MW = 0;
demand_served_percent = 100;

fprintf('BASE CASE RESULTS\n');
fprintf('OPF converged                  = %d\n', opf_converged);
fprintf('Total demand served (MW)       = %.4f\n', total_demand_MW);
fprintf('Total generation dispatched    = %.4f\n', total_generation_MW);
fprintf('Total real power losses (MW)   = %.4f\n', total_losses_MW);
fprintf('Load curtailment (MW)          = %.4f\n', base_case_curtailment_MW);
fprintf('Demand served (%%)              = %.2f\n', demand_served_percent);
fprintf('Minimum bus voltage (p.u.)     = %.4f\n', min_voltage_pu);
fprintf('Maximum bus voltage (p.u.)     = %.4f\n', max_voltage_pu);
fprintf('Maximum branch loading (%%)     = %.4f\n', max_branch_loading_percent);