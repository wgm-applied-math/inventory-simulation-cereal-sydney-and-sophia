%% Run samples of the Inventory simulation
%
% Collect statistics and plot histograms along the way.

%% Set up

% How many samples of the simulation to run.
NumSamples = 100;

% Run each sample for this many days.
MaxTime = 100;

% Samples are stored in this cell array of Inventory objects
InventorySamples = cell([NumSamples, 1]);

% The final running cost of each sample is collected in this array.
TotalCosts = zeros([NumSamples, 1]);

%% Run simulation samples

% Run samples of the simulation.
% Log entries are recorded at the end of every day

for j = 1:NumSamples
    inventory = Inventory( ...
        OnHand=600, ...
        ReorderLevel=100, ...
        RequestBatchSize=300);
    run_until(inventory, MaxTime);
    InventorySamples{j} = inventory;
    TotalCosts(j) = inventory.RunningCost;
end

%% Make pictures

% Make a figure with one set of axes.
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);

% MATLAB-ism: Once you've created a picture, you can use "hold on" to cause
% further plotting function to work with the same picture rather than
% create a new one.
hold(ax, 'on');

% Start with a histogram of the running costs at the end of MaxTime days.
h = histogram(ax, TotalCosts, Normalization="probability");

% Easiest way I've found to save a figure as a PDF file
exportgraphics(fig, "Total cost histogram.pdf");