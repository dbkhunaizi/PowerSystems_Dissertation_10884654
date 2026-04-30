% runs AC OPF of random baseline outages with minimum load curtailment
% unresolved OPF hours are assigned at least the disconnected demand

clear; clc;
define_constants;

load('build_baseline_8760.mat');    % A_branch, A_gen, A_master, info
load('set_regions_ieee24.mat');     % mpc

mpc_base = mpc;   % keep untouched original case

T  = size(A_branch, 2);
nl = size(mpc_base.branch, 1);
ng = size(mpc_base.gen, 1);
nb = size(mpc_base.bus, 1);

if size(A_branch,1) ~= nl
    error('A_branch row count does not match number of branches in mpc.');
end

if size(A_gen,1) ~= ng
    error('A_gen row count does not match number of generators in mpc.');
end

if T ~= 8760
    warning('Expected T = 8760, but got T = %d.', T);
end

% =========================================================
% MLC / VOLL SETTINGS
% =========================================================
voll = 10000;      % very high curtailment cost
curtail_tol = 1e-3; % MW threshold to ignore numerical noise

% =========================================================
% ADD LOAD CURTAILMENT GENERATORS ONCE TO BASE CASE
% Each load bus gets one fictitious generator
% =========================================================
mpc_mlc = add_mlc_generators(mpc_base, voll);

nGenOrig = ng;
nGenTot  = size(mpc_mlc.gen,1);
nCurtGen = nGenTot - nGenOrig;

fprintf('Original generators       : %d\n', nGenOrig);
fprintf('Curtailment generators    : %d\n', nCurtGen);
fprintf('Total generators in OPF   : %d\n', nGenTot);

% =========================================================
% MATPOWER OPTIONS
% =========================================================
mpopt = mpoption('verbose', 0, 'out.all', 0);

% =========================================================
% PREALLOCATE OUTPUTS
% =========================================================
success_hourly          = false(T,1);
unresolved_flag         = false(T,1);
total_curtail_hourly    = zeros(T,1);
disconnected_demand_MW  = zeros(T,1);
curtailment_by_bus      = NaN(T, nb);
opf_obj_hourly          = NaN(T,1);
n_branch_out_hourly     = zeros(T,1);
n_gen_out_hourly        = zeros(T,1);

