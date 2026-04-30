function out = run_mlc_opf_hour(mpc_base, branch_availability, gen_availability, voll)
%RUN_MLC_OPF_HOUR
% One-hour AC OPF with minimum load curtailment (MLC),
% with handling of disconnected islands.

    define_constants;

    if nargin < 4
        voll = 10000;
    end

    % ---------------------------------
    % 0) Start from base case
    % ---------------------------------
    mpc = mpc_base;

    % ---------------------------------
    % 1) Apply branch outages
    % ---------------------------------
    if length(branch_availability) ~= size(mpc.branch, 1)
        error('branch_availability length must match number of branches.');
    end

    mpc.branch(:, BR_STATUS) = double(branch_availability(:));

    % ---------------------------------
    % 1b) Apply generator outages
    % ---------------------------------
    nGenOrigPhysical = size(mpc_base.gen, 1);

    if length(gen_availability) ~= nGenOrigPhysical
        error('gen_availability length must match number of generators.');
    end

    gen_up = logical(gen_availability(:));
    mpc.gen(1:nGenOrigPhysical, GEN_STATUS) = gen_up;

    off_idx = find(~gen_up);
    if ~isempty(off_idx)
        mpc.gen(off_idx, PG)   = 0;
        mpc.gen(off_idx, QG)   = 0;
        mpc.gen(off_idx, PMAX) = 0;
        mpc.gen(off_idx, PMIN) = 0;
        mpc.gen(off_idx, QMAX) = 0;
        mpc.gen(off_idx, QMIN) = 0;
    end

    % Keep original real and reactive load
    Pd_original = mpc.bus(:, PD);
    Qd_original = mpc.bus(:, QD);

    % ---------------------------------
    % 2) Find islands
    % ---------------------------------
    [groups, ~] = find_islands(mpc);

    if isempty(groups)
        out.success = 0;
        out.results = [];
        out.total_curtail = NaN;
        out.curtail_by_bus = [];
        out.load_buses = [];
        out.disconnected_buses = [];
        out.disconnected_curtail = NaN;
        return;
    end

    % ---------------------------------
    % 3) Find the original reference bus
    % ---------------------------------
    ref_row = find(mpc_base.bus(:, BUS_TYPE) == REF, 1);

    if isempty(ref_row)
        error('No reference bus found in base case.');
    end

    ref_bus = mpc_base.bus(ref_row, BUS_I);

    main_group_idx = [];
    for g = 1:length(groups)
        if any(groups{g} == ref_bus)
            main_group_idx = g;
            break;
        end
    end

    if isempty(main_group_idx)
        out.success = 0;
        out.results = [];
        out.total_curtail = NaN;
        out.curtail_by_bus = [];
        out.load_buses = [];
        out.disconnected_buses = [];
        out.disconnected_curtail = NaN;
        return;
    end

    main_group_buses = groups{main_group_idx};

    % ---------------------------------
    % 4) Fully curtail load outside main island
    % ---------------------------------
    all_bus_numbers = mpc.bus(:, BUS_I);
    is_in_main = ismember(all_bus_numbers, main_group_buses);

    disconnected_rows = find(~is_in_main);
    disconnected_buses = all_bus_numbers(disconnected_rows);

    disconnected_curtail = 0;
    disconnected_curtail_by_bus = [];

    for k = 1:length(disconnected_rows)
        r = disconnected_rows(k);
        b = mpc.bus(r, BUS_I);
        pd = Pd_original(r);

        if pd > 0
            disconnected_curtail = disconnected_curtail + pd;
            disconnected_curtail_by_bus = [disconnected_curtail_by_bus; b, pd];
        end

        mpc.bus(r, PD) = 0;
        mpc.bus(r, QD) = 0;
        mpc.bus(r, BUS_TYPE) = NONE;
    end

    % ---------------------------------
    % 5) Turn off generators outside main island
    % ---------------------------------
    gen_bus_numbers = mpc.gen(:, GEN_BUS);
    gen_outside = ~ismember(gen_bus_numbers, main_group_buses);

    mpc.gen(gen_outside, GEN_STATUS) = 0;
    mpc.gen(gen_outside, PG) = 0;
    mpc.gen(gen_outside, QG) = 0;

    % ---------------------------------
    % 6) Turn off branches outside main island
    % ---------------------------------
    from_in = ismember(mpc.branch(:, F_BUS), main_group_buses);
    to_in   = ismember(mpc.branch(:, T_BUS), main_group_buses);
    branch_keep = from_in & to_in;

    mpc.branch(~branch_keep, BR_STATUS) = 0;

    % ---------------------------------
    % 7) Find remaining connected load buses
    % ---------------------------------
    Pd = mpc.bus(:, PD);
    Qd = mpc.bus(:, QD);

    load_idx = find(Pd > 0);
    nLoad = length(load_idx);

    if nLoad == 0
        out.success = 1;
        out.results = [];
        out.total_curtail = disconnected_curtail;
        out.curtail_by_bus = disconnected_curtail_by_bus;
        out.load_buses = [];
        out.disconnected_buses = disconnected_buses;
        out.disconnected_curtail = disconnected_curtail;
        return;
    end

    % ---------------------------------
    % 8) Build fictitious generators
    % ---------------------------------
    fake_gen = zeros(nLoad, size(mpc.gen, 2));

    for k = 1:nLoad
        r = load_idx(k);

        Pd_k = Pd(r);
        Qd_k = Qd(r);

        fake_gen(k, GEN_BUS)    = mpc.bus(r, BUS_I);
        fake_gen(k, PG)         = 0;
        fake_gen(k, QG)         = 0;
        fake_gen(k, QMAX)       = max(Qd_k, 0);
        fake_gen(k, QMIN)       = min(-Qd_k, 0);
        fake_gen(k, VG)         = 1.0;
        fake_gen(k, MBASE)      = mpc.baseMVA;
        fake_gen(k, GEN_STATUS) = 1;
        fake_gen(k, PMAX)       = Pd_k;
        fake_gen(k, PMIN)       = 0;
    end

    nGenOrig = size(mpc.gen, 1);
    mpc.gen = [mpc.gen; fake_gen];

    % ---------------------------------
    % 9) Build matching gencost rows
    % ---------------------------------
    fake_gencost = zeros(nLoad, size(mpc.gencost, 2));

    for k = 1:nLoad
        fake_gencost(k, 1) = 2;
        fake_gencost(k, 2) = 0;
        fake_gencost(k, 3) = 0;
        fake_gencost(k, 4) = 2;
        fake_gencost(k, 5) = voll;
        fake_gencost(k, 6) = 0;
    end

    mpc.gencost = [mpc.gencost; fake_gencost];

    % ---------------------------------
    % 10) Run AC OPF
    % ---------------------------------
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    results = runopf(mpc, mpopt);

    % ---------------------------------
    % 11) Extract curtailment
    % ---------------------------------
    if results.success
        fake_pg = results.gen(nGenOrig+1:end, PG);
        connected_curtail = sum(fake_pg);
        connected_curtail_by_bus = [mpc.bus(load_idx, BUS_I), fake_pg];

        total_curtail = disconnected_curtail + connected_curtail;
        curtail_by_bus = [disconnected_curtail_by_bus; connected_curtail_by_bus];

        out.success = 1;
        out.results = results;
        out.total_curtail = total_curtail;
        out.curtail_by_bus = curtail_by_bus;
        out.load_buses = mpc.bus(load_idx, BUS_I);
        out.disconnected_buses = disconnected_buses;
        out.disconnected_curtail = disconnected_curtail;
    else
        out.success = 0;
        out.results = results;
        out.total_curtail = NaN;
        out.curtail_by_bus = [];
        out.load_buses = mpc.bus(load_idx, BUS_I);
        out.disconnected_buses = disconnected_buses;
        out.disconnected_curtail = disconnected_curtail;
    end
end