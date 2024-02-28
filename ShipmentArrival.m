classdef ShipmentArrival < Event
    % ShipmentArrival An event representing the arrival of a shipment.
    properties
        % Amount The amount of material contained in this shipment.
        % The default value is one unit.
        Amount = 1;
    end
    methods
        function obj = ShipmentArrival(KWArgs)
            % ShipmentArrival Constructor.
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
            % visit Call handle_shipment_arrival.
            [varargout{1:nargout}] = handle_shipment_arrival(other, obj);
        end
    end
end