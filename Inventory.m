classdef Inventory < handle
    % Inventory Simulation of an inventory system.
    %   Simulation object that keeps track of orders, incoming material,
    %   outoing material, material on hand, and costs.
    %
    %   Some jargon: A _request_ for material means that the entity modeled
    %   by this object orders a batch of material from a supplier, and it
    %   will replenish this inventory. An _order_ for material means that a
    %   customer orders material, and that order will be filled out of this
    %   inventory.
    % 
    %   Each time step represents one day during which orders
    %   arrive and are filled.  When the on-hand amount drops below a
    %   thresholds, a request is placed for 

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

        % Log - Table of log entries.  The columns are:
        % * Time - Time of the entry
        % * OnHand - Amount of material on hand
        % * Backlog - Total amount of all backlogged orders
        % * RunningCost - Total cost incurred up to that time
        Log = table( ...
            Size=[0, 4], ...
            VariableNames={'Time', 'OnHand', 'Backlog', 'RunningCost'}, ...
            VariableTypes={'double', 'double', 'double', 'double'});

        % RunningCost - Total cost incurred so far.
        RunningCost = 0.0;

        % Backlog - List of backlogged orders.
        Backlog = {};

        % Fulfilled - List of fulfilled orders.
        Fulfilled = {};
    end
    methods
        function obj = Inventory(KWArgs)
            % Inventory Constructor.
            % Public properties can be specified as named arguments.
            arguments
                KWArgs.?Inventory;
            end
            fnames = fieldnames(KWArgs);
            for ifield=1:length(fnames)
                s = fnames{ifield};
                obj.(s) = KWArgs.(s);
            end
            % Events has to be initialized in the constructor.
            obj.Events = PriorityQueue({}, @(x) x.Time);

            % The first event is to begin the first day.
            schedule_event(obj, BeginDay(Time=0));
        end

        function obj = run_until(obj, MaxTime)
            % run_until Event loop.
            %
            % obj = run_until(obj, MaxTime) Repeatedly handle the next
            % event until the current time is at least MaxTime.

            while obj.Time <= MaxTime
                handle_next_event(obj)
            end
        end

        function schedule_event(obj, event)
            % schedule_event Add an event object to the event queue.

            assert(event.Time >= obj.Time, ...
                "Event happens in the past");
            push(obj.Events, event);
        end

        function handle_next_event(obj)
            % handle_next_event Pop the next event and use the visitor
            % mechanism on it to do something interesting.

            assert(~is_empty(obj.Events), ...
                "No unhandled events");
            event = pop_first(obj.Events);
            assert(event.Time >= obj.Time, ...
                "Event happens in the past");
            obj.Time = event.Time;
            visit(event, obj);
        end

        function handle_begin_day(obj, ~)
            % handle_begin_day Generate random orders that come in today.
            %
            % handle_begin_day(obj, begin_day_event) - Handle a BeginDay
            % event.  Generate a random number of orders of random sizes
            % that arrive at uniformly spaced times during the day.  Each
            % is represented by an OutgoingOrder event and added to the
            % event queue.  Also schedule the EndDay event for the end of
            % today, and the BeginDay event for the beginning of tomorrow.
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
                order = obj.Backlog{j};
                order.Time = obj.Time;
                schedule_event(obj, order);
            end
            obj.Backlog = {};
            obj.RequestPlaced = false;
        end

        function maybe_request_more(obj)
            % maybe_request_more If the amount of material on-hand is below
            % the ReorderLevel, place a request for more.
            % 
            % If a request has been placed but not yet fulfilled, no
            % additional request is placed.

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
            % handle_outgoing_order Handle an OutgoingOrder event.
            %
            % handle_outgoing_order(obj, order) - If there is enough
            % material on hand to fulfill the order, deduct the Amount of
            % the order from OnHand, and append the order to the Fulfilled
            % list.  Otherwise, append the order to the Backlog list.
            % Then call maybe_request_more.  There is no attempt to
            % partially fill an order.
            if obj.OnHand >= order.Amount
                obj.OnHand = obj.OnHand - order.Amount;
                obj.Fulfilled{end+1} = order;
            else
                obj.Backlog{end+1} = order;
            end
            maybe_request_more(obj);
        end

        function handle_end_day(obj, ~)
            % handle_end_day Handle an EndDay event.
            %
            % handle_end_day(obj, end_day) - Record holding cost for the
            % amount of material on hand.  Record shortage cost for the
            % total amount of all backlogged orders.  Record an entry to
            % the Log table.  Schedule the beginning of the next day to
            % happen immediately.
            % 
            % *Note:* There is no separate RecordToLog event in this
            % simulation like there is in ServiceQueue.

            obj.RunningCost = obj.RunningCost ...
                + obj.OnHand * obj.HoldingCostPerUnitPerTimeStep;
            obj.RunningCost = obj.RunningCost ...
                + total_backlog(obj) * obj.ShortageCostPerUnitPerTimeStep;
            record_log(obj);
            % Schedule the beginning of the next day to happen immediately.
            schedule_event(obj, BeginDay(Time=obj.Time));
        end

        function tb = total_backlog(obj)
            % total_backlog Compute the total amount of all backlogged
            % orders.
            tb = 0;
            for j = 1:length(obj.Backlog)
                tb = tb + obj.Backlog{j}.Amount;
            end
        end

        function record_log(obj)
            % record_log Add an entry to the Log table.
            tb = total_backlog(obj);
            obj.Log(end+1, :) = {obj.Time, obj.OnHand, tb, obj.RunningCost};
        end
    end
end
