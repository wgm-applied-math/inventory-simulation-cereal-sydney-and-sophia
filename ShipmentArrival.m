classdef ShipmentArrival < handle
    properties
        Time;
        Amount;
    end
    methods
        function obj = ShipmentArrival(Time, Amount)
            arguments
                Time = 0.0;
                Amount = 600;
            end
            obj.Time = Time;
            obj.Amount = Amount;
        end
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_shipment_arrival(other, obj);
        end
    end
end