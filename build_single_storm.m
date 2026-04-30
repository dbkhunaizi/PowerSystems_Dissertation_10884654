clear; clc;

load('build_baseline_8760.mat');   % loads A_branch, A_gen, A_master, info
load('set_regions_ieee24.mat');    % loads branch_region, mpc

T = 8760;
nBr = size(A_branch,1);


% STORM PARAMETERS
wcrit_tower = 45;   % m/s
wcoll_tower = 150;

wcrit_line  = 30;   % m/s
wcoll_line  = 60;

% CORRIDOR TOWER COUNTS (3 classes based on reactance)

N_short  = 8;
N_medium = 10;
N_long   = 12;

% Default all branches to medium
N_towers_branch = N_medium * ones(nBr,1);

% Use branch reactance as a proxy for relative corridor length
x_branch = abs(mpc.branch(:,4));

% Identify non-transformer lines only
is_line = (mpc.branch(:,9) == 0);

% Reactances of actual transmission lines only
x_lines = x_branch(is_line);

% Split line reactances into 3 groups using terciles
q1 = quantile(x_lines, 1/3);
q2 = quantile(x_lines, 2/3);

for i = 1:nBr
    if is_line(i)
        if x_branch(i) <= q1
            N_towers_branch(i) = N_short;
        elseif x_branch(i) <= q2
            N_towers_branch(i) = N_medium;
        else
            N_towers_branch(i) = N_long;
        end
    else
        % transformer excluded from wind fragility 
        N_towers_branch(i) = 0;
    end
end

