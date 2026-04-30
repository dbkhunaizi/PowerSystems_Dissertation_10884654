% Aim: To Generate the baseline Case from the script
% build_baseline_availbility_8760 

clear; clc;
define_constants;
mpc = loadcase('case24_ieee_rts');

seed = 1;  % choose any number (same seed = same results)
[A_branch, A_gen, A_master, info] = build_baseline_availability_8760(mpc, seed);

disp(info)

save('baseline_ieee24_random.mat', 'A_branch', 'A_gen', 'A_master', 'info');
disp('Saved baseline_ieee24_random.mat');