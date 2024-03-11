%% Run samples of the Inventory simulation
%
% Collect statistics and plot histograms along the way.

%% Set up

% How many samples of the simulation to run.
NumSamples = 100;

% Run each sample for this many days.
MaxTime = 1000;

% Samples are stored in this cell array of Inventory objects
InventorySamples = cell([NumSamples, 1]);

% The final running cost of each sample is collected in this array.
TotalCosts = zeros([NumSamples, 1]);

%% Run simulation samples

% Make this reproducible
rng("default");

% Run samples of the simulation.
% Log entries are recorded at the end of every day

for j = 1:NumSamples
    inventory = Inventory( ...
        OnHand=200, ...
        ReorderPoint=50, ...
        RequestBatchSize=200);
    run_until(inventory, MaxTime);
    InventorySamples{j} = inventory;
    TotalCosts(j) = inventory.RunningCost;
end

%% Make pictures

% Make a figure with one set of axes.
fig = figure();
t = tiledlayout(fig,1,1);

ax = nexttile(t);

% Histogram of the running costs per day.
h = histogram(ax, TotalCosts/MaxTime, Normalization="probability");

% Easiest way I've found to save a figure as a PDF file
exportgraphics(fig, "Daily cost histogram.pdf");

meanDailyCost = mean(TotalCosts/MaxTime);
