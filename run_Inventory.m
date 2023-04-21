function [inventories, running_costs] = run_Inventory(NSamples)
    inventories = {};
    running_costs = zeros([1, NSamples]);
    for j = 1:NSamples
        inventory = Inventory(OnHand=600, ReorderLevel=50, RequestBatchSize=100);
        while inventory.Time < 100.0
            handle_next_event(inventory);
        end
        inventories{j} = inventory;
        running_costs(j) = inventory.RunningCost;
    end
end