% =========================================================
% HOURLY BASELINE OPF LOOP
% =========================================================
for h = 1:T
    if mod(h,500) == 0 || h == 1 || h == T
        fprintf('Running baseline OPF hour %d of %d...\n', h, T);
    end

    mpc_h = mpc_mlc;

    % -----------------------------------------------------
    % Apply branch availability for this hour
    % -----------------------------------------------------
    branch_up = logical(A_branch(:,h));
    mpc_h.branch(:, BR_STATUS) = branch_up;

    % -----------------------------------------------------
    % Apply original generator availability for this hour
    % Curtailment generators always remain available
    % -----------------------------------------------------
    gen_up = logical(A_gen(:,h));

    % First set original generators according to A_gen
    mpc_h.gen(1:nGenOrig, GEN_STATUS) = gen_up;

    % Force unavailable original generators to zero output capability
    off_idx = find(~gen_up);
    if ~isempty(off_idx)
        mpc_h.gen(off_idx, PG)   = 0;
        mpc_h.gen(off_idx, QG)   = 0;
        mpc_h.gen(off_idx, PMAX) = 0;
        mpc_h.gen(off_idx, PMIN) = 0;
        mpc_h.gen(off_idx, QMAX) = 0;
        mpc_h.gen(off_idx, QMIN) = 0;
    end

    % Curtailment generators stay online
    mpc_h.gen(nGenOrig+1:end, GEN_STATUS) = 1;

    n_branch_out_hourly(h) = sum(~branch_up);
    n_gen_out_hourly(h)    = sum(~gen_up);

    % -----------------------------------------------------
    % Run AC OPF
    % -----------------------------------------------------
    try
        warning('off','all');
        results = runopf(mpc_h, mpopt);
        warning('on','all');

        success_hourly(h) = results.success;

        if results.success
            % Curtailment is generation from fictitious generators
            curtail_pg = results.gen(nGenOrig+1:end, PG);

            total_curtail_hourly(h) = sum(curtail_pg);
            opf_obj_hourly(h)       = results.f;

            % Map curtailment back to buses
            curtail_bus_ids = mpc_h.gen(nGenOrig+1:end, GEN_BUS);
            curtail_by_bus_h = zeros(1, nb);

            for k = 1:length(curtail_pg)
                busnum = curtail_bus_ids(k);
                row = find(mpc_h.bus(:, BUS_I) == busnum, 1);

                if ~isempty(row)
                    curtail_by_bus_h(row) = curtail_by_bus_h(row) + curtail_pg(k);
                end
            end

            curtailment_by_bus(h,:) = curtail_by_bus_h;

        else
            % unresolved OPF hour: assign at least disconnected demand
            success_hourly(h) = false;
            unresolved_flag(h) = true;
            disconnected_demand_MW(h) = estimate_disconnected_demand(mpc_h, nGenOrig);
            total_curtail_hourly(h) = disconnected_demand_MW(h);
            opf_obj_hourly(h) = NaN;

            fprintf('Baseline OPF failed at hour %d | assigned disconnected demand = %.4f MW\n', ...
                h, disconnected_demand_MW(h));
        end

    catch ME
        warning('on','all');
        success_hourly(h) = false;
        unresolved_flag(h) = true;
        disconnected_demand_MW(h) = estimate_disconnected_demand(mpc_h, nGenOrig);
        total_curtail_hourly(h) = disconnected_demand_MW(h);
        opf_obj_hourly(h) = NaN;

        fprintf('Hour %d failed with error: %s\n', h, ME.message);
        fprintf('Assigned disconnected demand = %.4f MW\n', disconnected_demand_MW(h));
    end
end

% =========================================================
% SUMMARY METRICS
% =========================================================
hours_successful = sum(success_hourly);
hours_failed     = T - hours_successful;
success_rate     = hours_successful / T;
failed_hours_baseline = find(~success_hourly);

% meaningful curtailment hours using threshold
hours_curtailed = sum(total_curtail_hourly > curtail_tol);

% LOLP estimated from hours with meaningful unserved load
LOLP_baseline = hours_curtailed / T;

% ENS in MWh (1-hour time steps)
ENS_MWh = sum(total_curtail_hourly);

max_curtail_MW = max(total_curtail_hourly);

mean_curtail_ifany = mean(total_curtail_hourly(total_curtail_hourly > curtail_tol));
if isempty(mean_curtail_ifany) || isnan(mean_curtail_ifany)
    mean_curtail_ifany = 0;
end

