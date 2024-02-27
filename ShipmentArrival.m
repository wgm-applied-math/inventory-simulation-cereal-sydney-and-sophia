classdef ShipmentArrival < Event
    properties
        Amount = 1;
    end
    methods
        function obj = ShipmentArrival(KWArgs)
            % ShipmentArrival ShipmentArrival constructor.
            % Public properties can be specified as named arguments.
            arguments
                KWArgs.?ShipmentArrival;
            end
            fnames = fieldnames(KWArgs);
            for ifield=1:length(fnames)
                s = fnames{ifield};
                obj.(s) = KWArgs.(s);
            end
        end
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_shipment_arrival(other, obj);
        end
    end
end