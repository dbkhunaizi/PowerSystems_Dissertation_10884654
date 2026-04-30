
# PowerSystems_Dissertation_10884654

## Project Overview

This MATLAB project assesses the resilience of the IEEE 24-bus Reliability Test System under stochastic windstorm conditions. The study compares classical reliability-style metrics, such as Expected Energy Not Supplied (EENS) and Loss of Load Probability (LOLP), with event-level resilience metrics based on system performance curves.

The modelling framework combines baseline component outage modelling, windstorm-induced transmission line outages, and minimum load curtailment optimal power flow (MLC-OPF) analysis using MATPOWER.

## Software Requirements

The code requires:

- MATLAB
- MATPOWER
- IEEE 24-bus RTS case file: `base_case.m`
- Project `.m` files and saved `.mat` result files

The baseline availability function uses inverse transform sampling for exponential up/down durations. Therefore, it does not require `exprnd`. Some other scripts may use functions such as `prctile`, which can require the MATLAB Statistics and Machine Learning Toolbox.

## Main Workflow

The code is organised into separate modelling layers:

1. **Baseline availability modelling**  
   Generates chronological availability matrices for branches and generators using Sequential Monte Carlo Simulation.

2. **Windstorm modelling**  
   Creates stochastic windstorm events with different severity levels: low, medium and high.

3. **Fragility and outage modelling**  
   Converts hourly wind speeds into branch failure probabilities using wind fragility assumptions.

4. **OPF and minimum load curtailment analysis**  
   Runs hourly OPF with fictitious load-curtailment generators to calculate curtailed load.

5. **Results post-processing**  
   Calculates reliability and resilience metrics, including EENS, LOLP, Event-ENS, peak curtailment, performance curves and recovery duration.

## Key Files

| File | Purpose |
|---|---|
| `base_case.m` | IEEE 24-bus RTS case file used for power flow and OPF analysis. |
| `build_baseline_availability_8760.m` | Function that generates the 8760-hour baseline branch and generator availability matrices using a two-state Sequential Monte Carlo model. |
| `run_baseline.m` | Script that calls `build_baseline_availability_8760.m`, generates the no-storm baseline availability matrices using a fixed random seed, and saves the output as `build_baseline_8760.mat`. |
| `run_mlc_opf_hour.m` | Main hourly island-aware MLC-OPF function. It applies branch and generator outages, checks for disconnected islands, counts disconnected load as curtailed demand, adds fictitious load-curtailment generators, and runs AC OPF. |
| `run_baseline_8760_with_mlc.m` | Final baseline yearly assessment script. It runs the 8760-hour no-storm baseline case by calling `run_mlc_opf_hour.m` for each hour and saves `baseline_mlc_results_8760.mat`. |
| `run_baseline_8760_opf.m` | Earlier/alternative baseline OPF implementation with built-in curtailment generator and disconnected-demand logic. It is kept for traceability, but the final island-aware workflow uses `run_baseline_8760_with_mlc.m` and `run_mlc_opf_hour.m`. |
| `smcs_row.m` | Generates one chronological up/down availability sequence for a component. |
| `set_regions_ieee24.m` | Assigns IEEE 24-bus system buses and branches into simplified regions. |
| `build_single_storm.m` | Generates stochastic windstorm events for each severity level and combines baseline and storm-induced branch outages into `A_total_branch`. |
| `resilience_results_single.m` | Runs the full 8760-hour storm resilience assessment for one storm severity and Monte Carlo iteration using `run_mlc_opf_hour.m`. |

## Input Files

The main input files are:

| File | Description |
|---|---|
| `base_case.m` | IEEE 24-bus Reliability Test System used for power flow and OPF analysis. |
| `build_baseline_8760.mat` | Baseline branch and generator availability matrices used in the yearly baseline and storm resilience simulations. |
| `set_regions_ieee24.mat` | Saved regional mapping for the IEEE RTS-24 system. |
| `storm_result_low_mc*.mat` | Low-severity storm outage results. |
| `storm_result_medium_mc*.mat` | Medium-severity storm outage results. |
| `storm_result_high_mc*.mat` | High-severity storm outage results. |

