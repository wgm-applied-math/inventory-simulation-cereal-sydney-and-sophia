classdef Inventory < handle
    properties (SetAccess = public)
        Time = 0.0;
        OnHand = 0.0;
        RequestCostPerBatch = 25.0;
        RequestCostPerUnit = 3.0;
        HoldingCostPerUnitPerTimeStep = 0.05/7;
        ShortageCostPerUnitPerTimeStep = 2.00/7;
        RequestBatchSize = 600;
        ReorderLevel = 200;
        OutgoingSizeDist = makedist("Gamma", a=10, b=2);
        OutgoingCountDist = makedist("Poisson", lambda=4);
        IncomingLeadTime = 2.0;
    end
    properties (SetAccess = private)
        IncomingOrderPlaced = false;
        Events;
        Log;
        RunningCost = 0.0;
        Backlog = {};
        Fulfilled = {};
    end
    methods
        function obj = Inventory(KWArgs)
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
                Size=[0, 3], ...
                VariableNames={'Time', 'OnHand', 'RunningCost'}, ...
                VariableTypes={'double', 'double', 'double'});
            schedule_event(obj, BeginDay(0));
        end
        function schedule_event(obj, event)
            if event.Time < obj.Time
                error('event happens in the past');
            end
            push(obj.Events, event);
        end
        function handle_next_event(obj)
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
            % Schedule orders that come in today
            n_orders = random(obj.OutgoingCountDist);
            for j=1:n_orders
                amount = random(obj.OutgoingSizeDist);
                event = OutgoingOrder(obj.Time+(j-1)/n_orders, amount);
                schedule_event(obj, event);
            end
            % Schedule the end of the day
            schedule_event(obj, EndDay(obj.Time + 0.99));
            % Schedule the beginning of the next day
            schedule_event(obj, BeginDay(obj.Time+1));
            record_log(obj);
        end
        function handle_shipment_arrival(obj, arrival)
            obj.OnHand = obj.OnHand + arrival.Amount;
            % Reschedule all the backlogged orders for right now
            for j=1:length(obj.Backlog)
                retry_order = OutgoingOrder(obj.Time, ...
                    obj.Backlog{j}.Amount);
                schedule_event(obj, retry_order);
            end
            obj.Backlog = {};
            obj.IncomingOrderPlaced = false;
        end
        function maybe_order_more(obj)
            if ~obj.IncomingOrderPlaced && obj.OnHand <= obj.ReorderLevel
                order_cost = obj.RequestCostPerBatch ...
                    + obj.RequestBatchSize * obj.RequestCostPerUnit;
                obj.RunningCost = obj.RunningCost + order_cost;
                arrival = ShipmentArrival(obj.Time + obj.IncomingLeadTime, ...
                    obj.RequestBatchSize);
                schedule_event(obj, arrival);
                obj.IncomingOrderPlaced = true;
            end
        end
        function handle_outgoing_order(obj, order)
            if obj.OnHand >= order.Amount
                obj.OnHand = obj.OnHand - order.Amount;
                obj.Fulfilled{end+1} = order;
            else
                obj.Backlog{end+1} = order;
                maybe_order_more(obj);
            end
        end
        function handle_end_day(obj, ~)
            if obj.OnHand >= 0
                obj.RunningCost = obj.RunningCost ...
                    + obj.OnHand * obj.HoldingCostPerUnitPerTimeStep;
            end
            for j=1:length(obj.Backlog)
                obj.RunningCost = obj.RunningCost ...
                    + obj.Backlog{j}.Amount * obj.ShortageCostPerUnitPerTimeStep;
            end
            record_log(obj);
        end
        function record_log(obj)
            obj.Log(end+1, :) = {obj.Time, obj.OnHand, obj.RunningCost};
        end
    end
end