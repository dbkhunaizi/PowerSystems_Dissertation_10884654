clear; clc;
define_constants;

load('build_baseline_8760.mat', 'A_branch', 'A_gen');
load('baseline_mlc_results_8760.mat', 'total_curtail_hourly', 'curtail_tol');
mpc_base = loadcase('case24_ieee_rts');

curtailed_hours = find(total_curtail_hourly > curtail_tol);

for k = 1:length(curtailed_hours)
    h = curtailed_hours(k);

    out = run_mlc_opf_hour(mpc_base, A_branch(:,h), A_gen(:,h), 10000);

    if ~isempty(out.curtail_by_bus)
        keep = out.curtail_by_bus(:,2) > curtail_tol;

        fprintf('\nHour %d | Total curtailment = %.4f MW\n', h, out.total_curtail);
        disp('Buses with meaningful curtailment [bus, MW]:');
        disp(out.curtail_by_bus(keep,:));
    end
end