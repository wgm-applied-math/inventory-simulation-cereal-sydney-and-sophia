classdef Inventory < handle
    % Inventory Simulation of an inventory system.
    %   Simulation object that keeps track of orders, incoming material,
    %   outoing material, and material on hand. Also keeps track of costs.
    %   Some jargon: A _request_ for material means that the entity modeled
    %   by this object orders a batch of material from a supplier, and it
    %   will replenish this inventory. An _order_ for material means that a
    %   customer orders material, and that order will be filled out of this
    %   inventory.

    properties (SetAccess = public)
        % OnHand - Amount of material on hand
        OnHand = 0.0;

        % RequestCostPerBatch - Fixed cost to request a batch of material,
        % independent of the size of the batch.
        RequestCostPerBatch = 25.0;

        % RequestCostPerUnit - Variable cost factor; cost of each unit
        % requested in a batch.
        RequestCostPerUnit = 3.0;

        % HoldingCostPerUnitPerTimeStep - Cost to hold one unit of material
        % on hand for one time step.
        HoldingCostPerUnitPerTimeStep = 0.05/7;

        % ShortageCostPerUnitPerTimeStep - Cost factor for a backlogged
        % order; how much it costs to be one unit short for one time step.
        ShortageCostPerUnitPerTimeStep = 2.00/7;

        % RequestBatchSize - When requesting a batch of material, how many
        % units to request in a batch.
        RequestBatchSize = 600;

        % ReorderLevel - When the amount of material on hand drops to this
        % many units, request another batch.
        ReorderLevel = 200;

        % IncomingLeadTime - When a batch is requested, it will be this
        % many time step before the batch arrives.
        IncomingLeadTime = 2.0;

        % OutgoingSizeDist - Distribution sampled to determine the size of
        % random outgoing orders placed to this inventory.
        OutgoingSizeDist = makedist("Gamma", a=10, b=2);

        % OutgoingCountDist - Distribution sampled to determine the number
        % of random outgoing orders placed to this inventory per time step.
        OutgoingCountDist = makedist("Poisson", lambda=4);
    end
    properties (SetAccess = private)
        % Time - Current time
        Time = 0.0;

        % RequestPlaced - True if a request has been made for a batch of
        % material to replenish this inventory, but has not yet arrived.
        % False if the inventory is not waiting for a request to be
        % fulfilled. If a request has been placed, no additional request
        % will be placed until it has been fulfilled.
        RequestPlaced = false;

        % Events - PriorityQueue of events ordered by time.
        Events;

        % Log - Table of log entries.
        Log;

        % RunningCost - Total cost incurred so far.
        RunningCost = 0.0;

        % Backlog - List of backlogged orders.
        Backlog = {};

        % Fulfilled - List of fulfilled orders.
        Fulfilled = {};
    end
    methods
        function obj = Inventory(KWArgs)
            % Inventory constructor.
            % Public properties can be specified as named arguments.
            arguments
                KWArgs.?Inventory;
            end
            fnames = fieldnames(KWArgs);
            for ifield=1:length(fnames)
                s = fnames{ifield};
                obj.(s) = KWArgs.(s);
            end
            obj.Events = PriorityQueue({}, @(x) x.Time);
            obj.Log = table( ...
                Size=[0, 4], ...
                VariableNames={'Time', 'OnHand', 'Backlog', 'RunningCost'}, ...
                VariableTypes={'double', 'double', 'double', 'double'});
            schedule_event(obj, BeginDay(Time=0));
        end

        function obj = run_until(obj, MaxTime)
            % run_until Event loop.
            %
            % obj = run_until(obj, MaxTime) Repeatedly handle the next
            % event until the current time is at least MaxTime.

            while obj.Time < MaxTime
                handle_next_event(obj)
            end
        end

        function schedule_event(obj, event)
            % schedule_event Add an event object to the event queue.

            if event.Time < obj.Time
                error('event happens in the past');
            end
            push(obj.Events, event);
        end

        function handle_next_event(obj)
            % handle_next_event Pop the next event and use the visitor
            % mechanism on it to do something interesting.

            if is_empty(obj.Events)
                error('no unhandled events');
            end
            event = pop_first(obj.Events);
            if obj.Time > event.Time
                error('event happened in the past');
            end
            obj.Time = event.Time;
            visit(event, obj);
        end

        function handle_begin_day(obj, ~)
            % handle_begin_day Generate random orders that come in today.
            %
            % handle_begin_day(obj, begin_day_event) - Handle a
            % BeginDay event.  Generate a random number of orders
            % of random sizes that arrive at uniformly spaced
            % times during the day.  Each is represented by an
            % OutgoingOrder event and added to the event queue.
            % Also schedule the EndDay event for the end of today, and
            % the BeginDay event for the beginning of tomorrow.

            n_orders = random(obj.OutgoingCountDist);
            for j=1:n_orders
                amount = random(obj.OutgoingSizeDist);
                order_received_time = obj.Time+j/(1+n_orders);
                event = OutgoingOrder( ...
                    Time=order_received_time, ...
                    Amount=amount, ...
                    OriginalTime=order_received_time);
                schedule_event(obj, event);
            end
            % Schedule the end of the day
            schedule_event(obj, EndDay(Time=obj.Time+0.99));
            % Schedule the beginning of the next day
            schedule_event(obj, BeginDay(Time=obj.Time+1));
            record_log(obj);
        end

        function handle_shipment_arrival(obj, arrival)
            % handle_shipment_arrival A shipment has arrived in response to
            % a request.
            %
            % handle_shipment_arrival(obj, arrival_event) - Handle a
            % ShipmentArrival event.  Add the amount of material in this
            % shipment to the on-hand amount.  Reschedule all backlogged
            % orders to run immediately.  Set RequestPlaced to false.

            % Add received amount to on-hand amount.
            obj.OnHand = obj.OnHand + arrival.Amount;

            % Reschedule all the backlogged orders for right now.
            for j=1:length(obj.Backlog)
                retry_order = reschedule(obj.Backlog{j}, obj.Time);
                schedule_event(obj, retry_order);
            end
            obj.Backlog = {};
            obj.RequestPlaced = false;
        end

        function maybe_order_more(obj)
            % maybe_order_more 
            if ~obj.RequestPlaced && obj.OnHand <= obj.ReorderLevel
                order_cost = obj.RequestCostPerBatch ...
                    + obj.RequestBatchSize * obj.RequestCostPerUnit;
                obj.RunningCost = obj.RunningCost + order_cost;
                arrival = ShipmentArrival( ...
                    Time=obj.Time+obj.IncomingLeadTime, ...
                    Amount=obj.RequestBatchSize);
                schedule_event(obj, arrival);
                obj.RequestPlaced = true;
            end
        end

        function handle_outgoing_order(obj, order)
            if obj.OnHand >= order.Amount
                obj.OnHand = obj.OnHand - order.Amount;
                obj.Fulfilled{end+1} = order;
            else
                obj.Backlog{end+1} = order;
            end
            maybe_order_more(obj);
        end

        function handle_end_day(obj, ~)
            if obj.OnHand >= 0
                obj.RunningCost = obj.RunningCost ...
                    + obj.OnHand * obj.HoldingCostPerUnitPerTimeStep;
            end
            obj.RunningCost = obj.RunningCost ...
                + total_backlog(obj) * obj.ShortageCostPerUnitPerTimeStep;
            record_log(obj);
        end

        function tb = total_backlog(obj)
            tb = 0;
            for j = 1:length(obj.Backlog)
                tb = tb + obj.Backlog{j}.Amount;
            end
        end

        function record_log(obj)
            tb = total_backlog(obj);
            obj.Log(end+1, :) = {obj.Time, obj.OnHand, tb, obj.RunningCost};
        end
    end
end