fprintf('\n============================================\n');
fprintf('BASELINE 8760-HOUR OPF SUMMARY\n');
fprintf('============================================\n');
fprintf('Successful OPF hours            = %d\n', hours_successful);
fprintf('Failed OPF hours                = %d\n', hours_failed);
fprintf('OPF success rate                = %.4f\n', success_rate);
fprintf('Hours with load curtailment     = %d\n', hours_curtailed);
fprintf('Baseline LOLP                   = %.6f\n', LOLP_baseline);
fprintf('Total ENS (MWh)                 = %.4f\n', ENS_MWh);
fprintf('Maximum hourly curtailment (MW) = %.4f\n', max_curtail_MW);
fprintf('Mean curtailment if disrupted   = %.4f\n', mean_curtail_ifany);
fprintf('\nBaseline failed hours:\n');
disp(failed_hours_baseline(:)');

% =========================================================
% SAVE RESULTS
% =========================================================
save('baseline_opf_results_8760.mat', ...
    'success_hourly', 'unresolved_flag', 'total_curtail_hourly', ...
    'disconnected_demand_MW', 'curtailment_by_bus', ...
    'opf_obj_hourly', 'n_branch_out_hourly', 'n_gen_out_hourly', ...
    'hours_successful', 'hours_failed', 'success_rate', ...
    'hours_curtailed', 'LOLP_baseline', 'ENS_MWh', ...
    'max_curtail_MW', 'mean_curtail_ifany', ...
    'failed_hours_baseline', 'voll', 'curtail_tol', 'T');

disp('Saved: baseline_opf_results_8760.mat');

% =========================================================
% OPTIONAL QUICK PLOTS
% =========================================================
figure;
plot(total_curtail_hourly);
xlabel('Hour');
ylabel('Curtailment / assigned unserved load (MW)');
title('Baseline hourly unserved load');
grid on;

figure;
plot(double(success_hourly));
xlabel('Hour');
ylabel('OPF success (1=yes, 0=no)');
title('Baseline OPF success by hour');
grid on;

% =========================================================
% LOCAL FUNCTIONS
% =========================================================
function mpc_out = add_mlc_generators(mpc_in, voll)
    define_constants;

    mpc_out = mpc_in;
    nb = size(mpc_out.bus,1);

    load_buses = find(mpc_out.bus(:, PD) > 0);
    nLoad = numel(load_buses);

    new_gen = zeros(nLoad, size(mpc_out.gen,2));
    new_gencost = zeros(nLoad, size(mpc_out.gencost,2));

    for idx = 1:nLoad
        b = load_buses(idx);
        Pd = mpc_out.bus(b, PD);
        busnum = mpc_out.bus(b, BUS_I);

        % Fictitious generator representing curtailable load
        g = zeros(1, size(mpc_out.gen,2));
        g(GEN_BUS)    = busnum;
        g(PG)         = 0;
        g(QG)         = 0;
        g(QMAX)       = 999;
        g(QMIN)       = -999;
        g(VG)         = 1.0;
        g(MBASE)      = 100;
        g(GEN_STATUS) = 1;
        g(PMAX)       = Pd;
        g(PMIN)       = 0;

        new_gen(idx,:) = g;

        % Polynomial cost: f(P) = voll * P
        c = zeros(1, size(mpc_out.gencost,2));
        c(1) = 2;
        c(2) = 0;
        c(3) = 0;
        c(4) = 2;
        c(5) = voll;
        c(6) = 0;

        new_gencost(idx,:) = c;
    end

    mpc_out.gen     = [mpc_out.gen; new_gen];
    mpc_out.gencost = [mpc_out.gencost; new_gencost];
end

function disconnected_demand = estimate_disconnected_demand(mpc_h, nGenOrig)
    define_constants;

    nb = size(mpc_h.bus,1);
    bus_numbers = mpc_h.bus(:, BUS_I);

    % active branches only
    active_branch = mpc_h.branch(:, BR_STATUS) == 1;

    % build adjacency matrix for active network
    A = sparse(nb, nb);

    for k = find(active_branch)'
        f_bus = mpc_h.branch(k, F_BUS);
        t_bus = mpc_h.branch(k, T_BUS);

        i = find(bus_numbers == f_bus, 1);
        j = find(bus_numbers == t_bus, 1);

        if ~isempty(i) && ~isempty(j)
            A(i,j) = 1;
            A(j,i) = 1;
        end
    end

    G = graph(A);
    comp = conncomp(G);

    % identify components that have at least one available original generator
    online_gen = mpc_h.gen(1:nGenOrig, GEN_STATUS) == 1;
    gen_buses = mpc_h.gen(1:nGenOrig, GEN_BUS);
    online_gen_buses = gen_buses(online_gen);

    supplied_components = false(1, max(comp));

    for b = online_gen_buses'
        idx = find(bus_numbers == b, 1);
        if ~isempty(idx)
            supplied_components(comp(idx)) = true;
        end
    end

    disconnected_demand = 0;

    for i = 1:nb
        if ~supplied_components(comp(i))
            disconnected_demand = disconnected_demand + mpc_h.bus(i, PD);
        end
    end
end