## Main Output Files

The code produces output files such as:

| File | Description |
|---|---|
| `baseline_mlc_results_8760.mat` | Final baseline 8760-hour MLC-OPF results under no storm-induced outages. |
| `yearly_resilience_low_mc*.mat` | Annual OPF and load-curtailment results for low-severity Monte Carlo simulations. |
| `yearly_resilience_medium_mc*.mat` | Annual OPF and load-curtailment results for medium-severity Monte Carlo simulations. |
| `yearly_resilience_high_mc*.mat` | Annual OPF and load-curtailment results for high-severity Monte Carlo simulations. |
| `summary_low_allruns.mat` | Summary of annual EENS and LOLP across all low-severity Monte Carlo runs. |
| `summary_medium_allruns.mat` | Summary of annual EENS and LOLP across all medium-severity Monte Carlo runs. |
| `summary_high_allruns.mat` | Summary of annual EENS and LOLP across all high-severity Monte Carlo runs. |
| `event_summary_low.mat` | Event-level summary file used to identify the highest Event-ENS case across the low-severity Monte Carlo runs. |
| `event_summary_medium.mat` | Event-level summary file used to identify the highest Event-ENS case across the medium-severity Monte Carlo runs. |
| `event_summary_high.mat` | Event-level summary file used to identify the highest Event-ENS case across the high-severity Monte Carlo runs. |
| `storm_summary_low.mat` | Stores windstorm/GPD parameter information for the low-severity storm case. |
| `storm_summary_medium.mat` | Stores windstorm/GPD parameter information for the medium-severity storm case. |
| `storm_summary_high.mat` | Stores windstorm/GPD parameter information for the high-severity storm case. |
| `worstevent_metrics_<severity>_mc<run>.mat` | Event-level trapezoid resilience metrics for the selected worst-event run in each severity class. |

The `*` symbol represents the Monte Carlo run number. For example:

```matlab
yearly_resilience_low_mc1.mat
yearly_resilience_low_mc10.mat
yearly_resilience_high_mc16.mat
```

The `<severity>` and `<run>` labels are placeholders. For example:

```matlab
worstevent_metrics_low_mc10.mat
worstevent_metrics_medium_mc2.mat
worstevent_metrics_high_mc16.mat
```

## Variables Stored in `baseline_mlc_results_8760.mat`

The file `baseline_mlc_results_8760.mat` stores the final no-storm baseline MLC-OPF results.

| Variable | Description |
|---|---|
| `opf_success` | Logical array showing whether the OPF solved successfully in each hour. |
| `total_curtail_hourly` | Hourly total curtailed load across the 8760-hour baseline simulation. |
| `disconnected_curtail` | Hourly curtailment assigned to disconnected load when islands occur. |
| `n_branch_out_hourly` | Number of unavailable branches in each hour. |
| `n_gen_out_hourly` | Number of unavailable generators in each hour. |
| `hours_successful` | Number of hours where the OPF solved successfully. |
| `hours_failed` | Number of hours where the OPF did not solve successfully. |
| `success_rate` | Share of hours where the OPF solved successfully. |
| `hours_curtailed` | Number of hours with non-zero load curtailment. |
| `LOLP_baseline` | Baseline Loss of Load Probability. |
| `ENS_MWh` | Baseline Energy Not Supplied in MWh. |
| `max_curtail_MW` | Maximum hourly curtailment in MW. |
| `mean_curtail_ifany` | Mean curtailed load during hours with curtailment. |
| `total_branch_outage_hours` | Total number of branch outage-hours across the baseline year. |
| `mean_branches_out_per_hour` | Average number of unavailable branches per hour. |
| `mean_branches_out_failed_hours` | Mean number of unavailable branches during failed OPF hours. |
| `max_branches_out_failed_hours` | Maximum number of unavailable branches during failed OPF hours. |
| `failed_hours_baseline` | List of baseline hours where the OPF failed or was unresolved. |
| `voll` | Value of Lost Load used in the MLC-OPF model. |
| `curtail_tol` | Curtailment tolerance used to remove very small numerical values. |
| `T` | Number of simulated hours, usually 8760. |