fprintf('Short corridors: %d\n', sum((N_towers_branch == N_short)  & is_line));
fprintf('Medium corridors: %d\n', sum((N_towers_branch == N_medium) & is_line));
fprintf('Long corridors: %d\n', sum((N_towers_branch == N_long)   & is_line));
disp('Branch-specific tower counts:')
disp(N_towers_branch')

% =====================================================
% REPAIR MODEL PARAMETERS
% =====================================================
base_repair = 9;    % normal repair time in hours
alpha       = 1.0;  % max extra factor: f(wmax) = 1 + alpha

% =====================================================
% SPATIAL FOOTPRINT PARAMETERS
% =====================================================
k1 = 0.7;    % adjacent region wind reduction factor
k2 = 0.4;    % far region wind reduction factor

% =====================================================
% SEVERITY CASES
% =====================================================
severity_list = {'low','medium','high'};
Nmc = 20;   % iteration value

for s = 1:length(severity_list)

    severity_case = severity_list{s};

    fprintf('\n=================================================\n');
    fprintf('Running storm severity case: %s\n', upper(severity_case));
    fprintf('=================================================\n');

    % ---------------------------------------------
    % Severity-dependent GPD parameters
    % ---------------------------------------------
    switch lower(severity_case)
        case 'low'
            u    = 30;
            B    = 10;
            e    = 0.0;
            wmax = 55;

        case 'medium'
            u    = 40;
            B    = 20;
            e    = 0.1;
            wmax = 75;

        case 'high'
            u    = 50;
            B    = 25;
            e    = 0.15;
            wmax = 100;

        otherwise
            error('severity_case must be low, medium, or high.');
    end

    % ---------------------------------------------
    % Preallocate summary arrays for this severity
    % ---------------------------------------------
    storm_start_all       = zeros(Nmc,1);
    storm_duration_all    = zeros(Nmc,1);
    storm_end_all         = zeros(Nmc,1);
    start_region_all      = zeros(Nmc,1);
    w_peak_all            = zeros(Nmc,1);
    n_failed_branches_all = zeros(Nmc,1);

    for mc = 1:Nmc

        fprintf('\n--- %s storm, Monte Carlo run %d of %d ---\n', ...
            upper(severity_case), mc, Nmc);

        % Reset storm damage matrix for this realization
        A_storm_branch = ones(nBr, T);

    % =====================================================
    % SAMPLE ONE MOVING STORM
    % =====================================================
    storm_start_hour = randi([1 T]);
    storm_duration   = randi([2 12]);
    storm_end_hour   = min(T, storm_start_hour + storm_duration - 1);

    start_region = randi([1 3]);   % 1=North, 2=Middle, 3=South

    % Define storm-center path
    % Regions are ordered as: 1 = North, 2 = Middle, 3 = South
    if start_region == 1
        storm_path = [1 2 3];
    elseif start_region == 3
        storm_path = [3 2 1];
    else
        if rand < 0.5
            storm_path = [2 1 2 3];
        else
            storm_path = [2 3 2 1];
        end
    end

    nRegionsInPath = length(storm_path);

    % Time spent in each storm-center location , Time is equally split in
    % regions as a model assumption
    region_duration = ceil(storm_duration / nRegionsInPath);

    fprintf('Storm starts at hour %d in region %d\n', storm_start_hour, start_region);
    fprintf('Storm total duration = %d hours\n', storm_duration);
    fprintf('Storm path = ');
    fprintf('%d ', storm_path);
    fprintf('\n');
    fprintf('Region duration per path step = %d hours\n', region_duration);

    % =====================================================
    % SAMPLE STORM PEAK WIND FROM GPD
    % =====================================================
    U_peak = min(rand, 0.9999);

    if abs(e) < 1e-8
        w_peak = u - B*log(1-U_peak);
    else
        w_peak = u + (B/e)*((1-U_peak)^(-e) - 1);
    end

    % Cap for physical realism
    w_peak = min(w_peak, wmax);

    fprintf('Sampled storm peak wind = %.2f m/s\n', w_peak);

    % =====================================================
    % BUILD TEMPORAL STORM PROFILE
    % Rule:
    % 2-4 hours  -> triangular
    % 5-7 hours  -> trapezoid with 1 peak hour
    % 8-12 hours -> trapezoid with 2 peak hours
    % =====================================================
    min_frac = 0.6;
    profile  = zeros(storm_duration,1);

    if storm_duration >= 2 && storm_duration <= 4
        % -----------------------------
        % TRIANGULAR PROFILE
        % -----------------------------
        if storm_duration == 2
            profile = [min_frac; 1.0];
        else
            peak_pos = ceil(storm_duration/2);

            for t = 1:storm_duration
                if t <= peak_pos
                    if peak_pos == 1
                        profile(t) = 1.0;
                    else
                        profile(t) = min_frac + (1-min_frac)*(t-1)/(peak_pos-1);
                    end
                else
                    denom = storm_duration - peak_pos;
                    if denom == 0
                        profile(t) = min_frac;
                    else
                        profile(t) = min_frac + (1-min_frac)*(storm_duration-t)/denom;
                    end
                end
            end
        end

    elseif storm_duration >= 5 && storm_duration <= 7
        % -----------------------------
        % TRAPEZOID WITH 1 PEAK HOUR
        % -----------------------------
        n_peak  = 1;
        n_rem   = storm_duration - n_peak;
        n_rise  = floor(n_rem/2);
        n_decay = n_rem - n_rise;

        rise_part  = linspace(min_frac, 1.0, n_rise+1);
        rise_part  = rise_part(1:end-1);
        peak_part  = 1.0;
        decay_part = linspace(1.0, min_frac, n_decay+1);
        decay_part = decay_part(2:end);

        profile = [rise_part, peak_part, decay_part]';

    elseif storm_duration >= 8 && storm_duration <= 12
        % -----------------------------
        % TRAPEZOID WITH 2 PEAK HOURS
        % -----------------------------
        n_peak  = 2;
        n_rem   = storm_duration - n_peak;
        n_rise  = floor(n_rem/2);
        n_decay = n_rem - n_rise;

        rise_part  = linspace(min_frac, 1.0, n_rise+1);
        rise_part  = rise_part(1:end-1);
        peak_part  = ones(1, n_peak);
        decay_part = linspace(1.0, min_frac, n_decay+1);
        decay_part = decay_part(2:end);

        profile = [rise_part, peak_part, decay_part]';

    else
        error('storm_duration must be between 2 and 12 hours.');
    end

    disp('Storm profile multipliers:')
    disp(profile')

    w_hourly = w_peak * profile;

    disp('Hourly storm-center wind speeds (m/s):')
    disp(w_hourly')

    disp('Hour-by-hour storm-center wind:')
    for t = 1:storm_duration
        fprintf('Storm hour %d: profile = %.3f, wind = %.2f m/s\n', ...
            t, profile(t), w_hourly(t));
    end

   if mc == 1
    figure;
    plot(1:storm_duration, w_hourly, '-o');
    xlabel('Storm hour');
    ylabel('Wind speed (m/s)');
    title(['Hourly storm-center wind profile - ' upper(severity_case)]);
    grid on;
end

    % =====================================================
    % HOURLY MOVING STORM LOOP
    % =====================================================
    for h = storm_start_hour : storm_end_hour

        % ---------------------------------------------
        % Determine storm-center region at hour h
        % ---------------------------------------------
        elapsed_hours = h - storm_start_hour;
        path_index = floor(elapsed_hours / region_duration) + 1;
        path_index = min(path_index, nRegionsInPath);

        current_region = storm_path(path_index);

        % ---------------------------------------------
        % Storm-center wind from temporal storm profile
        % ---------------------------------------------
        storm_hour_index = h - storm_start_hour + 1;
        w = w_hourly(storm_hour_index);

        % ---------------------------------------------
        % Assign spatial footprint wind to all regions
        % ---------------------------------------------
        w_region = zeros(3,1);

        for r = 1:3
            d = abs(r - current_region);

            if d == 0
                w_region(r) = w;
            elseif d == 1
                w_region(r) = k1 * w;
            else
                w_region(r) = k2 * w;
            end
        end

        % ---------------------------------------------
        % Loop over all regions using their footprint wind
        % ---------------------------------------------
        for r = 1:3

            w_r = w_region(r);
            affected_branches = find(branch_region == r);

            for i = affected_branches'

                % Skip transformers / non-line branches
                if ~is_line(i)
                    continue;
                end

                % Skip if branch already out due to storm at this hour
                if A_storm_branch(i,h) == 0
                    continue;
                end

                % ---------------------------------------------
                % Tower fragility using region-specific wind
                % ---------------------------------------------
                if w_r <= wcrit_tower
                    P_tower = 0;
                elseif w_r >= wcoll_tower
                    P_tower = 1;
                else
                    P_tower = (w_r - wcrit_tower) / (wcoll_tower - wcrit_tower);
                end

                % Corridor probability using branch-specific tower count
                Ni = N_towers_branch(i);
                P_corr = 1 - (1 - P_tower)^Ni;

                % ---------------------------------------------
                % Conductor fragility using region-specific wind
                % ---------------------------------------------
                if w_r <= wcrit_line
                    P_line = 0;
                elseif w_r >= wcoll_line
                    P_line = 1;
                else
                    P_line = (w_r - wcrit_line) / (wcoll_line - wcrit_line);
                end

                % Combined branch failure probability
                P_fail = 1 - (1 - P_corr) * (1 - P_line);

                % ---------------------------------------------
                % Random failure
                % ---------------------------------------------
                if rand < P_fail

                    % Storm-dependent repair extension
                    repair_factor = 1 + alpha * (w_r - u) / (wmax - u);
                    repair_factor = max(1, min(1 + alpha, repair_factor));

                    repair_time = ceil(base_repair * repair_factor);

                    % Mark branch unavailable from failure hour onward
                    outage_end = min(T, h + repair_time - 1);
                    A_storm_branch(i, h:outage_end) = 0;
                end
            end
        end
    end

    % =====================================================
    % COMBINE WITH BASELINE
    % =====================================================
    A_total_branch = A_branch & A_storm_branch;

    failed_branches_any = find(any(A_storm_branch == 0, 2));
    n_failed_branches = length(failed_branches_any);

storm_start_all(mc)       = storm_start_hour;
storm_duration_all(mc)    = storm_duration;
storm_end_all(mc)         = storm_end_hour;
start_region_all(mc)      = start_region;
w_peak_all(mc)            = w_peak;
n_failed_branches_all(mc) = n_failed_branches;

    fprintf('Number of branches affected by %s storm = %d\n', ...
        severity_case, n_failed_branches);

    % =====================================================
    % SAVE RESULTS
    % =====================================================
    save(['storm_result_' severity_case '_mc' num2str(mc) '.mat'], ...
     'A_branch', 'A_storm_branch', 'A_total_branch', ...
     'storm_start_hour', 'storm_duration', 'storm_end_hour', ...
     'storm_path', 'start_region', 'region_duration', ...
     'N_towers_branch', 'k1', 'k2', ...
     'severity_case', 'u', 'B', 'e', 'wmax', ...
     'w_peak', 'w_hourly', 'profile', ...
     'failed_branches_any', 'n_failed_branches');
   disp(['Saved: storm_result_' severity_case '_mc' num2str(mc) '.mat']);
    end

% Save summary for this severity case
    save(['storm_summary_' severity_case '_MC.mat'], ...
        'storm_start_all', 'storm_duration_all', 'storm_end_all', ...
        'start_region_all', 'w_peak_all', 'n_failed_branches_all', ...
        'severity_case', 'Nmc', 'u', 'B', 'e', 'wmax');

end   % closes for s = 1:length(severity_list)

disp('All storm severity cases completed.');
