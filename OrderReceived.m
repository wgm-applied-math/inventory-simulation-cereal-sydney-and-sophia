classdef OrderReceived < Event
    % OrderReceived Event the represents the arrival of an outgoing order.

    properties

        % Amount - Amount of material being ordered.
        Amount = 1;

        % OriginalTime - The time this order was originally received. The
        % Time property, inherited from Event, is updated by
        % Inventory.handle_shipment_arrived when a backlogged order is
        % rescheduled, so its final value represents the time at which the
        % order was actually fulfilled.
        OriginalTime = 0;
    end
    methods
        function obj = OrderReceived(KWArgs)
            % OrderReceived Constructor.
            % Public properties can be specified as named arguments.
            arguments
                KWArgs.?OrderReceived;
            end
            fnames = fieldnames(KWArgs);
            for ifield=1:length(fnames)
                s = fnames{ifield};
                obj.(s) = KWArgs.(s);
            end
        end
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_order_received(other, obj);
        end
    end
end