## Variables Stored in `yearly_resilience_<severity>_mc*.mat`

Each `yearly_resilience_<severity>_mc*.mat` file stores the annual OPF and curtailment results for one storm Monte Carlo run.

| Variable | Description |
|---|---|
| `total_curtail_hourly` | Hourly total curtailed load across the 8760-hour simulation year. |
| `disconnected_curtail` | Hourly curtailment assigned to disconnected load when islands occur. |
| `opf_success` | Logical array showing whether the OPF solved successfully in each hour. |
| `ENS_case` | Total annual Energy Not Supplied for that Monte Carlo run, in MWh. |
| `LOLP_case` | Annual Loss of Load Probability for that Monte Carlo run. |
| `hours_with_curtail` | Number of hours in the year where load curtailment occurred. |
| `n_failed_hours` | Number of hours where the OPF did not solve successfully. |
| `max_hourly_curtail` | Maximum load curtailed in any single hour, in MW. |
| `failed_hours_case` | List of hours where the OPF failed or was unresolved. |
| `n_branch_out_hourly` | Number of unavailable branches in each hour. |
| `n_gen_out_hourly` | Number of unavailable generators in each hour. |
| `total_branch_outage_hours` | Total number of branch outage-hours across the year. |
| `mean_branches_out_per_hour` | Average number of unavailable branches per hour. |
| `mean_branches_out_failed_hours` | Mean number of unavailable branches during failed OPF hours. |
| `max_branches_out_failed_hours` | Maximum number of unavailable branches during failed OPF hours. |
| `voll` | Value of Lost Load used in the MLC-OPF model. |
| `curtail_tol` | Curtailment tolerance used to remove very small numerical values. |
| `T` | Number of simulated hours, usually 8760. |

## Variables Stored in `event_summary_<severity>.mat`

Each `event_summary_<severity>.mat` file stores event-level results across the Monte Carlo realisations for one windstorm severity class. These files are used to select the worst event based on the highest Event-ENS.

| Variable | Description |
|---|---|
| `Annual_EENS_all` | Annual EENS value for each Monte Carlo run. |
| `Event_ENS_all` | Event-ENS value for each Monte Carlo run. |
| `LOLP_all` | Annual LOLP value for each Monte Carlo run. |
| `all_curtail` | Cell array containing the hourly curtailment profile for each Monte Carlo run. |
| `storm_start_all` | Storm start hour for each Monte Carlo run. |
| `storm_end_all` | Storm end hour for each Monte Carlo run. |
| `worst_curtail` | Hourly curtailment profile for the worst Event-ENS run. |
| `worst_event_ENS` | Highest Event-ENS value identified across the Monte Carlo runs. |
| `worst_event_idx` | Monte Carlo run number corresponding to the highest Event-ENS. |
| `worst_year_EENS` | Annual EENS value for the same run that produced the worst Event-ENS. |
| `worst_year_LOLP` | Annual LOLP value for the same run that produced the worst Event-ENS. |

## Variables Stored in Storm Result Files

Storm result files may contain variables such as:

| Variable | Description |
|---|---|
| `A_total_branch` | Final branch availability matrix after combining baseline and storm-induced outages. |
| `storm_start_hour` | Starting hour of the storm event. |
| `storm_end_hour` | Ending hour of the storm event. |
| `storm_path` | Regional path followed by the storm. |
| `w_peak` | Peak wind speed sampled for the storm. |

The baseline and storm-induced branch availability matrices are combined in `build_single_storm.m` using a logical AND operation:

```matlab
A_total_branch = A_branch & A_storm_branch;
```

