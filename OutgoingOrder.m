classdef OutgoingOrder < handle
    properties
        Time;
        Amount;
    end
    methods
        function obj = OutgoingOrder(Time, Amount)
            arguments
                Time = 0.0;
                Amount = 22;
            end
            obj.Time = Time;
            obj.Amount = Amount;
        end
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_outgoing_order(other, obj);
        end
    end
end