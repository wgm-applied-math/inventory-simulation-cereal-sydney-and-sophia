function inventory = test_Inventory()
    inventory = Inventory(OnHand=600);
    while inventory.Time < 100.0
        handle_next_event(inventory);
    end
end