This means that a branch is considered available only if it is available under both the baseline outage model and the storm-induced outage model.

## Variables Stored in Event-Selected Trapezoid Metric Files

The `worstevent_metrics_<severity>_mc<run>.mat` files store the event-level resilience metrics for the selected worst event in each severity class. The selected event is based on the Monte Carlo run with the highest Event-ENS.

| Variable | Description |
|---|---|
| `event_ENS` | Energy not supplied during the selected storm event. |
| `peak_curtail` | Maximum hourly load curtailment during the selected storm event. |
| `phi` | Pre-disturbance performance level. |
| `min_perf` | Minimum system performance reached during the event. |
| `Lambda` | Degradation time from the first performance drop to the minimum performance point. |
| `Pi` | Recovery time from the minimum performance point back to the pre-disturbance performance level. |
| `E` | Area of performance loss during the selected event. |
| `storm_start` | Start hour of the selected storm event. |
| `storm_end` | End hour of the selected storm event. |
| `worst_event_idx` | Monte Carlo run number corresponding to the selected worst event. |
| `annual_EENS` | Annual EENS value for the same Monte Carlo run. |
| `annual_LOLP` | Annual LOLP value for the same Monte Carlo run. |

## Results Processing Files

| File | Purpose |
|---|---|
| `analyze_worst_case.m` | Plots the worst-event resilience performance curve for a selected severity case. It loads `event_summary_<severity>.mat`, uses the Monte Carlo run with the highest Event-ENS, calculates the performance curve, and marks the storm window, minimum performance point, degradation phase and recovery phase. |
| `analyze_severity_cases.m` | Loads the 20 annual resilience result files for a selected severity class, calculates summary statistics for EENS and LOLP, identifies the worst annual EENS run, and saves the results in `summary_<severity>_allruns.mat`. |
| `four_char_trap_metric.m` | Calculates the main trapezoid-based resilience characteristics for the worst event in a selected severity class: minimum performance, degradation time, recovery time and area of performance loss. It also reports Event-ENS, annual EENS, annual LOLP and peak curtailment for the same Monte Carlo run. |
| `divergence_plot.m` | Compares annual ENS with worst-event ENS for the selected worst-event Monte Carlo run in each severity class. It produces an overlaid bar chart showing how much of the annual ENS is caused by the worst storm event. |
| `comparison_graph.m` | Compares baseline, low-, medium- and high-severity cases using annual EENS and LOLP. It loads the summary files for each severity class, calculates the mean and standard deviation, and produces bar charts with error bars. |

## Notes on Results Processing

The results processing scripts are used after the main simulations have been completed. They do not create new outage scenarios or rerun the OPF model. Instead, they load saved `.mat` result files and calculate summary statistics, resilience metrics and dissertation figures.

The severity class is usually selected manually inside the relevant script using:

```matlab
severity = 'low';   % change to 'medium' or 'high' as needed
```

## How to Run the Code

Run the scripts in the following order.

### 1. Set up MATPOWER

Before running the project scripts, add MATPOWER to the MATLAB path:

```matlab
addpath(genpath('path_to_matpower'));
define_constants;
```

Replace `path_to_matpower` with the location of the MATPOWER folder on your own computer.

### 2. Open the project folder

Open the main project folder in MATLAB. This should be the folder that contains the README file and the main `.m` scripts.

Then run:

```matlab
addpath(genpath(pwd));
```

This adds the current project folder and all subfolders to the MATLAB path.

### 3. Generate the baseline availability matrix

Run:

```matlab
run_baseline
```

This script loads the IEEE RTS-24 case, sets the random seed, and calls:

```matlab
[A_branch, A_gen, A_master, info] = build_baseline_availability_8760(mpc, seed);
```

The output is saved as:

```matlab
build_baseline_8760.mat
```

This file contains:

- `A_branch`: branch availability matrix over 8760 hours
- `A_gen`: generator availability matrix over 8760 hours
- `A_master`: combined branch and generator availability matrix
- `info`: summary information about the baseline simulation

