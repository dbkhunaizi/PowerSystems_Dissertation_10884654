function [A_branch, A_gen, A_master, info] = build_baseline_availability_8760(mpc, seed)
%BUILD_BASELINE_AVAILABILITY_8760
% Creates chronological baseline availability matrices over 8760 hours
% uses 2-state sequential Monte Carlo model

% Outputs:
%   A_branch : nl x 8760   (1 = up, 0 = down)
%   A_gen    : ng x 8760   (1 = up, 0 = down)
%   A_master : (nl+ng) x 8760   stacked [A_branch; A_gen]
%   info     : struct with rates and summary info
%
% Assumptions:
%   1. same failure rate for every branch
%   2. same repair rate for every branch 
%   3. failure rate = 4 outages/year
%   4. mean repair time = 9 hours

    define_constants;

    if nargin < 2
        seed = [];
    end
    if ~isempty(seed)
        rng(seed);
    end

    % -----------------------------
    % Load system sizes
    % -----------------------------
    nl = size(mpc.branch, 1);
    ng = size(mpc.gen, 1);
    T  = 8760;

    % -----------------------------
    % Baseline rates
    % -----------------------------
    lambda_year = 4;        % failures per year
    lambda = lambda_year / 8760;   % failures per hour
    mu = 1 / 9;             % repair rate per hour

    % -----------------------------
    % Preallocate availability matrices
    % -----------------------------
    A_branch = ones(nl, T);
    A_gen    = ones(ng, T);

    % -----------------------------
    % Build branch availability rows
    % -----------------------------
    for i = 1:nl
        A_branch(i, :) = one_component_timeline(T, lambda, mu);
    end

    % -----------------------------
    % Build generator availability rows
    % -----------------------------
    for i = 1:ng
        A_gen(i, :) = one_component_timeline(T, lambda, mu);
    end

    % -----------------------------
    % Stack into one master matrix
    % -----------------------------
    A_master = [A_branch; A_gen];

    % -----------------------------
    % Info struct
    % -----------------------------
    info = struct();
    info.T = T;
    info.nl = nl;
    info.ng = ng;
    info.lambda_year = lambda_year;
    info.lambda_per_hour = lambda;
    info.mu_per_hour = mu;
    info.mean_repair_hours = 1 / mu;
    info.branch_avg_availability = mean(A_branch(:));
    info.gen_avg_availability = mean(A_gen(:));
end


function A = one_component_timeline(T, lambda, mu)
%ONE_COMPONENT_TIMELINE
% Generates one 1 x T up/down timeline using exponential up/down durations.
%
% State convention:
%   1 = component up
%   0 = component down

    A = ones(1, T);

    t = 1;
    state = 1;   % start in service

    while t <= T
        if state == 1
            % Up-state duration
            dur = -log(rand) / lambda;
            dur = max(1, ceil(dur));

            t_end = min(T, t + dur - 1);
            A(t:t_end) = 1;

            t = t_end + 1;
            state = 0;

        else
            % Down-state duration
            dur = -log(rand) / mu;
            dur = max(1, ceil(dur));

            t_end = min(T, t + dur - 1);
            A(t:t_end) = 0;

            t = t_end + 1;
            state = 1;
        end
    end
end