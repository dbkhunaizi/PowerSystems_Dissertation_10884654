clear; clc;
define_constants;

% --- Load your IEEE-24 case ---
mpc = loadcase('case24_ieee_rts');

% --- Get bus numbers (MATPOWER uses BUS_I as bus ID) ---
bus_ids = mpc.bus(:, BUS_I);
nb = length(bus_ids);

% =========================================================
% STEP A: ASSIGN EACH BUS TO A REGION (1=NORTH, 2=MID, 3=SOUTH)
% =========================================================
north_buses = [1 2 3 4 5 6 7 8];
mid_buses   = [9 10 11 12 13 14 15 16];
south_buses = [17 18 19 20 21 22 23 24];

% Create region vector aligned to mpc.bus rows
bus_region = zeros(nb,1);

% Helper: map bus IDs -> row indices in mpc.bus
[~, idxN] = ismember(north_buses, bus_ids);
[~, idxM] = ismember(mid_buses,   bus_ids);
[~, idxS] = ismember(south_buses, bus_ids);

% Safety: remove any zeros (bus ID not found)
idxN = idxN(idxN > 0);
idxM = idxM(idxM > 0);
idxS = idxS(idxS > 0);

% Assign regions
bus_region(idxN) = 1;
bus_region(idxM) = 2;
bus_region(idxS) = 3;

% Check if any bus still unassigned
unassigned = find(bus_region == 0);
if ~isempty(unassigned)
    fprintf('Unassigned buses (by BUS_I):\n');
    disp(bus_ids(unassigned)');
    error('Some buses are not assigned to North/Mid/South. Fill the lists.');
end

% Write to MATPOWER bus "AREA" column
mpc.bus(:, BUS_AREA) = bus_region;

% =========================================================
% STEP B: DERIVE BRANCH END REGIONS FROM BUS REGIONS
% =========================================================
fbus = mpc.branch(:, F_BUS);
tbus = mpc.branch(:, T_BUS);

[~, iF] = ismember(fbus, bus_ids);
[~, iT] = ismember(tbus, bus_ids);

areaF = mpc.bus(iF, BUS_AREA);
areaT = mpc.bus(iT, BUS_AREA);

% Store region at both ends of each branch
branch_region_from = areaF;
branch_region_to   = areaT;

% Optional single-label branch region:
% - if both ends are same region -> branch belongs to that region
% - if it connects two regions -> mark as 0 (INTER-AREA)
branch_region = areaF;
branch_region(areaF ~= areaT) = 0;

% =========================================================
% STEP C: DERIVE GENERATOR REGION FROM ITS BUS REGION
% =========================================================
gen_bus = mpc.gen(:, GEN_BUS);
[~, iG] = ismember(gen_bus, bus_ids);
gen_region = mpc.bus(iG, BUS_AREA);

% =========================================================
% STEP D: SAVE OUTPUTS
% =========================================================
save('set_regions_ieee24.mat', ...
    'mpc', 'bus_region', 'branch_region', ...
    'branch_region_from', 'branch_region_to', ...
    'gen_region');

disp('Saved: set_regions_ieee24.mat');

% =========================================================
% STEP E: QUICK SUMMARY
% =========================================================
fprintf('Buses per region: North=%d, Mid=%d, South=%d\n', ...
    sum(bus_region == 1), sum(bus_region == 2), sum(bus_region == 3));

fprintf('Branches (single-label summary): North=%d, Mid=%d, South=%d, Inter-area=%d\n', ...
    sum(branch_region == 1), sum(branch_region == 2), ...
    sum(branch_region == 3), sum(branch_region == 0));

fprintf('Generators: North=%d, Mid=%d, South=%d\n', ...
    sum(gen_region == 1), sum(gen_region == 2), sum(gen_region == 3));

fprintf('Inter-area branches (from-to regions): %d\n', sum(branch_region_from ~= branch_region_to));