### 4. Run the baseline MLC-OPF assessment

Run:

```matlab
run_baseline_8760_with_mlc
```

This is the final baseline assessment script. It loads the baseline availability matrices, loops through the 8760 simulation hours, and calls:

```matlab
run_mlc_opf_hour
```

to calculate hourly load curtailment using the island-aware MLC-OPF method.

The output is saved as:

```matlab
baseline_mlc_results_8760.mat
```

### 5. Define the RTS-24 network regions

Run:

```matlab
set_regions_ieee24
```

This assigns the IEEE RTS-24 buses and branches into simplified regions used for the windstorm movement model.

### 6. Generate storm outage files

Run:

```matlab
build_single_storm
```

Inside the script, select the required severity case:

```matlab
severity = 'low';   % change to 'medium' or 'high'
```

This creates storm outage files such as:

```matlab
storm_result_low_mc1.mat
storm_result_medium_mc1.mat
storm_result_high_mc1.mat
```

Repeat this step for the required Monte Carlo runs and severity classes.

### 7. Run the yearly storm resilience OPF assessment

Run:

```matlab
resilience_results_single
```

This script applies the branch and generator availability matrices hour-by-hour and calls:

```matlab
run_mlc_opf_hour
```

to run the hourly minimum load curtailment OPF assessment.

The output is saved as:

```matlab
yearly_resilience_<severity>_mc<run>.mat
```

For example:

```matlab
yearly_resilience_low_mc10.mat
```

### 8. Summarise annual reliability metrics

Run:

```matlab
analyze_severity_cases
```

This loads the 20 yearly resilience files for a selected severity class and calculates summary statistics for annual EENS and LOLP. The output is saved as:

```matlab
summary_<severity>_allruns.mat
```

### 9. Analyse the worst-event case

Run:

```matlab
analyze_worst_case
```

This plots the resilience performance curve for the worst Event-ENS run in the selected severity class.

Then run:

```matlab
four_char_trap_metric
```

This calculates the trapezoid-based resilience metrics for the selected worst event.

### 10. Generate comparison plots

Run:

```matlab
divergence_plot
comparison_graph
```

These scripts generate comparison figures for the dissertation, including annual ENS versus worst-event ENS and baseline-versus-storm reliability metric comparisons.

## Main Metrics

The main annual reliability-style metrics are:

- Expected Energy Not Supplied (EENS)
- Loss of Load Probability (LOLP)

The main event-level resilience metrics are:

- Event-ENS
- Event-LOLP
- Peak load curtailment
- Minimum performance
- Degradation time
- Recovery time
- Area of performance loss

System performance is calculated as:

```matlab
Performance = 1 - total_curtailment / total_demand;
```

For the IEEE 24-bus RTS, the total demand is:

```matlab
Pd_total = 2850;
```

## Key Modelling Assumptions

- The IEEE RTS-24 system does not include real geographical coordinates, so the network is divided into simplified regions.
- Windstorm-induced outages are applied only to wind-exposed transmission line branches.
- Transformer branches are excluded from the wind fragility model.
- Generator outages are included through the baseline availability matrix and are not directly affected by storm fragility.
- Load curtailment is represented using fictitious generators with a high Value of Lost Load.
- The island-aware OPF method counts load outside the main energised island as disconnected curtailment.
- The study compares annual reliability-style metrics with event-level resilience metrics.
- Monte Carlo results should be interpreted as indicative probabilistic outcomes rather than fully converged estimates.

## Notes on Code Development

The code was developed in separate layers rather than as one large script. The main layers were baseline reliability modelling, windstorm generation, fragility and outage modelling, OPF assessment, and results post-processing.

Each layer was tested and debugged before being integrated with the next stage. Intermediate outputs such as outage matrices, storm timings, OPF success rates and curtailment values were checked regularly to reduce errors and improve traceability.

## Author

Prepared as part of an undergraduate dissertation on power system resilience assessment under stochastic windstorm conditions.
